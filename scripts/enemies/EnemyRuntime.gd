extends RefCounted

const Grid = preload("res://scripts/shared/Grid.gd")
const BuildingRules = preload("res://scripts/buildings/BuildingRules.gd")

const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

static func make_enemy(enemy_defs: Dictionary, kind: String, pos: Vector2, wave: int, tile_size: int, core_pos: Vector2i, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, building_defs: Dictionary) -> Dictionary:
	var def: Dictionary = enemy_defs.get(kind, enemy_defs.grunt)
	var start := Grid.world_cell(pos, tile_size)
	var goal := core_pos + Vector2i(1, 1)
	var path := find_path(start, goal, false, terrain, buildings, map_w, map_h, core_pos, building_defs)
	var fallback := find_path(start, goal, true, terrain, buildings, map_w, map_h, core_pos, building_defs)
	var max_hp: float = float(def.hp) + wave * 4.0
	var e := {"kind": kind, "pos": pos, "hp": max_hp, "max_hp": max_hp, "attack": 0.0, "shot_timer": randf() * float(def.fire_rate), "path_timer": 0.0, "path": path, "fallback_path": fallback, "path_index": 0,
		"facing": Vector2.RIGHT, "hit_flash": 0.0, "invuln": 0.0, "spawn_anim": 0.0, "enraged": false}
	if def.has("leap"):
		e["leap_timer"] = randf_range(1.0, float(def.leap.interval))
		e["leap_left"] = 0.0
	if def.has("blink"):
		e["blink_timer"] = randf_range(0.8, float(def.blink.interval))
	if def.has("slam"):
		e["slam_timer"] = randf_range(1.0, float(def.slam.interval))
	if def.has("spawner"):
		e["spawn_timer"] = float(def.spawner.interval)
		e["spawn_made"] = 0
	if def.has("charged_shot"):
		e["charging"] = false
		e["charge_left"] = 0.0
	return e

static func speed(e: Dictionary, def: Dictionary) -> float:
	var s: float = float(def.speed)
	if e.get("enraged", false) and def.has("enrage"):
		s *= float(def.enrage.get("speed", 1.0))
	return s

static func update_path(e: Dictionary, delta: float, tile_size: int, core_pos: Vector2i, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, building_defs: Dictionary) -> void:
	e.path_timer = e.get("path_timer", 0.0) - delta
	var current := Grid.world_cell(e.pos, tile_size)
	var goal := core_pos + Vector2i(1, 1)
	if e.path_timer <= 0.0 or e.get("path", []).is_empty() or not e.path.has(current):
		var path := find_path(current, goal, false, terrain, buildings, map_w, map_h, core_pos, building_defs)
		if not path.is_empty():
			e.path = path
			e.path_index = 0
		elif e.get("path", []).is_empty():
			e.path = find_path(current, goal, true, terrain, buildings, map_w, map_h, core_pos, building_defs)
			e.path_index = 0
		e.fallback_path = find_path(current, goal, true, terrain, buildings, map_w, map_h, core_pos, building_defs)
		e.path_timer = 0.55

static func move_target(e: Dictionary, tile_size: int, core_pos: Vector2i) -> Vector2:
	var path: Array = e.get("path", [])
	if path.is_empty():
		path = e.get("fallback_path", [])
	if path.is_empty():
		return Grid.cell_center(core_pos + Vector2i(1, 1), tile_size)
	var current := Grid.world_cell(e.pos, tile_size)
	var index := int(e.get("path_index", 0))
	var current_index := path.find(current)
	if current_index >= 0:
		index = current_index
	index = clamp(index + 1, 0, path.size() - 1)
	e.path_index = index
	return Grid.cell_center(path[index], tile_size)

static func tile_passable(cell: Vector2i, ignore_player_blocks: bool, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, core_pos: Vector2i, building_defs: Dictionary) -> bool:
	if not Grid.inside(cell, map_w, map_h):
		return false
	if terrain.get(cell, "rock") == "rock":
		return false
	if Grid.cell_in_rect(cell, core_pos, Vector2i(3, 3)):
		return true
	var b = buildings.get(cell)
	if b == null or ignore_player_blocks:
		return true
	return BuildingRules.is_belt_building(building_defs, b) or b.id == "pipe"

static func blocking_building(cell: Vector2i, buildings: Dictionary, building_defs: Dictionary) -> Variant:
	var b = buildings.get(cell)
	if b == null or BuildingRules.is_belt_building(building_defs, b) or b.id == "pipe":
		return null
	return b

static func find_path(start: Vector2i, goal: Vector2i, ignore_player_blocks: bool, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, core_pos: Vector2i, building_defs: Dictionary) -> Array[Vector2i]:
	if not Grid.inside(start, map_w, map_h) or not Grid.inside(goal, map_w, map_h):
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal or Grid.cell_in_rect(current, core_pos, Vector2i(3, 3)):
			goal = current
			break
		for d in DIRS:
			var next: Vector2i = current + d
			if came_from.has(next):
				continue
			if not tile_passable(next, ignore_player_blocks, terrain, buildings, map_w, map_h, core_pos, building_defs):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var p := goal
	while p != start:
		path.push_front(p)
		p = came_from[p]
	path.push_front(start)
	return path

static func path_direction(e: Dictionary, tile_size: int, core_pos: Vector2i) -> Vector2:
	var path: Array = e.get("path", [])
	var index := int(e.get("path_index", 0))
	if path.size() > index + 1:
		return Vector2(path[index + 1] - path[index]).normalized()
	return (Grid.cell_center(core_pos + Vector2i(1, 1), tile_size) - Vector2(e.pos)).normalized()

static func target(e: Dictionary, def: Dictionary, buildings: Dictionary, active_avatar_alive: bool, active_avatar_pos: Vector2, tile_size: int, core_pos: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var path_dir := path_direction(e, tile_size, core_pos)
	if active_avatar_alive and e.pos.distance_to(active_avatar_pos) <= float(def.range):
		var to_player := (active_avatar_pos - Vector2(e.pos)).normalized()
		best = {"type": "player", "pos": active_avatar_pos}
		best_score = e.pos.distance_to(active_avatar_pos) - path_dir.dot(to_player) * 18.0
	var seen := {}
	for b in buildings.values():
		var key := "%s:%s" % [str(b.id), str(b.pos)]
		if seen.has(key):
			continue
		seen[key] = true
		if b.id == "core":
			continue
		var pos := Grid.cell_center(b.pos, tile_size)
		var dist: float = e.pos.distance_to(pos)
		if dist > float(def.range):
			continue
		var to_target := (pos - Vector2(e.pos)).normalized()
		var score: float = dist - path_dir.dot(to_target) * 28.0
		if b.id != "wall":
			score -= 52.0
		if score < best_score:
			best_score = score
			best = {"type": "building", "pos": pos, "building": b}
	return best

static func heal_aura(enemies: Array[Dictionary], healer: Dictionary, aura: Dictionary, delta: float) -> void:
	var amount: float = float(aura.get("rate", 0.0)) * delta
	var radius: float = float(aura.get("radius", 0.0))
	if amount <= 0.0 or radius <= 0.0:
		return
	for other in enemies:
		if other == healer or other.hp <= 0.0:
			continue
		if healer.pos.distance_to(other.pos) > radius:
			continue
		var cap: float = float(other.get("max_hp", other.hp))
		other.hp = min(other.hp + amount, cap)

static func update_mechanics(e: Dictionary, def: Dictionary, delta: float, enemy_defs: Dictionary, wave: int, tile_size: int, core_pos: Vector2i, terrain: Dictionary, buildings: Dictionary, map_w: int, map_h: int, building_defs: Dictionary, active_avatar_alive: bool, active_avatar_pos: Vector2) -> Dictionary:
	var events := {"effects": [], "telegraphs": [], "spawns": [], "avatar_damage": 0.0}
	e.hit_flash = max(float(e.get("hit_flash", 0.0)) - delta, 0.0)
	e.invuln = max(float(e.get("invuln", 0.0)) - delta, 0.0)
	e.spawn_anim = min(float(e.get("spawn_anim", 0.0)) + delta * 3.5, 1.0)
	if def.has("enrage") and not e.get("enraged", false):
		if e.hp <= float(e.max_hp) * float(def.enrage.get("hp", 0.5)):
			e.enraged = true
			events.effects.append(effect("burst", e.pos, float(def.get("radius", 13.0)) * 1.2, Color("#ff7a33")))
	var current_target := target(e, def, buildings, active_avatar_alive, active_avatar_pos, tile_size, core_pos)
	if def.has("blink"):
		e.blink_timer = float(e.get("blink_timer", 0.0)) - delta
		if e.blink_timer <= 0.0 and not current_target.is_empty():
			e.blink_timer = float(def.blink.interval)
			var bdir: Vector2 = (Vector2(current_target.pos) - Vector2(e.pos)).normalized()
			var from: Vector2 = e.pos
			var dest: Vector2 = Vector2(e.pos) + bdir * float(def.blink.dist)
			if tile_passable(Grid.world_cell(dest, tile_size), true, terrain, buildings, map_w, map_h, core_pos, building_defs):
				e.pos = dest
			e.invuln = float(def.blink.get("invuln", 0.4))
			events.telegraphs.append({"type": "blink", "from": from, "to": e.pos, "color": def.color, "life": 0.3, "max_life": 0.3})
	if def.has("leap") and float(e.get("leap_left", 0.0)) <= 0.0:
		e.leap_timer = float(e.get("leap_timer", 0.0)) - delta
		if e.leap_timer <= 0.0 and not current_target.is_empty():
			e.leap_timer = float(def.leap.interval)
			var ldir: Vector2 = (Vector2(current_target.pos) - Vector2(e.pos)).normalized()
			e.leap_vel = ldir * float(def.leap.speed)
			e.leap_left = float(def.leap.dur)
	if def.has("slam"):
		e.slam_timer = float(e.get("slam_timer", 0.0)) - delta
		if e.slam_timer <= 0.0 and active_avatar_alive and Vector2(e.pos).distance_to(active_avatar_pos) <= float(def.slam.radius):
			e.slam_timer = float(def.slam.interval)
			events.telegraphs.append({"type": "blast", "pos": e.pos, "radius": float(def.slam.radius), "life": 0.35, "max_life": 0.35, "color": def.color})
			if active_avatar_pos.distance_to(e.pos) <= float(def.slam.radius):
				events.avatar_damage += float(def.slam.damage)
	if def.has("spawner") and int(e.get("spawn_made", 0)) < int(def.spawner.get("max", 999)):
		e.spawn_timer = float(e.get("spawn_timer", 0.0)) - delta
		if e.spawn_timer <= 0.0:
			e.spawn_timer = float(def.spawner.interval)
			var n := int(def.spawner.get("count", 1))
			for k in n:
				var jitter := Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
				events.spawns.append(make_enemy(enemy_defs, String(def.spawner.kind), Vector2(e.pos) + jitter, wave, tile_size, core_pos, terrain, buildings, map_w, map_h, building_defs))
			e.spawn_made = int(e.get("spawn_made", 0)) + n
			events.effects.append(effect("burst", e.pos, float(def.get("radius", 14.0)) * 1.2, def.color))
	if def.has("melee") and active_avatar_alive:
		if Vector2(e.pos).distance_to(active_avatar_pos) <= float(def.get("radius", 8.0)) + float(def.melee.get("reach", 18.0)):
			events.avatar_damage += float(def.melee.dps) * delta
	return events

static func update_shooting(e: Dictionary, def: Dictionary, delta: float, buildings: Dictionary, active_avatar_alive: bool, active_avatar_pos: Vector2, tile_size: int, core_pos: Vector2i) -> Dictionary:
	var events := {"effects": [], "projectiles": []}
	if def.has("melee"):
		return events
	if def.has("charged_shot"):
		return update_charged_shot(e, def, delta, buildings, active_avatar_alive, active_avatar_pos, tile_size, core_pos)
	e.shot_timer = e.get("shot_timer", 0.0) - delta
	if e.shot_timer > 0.0:
		return events
	var current_target := target(e, def, buildings, active_avatar_alive, active_avatar_pos, tile_size, core_pos)
	if current_target.is_empty():
		return events
	var fire_mult := 1.0
	var dmg_mult := 1.0
	if e.get("enraged", false) and def.has("enrage"):
		fire_mult = float(def.enrage.get("fire", 1.0))
		dmg_mult = float(def.enrage.get("damage", 1.0))
	e.shot_timer = float(def.fire_rate) * fire_mult
	var extra := {}
	if def.has("splash"):
		extra["splash"] = float(def.splash.radius)
	events.projectiles.append(projectile(e.pos, current_target.pos, float(def.damage) * dmg_mult, float(def.bullet_speed), "enemy", float(def.spread), extra))
	return events

static func update_charged_shot(e: Dictionary, def: Dictionary, delta: float, buildings: Dictionary, active_avatar_alive: bool, active_avatar_pos: Vector2, tile_size: int, core_pos: Vector2i) -> Dictionary:
	var events := {"effects": [], "projectiles": []}
	var cs: Dictionary = def.charged_shot
	if e.get("charging", false):
		var tgt := target(e, def, buildings, active_avatar_alive, active_avatar_pos, tile_size, core_pos)
		if not tgt.is_empty():
			e.charge_aim = tgt.pos
		e.charge_left = float(e.get("charge_left", 0.0)) - delta
		if e.charge_left <= 0.0:
			e.charging = false
			e.shot_timer = float(def.fire_rate)
			var aim: Vector2 = e.get("charge_aim", Vector2(e.pos) + Vector2(e.facing) * 240.0)
			events.projectiles.append(projectile(e.pos, aim, float(cs.damage), float(cs.bullet_speed), "enemy", 0.0, {"pierce": cs.get("pierce", false), "heavy": true}))
			events.effects.append(effect("burst", e.pos, float(def.get("radius", 12.0)) * 1.0, def.color))
		return events
	e.shot_timer = float(e.get("shot_timer", 0.0)) - delta
	if e.shot_timer > 0.0:
		return events
	var current_target := target(e, def, buildings, active_avatar_alive, active_avatar_pos, tile_size, core_pos)
	if current_target.is_empty():
		return events
	e.charging = true
	e.charge_left = float(cs.get("charge", 0.8))
	e.charge_aim = current_target.pos
	return events

static func damage_enemy(e: Dictionary, def: Dictionary, amount: float, opts: Dictionary = {}) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if amount <= 0.0 or e.hp <= 0.0:
		return effects
	if float(e.get("invuln", 0.0)) > 0.0:
		effects.append(effect("hit", e.pos, float(def.get("radius", 12.0)) * 0.9, Color(0.75, 0.85, 1.0)))
		return effects
	var final := amount
	var is_dot: bool = bool(opts.get("dot", false))
	if not is_dot:
		if def.has("shield"):
			var incoming := Vector2.ZERO
			if opts.has("dir"):
				incoming = Vector2(opts.dir).normalized()
			elif opts.has("source"):
				incoming = (Vector2(e.pos) - Vector2(opts.source)).normalized()
			if incoming != Vector2.ZERO:
				var facing: Vector2 = e.get("facing", Vector2.RIGHT)
				if facing.dot(-incoming) > cos(deg_to_rad(float(def.shield.arc) * 0.5)):
					final *= (1.0 - float(def.shield.reduction))
					effects.append(effect("hit", Vector2(e.pos) - incoming * float(def.get("radius", 14.0)), float(def.get("radius", 14.0)) * 0.8, Color("#9fc0ff")))
		if def.has("armor"):
			final = max(final - float(def.armor), amount * 0.1)
	e.hp -= final
	e.hit_flash = 0.12
	if not is_dot:
		effects.append(effect("hit", e.pos, float(def.get("radius", 12.0)) * 0.8, Color(1, 1, 1)))
	return effects

static func effect(kind: String, pos: Vector2, rad: float = 12.0, color: Color = Color(1, 1, 1)) -> Dictionary:
	return {"kind": kind, "pos": pos, "t": 0.0, "dur": 0.42, "scale": rad, "color": color}

static func projectile(from_pos: Vector2, to_pos: Vector2, damage: float, speed_value: float, team := "player", spread := 0.0, extra: Dictionary = {}) -> Dictionary:
	var dir := (to_pos - from_pos).normalized()
	if spread > 0.0:
		dir = dir.rotated(randf_range(-spread, spread))
	var proj := {"pos": from_pos, "vel": dir * speed_value, "damage": damage, "life": 1.6, "team": team}
	for k in extra:
		proj[k] = extra[k]
	return proj

static func update_effects(effects: Array[Dictionary], telegraphs: Array[Dictionary], delta: float) -> void:
	var i := 0
	while i < effects.size():
		effects[i].t += delta
		if effects[i].t >= effects[i].dur:
			effects.remove_at(i)
		else:
			i += 1
	var j := 0
	while j < telegraphs.size():
		telegraphs[j].life = float(telegraphs[j].life) - delta
		if telegraphs[j].life <= 0.0:
			telegraphs.remove_at(j)
		else:
			j += 1
