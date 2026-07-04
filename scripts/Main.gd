extends Node2D

const GameData = preload("res://scripts/shared/GameData.gd")
const BuildingData = preload("res://scripts/buildings/BuildingData.gd")
const BuildingRules = preload("res://scripts/buildings/BuildingRules.gd")
const BuildingStore = preload("res://scripts/buildings/BuildingStore.gd")
const BuildingRuntime = preload("res://scripts/buildings/BuildingRuntime.gd")
const BuildingText = preload("res://scripts/buildings/BuildingText.gd")
const BuildingPlacement = preload("res://scripts/buildings/BuildingPlacement.gd")
const EnemyData = preload("res://scripts/enemies/EnemyData.gd")
const EnemyArt = preload("res://scripts/enemies/EnemyArt.gd")
const WaveData = preload("res://scripts/enemies/WaveData.gd")
const EnemyRuntime = preload("res://scripts/enemies/EnemyRuntime.gd")
const EnemyDrawing = preload("res://scripts/enemies/EnemyDrawing.gd")
const EnemyLifecycle = preload("res://scripts/enemies/EnemyLifecycle.gd")
const MapGenerator = preload("res://scripts/map/MapGenerator.gd")
const VSData = preload("res://scripts/classes/vampire_survivor/VSData.gd")
const VSProgress = preload("res://scripts/classes/vampire_survivor/VSProgress.gd")
const VSStats = preload("res://scripts/classes/vampire_survivor/VSStats.gd")
const Grid = preload("res://scripts/shared/Grid.gd")
const InventoryHelper = preload("res://scripts/shared/Inventory.gd")

const TILE = 32
const MAP_W = 60
const MAP_H = 40
const BUILD_RANGE = 260.0
const CORE_POS = Vector2i(28, 25)
const CORE_SIZE = Vector2i(3, 3)
const DIRS = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DIR_NAMES = ["E", "S", "W", "N"]
const BELT_CAPACITY = 3
const TEST_STARTING_RESOURCES = {"copper": 999, "coal": 999, "graphite": 999, "lead": 999, "titanium": 999, "thorium": 999, "sand": 999, "silicon": 999, "plastinium": 999, "pyrite": 999, "water": 0}
const TEST_CORE_HEALTH = 999.0
const TEST_WAVE_TIMER = 999.0
const MAX_WAVE = 10
const PLAYER_MAX_HEALTH = 100.0
const PLAYER_RESPAWN_TIME = 2.0
const NODE_RANGE = 7.0
const LIGHTNING_CHARGE_TIME = 1.0
const LIGHTNING_MAX_CHARGE = 3
const LIGHTNING_RANGE = 240.0
const LIGHTNING_DAMAGE = 46.0
const BEAM_CHARGE_TIME = 0.8
const BEAM_MAX_CHARGE = 2

# --- VS: constants ---
const VS_ORB_CAP := 200
const VS_MAGNET_RADIUS := 90.0
const VS_HERO_MAX_HEALTH := 100.0
const VS_RESPAWN_BASE := 2.0
const VS_RESPAWN_PER_LEVEL := 2.0
const VS_MOVE_SPEED := 245.0
const ORBIT_RADIUS := 66.0
const ORBIT_SPEED := 3.4
const ORBIT_BLADE_HIT := 18.0
const ORBIT_MAX_BLADES := 8

var build_categories: Array[Dictionary] = GameData.build_categories()

var terrain = {}
var ore = {}
var buildings = {}
var blueprints: Array[Dictionary] = []
var items: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var liquids: Array[Dictionary] = []
var inventory = TEST_STARTING_RESOURCES.duplicate()
var selected = "conveyor"
var build_rot = 0
var player_pos = Vector2(30 * TILE, 28 * TILE)
var player_vel = Vector2.ZERO
var player_health = PLAYER_MAX_HEALTH
var player_respawn = 0.0
var player_alive = true
var core_health = TEST_CORE_HEALTH
var wave = 0
var wave_timer = TEST_WAVE_TIMER
var spawn_left = 0
var spawn_cooldown = 0.0
var won = false
var lost = false
var drag_active = false
var drag_start = Vector2i.ZERO
var drag_current = Vector2i.ZERO
var ui_root: CanvasLayer
var res_label: Label
var status_label: Label
var info_label: Label
var details_panel: PanelContainer
var details_label: Label
var restart_button: Button
var next_wave_button: Button
var class_menu_button: Button
var levelup_panel: PanelContainer
var levelup_buttons: Array[Button] = []
var camera: Camera2D
var selected_category: String = "turrets"
var build_grid: GridContainer
var category_rail: VBoxContainer
var category_buttons: Dictionary = {}
var build_buttons: Dictionary = {}
var power_efficiency: Dictionary = {}
var power_network_status: Dictionary = {}
var power_network_lines: Array = []
var lightning_bolts: Array[Dictionary] = []
var details_from_ui = false

# --- VS: state ---
var active_class: String = "factory"
var hero_pos: Vector2 = Vector2(30 * TILE, 28 * TILE)
var hero_vel: Vector2 = Vector2.ZERO
var hero_health: float = VS_HERO_MAX_HEALTH
var hero_alive: bool = true
var hero_respawn: float = 0.0
var vs_xp: int = 0
var vs_level: int = 1
var vs_inventory: int = 0
var orbs: Array[Dictionary] = []
var owned_spells: Dictionary = {"arc_bolt": 1}
var owned_upgrades: Dictionary = {}
var spell_cooldowns: Dictionary = {}
var levelup_queue: int = 0
var levelup_open: bool = false
var levelup_choices: Array = []
var nova_pulses: Array[Dictionary] = []
var orbit_angle: float = 0.0

# --- Enemy visuals / animation state ---
var anim_time: float = 0.0                       # global clock driving walk frames & pulses
var enemy_sheets: Dictionary = {}                # sheet key -> Texture2D (CC0 walk loops)
var fx_sheets: Dictionary = {}                   # effect key -> Texture2D
var enemy_effects: Array[Dictionary] = []        # transient hit/burst/slam anims
var enemy_telegraphs: Array[Dictionary] = []     # aim-line / shockwave warnings to draw
var pending_enemy_spawns: Array[Dictionary] = [] # spawner/on-death buffer, flushed post-iteration
var ore_tiers: Dictionary = GameData.ore_tiers()
var ore_colors: Dictionary = GameData.ore_colors()

var defs: Dictionary = BuildingData.defs(CORE_SIZE)
var building_health: Dictionary = BuildingData.health(TEST_CORE_HEALTH)
var enemy_defs: Dictionary = EnemyData.defs()

var spell_defs: Dictionary = VSData.spell_defs()
var upgrade_defs: Dictionary = VSData.upgrade_defs()

func _ready() -> void:
	randomize()
	camera = Camera2D.new()
	camera.zoom = Vector2(0.85, 0.85)
	camera.position = player_pos
	add_child(camera)
	_generate_level()
	_place_core()
	_make_ui()
	_load_enemy_art()
	set_process(true)
	queue_redraw()

# Load the CC0 factory-defense walk/effect sprite sheets once. Missing files are
# tolerated: `_draw_world` falls back to procedural silhouettes per enemy shape.
func _load_enemy_art() -> void:
	var sheets := EnemyArt.load_sheets()
	enemy_sheets = sheets["enemy_sheets"]
	fx_sheets = sheets["fx_sheets"]

func _generate_level() -> void:
	var level: Dictionary = MapGenerator.generate(MAP_W, MAP_H)
	terrain = level["terrain"]
	ore = level["ore"]

func _cleanup_ore_in_natural_walls() -> void:
	MapGenerator.cleanup_ore_in_natural_walls(terrain, ore)

func _is_belt_id(id: String) -> bool:
	return BuildingRules.is_belt_id(defs, id)

func _is_belt_building(b: Dictionary) -> bool:
	return BuildingRules.is_belt_building(defs, b)

func _is_drill_id(id: String) -> bool:
	return BuildingRules.is_drill_id(defs, id)

func _is_ammo_turret_id(id: String) -> bool:
	return BuildingRules.is_ammo_turret_id(defs, id)

func _is_fluid_turret_id(id: String) -> bool:
	return BuildingRules.is_fluid_turret_id(defs, id)

func _is_power_turret_id(id: String) -> bool:
	return BuildingRules.is_power_turret_id(defs, id)

func _is_factory_id(id: String) -> bool:
	return BuildingRules.is_factory_id(defs, id)

func _accepts_water(b: Dictionary) -> bool:
	return BuildingRules.accepts_water(defs, b)

func _accepts_liquid(b: Dictionary, kind: String) -> bool:
	return BuildingRules.accepts_liquid(defs, b, kind)

func _belt_speed_for(b: Dictionary) -> float:
	return BuildingRules.belt_speed_for(defs, b)

func _item_color(kind: String) -> Color:
	return ore_colors.get(kind, Color("#f2c766"))

func _factory_recipe(b: Dictionary) -> Dictionary:
	return BuildingRules.factory_recipe(defs, b)

func _recipe_inputs(recipe: Dictionary) -> Dictionary:
	return BuildingRules.recipe_inputs(recipe)

func _factory_has_inputs(b: Dictionary, recipe: Dictionary) -> bool:
	return BuildingStore.factory_has_inputs(b, recipe)

func _take_factory_inputs(b: Dictionary, recipe: Dictionary) -> void:
	BuildingStore.take_factory_inputs(b, recipe)

func _drill_output_kind(b: Dictionary) -> String:
	return BuildingRules.drill_output_kind(terrain, ore, b)

func _disc(center: Vector2i, radius: int) -> Array[Vector2i]:
	return Grid.disc(center, radius, MAP_W, MAP_H)

func _place_core() -> void:
	var b = _make_building("core", CORE_POS, 0, true)
	b.size = CORE_SIZE
	for p in _cells(CORE_POS, CORE_SIZE):
		buildings[p] = b

func _make_ui() -> void:
	ui_root = CanvasLayer.new()
	add_child(ui_root)
	res_label = Label.new()
	res_label.position = Vector2(420, 12)
	res_label.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(res_label)
	status_label = Label.new()
	status_label.position = Vector2(14, 12)
	status_label.add_theme_font_size_override("font_size", 18)
	ui_root.add_child(status_label)
	info_label = Label.new()
	info_label.position = Vector2(14, 655)
	info_label.add_theme_font_size_override("font_size", 15)
	ui_root.add_child(info_label)
	details_panel = PanelContainer.new()
	details_panel.anchor_left = 1.0
	details_panel.anchor_top = 1.0
	details_panel.anchor_right = 1.0
	details_panel.anchor_bottom = 1.0
	details_panel.offset_left = -470
	details_panel.offset_top = -416
	details_panel.offset_right = -110
	details_panel.offset_bottom = -326
	details_panel.visible = false
	ui_root.add_child(details_panel)
	details_label = Label.new()
	details_label.custom_minimum_size = Vector2(340, 78)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_panel.add_child(details_label)
	var panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_top = -320
	panel.offset_right = -14
	panel.offset_bottom = -14
	ui_root.add_child(panel)
	var outer_vbox = VBoxContainer.new()
	panel.add_child(outer_vbox)
	var hbox = HBoxContainer.new()
	outer_vbox.add_child(hbox)
	build_grid = GridContainer.new()
	build_grid.columns = 2
	build_grid.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(build_grid)
	category_rail = VBoxContainer.new()
	hbox.add_child(category_rail)
	for cat in build_categories:
		var cat_btn = Button.new()
		cat_btn.custom_minimum_size = Vector2(96, 30)
		cat_btn.text = cat.name
		cat_btn.toggle_mode = true
		cat_btn.pressed.connect(func() -> void:
			selected_category = cat.id
			_refresh_build_grid()
		)
		category_rail.add_child(cat_btn)
		category_buttons[cat.id] = cat_btn
	_refresh_build_grid()
	_hide_details()
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.position = Vector2(14, 610)
	restart_button.visible = false
	restart_button.pressed.connect(_restart)
	ui_root.add_child(restart_button)
	next_wave_button = Button.new()
	next_wave_button.text = "Next Wave"
	next_wave_button.position = Vector2(102, 610)
	next_wave_button.pressed.connect(_force_next_wave)
	ui_root.add_child(next_wave_button)
	class_menu_button = Button.new()
	class_menu_button.text = "Class: Factory"
	class_menu_button.position = Vector2(14, 570)
	class_menu_button.pressed.connect(_toggle_class)
	ui_root.add_child(class_menu_button)
	levelup_panel = PanelContainer.new()
	levelup_panel.anchor_left = 0.5
	levelup_panel.anchor_top = 0.5
	levelup_panel.anchor_right = 0.5
	levelup_panel.anchor_bottom = 0.5
	levelup_panel.offset_left = -300
	levelup_panel.offset_top = -90
	levelup_panel.offset_right = 300
	levelup_panel.offset_bottom = 90
	levelup_panel.visible = false
	ui_root.add_child(levelup_panel)
	var levelup_vbox = VBoxContainer.new()
	levelup_panel.add_child(levelup_vbox)
	var levelup_title = Label.new()
	levelup_title.text = "Level Up! Choose one:"
	levelup_title.add_theme_font_size_override("font_size", 18)
	levelup_vbox.add_child(levelup_title)
	var levelup_hbox = HBoxContainer.new()
	levelup_vbox.add_child(levelup_hbox)
	levelup_buttons.clear()
	for i in 3:
		var card = Button.new()
		card.custom_minimum_size = Vector2(188, 110)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.pressed.connect(_on_level_up_pick.bind(i))
		levelup_hbox.add_child(card)
		levelup_buttons.append(card)
	_update_info()

func _refresh_build_grid() -> void:
	for cat_id in category_buttons:
		# The combat category only appears in combat class; factory categories only in factory class.
		category_buttons[cat_id].visible = (cat_id == "combat") == _is_combat_class()
		category_buttons[cat_id].button_pressed = (cat_id == selected_category)
	for child in build_grid.get_children():
		child.queue_free()
	build_buttons.clear()
	for id in _ids_for_category(selected_category):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(104, 38)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.text = "%s\n%s" % [defs[id].name, _cost_text(defs[id].cost)]
		btn.toggle_mode = true
		btn.button_pressed = (selected == id)
		btn.mouse_entered.connect(func() -> void:
			details_from_ui = true
			_show_details(_building_details(id))
		)
		btn.mouse_exited.connect(func() -> void:
			details_from_ui = false
			_hide_details()
		)
		btn.pressed.connect(func() -> void:
			selected = id
			_update_info()
			_refresh_build_grid()
			queue_redraw()
		)
		build_grid.add_child(btn)
		build_buttons[id] = btn

func _process(delta: float) -> void:
	anim_time += delta
	if levelup_queue > 0 and not levelup_open:
		_open_level_up()
	if not lost and not won and not levelup_open:
		_update_enemy_effects(delta)
		if _is_combat_class():
			_update_hero(delta)
		else:
			_update_player(delta)
		_update_blueprints()
		_update_buildings(delta)
		_update_items(delta)
		_update_liquids(delta)
		_update_waves(delta)
		_update_enemies(delta)
		_update_orbs(delta)
		_update_spells(delta)
		_update_nova_pulses(delta)
		_update_projectiles(delta)
		_update_lightning_bolts(delta)
	camera.position = camera.position.lerp(hero_pos if _is_combat_class() else player_pos, 0.16)
	_update_hud()
	_update_world_hover_details()
	queue_redraw()

func _update_player(delta: float) -> void:
	if not player_alive:
		player_respawn -= delta
		if player_respawn <= 0.0:
			player_alive = true
			player_health = PLAYER_MAX_HEALTH
			player_pos = _cell_center(CORE_POS + Vector2i(1, 1))
		return
	var move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_vel = player_vel.lerp(move * 245.0, 0.22)
	player_pos += player_vel * delta
	player_pos.x = clamp(player_pos.x, TILE, (MAP_W - 1) * TILE)
	player_pos.y = clamp(player_pos.y, TILE, (MAP_H - 1) * TILE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_build"):
		build_rot = (build_rot + 1) % 4
		_update_info()
	if event.is_action_pressed("cancel_build"):
		selected = ""
		drag_active = false
		if build_grid != null:
			_refresh_build_grid()
		_update_info()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _is_belt_id(selected) or selected == "pipe":
				build_rot = (build_rot + 3) % 4
				_update_info()
			else:
				camera.zoom *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _is_belt_id(selected) or selected == "pipe":
				build_rot = (build_rot + 1) % 4
				_update_info()
			else:
				camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _mouse_over_ui():
				if selected == "":
					# The combat hero has no manual weapon; only the drone shoots.
					if not _is_combat_class():
						_shoot_at(get_global_mouse_position())
				else:
					drag_active = true
					drag_start = _mouse_cell()
					drag_current = drag_start
			elif not event.pressed and drag_active:
				drag_current = _mouse_cell()
				_commit_drag()
				drag_active = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not _mouse_over_ui():
			_delete_at(_mouse_cell())
			selected = ""
			drag_active = false
			_update_info()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed and not _mouse_over_ui():
			_pick_building_at(_mouse_cell())
	if event is InputEventMouseMotion and drag_active:
		drag_current = _mouse_cell()

func _commit_drag() -> void:
	if selected == "":
		return
	var cells = _drag_cells()
	for cell in cells:
		_try_place(selected, cell)

func _pick_building_at(cell: Vector2i) -> void:
	var b = buildings.get(cell)
	if b == null or b.id == "core":
		return
	selected = b.id
	if _is_belt_id(selected) or selected == "pipe" or _is_drill_id(selected):
		build_rot = b.rot
	selected_category = defs.get(selected, {}).get("category", selected_category)
	if build_grid != null:
		_refresh_build_grid()
	_update_info()

# --- VS: class switching ---
func _set_active_class(name: String) -> void:
	if name != "factory" and name != "combat":
		return
	active_class = name
	selected = ""
	drag_active = false
	if build_grid != null:
		selected_category = "combat" if active_class == "combat" else "turrets"
		_refresh_build_grid()
	_update_info()

func _is_combat_class() -> bool:
	return active_class == "combat"

func _toggle_class() -> void:
	_set_active_class("factory" if _is_combat_class() else "combat")
	if class_menu_button != null:
		class_menu_button.text = "Class: Combat" if _is_combat_class() else "Class: Factory"

# --- VS: hero ---
func _hero_respawn_time() -> float:
	return VSStats.hero_respawn_time(vs_level, VS_RESPAWN_BASE, VS_RESPAWN_PER_LEVEL)

func _hero_max_health() -> float:
	return VSStats.hero_max_health(VS_HERO_MAX_HEALTH, owned_upgrades)

func _hero_move_speed() -> float:
	return VSStats.hero_move_speed(VS_MOVE_SPEED, owned_upgrades)

func _damage_hero(amount: float) -> void:
	if not hero_alive:
		return
	hero_health -= amount
	if hero_health <= 0.0:
		hero_health = 0.0
		hero_alive = false
		hero_respawn = _hero_respawn_time()

func _update_hero(delta: float) -> void:
	if not hero_alive:
		hero_respawn -= delta
		if hero_respawn <= 0.0:
			hero_alive = true
			hero_health = _hero_max_health()
			hero_pos = _cell_center(CORE_POS + Vector2i(1, 1))
		return
	var move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	hero_vel = hero_vel.lerp(move * _hero_move_speed(), 0.22)
	hero_pos += hero_vel * delta
	hero_pos.x = clamp(hero_pos.x, TILE, (MAP_W - 1) * TILE)
	hero_pos.y = clamp(hero_pos.y, TILE, (MAP_H - 1) * TILE)

# --- VS: orbs ---
func _orb_drop_count(kind: String) -> int:
	var hp := float(enemy_defs.get(kind, enemy_defs.grunt).hp)
	if hp >= 120.0:
		return 3
	if hp >= 60.0:
		return 2
	return 1

func _drop_orbs(pos: Vector2, count: int) -> void:
	for i in count:
		var jitter := Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		orbs.append({"pos": pos + jitter})

func _hero_magnet_radius() -> float:
	return VSStats.hero_magnet_radius(VS_MAGNET_RADIUS, owned_upgrades)

func _update_orbs(delta: float) -> void:
	if not _is_combat_class() or not hero_alive:
		return
	var radius := _hero_magnet_radius()
	var i := 0
	while i < orbs.size():
		var orb = orbs[i]
		var to_hero: Vector2 = hero_pos - orb.pos
		var dist := to_hero.length()
		if dist <= radius:
			if dist <= 16.0:
				if vs_inventory < VS_ORB_CAP:
					vs_inventory += 1
					orbs.remove_at(i)
					continue
				i += 1
				continue
			orb.pos += to_hero.normalized() * min(dist, 320.0 * delta)
		i += 1

# --- VS: leveling ---
func _xp_needed(level: int) -> int:
	return VSProgress.xp_needed(level)

func _add_vs_xp(amount: int) -> void:
	if amount <= 0:
		return
	vs_xp += amount
	_check_level_up()

func _check_level_up() -> void:
	while vs_xp >= _xp_needed(vs_level):
		vs_xp -= _xp_needed(vs_level)
		vs_level += 1
		levelup_queue += 1

# --- VS: xp sink ---
func _xp_value(kind: String) -> int:
	return VSProgress.xp_value(kind)

func _xp_sink_consume_one(b: Dictionary) -> int:
	for kind in ["graphite", "copper", "coal"]:
		if _store_count(b, kind) > 0:
			_take_store(b, kind, 1)
			return _xp_value(kind)
	return 0

# --- VS: resource depot ---
func _depot_in_range_of_hero(b: Dictionary) -> bool:
	if not _is_combat_class() or not hero_alive:
		return false
	var range_px: float = float(defs["resource_depot"].get("depot_range", 150.0))
	return _building_center(b).distance_to(hero_pos) <= range_px

# --- VS: spells ---
func _spell_cooldown_scale() -> float:
	return VSStats.spell_cooldown_scale(owned_upgrades)

func _update_spells(delta: float) -> void:
	if not _is_combat_class() or not hero_alive:
		return
	# Orbiting Blades is a continuous, visible orbit rather than a cooldown cast.
	_update_orbit_blades(delta)
	for id in owned_spells.keys():
		if id == "orbiting_blades":
			continue
		var lvl := int(owned_spells[id])
		var base_cd: float = float(spell_defs[id].get("cooldown", 1.0))
		var cd := base_cd * _spell_cooldown_scale()
		spell_cooldowns[id] = float(spell_cooldowns.get(id, 0.0)) - delta
		if spell_cooldowns[id] <= 0.0:
			spell_cooldowns[id] = cd
			_cast_spell(id, lvl)

func _cast_spell(id: String, level: int) -> void:
	var sd: Dictionary = spell_defs[id]
	match String(sd.get("kind", "")):
		"projectile":
			var target = _nearest_enemy(hero_pos, float(sd.get("range", 260.0)))
			if target != null:
				var dmg: float = float(sd.damage) * (1.0 + 0.25 * (level - 1))
				_spell_projectile(hero_pos, target.pos, dmg, float(sd.bullet_speed))
		"nova":
			var radius: float = float(sd.radius) * (1.0 + 0.15 * (level - 1))
			var dmg2: float = float(sd.damage) * (1.0 + 0.3 * (level - 1))
			for e in enemies:
				if e.pos.distance_to(hero_pos) <= radius:
					_damage_enemy(e, dmg2, {"source": hero_pos})
			nova_pulses.append({"pos": hero_pos, "radius": 0.0, "max_radius": radius, "life": 0.35, "max_life": 0.35})

# Orbiting Blades: `level` blades (capped) circle the hero and damage enemies they sweep.
func _orbit_blade_count() -> int:
	return VSStats.orbit_blade_count(owned_spells, ORBIT_MAX_BLADES)

func _orbit_blade_positions() -> Array:
	var out: Array = []
	var count := _orbit_blade_count()
	for i in count:
		var a := orbit_angle + TAU * float(i) / float(count)
		out.append(hero_pos + Vector2(cos(a), sin(a)) * ORBIT_RADIUS)
	return out

func _update_orbit_blades(delta: float) -> void:
	var count := _orbit_blade_count()
	if count <= 0:
		return
	orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
	var lvl := int(owned_spells.get("orbiting_blades", 0))
	var dps: float = float(spell_defs["orbiting_blades"].damage) * (1.0 + 0.25 * (lvl - 1))
	var positions := _orbit_blade_positions()
	for e in enemies:
		for bp in positions:
			if e.pos.distance_to(bp) <= ORBIT_BLADE_HIT:
				_damage_enemy(e, dps * delta, {"dot": true})
				break

func _update_nova_pulses(delta: float) -> void:
	var i := 0
	while i < nova_pulses.size():
		var pulse = nova_pulses[i]
		pulse.life -= delta
		var t: float = 1.0 - clamp(pulse.life / float(pulse.max_life), 0.0, 1.0)
		pulse.radius = float(pulse.max_radius) * t
		if pulse.life <= 0.0:
			nova_pulses.remove_at(i)
		else:
			i += 1

func _spell_projectile(from_pos: Vector2, to_pos: Vector2, damage: float, speed: float) -> void:
	var dir = (to_pos - from_pos).normalized()
	projectiles.append({"pos": from_pos, "vel": dir * speed, "damage": damage, "life": 1.6, "team": "player", "spell": true})

# --- VS: level-up UI ---
func _roll_level_up_choices() -> Array:
	return VSProgress.roll_level_up_choices(spell_defs, upgrade_defs, owned_spells, owned_upgrades)

func _apply_level_up_choice(choice: Dictionary) -> void:
	match String(choice.get("type", "")):
		"spell":
			owned_spells[choice.id] = int(owned_spells.get(choice.id, 0)) + 1
		"upgrade":
			owned_upgrades[choice.id] = int(owned_upgrades.get(choice.id, 0)) + 1
			if choice.id == "vitality":
				hero_health = min(_hero_max_health(), hero_health + 25.0)
		"heal":
			hero_health = min(_hero_max_health(), hero_health + 25.0)

func _open_level_up() -> void:
	if levelup_queue <= 0:
		return
	levelup_queue -= 1
	levelup_open = true
	levelup_choices = _roll_level_up_choices()
	_refresh_level_up_ui()

func _refresh_level_up_ui() -> void:
	if levelup_panel == null:
		return
	levelup_panel.visible = levelup_open
	for i in levelup_buttons.size():
		var btn: Button = levelup_buttons[i]
		if i < levelup_choices.size():
			btn.text = String(levelup_choices[i].label)
			btn.visible = true
		else:
			btn.visible = false

func _on_level_up_pick(index: int) -> void:
	if index < 0 or index >= levelup_choices.size():
		return
	_apply_level_up_choice(levelup_choices[index])
	levelup_open = false
	_refresh_level_up_ui()
	if levelup_queue > 0:
		_open_level_up()

func _try_place(id: String, cell: Vector2i) -> void:
	if not defs.has(id):
		return
	var def: Dictionary = defs[id]
	if not _can_place(id, cell):
		return
	var existing = buildings.get(cell)
	if _is_belt_id(id) and existing != null and _is_belt_building(existing) and existing.id != "cross":
		if id == "conveyor" and existing.rot % 2 != build_rot % 2:
			existing.id = "cross"
			existing.rot = build_rot
		elif existing.rot != build_rot:
			existing.rot = build_rot
			existing.id = id
			existing.health = building_health.get(id, existing.health)
		elif existing.id != id:
			existing.id = id
			existing.health = building_health.get(id, existing.health)
		return
	if _is_belt_id(id) and existing != null and existing.id == "cross":
		return
	var in_range = _cell_center(cell).distance_to(player_pos) <= BUILD_RANGE
	if in_range and _can_afford(def.cost):
		_pay(def.cost)
		_add_building(id, cell, build_rot, true)
	else:
		blueprints.append({"id": id, "pos": cell, "rot": build_rot, "order": Time.get_ticks_msec()})

func _can_place(id: String, cell: Vector2i) -> bool:
	return BuildingPlacement.can_place(defs, terrain, ore, ore_tiers, buildings, id, cell, MAP_W, MAP_H)

func _add_building(id: String, cell: Vector2i, rot: int, built: bool) -> void:
	var b = _make_building(id, cell, rot, built)
	for p in _cells(cell, b.size):
		buildings[p] = b

func _make_building(id: String, cell: Vector2i, rot: int, built: bool) -> Dictionary:
	return BuildingRuntime.make(defs, building_health, id, cell, rot, built)

func _update_blueprints() -> void:
	var i = 0
	while i < blueprints.size():
		var bp = blueprints[i]
		if _cell_center(bp.pos).distance_to(player_pos) <= BUILD_RANGE and _can_afford(defs[bp.id].cost) and _can_place(bp.id, bp.pos):
			_pay(defs[bp.id].cost)
			_add_building(bp.id, bp.pos, bp.rot, true)
			blueprints.remove_at(i)
		else:
			i += 1

func _update_buildings(delta: float) -> void:
	_calculate_power_networks(delta)
	var seen = {}
	for b in buildings.values():
		var key = _building_key(b)
		if seen.has(key):
			continue
		seen[key] = true
		if _is_drill_id(b.id):
			var drill_efficiency = 1.0
			if defs.get(b.id, {}).has("power_consumption"):
				drill_efficiency = _power_efficiency_for(b)
			var drill_time = float(defs.get(b.id, {}).get("drill_time", 1.45))
			if _store_count(b, "water") > 0:
				drill_time /= 1.5
			if drill_efficiency > 0.0:
				b.timer += delta * drill_efficiency
			else:
				b.timer = min(b.timer, drill_time * 0.25)
			if b.timer >= drill_time:
				b.timer = 0.0
				if _emit_item(b.pos, _drill_output_kind(b), b):
					b.produced += 1
					if b.produced >= 10 and _store_count(b, "water") > 0:
						b.produced = 0
						_take_store(b, "water", 1)
		elif _is_ammo_turret_id(b.id):
			b.timer -= delta
			if b.timer <= 0.0:
				var turret_def: Dictionary = defs.get(b.id, {})
				var e = _nearest_enemy(_cell_center(b.pos), float(turret_def.get("turret_range", 210.0)))
				if e != null and _turret_ammo_count(b) > 0:
					var ammo = _take_turret_ammo(b)
					var water_boost = _store_count(b, "water") > 0
					b.timer = float(turret_def.get("turret_reload", 0.55)) / (1.5 if water_boost else 1.0)
					if water_boost:
						_take_store(b, "water", 1)
					var damage = float(turret_def.get("damage_%s" % ammo, turret_def.get("damage_copper", 28.0)))
					_projectile(_building_center(b), e.pos, damage, float(turret_def.get("turret_bullet_speed", 460.0)), "player", float(turret_def.get("turret_spread", 0.0)))
		elif _is_fluid_turret_id(b.id):
			_update_fluid_turret(b, delta)
		elif _is_power_turret_id(b.id):
			_update_power_turret(b, delta)
		elif b.id == "lightning_turret":
			_update_lightning_turret(b, delta)
			var e2 = _nearest_enemy(_cell_center(b.pos), LIGHTNING_RANGE)
			if e2 != null and _store_count(b, "charge") >= 1:
				_take_store(b, "charge", 1)
				_fire_lightning(_cell_center(b.pos), e2)
		elif b.id == "generator":
			if b.fuel <= 0.0 and _store_count(b, "coal") > 0:
				_take_store(b, "coal", 1)
				b.fuel = 12.0
			b.fuel = max(0.0, b.fuel - delta)
		elif _is_factory_id(b.id):
			var recipe = _factory_recipe(b)
			var output_kind = String(recipe.get("output", ""))
			_flush_output_store(b, output_kind)
			var has_input = _factory_has_inputs(b, recipe)
			var factory_efficiency = 1.0
			if defs.get(b.id, {}).has("power_consumption"):
				factory_efficiency = _power_efficiency_for(b)
			if has_input and factory_efficiency > 0.0:
				b.timer += delta * factory_efficiency
			else:
				b.timer = min(b.timer, 0.2)
			if b.timer >= float(recipe.get("craft_time", 1.8)) and has_input and factory_efficiency > 0.0:
				b.timer = 0.0
				_take_factory_inputs(b, recipe)
				for _i in range(int(recipe.get("output_amount", 1))):
					if not _emit_item(b.pos, output_kind, b):
						_add_store(b, output_kind, 1)
		elif b.id == "resource_depot":
			_flush_output_store(b, "copper")
			if _depot_in_range_of_hero(b) and vs_inventory > 0:
				var depot_powered = b.get("powered", false)
				var depot_rate: float = float(defs["resource_depot"].get("depot_rate_powered", 14.0)) if depot_powered else float(defs["resource_depot"].get("depot_rate", 6.0))
				b.timer += delta
				var depot_interval := 1.0 / depot_rate
				while b.timer >= depot_interval and vs_inventory > 0:
					b.timer -= depot_interval
					vs_inventory -= 1
					_add_store(b, "copper", 1)
					_flush_output_store(b, "copper")
		elif b.id == "xp_sink":
			var xp_powered = b.get("powered", false)
			var xp_rate: float = float(defs["xp_sink"].get("xp_rate_powered", 10.0)) if xp_powered else float(defs["xp_sink"].get("xp_rate", 4.0))
			b.timer += delta
			var xp_interval := 1.0 / xp_rate
			while b.timer >= xp_interval:
				b.timer -= xp_interval
				var consumed := _xp_sink_consume_one(b)
				if consumed == 0:
					b.timer = 0.0
					break
				_add_vs_xp(consumed)
		elif defs.get(b.id, {}).has("fluid_output"):
			var fluid_efficiency = 1.0
			if defs.get(b.id, {}).has("power_consumption"):
				fluid_efficiency = _power_efficiency_for(b)
			if fluid_efficiency > 0.0:
				b.timer += delta * fluid_efficiency
			var interval = float(defs.get(b.id, {}).get("fluid_interval", 0.6))
			if b.timer >= interval:
				b.timer = 0.0
				_emit_liquid_from_building(b, String(defs[b.id].get("fluid_output", "water")))

func _building_center(b: Dictionary) -> Vector2:
	return BuildingRuntime.center(b, TILE)

func _building_key(b: Dictionary) -> String:
	return BuildingRuntime.key(b)

func _power_key(b: Dictionary) -> String:
	return BuildingRuntime.power_key(b)

func _calculate_power_networks(delta: float) -> Dictionary:
	var seen = {}
	var all_buildings: Array[Dictionary] = []
	for b in buildings.values():
		var key = _building_key(b)
		if seen.has(key):
			continue
		seen[key] = true
		all_buildings.append(b)
		b.powered = false

	power_efficiency.clear()
	power_network_status.clear()
	power_network_lines.clear()

	var nodes: Array[Dictionary] = []
	var power_participants: Array[Dictionary] = []
	for b in all_buildings:
		if b.id == "node":
			nodes.append(b)
		elif _is_power_participant(b):
			power_participants.append(b)

	var node_links: Dictionary = {}
	for i in range(nodes.size()):
		node_links[i] = []
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var bridge = null
			if Vector2(nodes[i].pos - nodes[j].pos).length() <= NODE_RANGE:
				bridge = null
			else:
				for p in power_participants:
					if _building_in_node_range(p, nodes[i]) and _building_in_node_range(p, nodes[j]):
						bridge = p
						break
				if bridge == null:
					continue
			node_links[i].append({"to": j, "bridge": bridge})
			node_links[j].append({"to": i, "bridge": bridge})

	var visited: Dictionary = {}
	var network_count = 0
	for i in range(nodes.size()):
		if visited.has(i):
			continue
		var stack: Array[int] = [i]
		visited[i] = true
		var comp_indices: Array[int] = [i]
		var comp_edges: Array[Dictionary] = []
		while not stack.is_empty():
			var cur = stack.pop_back()
			for edge in node_links[cur]:
				var j = int(edge["to"])
				if visited.has(j):
					continue
				visited[j] = true
				comp_indices.append(j)
				stack.append(j)
				comp_edges.append({"from": cur, "to": j, "bridge": edge["bridge"]})
		var comp_nodes: Array[Dictionary] = []
		for idx in comp_indices:
			comp_nodes.append(nodes[idx])
		_process_network(comp_nodes, comp_edges, power_participants, nodes, delta)
		network_count += 1
	return {"networks": network_count}

func _process_network(comp_nodes: Array[Dictionary], comp_edges: Array[Dictionary], power_participants: Array[Dictionary], all_nodes: Array[Dictionary], delta: float) -> void:
	var participants: Array[Dictionary] = []
	var participant_seen: Dictionary = {}
	for nb in comp_nodes:
		nb.powered = true
		for b in power_participants:
			var participant_key = _building_key(b)
			if participant_seen.has(participant_key):
				continue
			if _building_in_node_range(b, nb):
				participant_seen[participant_key] = true
				participants.append(b)
				b.powered = true

	var bridged_participants = {}
	for edge in comp_edges:
		var a = all_nodes[int(edge["from"])]
		var c = all_nodes[int(edge["to"])]
		if edge["bridge"] == null:
			_add_power_link(a, c)
		else:
			_add_power_link(a, edge["bridge"])
			_add_power_link(edge["bridge"], c)
			bridged_participants[edge["bridge"]] = true

	for p in participants:
		if bridged_participants.has(p):
			continue
		var closest_node = _closest_node_for(p, comp_nodes)
		if closest_node != null:
			_add_power_link(closest_node, p)

	var generation = 0.0
	var consumption = 0.0
	var batteries: Array[Dictionary] = []
	for b in participants:
		var d: Dictionary = defs.get(b.id, {})
		if _is_power_producer(b):
			if not d.get("requires_fuel", false) or b.fuel > 0.0:
				generation += float(d.get("power_production", 0.0))
		elif _is_power_storage(b):
			batteries.append(b)
		if _is_power_consumer(b):
			consumption += float(d["power_consumption"])

	var status = {"generation": generation, "consumption": consumption, "excess": 0.0, "deficit": 0.0, "efficiency": 0.0}
	if consumption <= 0.0:
		_charge_batteries(batteries, generation * delta)
		status["excess"] = generation
		status["efficiency"] = 1.0 if generation > 0.0 else 0.0
		_assign_power_status(participants, status)
		return

	if generation >= consumption:
		_charge_batteries(batteries, (generation - consumption) * delta)
		status["excess"] = generation - consumption
		status["efficiency"] = 1.0
		for b in participants:
			if _is_power_consumer(b):
				power_efficiency[_power_key(b)] = 1.0
	else:
		var deficit_energy = (consumption - generation) * delta
		var provided_energy = _discharge_batteries(batteries, deficit_energy)
		var supplied_energy = generation * delta + provided_energy
		var demand_energy = consumption * delta
		var ratio = 0.0
		if demand_energy > 0.0:
			ratio = clamp(supplied_energy / demand_energy, 0.0, 1.0)
		status["deficit"] = max(0.0, (demand_energy - supplied_energy) / max(delta, 0.0001))
		status["efficiency"] = ratio
		for b in participants:
			if _is_power_consumer(b):
				power_efficiency[_power_key(b)] = ratio
	_assign_power_status(participants, status)

func _is_power_producer(b: Dictionary) -> bool:
	return BuildingRules.is_power_producer(defs, b)

func _is_power_consumer(b: Dictionary) -> bool:
	return BuildingRules.is_power_consumer(defs, b)

func _is_power_storage(b: Dictionary) -> bool:
	return BuildingRules.is_power_storage(defs, b)

func _is_power_participant(b: Dictionary) -> bool:
	return BuildingRules.is_power_participant(defs, b)

func _power_storage_capacity(b: Dictionary) -> float:
	return BuildingRules.power_storage_capacity(defs, b)

func _building_in_node_range(b: Dictionary, node: Dictionary) -> bool:
	return _building_center(b).distance_to(_building_center(node)) <= NODE_RANGE * TILE

func _closest_node_for(b: Dictionary, nodes: Array[Dictionary]) -> Variant:
	var best = null
	var best_d = INF
	for node in nodes:
		var d = _building_center(b).distance_to(_building_center(node))
		if d < best_d:
			best_d = d
			best = node
	return best

func _add_power_link(a: Dictionary, b: Dictionary) -> void:
	power_network_lines.append({"from": _building_center(a), "to": _building_center(b), "a": a, "b": b})

func _power_link_count_for(b: Dictionary) -> int:
	var count = 0
	for line in power_network_lines:
		if typeof(line) == TYPE_DICTIONARY and (line.a == b or line.b == b):
			count += 1
	return count

func _assign_power_status(participants: Array[Dictionary], status: Dictionary) -> void:
	for b in participants:
		power_network_status[_power_key(b)] = status

func _charge_batteries(batteries: Array[Dictionary], energy: float) -> void:
	var remaining = energy
	for bat in batteries:
		if remaining <= 0.0:
			break
		var cap = _power_storage_capacity(bat)
		var current = float(bat.store.get("power", 0))
		var space = max(0.0, cap - current)
		var add = min(space, remaining)
		bat.store["power"] = current + add
		remaining -= add

func _discharge_batteries(batteries: Array[Dictionary], energy_needed: float) -> float:
	var remaining_need = energy_needed
	var provided = 0.0
	for bat in batteries:
		if remaining_need <= 0.0:
			break
		var current = float(bat.store.get("power", 0))
		var take = min(current, remaining_need)
		bat.store["power"] = current - take
		remaining_need -= take
		provided += take
	return provided

func _power_efficiency_for(b: Dictionary) -> float:
	return BuildingRuntime.power_efficiency_for(power_efficiency, b)

func _update_lightning_turret(b: Dictionary, delta: float) -> void:
	var efficiency = _power_efficiency_for(b)
	if efficiency <= 0.0:
		return
	var current = float(b.store.get("charge", 0))
	var gained = efficiency * delta / LIGHTNING_CHARGE_TIME
	current = min(float(LIGHTNING_MAX_CHARGE), current + gained)
	b.store["charge"] = current

func _update_fluid_turret(b: Dictionary, delta: float) -> void:
	b.timer -= delta
	if b.timer > 0.0:
		return
	var turret_def: Dictionary = defs.get(b.id, {})
	var e = _nearest_enemy(_building_center(b), float(turret_def.get("turret_range", 190.0)))
	var fluid = _take_turret_liquid(b)
	if e == null or fluid == "":
		return
	b.timer = float(turret_def.get("turret_reload", 0.7))
	var damage = float(turret_def.get("damage_%s" % fluid, 18.0))
	_projectile(_building_center(b), e.pos, damage, float(turret_def.get("turret_bullet_speed", 390.0)), "player", float(turret_def.get("turret_spread", 0.0)))

func _update_power_turret(b: Dictionary, delta: float) -> void:
	var efficiency = _power_efficiency_for(b)
	if efficiency <= 0.0:
		return
	b.timer -= delta * efficiency
	if b.timer > 0.0:
		return
	var turret_def: Dictionary = defs.get(b.id, {})
	var e = _nearest_enemy(_building_center(b), float(turret_def.get("turret_range", 285.0)))
	if e == null:
		return
	b.timer = float(turret_def.get("turret_reload", 0.85))
	_projectile(_building_center(b), e.pos, float(turret_def.get("damage_power", 72.0)), float(turret_def.get("turret_bullet_speed", 760.0)), "player", float(turret_def.get("turret_spread", 0.0)))
func _fire_lightning(from_pos: Vector2, e: Dictionary) -> void:
	_damage_enemy(e, LIGHTNING_DAMAGE, {"source": from_pos})
	lightning_bolts.append({"from": from_pos, "to": e.pos, "life": 0.16})

func _update_lightning_bolts(delta: float) -> void:
	var i = 0
	while i < lightning_bolts.size():
		lightning_bolts[i].life -= delta
		if lightning_bolts[i].life <= 0.0:
			lightning_bolts.remove_at(i)
		else:
			i += 1

func _emit_item(cell: Vector2i, kind: String, source := {}) -> bool:
	var outputs = _valid_output_targets(cell, kind, source)
	if outputs.is_empty() and _touches_core(cell):
		inventory[kind] = inventory.get(kind, 0) + 1
		return true
	if outputs.is_empty():
		return false
	var start_index = 0
	if typeof(source) == TYPE_DICTIONARY and source.has("output_cursor"):
		start_index = int(source.output_cursor) % outputs.size()
	for offset in range(outputs.size()):
		var index = (start_index + offset) % outputs.size()
		var target = outputs[index]
		if _try_emit_to_target(target, kind):
			if typeof(source) == TYPE_DICTIONARY and source.has("output_cursor"):
				source.output_cursor = (index + 1) % max(outputs.size(), 1)
			return true
	return false

func _try_emit_to_target(target: Dictionary, kind: String) -> bool:
	if target.type == "core":
		inventory[kind] = inventory.get(kind, 0) + 1
		return true
	if target.type == "building":
		return _deliver_item_to_building(target.building, kind)
	if target.type == "belt":
		if _belt_item_count(target.cell) >= BELT_CAPACITY:
			return false
		var b = buildings.get(target.cell)
		if b == null:
			return false
		items.append({"kind": kind, "cell": target.cell, "progress": 0.05, "dir": _belt_output_dir_for_entry(b, target.outward_dir)})
		return true
	return false

func _valid_output_targets(cell: Vector2i, kind: String, source := {}) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if typeof(source) == TYPE_DICTIONARY and source.has("pos") and source.has("size"):
		for p in _cells(source.pos, source.size):
			for dir_index in range(DIRS.size()):
				var np = p + DIRS[dir_index]
				if _cell_in_rect(np, source.pos, source.size) or _target_list_has_cell(targets, np):
					continue
				var b = buildings.get(np)
				if b != null and _is_belt_building(b) and _belt_can_be_output_from_source(b, dir_index):
					targets.append({"type": "belt", "cell": np, "outward_dir": dir_index})
				elif b != null and _deliver_item_to_building_would_accept(b, kind):
					targets.append({"type": "building", "cell": np, "building": b})
	else:
		for dir_index in range(DIRS.size()):
			var np = cell + DIRS[dir_index]
			var b = buildings.get(np)
			if b != null and _is_belt_building(b) and _belt_can_be_output_from_source(b, dir_index):
				targets.append({"type": "belt", "cell": np, "outward_dir": dir_index})
			elif b != null and _deliver_item_to_building_would_accept(b, kind):
				targets.append({"type": "building", "cell": np, "building": b})
	if _touches_core(cell):
		targets.append({"type": "core", "cell": CORE_POS})
	return targets

func _target_list_has_cell(targets: Array[Dictionary], cell: Vector2i) -> bool:
	for target in targets:
		if target.cell == cell:
			return true
	return false

func _belt_can_be_output_from_source(b: Dictionary, outward_dir: int) -> bool:
	if _is_belt_building(b) and b.id != "cross":
		return b.rot != (outward_dir + 2) % 4
	if b.id == "cross":
		return true
	return false

func _belt_output_dir_for_entry(b: Dictionary, outward_dir: int) -> int:
	if b.id == "cross":
		return outward_dir
	return b.rot

func _adjacent_output_cells(cell: Vector2i, source := {}) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(source) == TYPE_DICTIONARY and source.has("pos") and source.has("size"):
		for p in _cells(source.pos, source.size):
			for d in DIRS:
				var np = p + d
				if not _cell_in_rect(np, source.pos, source.size) and not cells.has(np):
					cells.append(np)
	else:
		for d in DIRS:
			cells.append(cell + d)
	return cells

func _update_items(delta: float) -> void:
	for item in items:
		var belt = buildings.get(item.cell)
		item.progress += delta * _belt_speed_for(belt if belt != null else {"id": "conveyor"})
	var i = 0
	while i < items.size():
		var item = items[i]
		if item.progress < 1.0:
			i += 1
			continue
		item.progress = 0.0
		var b = buildings.get(item.cell)
		if b == null:
			items.remove_at(i)
			continue
		var dir = b.rot
		if b.id == "cross":
			dir = item.dir
		var next = item.cell + DIRS[dir]
		if _core_contains(next):
			inventory[item.kind] = inventory.get(item.kind, 0) + 1
			items.remove_at(i)
			continue
		var nb = buildings.get(next)
		if nb != null and _is_belt_building(nb) and _belt_item_count(next) < BELT_CAPACITY:
			item.cell = next
			if nb.id != "cross":
				item.dir = nb.rot
			i += 1
		elif nb != null and _deliver_item_to_building(nb, item.kind):
			items.remove_at(i)
		else:
			item.progress = 1.0
			i += 1

func _deliver_item_to_building(b: Dictionary, kind: String) -> bool:
	return BuildingStore.deliver_item(defs, b, kind, _xp_value(kind))

func _deliver_item_to_building_would_accept(b: Dictionary, kind: String) -> bool:
	return BuildingRules.item_delivery_would_accept(defs, b, kind, _xp_value(kind))

func _building_item_capacity(b: Dictionary, kind: String) -> int:
	return BuildingRules.building_item_capacity(defs, b, kind)

func _deliver_liquid_to_building(b: Dictionary, kind: String) -> bool:
	return BuildingStore.deliver_liquid(defs, b, kind)

func _building_liquid_capacity(b: Dictionary, kind: String) -> int:
	return BuildingRules.building_liquid_capacity(defs, b, kind)

func _turret_ammo_types(b: Dictionary) -> Array:
	return BuildingStore.turret_ammo_types(defs, b)

func _turret_ammo_count(b: Dictionary) -> int:
	return BuildingStore.turret_ammo_count(defs, b)

func _take_turret_ammo(b: Dictionary) -> String:
	return BuildingStore.take_turret_ammo(defs, b)

func _take_turret_liquid(b: Dictionary) -> String:
	return BuildingStore.take_turret_liquid(defs, b)
func _belt_item_count(cell: Vector2i) -> int:
	var count = 0
	for item in items:
		if item.cell == cell:
			count += 1
	return count

func _add_store(b: Dictionary, kind: String, amount: int) -> void:
	BuildingStore.add(b, kind, amount)

func _take_store(b: Dictionary, kind: String, amount: int) -> void:
	BuildingStore.take(b, kind, amount)

func _store_count(b: Dictionary, kind: String) -> int:
	return BuildingStore.count(b, kind)

func _flush_output_store(b: Dictionary, kind: String) -> void:
	if _store_count(b, kind) <= 0:
		return
	if _emit_item(b.pos, kind, b):
		_take_store(b, kind, 1)

func _emit_liquid(cell: Vector2i, kind := "water") -> void:
	var source = buildings.get(cell)
	if source != null:
		_emit_liquid_from_building(source, kind)
		return
	for d in DIRS:
		var np = cell + d
		var b = buildings.get(np)
		if b != null and b.id == "pipe":
			liquids.append({"kind": kind, "cell": np, "progress": 0.05, "dir": b.rot})
			return

func _emit_liquid_from_building(source: Dictionary, kind := "water") -> void:
	for p in _cells(source.pos, source.size):
		for d in DIRS:
			var np = p + d
			if _cell_in_rect(np, source.pos, source.size):
				continue
			var b = buildings.get(np)
			if b != null and b.id == "pipe":
				liquids.append({"kind": kind, "cell": np, "progress": 0.05, "dir": b.rot})
				return

func _update_liquids(delta: float) -> void:
	for l in liquids:
		l.progress += delta * 1.8
	var i = 0
	while i < liquids.size():
		var l = liquids[i]
		if l.progress < 1.0:
			i += 1
			continue
		l.progress = 0.0
		var b = buildings.get(l.cell)
		if b == null or b.id != "pipe":
			liquids.remove_at(i)
			continue
		var next = l.cell + DIRS[b.rot]
		var nb = buildings.get(next)
		if nb != null and nb.id == "pipe":
			l.cell = next
			l.dir = nb.rot
			i += 1
		elif nb != null and _deliver_liquid_to_building(nb, l.get("kind", "water")):
			liquids.remove_at(i)
		else:
			liquids.remove_at(i)

func _update_waves(delta: float) -> void:
	var state := EnemyLifecycle.update_waves(wave, wave_timer, spawn_left, spawn_cooldown, MAX_WAVE, TEST_WAVE_TIMER, enemies.is_empty(), delta)
	_apply_wave_state(state)
	if bool(state.get("won", false)):
		won = true
		restart_button.visible = true
		return
	var spawn_kind := String(state.get("spawn_kind", ""))
	if spawn_kind != "":
		_spawn_enemy(spawn_kind)

func _force_next_wave() -> void:
	_apply_wave_state(EnemyLifecycle.force_next_wave(wave, wave_timer, spawn_left, spawn_cooldown, MAX_WAVE, TEST_WAVE_TIMER, enemies.is_empty(), won, lost))

func _start_next_wave() -> void:
	_apply_wave_state(EnemyLifecycle.start_next_wave(wave, TEST_WAVE_TIMER))

func _enemy_kind_for_wave() -> String:
	return EnemyLifecycle.enemy_kind_for_wave(wave, MAX_WAVE)

func _apply_wave_state(state: Dictionary) -> void:
	wave = int(state.get("wave", wave))
	wave_timer = float(state.get("wave_timer", wave_timer))
	spawn_left = int(state.get("spawn_left", spawn_left))
	spawn_cooldown = float(state.get("spawn_cooldown", spawn_cooldown))

func _spawn_enemy(kind: String) -> void:
	enemies.append(_make_enemy(kind, _cell_center(Vector2i(5, 5))))

func _make_enemy(kind: String, pos: Vector2) -> Dictionary:
	return EnemyRuntime.make_enemy(enemy_defs, kind, pos, wave, TILE, CORE_POS, terrain, buildings, MAP_W, MAP_H, defs)

func _update_enemies(delta: float) -> void:
	pending_enemy_spawns.clear()
	for e in enemies:
		if e.hp <= 0.0:
			continue
		var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
		_update_enemy_path(e)
		_update_enemy_mechanics(e, def, delta)
		_enemy_shoot(e, delta)
		if def.has("heal_aura"):
			_enemy_heal_aura(e, def.heal_aura, delta)
		_apply_enemy_attack_events(EnemyRuntime.update_movement(e, def, delta, TILE, CORE_POS, buildings, defs))
	_apply_enemy_lifecycle_events(EnemyLifecycle.cleanup_dead(enemies, enemy_defs, wave, TILE, CORE_POS, terrain, buildings, MAP_W, MAP_H, defs))
	# Flush spawner / on-death children after iteration to avoid mutating mid-loop.
	for child in pending_enemy_spawns:
		enemies.append(child)
	pending_enemy_spawns.clear()

# Effective move speed: enraged archetypes surge once their HP threshold is crossed.
func _enemy_speed(e: Dictionary, def: Dictionary) -> float:
	return EnemyRuntime.speed(e, def)

# Per-enemy signature mechanics. Runs before shooting/movement each frame.
func _update_enemy_mechanics(e: Dictionary, def: Dictionary, delta: float) -> void:
	var events := EnemyRuntime.update_mechanics(e, def, delta, enemy_defs, wave, TILE, CORE_POS, terrain, buildings, MAP_W, MAP_H, defs, _active_avatar_alive(), _active_avatar_pos())
	_apply_enemy_events(events)

# Heal nearby living enemies (support units) up to their max HP.
func _enemy_heal_aura(healer: Dictionary, aura: Dictionary, delta: float) -> void:
	EnemyRuntime.heal_aura(enemies, healer, aura, delta)

# --- Damage routing & FX -----------------------------------------------------

# Single entry point for all damage dealt TO enemies. Honors phase invulnerability,
# directional shields, and flat armor. opts: {dir=travel dir, source=origin point, dot=bool}.
func _damage_enemy(e: Dictionary, amount: float, opts: Dictionary = {}) -> void:
	var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	for fx in EnemyRuntime.damage_enemy(e, def, amount, opts):
		enemy_effects.append(fx)

# Artillery/siege shells: burst on impact, hitting the avatar and nearby buildings.
func _detonate_splash(pos: Vector2, radius: float, dmg: float) -> void:
	_spawn_effect("burst", pos, radius * 0.9, Color("#ffb347"))
	_spawn_telegraph({"type": "blast", "pos": pos, "radius": radius, "life": 0.32, "max_life": 0.32, "color": Color("#ffb347")})
	if _active_avatar_alive() and pos.distance_to(_active_avatar_pos()) <= radius:
		_damage_active_avatar(dmg)
	var seen := {}
	for b in buildings.values():
		var key = _building_key(b)
		if seen.has(key):
			continue
		seen[key] = true
		if b.id == "core":
			continue
		if pos.distance_to(_cell_center(b.pos)) <= radius:
			_damage_building(b, dmg)

func _spawn_effect(kind: String, pos: Vector2, rad: float = 12.0, color: Color = Color(1, 1, 1)) -> void:
	enemy_effects.append(EnemyRuntime.effect(kind, pos, rad, color))

func _spawn_telegraph(t: Dictionary) -> void:
	enemy_telegraphs.append(t)

# Advance transient hit/burst sprite anims and warning telegraphs; cull the expired.
func _update_enemy_effects(delta: float) -> void:
	EnemyRuntime.update_effects(enemy_effects, enemy_telegraphs, delta)

# Brood-style enemies burst into smaller spawns when they die.
func _enemy_on_death(e: Dictionary) -> void:
	var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	for child in EnemyLifecycle.on_death_spawns(e, def, enemy_defs, wave, TILE, CORE_POS, terrain, buildings, MAP_W, MAP_H, defs):
		pending_enemy_spawns.append(child)

func _update_enemy_path(e: Dictionary) -> void:
	EnemyRuntime.update_path(e, get_process_delta_time(), TILE, CORE_POS, terrain, buildings, MAP_W, MAP_H, defs)

func _enemy_move_target(e: Dictionary) -> Vector2:
	return EnemyRuntime.move_target(e, TILE, CORE_POS)

func _enemy_tile_passable(cell: Vector2i, ignore_player_blocks: bool) -> bool:
	return EnemyRuntime.tile_passable(cell, ignore_player_blocks, terrain, buildings, MAP_W, MAP_H, CORE_POS, defs)

func _enemy_blocking_building(cell: Vector2i) -> Variant:
	return EnemyRuntime.blocking_building(cell, buildings, defs)

func _find_enemy_path(start: Vector2i, goal: Vector2i, ignore_player_blocks: bool) -> Array[Vector2i]:
	return EnemyRuntime.find_path(start, goal, ignore_player_blocks, terrain, buildings, MAP_W, MAP_H, CORE_POS, defs)

func _enemy_path_direction(e: Dictionary) -> Vector2:
	return EnemyRuntime.path_direction(e, TILE, CORE_POS)

func _enemy_target(e: Dictionary) -> Dictionary:
	var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	return EnemyRuntime.target(e, def, buildings, _active_avatar_alive(), _active_avatar_pos(), TILE, CORE_POS)

func _enemy_shoot(e: Dictionary, delta: float) -> void:
	var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	_apply_enemy_events(EnemyRuntime.update_shooting(e, def, delta, buildings, _active_avatar_alive(), _active_avatar_pos(), TILE, CORE_POS))

# Marksman-style wind-up: telegraph an aim line, then release one piercing bolt.
func _enemy_charged_shot(e: Dictionary, def: Dictionary, delta: float) -> void:
	_apply_enemy_events(EnemyRuntime.update_charged_shot(e, def, delta, buildings, _active_avatar_alive(), _active_avatar_pos(), TILE, CORE_POS))

func _apply_enemy_events(events: Dictionary) -> void:
	for fx in events.get("effects", []):
		enemy_effects.append(fx)
	for telegraph in events.get("telegraphs", []):
		enemy_telegraphs.append(telegraph)
	for child in events.get("spawns", []):
		pending_enemy_spawns.append(child)
	for p in events.get("projectiles", []):
		projectiles.append(p)
	var avatar_damage := float(events.get("avatar_damage", 0.0))
	if avatar_damage > 0.0:
		_damage_active_avatar(avatar_damage)

func _apply_enemy_lifecycle_events(events: Dictionary) -> void:
	for death in events.get("deaths", []):
		_drop_orbs(death.pos, _orb_drop_count(death.kind))
	_apply_enemy_events(events)

func _enemy_attack_building(e: Dictionary, b: Dictionary, delta: float) -> void:
	var def: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	_apply_enemy_attack_events(EnemyRuntime.attack_building(e, b, def, delta))

func _apply_enemy_attack_events(events: Dictionary) -> void:
	var core_damage := float(events.get("core_damage", 0.0))
	if core_damage > 0.0:
		core_health -= core_damage
		if core_health <= 0.0:
			lost = true
			restart_button.visible = true
	for hit in events.get("building_damage", []):
		_damage_building(hit.building, float(hit.amount))

func _damage_building(b: Dictionary, amount: float) -> void:
	b.health -= amount
	if b.health <= 0.0:
		_remove_building(b)

func _damage_player(amount: float) -> void:
	if not player_alive:
		return
	player_health -= amount
	if player_health <= 0.0:
		player_alive = false
		player_respawn = PLAYER_RESPAWN_TIME
		player_vel = Vector2.ZERO

func _active_avatar_pos() -> Vector2:
	return hero_pos if _is_combat_class() else player_pos

func _active_avatar_alive() -> bool:
	return hero_alive if _is_combat_class() else player_alive

func _damage_active_avatar(amount: float) -> void:
	if _is_combat_class():
		_damage_hero(amount)
	else:
		_damage_player(amount)

func _update_projectiles(delta: float) -> void:
	_apply_projectile_events(EnemyRuntime.update_projectiles(projectiles, enemies, buildings, _active_avatar_alive(), _active_avatar_pos(), TILE, delta))

func _apply_projectile_events(events: Dictionary) -> void:
	for hit in events.get("enemy_damage", []):
		_damage_enemy(hit.enemy, float(hit.amount), hit.get("opts", {}))
	for amount in events.get("avatar_damage", []):
		_damage_active_avatar(float(amount))
	for hit in events.get("building_damage", []):
		_damage_building(hit.building, float(hit.amount))
	for splash in events.get("splashes", []):
		_detonate_splash(splash.pos, float(splash.radius), float(splash.damage))

func _shoot_at(world_pos: Vector2) -> void:
	if player_alive:
		_projectile(player_pos, world_pos, 18.0, 520.0, "player")

func _projectile(from_pos: Vector2, to_pos: Vector2, damage: float, speed: float, team := "player", spread := 0.0, extra: Dictionary = {}) -> void:
	var dir = (to_pos - from_pos).normalized()
	if spread > 0.0:
		dir = dir.rotated(randf_range(-spread, spread))
	var proj := {"pos": from_pos, "vel": dir * speed, "damage": damage, "life": 1.6, "team": team}
	for k in extra:
		proj[k] = extra[k]
	projectiles.append(proj)

func _nearest_enemy(pos: Vector2, search_range: float) -> Variant:
	var best = null
	var best_d = search_range
	for e in enemies:
		var d = pos.distance_to(e.pos)
		if d < best_d:
			best_d = d
			best = e
	return best

func _delete_at(cell: Vector2i) -> void:
	for i in range(blueprints.size() - 1, -1, -1):
		if blueprints[i].pos == cell:
			blueprints.remove_at(i)
			return
	var b = buildings.get(cell)
	if b != null and b.id != "core":
		_remove_building(b)

func _remove_building(b: Dictionary) -> void:
	for p in _cells(b.pos, b.size):
		buildings.erase(p)

func _draw() -> void:
	_draw_world()
	_draw_range()
	_draw_preview()

func _draw_world() -> void:
	for y in MAP_H:
		for x in MAP_W:
			var p = Vector2i(x, y)
			var r = Rect2(Vector2(p * TILE), Vector2(TILE, TILE))
			var t: String = terrain[p]
			var col = Color("#586454")
			if t == "stone":
				col = Color("#68705f")
			elif t == "rock":
				col = Color("#3d4248")
			elif t == "water":
				col = Color("#285f82")
			elif t == "spawn":
				col = Color("#94393f")
			draw_rect(r, col)
			if ore.has(p):
				draw_circle(r.get_center(), 10, _item_color(String(ore[p])))
			draw_rect(r, Color(0, 0, 0, 0.18), false, 1)
	var seen = {}
	for b in buildings.values():
		var key = _building_key(b)
		if seen.has(key):
			continue
		seen[key] = true
		_draw_building(b, false)
	for bp in blueprints:
		var ghost = _make_building(bp.id, bp.pos, bp.rot, false)
		_draw_building(ghost, true)
	for line in power_network_lines:
		if typeof(line) == TYPE_DICTIONARY:
			draw_line(line["from"], line["to"], Color(0.96, 0.87, 0.32, 0.85), 2.0)
		else:
			draw_line(line[0], line[1], Color(0.96, 0.87, 0.32, 0.85), 2.0)
	for bolt in lightning_bolts:
		_draw_lightning_bolt(bolt.from, bolt.to)
	for item in items:
		var dir = item.dir
		var pos = _cell_center(item.cell) + Vector2(DIRS[dir]) * ((item.progress - 0.5) * TILE)
		draw_circle(pos, 5, _item_color(String(item.kind)))
	for l in liquids:
		var pos = _cell_center(l.cell) + Vector2(DIRS[l.dir]) * ((l.progress - 0.5) * TILE)
		draw_circle(pos, 5, Color("#69c9e8"))
	for tg in enemy_telegraphs:
		_draw_telegraph(tg)
	for e in enemies:
		_draw_enemy(e)
	for fx in enemy_effects:
		_draw_effect(fx)
	for p in projectiles:
		if p.get("spell", false):
			draw_circle(p.pos, 8, Color(0.72, 0.55, 1.0, 0.35))
			draw_circle(p.pos, 5, Color("#c9a6ff"))
		elif p.get("splash", 0.0) > 0.0:
			# Lobbed shell: fat glowing mortar round with a motion trail.
			draw_line(p.pos - p.vel.normalized() * 12.0, p.pos, Color(1.0, 0.72, 0.3, 0.4), 3.0)
			draw_circle(p.pos, 7, Color(1.0, 0.7, 0.28, 0.35))
			draw_circle(p.pos, 4, Color("#ffcf6a"))
		elif p.get("heavy", false):
			# Marksman piercing bolt: bright elongated lance.
			draw_line(p.pos - p.vel.normalized() * 16.0, p.pos, Color(0.5, 1.0, 0.95, 0.85), 3.0)
			draw_circle(p.pos, 4, Color("#eafffb"))
		else:
			draw_circle(p.pos, 4, Color("#ff8068") if p.get("team", "player") == "enemy" else Color("#ffe07a"))
	for orb in orbs:
		draw_circle(orb.pos, 4, Color("#4fa8ff"))
	for pulse in nova_pulses:
		var pt: float = clamp(pulse.life / float(pulse.max_life), 0.0, 1.0)
		draw_arc(pulse.pos, max(float(pulse.radius), 1.0), 0.0, TAU, 40, Color(0.66, 0.5, 1.0, 0.25 + 0.5 * pt), 4.0)
	if _is_combat_class() and hero_alive:
		for bp in _orbit_blade_positions():
			draw_line(hero_pos, bp, Color(0.8, 0.85, 1.0, 0.25), 1.5)
			draw_circle(bp, 7, Color("#e6ecff"))
			draw_circle(bp, 4, Color("#9fb4ff"))
	if _is_combat_class():
		if hero_alive:
			draw_circle(hero_pos, 12, Color("#d98cff"))
			draw_circle(hero_pos, 5, Color("#f4e2ff"))
		else:
			draw_circle(hero_pos, 12, Color(0.55, 0.4, 0.6, 0.35))
	else:
		if player_alive:
			var aim = (get_global_mouse_position() - player_pos).normalized()
			draw_circle(player_pos, 13, Color("#8bd1ff"))
			draw_line(player_pos, player_pos + aim * 20.0, Color("#f5d76a"), 4)
		else:
			draw_circle(player_pos, 13, Color(0.35, 0.45, 0.55, 0.35))

# --- Enemy rendering: sprite walk-frames with procedural silhouette fallback ---

func _draw_enemy(e: Dictionary) -> void:
	var edef: Dictionary = enemy_defs.get(e.kind, enemy_defs.grunt)
	EnemyDrawing.draw_enemy(self, e, edef, enemy_sheets, anim_time)

func _draw_telegraph(tg: Dictionary) -> void:
	EnemyDrawing.draw_telegraph(self, tg)

func _draw_effect(fx: Dictionary) -> void:
	EnemyDrawing.draw_effect(self, fx, fx_sheets)

func _draw_building(b: Dictionary, ghost: bool) -> void:
	var rect = Rect2(Vector2(b.pos * TILE), Vector2(b.size * TILE))
	var alpha = 0.42 if ghost else 1.0
	var col = Color("#6f7f8e", alpha)
	match b.id:
		"core":
			col = Color("#416e89", alpha)
		"conveyor":
			col = Color("#355f7a", alpha)
		"fast_conveyor":
			col = Color("#4a7188", alpha)
		"titan_conveyor":
			col = Color("#3d7b7a", alpha)
		"thorium_conveyor":
			col = Color("#70548d", alpha)
		"cross":
			col = Color("#506c86", alpha)
		"drill":
			col = Color("#7e6d46", alpha)
		"rotary_drill":
			col = Color("#7d7a52", alpha)
		"impact_drill":
			col = Color("#4f7d61", alpha) if b.powered else Color("#4d5b4f", alpha)
		"blast_drill":
			col = Color("#7d525f", alpha) if b.powered else Color("#5a464c", alpha)
		"wall":
			col = Color("#8a929a", alpha)
		"turret":
			col = Color("#4d9cc6", alpha) if b.powered else Color("#526675", alpha)
		"scatter_tower":
			col = Color("#5c8fb6", alpha) if b.powered else Color("#586470", alpha)
		"generator":
			col = Color("#7a5d35", alpha)
		"node":
			col = Color("#75b772", alpha) if b.powered else Color("#4c6350", alpha)
		"battery":
			col = Color("#3a4a52", alpha)
		"lightning_turret":
			col = Color("#b98af0", alpha) if b.powered else Color("#5c4d6b", alpha)
		"rail_tower":
			col = Color("#80a5cf", alpha) if b.powered else Color("#586678", alpha)
		"press":
			col = Color("#777087", alpha) if b.powered else Color("#575160", alpha)
		"carbon_refinery":
			col = Color("#8291b9", alpha) if b.powered else Color("#576073", alpha)
		"pump":
			col = Color("#3b9dbb", alpha)
		"pipe":
			col = Color("#4d8fb0", alpha)
	draw_rect(rect.grow(-3), Color("#1b1e22", alpha))
	draw_rect(rect.grow(-6), col)
	if _is_belt_building(b) or b.id == "pipe":
		if _is_belt_building(b):
			_draw_conveyor_shape(b, rect, alpha)
		else:
			_draw_arrow(rect.get_center(), b.rot, Color("#7fe3ff", alpha))
	elif b.id == "cross":
		draw_line(rect.get_center() + Vector2(-11, 0), rect.get_center() + Vector2(11, 0), Color("#f5d76a", alpha), 3)
		draw_line(rect.get_center() + Vector2(0, -11), rect.get_center() + Vector2(0, 11), Color("#7fe3ff", alpha), 3)
	elif _is_drill_id(b.id):
		draw_circle(rect.get_center(), 8, Color("#f5c05a", alpha))
	elif b.id == "battery":
		_draw_battery_level(b, rect, alpha)
	if _is_factory_id(b.id) or b.id == "generator" or _is_ammo_turret_id(b.id) or _is_fluid_turret_id(b.id) or _is_drill_id(b.id) or b.id == "lightning_turret":
		_draw_factory_inventory(b, rect, alpha)

func _draw_arrow(pos: Vector2, rot: int, col: Color) -> void:
	var d = Vector2(DIRS[rot])
	var side = Vector2(-d.y, d.x)
	draw_line(pos - d * 10, pos + d * 10, col, 3)
	draw_polygon([pos + d * 12, pos + side * 6, pos - side * 6], [col])

func _draw_factory_inventory(b: Dictionary, rect: Rect2, alpha: float) -> void:
	var coal_count = min(_store_count(b, "coal"), 4)
	var graphite_count = min(_store_count(b, "graphite"), 4)
	var copper_count = min(_store_count(b, "copper"), 4)
	var water_count = min(_store_count(b, "water"), 4)
	if _is_ammo_turret_id(b.id):
		for i in range(copper_count):
			draw_circle(rect.position + Vector2(9 + i * 7, rect.size.y - 9), 3, Color("#e0a13f", alpha))
		for i in range(graphite_count):
			draw_circle(rect.position + Vector2(9 + (i + copper_count) * 7, rect.size.y - 9), 3, Color("#8ea0ad", alpha))
		for i in range(water_count):
			draw_circle(rect.position + Vector2(rect.size.x - 9 - i * 7, 9), 3, Color("#69c9e8", alpha))
	elif _is_drill_id(b.id):
		for i in range(water_count):
			draw_circle(rect.position + Vector2(9 + i * 7, rect.size.y - 8), 3, Color("#69c9e8", alpha))
	elif b.id == "lightning_turret":
		var charge_count = int(_store_count(b, "charge"))
		for i in range(charge_count):
			draw_circle(rect.position + Vector2(9 + i * 9, rect.size.y - 9), 3.5, Color("#f5e04a", alpha))
	else:
		for i in range(coal_count):
			draw_circle(rect.position + Vector2(11 + i * 8, 12), 3, Color("#202025", alpha))
		for i in range(graphite_count):
			draw_circle(rect.position + Vector2(11 + i * 8, 22), 3, Color("#8ea0ad", alpha))
	if b.id == "generator" and b.fuel > 0.0:
		draw_circle(rect.end - Vector2(13, 13), 5, Color("#ffb84d", alpha))
	if _is_factory_id(b.id) and b.timer > 0.0:
		var craft_time = float(_factory_recipe(b).get("craft_time", 1.8))
		var w = clamp(b.timer / craft_time, 0.0, 1.0) * (rect.size.x - 16)
		draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 13), Vector2(w, 4)), Color("#8ea0ad", alpha))

func _draw_battery_level(b: Dictionary, rect: Rect2, alpha: float) -> void:
	var cap = float(defs.get("battery", {}).get("power_storage", 100.0))
	var stored = float(b.store.get("power", 0))
	var ratio = 0.0 if cap <= 0.0 else clamp(stored / cap, 0.0, 1.0)
	var inner = rect.grow(-9)
	var h = ratio * inner.size.y
	draw_rect(Rect2(inner.position.x, inner.position.y + (inner.size.y - h), inner.size.x, h), Color("#f5e04a", alpha))

func _draw_lightning_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var d = to_pos - from_pos
	var side = Vector2(-d.y, d.x).normalized()
	var mid = from_pos.lerp(to_pos, 0.5) + side * 8.0
	draw_line(from_pos, mid, Color("#f5e04a", 0.9), 3.0)
	draw_line(mid, to_pos, Color("#ffffff", 0.9), 3.0)

func _draw_conveyor_shape(b: Dictionary, rect: Rect2, alpha: float) -> void:
	var center = rect.get_center()
	var belt_col = Color("#83cdf3", alpha)
	if b.id == "fast_conveyor":
		belt_col = Color("#8fd6ff", alpha)
	elif b.id == "titan_conveyor":
		belt_col = Color("#87efe1", alpha)
	elif b.id == "thorium_conveyor":
		belt_col = Color("#d8a4ff", alpha)
	var arrow_col = Color("#f5d76a", alpha)
	var out_dir: int = b.rot
	var dirs: Array[int] = [out_dir]
	for input_dir in _conveyor_input_dirs(b.pos):
		if not dirs.has(input_dir):
			dirs.append(input_dir)
	for dir in dirs:
		var v = Vector2(DIRS[dir])
		draw_line(center, center + v * 13.0, belt_col, 7)
		draw_line(center, center + v * 13.0, Color("#183442", alpha), 2)
	var queued = _belt_item_count(b.pos)
	for i in range(queued):
		draw_circle(rect.position + Vector2(9 + i * 7, rect.size.y - 8), 2.5, Color("#f2c766", alpha))
	_draw_arrow(center + Vector2(DIRS[out_dir]) * 2.0, out_dir, arrow_col)

func _conveyor_input_dirs(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for i in range(DIRS.size()):
		var np = cell + DIRS[i]
		var nb = buildings.get(np)
		if nb == null:
			continue
		var from_neighbor_to_cell = (i + 2) % 4
		if _is_belt_building(nb) and nb.id != "cross" and nb.rot == from_neighbor_to_cell:
			result.append(i)
		elif nb.id == "cross" and _cross_outputs_toward(nb, from_neighbor_to_cell):
			result.append(i)
		elif (_is_drill_id(nb.id) or _is_factory_id(nb.id)) and _building_can_output_to(nb, cell):
			result.append(i)
	return result

func _cross_outputs_toward(_b: Dictionary, dir: int) -> bool:
	return dir % 2 == 0 or dir % 2 == 1

func _building_can_output_to(b: Dictionary, target: Vector2i) -> bool:
	for output in _valid_output_targets(b.pos, "copper", b):
		if output.cell == target:
			return true
	return false

func _draw_range() -> void:
	draw_arc(player_pos, BUILD_RANGE, 0, TAU, 96, Color(0.7, 0.9, 1.0, 0.22), 2)

func _draw_preview() -> void:
	if selected == "" or _mouse_over_ui():
		return
	for c in (_drag_cells() if drag_active else [_mouse_cell()]):
		var ok = _can_place(selected, c)
		var rect = Rect2(Vector2(c * TILE), Vector2(defs[selected].size * TILE))
		var col = Color(0.25, 1.0, 0.55, 0.35) if ok else Color(1.0, 0.15, 0.15, 0.35)
		if ok and _cell_center(c).distance_to(player_pos) > BUILD_RANGE:
			col = Color(0.7, 0.7, 0.7, 0.45)
		draw_rect(rect, col)
		if _is_belt_id(selected) or selected == "pipe":
			_draw_arrow(rect.get_center(), build_rot, Color(1, 1, 1, 0.8))

func _drag_cells() -> Array[Vector2i]:
	if not (_is_belt_id(selected) or selected in ["wall", "pipe"]):
		return [drag_start]
	var diff = drag_current - drag_start
	var cells: Array[Vector2i] = []
	if diff == Vector2i.ZERO:
		return [drag_start]
	if abs(diff.x) >= abs(diff.y):
		build_rot = 0 if diff.x >= 0 else 2
		var step = 1 if diff.x >= 0 else -1
		for x in range(drag_start.x, drag_current.x + step, step):
			cells.append(Vector2i(x, drag_start.y))
	else:
		build_rot = 1 if diff.y >= 0 else 3
		var step = 1 if diff.y >= 0 else -1
		for y in range(drag_start.y, drag_current.y + step, step):
			cells.append(Vector2i(drag_start.x, y))
	return cells

func _vs_hud_text() -> String:
	var need := _xp_needed(vs_level)
	var hero_text := "%d" % int(hero_health) if hero_alive else "respawn %.1fs" % max(hero_respawn, 0.0)
	return "Combat  Lv %d   XP %d / %d   Orbs %d / %d   HP %s/%d   Core %.0f" % [vs_level, vs_xp, need, vs_inventory, VS_ORB_CAP, hero_text, int(_hero_max_health()), core_health]

func _update_hud() -> void:
	if _is_combat_class():
		res_label.text = _vs_hud_text()
	else:
		var player_text = "Drone %.0f" % player_health if player_alive else "Drone respawn %.1fs" % max(player_respawn, 0.0)
		res_label.text = "Copper %d   Coal %d   Graphite %d   Lead %d   Titanium %d   Thorium %d   Water %d   Core %.0f   %s" % [inventory.copper, inventory.coal, inventory.graphite, inventory.lead, inventory.titanium, inventory.thorium, inventory.water, core_health, player_text]
	if won:
		status_label.text = "Victory - all %d waves survived" % MAX_WAVE
	elif lost:
		status_label.text = "Core destroyed"
	elif spawn_left > 0 or not enemies.is_empty():
		status_label.text = "Wave %d / %d   Enemies %d" % [wave, MAX_WAVE, enemies.size() + spawn_left]
	else:
		status_label.text = "Wave %d / %d   Next in %.0fs" % [wave + 1, MAX_WAVE, wave_timer]

func _update_info() -> void:
	if selected == "":
		info_label.text = "No block selected. Left click shoots. WASD moves, wheel zooms, R rotates, right click deletes."
	else:
		var d: Dictionary = defs[selected]
		info_label.text = "%s: %s. Cost %s. R rotates. Drag belts, walls, and pipes." % [d.category, d.name, _cost_text(d.cost)]

func _ids_for_category(category_id: String) -> Array[String]:
	return BuildingText.ids_for_category(defs, category_id)

func _building_details(id: String) -> String:
	return BuildingText.building_details(defs, building_health, id, LIGHTNING_MAX_CHARGE, LIGHTNING_CHARGE_TIME, NODE_RANGE)

func _building_instance_details(b: Dictionary) -> String:
	return BuildingText.building_instance_details(defs, building_health, b, power_network_status, LIGHTNING_MAX_CHARGE, LIGHTNING_CHARGE_TIME, NODE_RANGE)

func _power_status_text(b: Dictionary) -> String:
	return BuildingText.power_status_text(b, power_network_status)

func _show_details(text: String) -> void:
	if details_panel == null or details_label == null:
		return
	details_label.text = text
	details_panel.visible = text != ""

func _hide_details() -> void:
	if details_panel == null:
		return
	details_panel.visible = false
	if details_label != null:
		details_label.text = ""

func _update_world_hover_details() -> void:
	if details_from_ui or details_panel == null:
		return
	if _mouse_over_ui() or drag_active:
		_hide_details()
		return
	var b = buildings.get(_mouse_cell())
	if b != null:
		_show_details(_building_instance_details(b))
	else:
		_hide_details()

func _restart() -> void:
	terrain.clear()
	ore.clear()
	buildings.clear()
	blueprints.clear()
	items.clear()
	enemies.clear()
	projectiles.clear()
	liquids.clear()
	inventory = TEST_STARTING_RESOURCES.duplicate()
	player_pos = Vector2(30 * TILE, 28 * TILE)
	player_health = PLAYER_MAX_HEALTH
	player_respawn = 0.0
	player_alive = true
	core_health = TEST_CORE_HEALTH
	wave = 0
	wave_timer = TEST_WAVE_TIMER
	spawn_left = 0
	won = false
	lost = false
	restart_button.visible = false
	_generate_level()
	_place_core()

func _cells(pos: Vector2i, size: Vector2i) -> Array[Vector2i]:
	return Grid.cells(pos, size)

func _inside(p: Vector2i) -> bool:
	return Grid.inside(p, MAP_W, MAP_H)

func _cell_center(p: Vector2i) -> Vector2:
	return Grid.cell_center(p, TILE)

func _world_cell(pos: Vector2) -> Vector2i:
	return Grid.world_cell(pos, TILE)

func _mouse_cell() -> Vector2i:
	return _world_cell(get_global_mouse_position())

func _mouse_over_ui() -> bool:
	var m = get_viewport().get_mouse_position()
	var s = get_viewport_rect().size
	return m.x > s.x - 490 and m.y > s.y - 350

func _core_contains(p: Vector2i) -> bool:
	return Grid.cell_in_rect(p, CORE_POS, CORE_SIZE)

func _touches_core(p: Vector2i) -> bool:
	return Grid.touches_rect(p, CORE_POS, CORE_SIZE, DIRS)

func _cell_in_rect(p: Vector2i, pos: Vector2i, size: Vector2i) -> bool:
	return Grid.cell_in_rect(p, pos, size)

func _can_afford(cost: Dictionary) -> bool:
	return InventoryHelper.can_afford(inventory, cost)

func _pay(cost: Dictionary) -> void:
	InventoryHelper.pay(inventory, cost)

func _cost_text(cost: Dictionary) -> String:
	return InventoryHelper.cost_text(cost)
