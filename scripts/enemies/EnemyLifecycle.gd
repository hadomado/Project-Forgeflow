extends RefCounted

const WaveData = preload("res://scripts/enemies/WaveData.gd")
const EnemyRuntime = preload("res://scripts/enemies/EnemyRuntime.gd")

static func update_waves(wave: int, wave_timer: float, spawn_left: int, spawn_cooldown: float, max_wave: int, wave_delay: float, enemies_empty: bool, delta: float) -> Dictionary:
	# Endless waves: there is no win cap. max_wave only gates the boss roster.
	var state := {"wave": wave, "wave_timer": wave_timer, "spawn_left": spawn_left, "spawn_cooldown": spawn_cooldown, "won": false, "spawn_kind": ""}
	if spawn_left <= 0 and enemies_empty:
		state.wave_timer = float(state.wave_timer) - delta
		if float(state.wave_timer) <= 0.0:
			_start_next_wave_state(state, wave_delay)
	if int(state.spawn_left) > 0:
		state.spawn_cooldown = float(state.spawn_cooldown) - delta
		if float(state.spawn_cooldown) <= 0.0:
			state.spawn_cooldown = 1.1
			state.spawn_left = int(state.spawn_left) - 1
			state.spawn_kind = enemy_kind_for_wave(int(state.wave), max_wave)
	return state

static func force_next_wave(wave: int, wave_timer: float, spawn_left: int, spawn_cooldown: float, max_wave: int, wave_delay: float, enemies_empty: bool, won: bool, lost: bool) -> Dictionary:
	var state := {"wave": wave, "wave_timer": wave_timer, "spawn_left": spawn_left, "spawn_cooldown": spawn_cooldown, "started": false}
	if won or lost:  # endless: no wave cap, only a loss ends the run
		return state
	if spawn_left <= 0 and enemies_empty:
		_start_next_wave_state(state, wave_delay)
		state.started = true
	return state

static func start_next_wave(wave: int, wave_delay: float) -> Dictionary:
	var state := {"wave": wave, "wave_timer": wave_delay, "spawn_left": 0, "spawn_cooldown": 0.0}
	_start_next_wave_state(state, wave_delay)
	return state

static func enemy_kind_for_wave(wave: int, max_wave: int) -> String:
	return WaveData.enemy_kind_for_wave(wave, max_wave)

static func cleanup_dead(enemies: Array[Dictionary], enemy_defs: Dictionary, wave: int, tile_size: int, core_pos: Vector2i, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, building_defs: Dictionary) -> Dictionary:
	var events := {"deaths": [], "effects": [], "spawns": []}
	var i := 0
	while i < enemies.size():
		if enemies[i].hp <= 0.0:
			var e: Dictionary = enemies[i]
			var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
			events.deaths.append({"kind": e.kind, "pos": e.pos})
			events.effects.append(EnemyRuntime.effect("burst", e.pos, float(def.get("radius", 12.0)) * 1.5, def.color))
			for child in on_death_spawns(e, def, enemy_defs, wave, tile_size, core_pos, terrain, buildings, map_w, map_h, building_defs):
				events.spawns.append(child)
			enemies.remove_at(i)
		else:
			i += 1
	return events

static func on_death_spawns(e: Dictionary, def: Dictionary, enemy_defs: Dictionary, wave: int, tile_size: int, core_pos: Vector2i, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, building_defs: Dictionary) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	if not def.has("on_death_spawn"):
		return children
	var spawn: Dictionary = def.on_death_spawn
	var kind: String = String(spawn.get("kind", "swarmling"))
	var count: int = int(spawn.get("count", 0))
	for n in count:
		var jitter := Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		children.append(EnemyRuntime.make_enemy(enemy_defs, kind, Vector2(e.pos) + jitter, wave, tile_size, core_pos, terrain, buildings, map_w, map_h, building_defs))
	return children

static func _start_next_wave_state(state: Dictionary, wave_delay: float) -> void:
	state.wave = int(state.wave) + 1
	state.spawn_left = 2 + int(state.wave) * 2
	state.spawn_cooldown = 0.1
	state.wave_timer = wave_delay
