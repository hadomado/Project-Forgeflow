extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var ok = run_feature_tests()
	if ok:
		print("FEATURE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func run_feature_tests() -> bool:
	_test_vs_class_switch_preserves_state()
	_test_vs_hero_respawn_scales_with_level()
	_test_vs_orbs_drop_magnet_and_cap()
	_test_vs_xp_curve_and_leveling()
	_test_vs_xp_sink_credits_only_source()
	_test_vs_resource_depot_converts_orbs_to_copper()
	_test_vs_spells_autocast_and_damage()
	_test_vs_level_up_choice_pick_one_of_three()
	_test_vs_passive_upgrades_change_stats()
	_test_vs_enemy_fire_damages_hero()
	_test_vs_build_panel_and_hud_gating()
	_test_vs_spell_visuals_and_orbit()
	_test_natural_walls_clean_ore_and_block_enemy()
	_test_pathfinding_respects_and_ignores_player_blocks()
	_test_enemy_target_bias_prefers_buildings()
	_test_damage_removes_destroyed_building()
	_test_enemy_defs_have_fifteen_distinct_types()
	_test_brood_splits_into_swarmlings_on_death()
	_test_mender_heals_nearby_wounded_enemies()
	_test_berserker_enrages_below_half_hp()
	_test_armor_reduces_incoming_damage()
	_test_warden_shield_blocks_frontal_damage()
	_test_splash_detonation_respects_radius()
	_test_wraith_phase_ignores_damage()
	_test_waves_scale_to_ten_and_introduce_new_enemies()
	_test_open_pipes_spill_and_consumers_accept_water()
	_test_build_categories_and_details()
	_test_build_category_rail_stays_inside_panel_with_many_buildings()
	_test_progression_defs_include_new_ores_and_tiers()
	_test_generated_level_contains_new_ore_tiers()
	_test_tiered_drills_respect_ore_hardness()
	_test_tiered_conveyors_move_items_at_different_speeds()
	_test_power_networks_merge_and_scale_efficiency()
	_test_battery_charges_and_discharges()
	_test_lightning_turret_charge_scales_with_power()
	_test_graphite_press_runs_without_power()
	_test_advanced_factory_requires_power_and_produces_more_graphite()
	_test_generator_requires_stored_coal()
	_test_core_acts_as_power_battery()
	_test_power_links_only_relevant_minimal_connections()
	_test_details_bubble_visibility_and_runtime_power()
	_test_sand_magma_and_new_block_defs()
	_test_new_factories_and_fluid_chain()
	_test_new_turrets_fire_with_required_inputs()
	_test_base_turret_accepts_default_ammo()
	_test_world_starts_with_one_chunk()
	_test_map_expands_every_five_waves()
	_test_only_furthest_chunks_spawn_enemies()
	_test_ore_deposits_have_geode_cores()
	_test_sand_and_magma_generate_in_terrain()
	return failures.is_empty()

func _new_game() -> Node2D:
	var game = MainScript.new()
	get_root().add_child(game)
	game._generate_level()
	game._place_core()
	return game

func _finish_game(game: Node2D) -> void:
	game.queue_free()

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])

func _test_vs_class_switch_preserves_state() -> void:
	var game = _new_game()
	game._make_ui()
	_assert_eq(game.active_class, "factory", "Game should start in the factory class.")
	game._add_building("wall", Vector2i(10, 10), 0, true)
	game.inventory.copper = 123
	game.vs_xp = 7
	game.vs_level = 3
	game.vs_inventory = 44
	game._set_active_class("combat")
	_assert_true(game._is_combat_class(), "Switching to combat should report combat class active.")
	_assert_true(game.buildings.has(Vector2i(10, 10)), "Switching class must not remove buildings.")
	_assert_eq(game.inventory.copper, 123, "Switching class must not change factory inventory.")
	_assert_eq(game.vs_xp, 7, "Switching class must not change vs_xp.")
	_assert_eq(game.vs_level, 3, "Switching class must not change vs_level.")
	_assert_eq(game.vs_inventory, 44, "Switching class must not change vs_inventory.")
	game._set_active_class("factory")
	_assert_true(not game._is_combat_class(), "Switching back should report factory class.")
	_finish_game(game)

func _test_vs_hero_respawn_scales_with_level() -> void:
	var game = _new_game()
	game.vs_level = 1
	_assert_eq(game._hero_respawn_time(), 1.0, "Level 1 respawn should be 1s per level = 1s.")
	game.vs_level = 3
	_assert_eq(game._hero_respawn_time(), 3.0, "Level 3 respawn should be 1s per level = 3s.")
	game.vs_level = 30
	_assert_eq(game._hero_respawn_time(), 20.0, "Respawn should cap at 20s.")
	game.vs_level = 2
	game.hero_health = 10.0
	game._damage_hero(999.0)
	_assert_true(not game.hero_alive, "Hero should die when health hits 0.")
	_assert_eq(game.hero_respawn, 2.0, "Dead hero should queue a 1s*2 = 2s respawn.")
	game._update_hero(6.0)
	_assert_true(game.hero_alive, "Hero should revive after the respawn timer elapses.")
	_assert_eq(game.hero_health, game.VS_HERO_MAX_HEALTH, "Revived hero should be at full health.")
	_finish_game(game)

func _test_vs_orbs_drop_magnet_and_cap() -> void:
	var game = _new_game()
	game._make_ui()
	_assert_eq(game._orb_drop_count("scout"), 1, "Scouts should drop 1 orb.")
	_assert_true(game._orb_drop_count("siege") >= 3, "Siege should drop at least 3 orbs.")
	game._set_active_class("combat")
	game.hero_pos = Vector2(500, 500)
	game.hero_alive = true
	game.orbs.append({"pos": Vector2(505, 500)})
	game._update_orbs(0.5)
	_assert_eq(game.vs_inventory, 1, "Orb within magnet radius should be collected.")
	_assert_eq(game.orbs.size(), 0, "Collected orb should be removed from the world.")
	game.vs_inventory = game.VS_ORB_CAP
	game.orbs.append({"pos": Vector2(505, 500)})
	game._update_orbs(0.5)
	_assert_eq(game.vs_inventory, game.VS_ORB_CAP, "Inventory should not exceed the cap.")
	_assert_eq(game.orbs.size(), 1, "Overflow orb should stay on the ground.")
	_finish_game(game)

func _test_vs_xp_curve_and_leveling() -> void:
	var game = _new_game()
	_assert_eq(game._xp_needed(1), 5, "Level 1->2 should need 5 XP.")
	_assert_eq(game._xp_needed(2), 8, "Level 2->3 should need 8 XP.")
	_assert_eq(game._xp_needed(3), 12, "Level 3->4 should need 12 XP.")
	game.vs_level = 1
	game.vs_xp = 0
	game.levelup_queue = 0
	game._add_vs_xp(6)
	_assert_eq(game.vs_level, 2, "6 XP should push level 1 to level 2.")
	_assert_eq(game.vs_xp, 1, "Remainder XP (6-5) should carry over.")
	_assert_eq(game.levelup_queue, 1, "A level-up should queue one choice.")
	game._add_vs_xp(100)
	_assert_true(game.vs_level >= 4, "A large XP lump should grant several levels.")
	_assert_true(game.levelup_queue >= 3, "Each level gained should queue a choice.")
	_finish_game(game)

func _test_vs_xp_sink_credits_only_source() -> void:
	var game = _new_game()
	_assert_eq(game._xp_value("graphite"), 3, "Graphite should be worth 3 XP.")
	_assert_eq(game._xp_value("copper"), 1, "Copper should be worth 1 XP.")
	_assert_eq(game._xp_value("coal"), 1, "Coal should be worth 1 XP.")
	_assert_eq(game._xp_value("titanium"), 0, "Non-accepted items should be worth 0 XP.")
	game._add_building("xp_sink", Vector2i(20, 20), 0, true)
	var sink = game.buildings[Vector2i(20, 20)]
	_assert_true(game._deliver_item_to_building_would_accept(sink, "graphite"), "XP sink should accept graphite.")
	_assert_true(game._deliver_item_to_building_would_accept(sink, "copper"), "XP sink should accept copper.")
	_assert_true(not game._deliver_item_to_building_would_accept(sink, "titanium"), "XP sink should reject non-XP items.")
	game.vs_xp = 0
	game.vs_level = 1
	game._add_store(sink, "graphite", 1)
	game._update_buildings(5.0)
	_assert_eq(game.vs_xp, 3, "Feeding one graphite should credit exactly 3 XP through the sink.")
	_assert_eq(game._store_count(sink, "graphite"), 0, "The XP sink should consume the fed graphite.")
	_finish_game(game)

func _test_vs_resource_depot_converts_orbs_to_copper() -> void:
	var game = _new_game()
	game._make_ui()
	game._add_building("resource_depot", Vector2i(20, 20), 0, true)
	game._add_building("conveyor", Vector2i(22, 20), 0, true)
	var depot = game.buildings[Vector2i(20, 20)]
	game.buildings[Vector2i(22, 20)].rot = 0
	game._set_active_class("combat")
	game.hero_alive = true
	game.hero_pos = game._building_center(depot)
	game.vs_inventory = 10
	_assert_true(game._depot_in_range_of_hero(depot), "Hero standing on the depot should be in range.")
	game._update_buildings(2.0)
	_assert_true(game.vs_inventory < 10, "Depot should drain orbs from inventory while the hero is in range.")
	var produced_copper = int(depot.store.get("copper", 0)) + int(game._belt_item_count(Vector2i(22, 20)))
	_assert_true(produced_copper > 0, "Drained orbs should become copper (stored or emitted to a belt).")
	var before = int(game.vs_inventory)
	game.hero_pos = Vector2(2000, 2000)
	game._update_buildings(2.0)
	_assert_eq(game.vs_inventory, before, "Depot should not drain when the hero is out of range.")
	_finish_game(game)

func _test_vs_spells_autocast_and_damage() -> void:
	var game = _new_game()
	game._make_ui()
	_assert_eq(int(game.owned_spells.get("arc_bolt", 0)), 1, "Hero should start with Arc Bolt at level 1.")
	game._set_active_class("combat")
	game.hero_alive = true
	game.hero_pos = Vector2(500, 500)
	var e = game._make_enemy("grunt", Vector2(560, 500))
	game.enemies.append(e)
	var hp_before = float(e.hp)
	# Use a realistic small timestep: the projectile hit test is a per-frame
	# proximity check, so a coarse dt would leap the bolt past the enemy.
	for n in 60:
		game._update_spells(0.05)
		game._update_projectiles(0.05)
	_assert_true(e.hp < hp_before, "Arc Bolt should auto-cast and damage a nearby enemy.")
	_finish_game(game)

func _test_vs_level_up_choice_pick_one_of_three() -> void:
	var game = _new_game()
	game._make_ui()
	game.owned_spells = {"arc_bolt": 1}
	game.owned_upgrades = {}
	var choices = game._roll_level_up_choices()
	_assert_eq(choices.size(), 3, "Level-up should offer exactly 3 choices.")
	game._apply_level_up_choice({"type": "spell", "id": "pulse_nova"})
	_assert_eq(int(game.owned_spells.get("pulse_nova", 0)), 1, "Choosing a new spell should grant it at level 1.")
	game._apply_level_up_choice({"type": "spell", "id": "pulse_nova"})
	_assert_eq(int(game.owned_spells.get("pulse_nova", 0)), 2, "Choosing an owned spell should level it up.")
	game._apply_level_up_choice({"type": "upgrade", "id": "swiftness"})
	_assert_eq(int(game.owned_upgrades.get("swiftness", 0)), 1, "Choosing an upgrade should increment it.")
	game.levelup_queue = 2
	game.levelup_open = false
	game._open_level_up()
	_assert_true(game.levelup_open, "Opening a level-up should set the pause flag.")
	_assert_eq(game.levelup_choices.size(), 3, "Opening should populate 3 choice cards.")
	_assert_eq(game.levelup_queue, 1, "Opening should consume one queued level-up.")
	_finish_game(game)

func _test_vs_passive_upgrades_change_stats() -> void:
	var game = _new_game()
	var base_speed = float(game._hero_move_speed())
	var base_magnet = float(game._hero_magnet_radius())
	var base_cd = float(game._spell_cooldown_scale())
	var base_hp = float(game._hero_max_health())
	game.owned_upgrades = {"swiftness": 1, "lodestone": 1, "rapid_casting": 1, "vitality": 1}
	_assert_true(game._hero_move_speed() > base_speed, "Swiftness should increase move speed.")
	_assert_true(game._hero_magnet_radius() > base_magnet, "Lodestone should increase magnet radius.")
	_assert_true(game._spell_cooldown_scale() < base_cd, "Rapid Casting should reduce cooldown scale.")
	_assert_true(game._hero_max_health() > base_hp, "Vitality should increase max health.")
	_finish_game(game)

func _test_vs_enemy_fire_damages_hero() -> void:
	var game = _new_game()
	game._make_ui()
	game._set_active_class("combat")
	game.hero_alive = true
	game.hero_health = game.VS_HERO_MAX_HEALTH
	game._damage_active_avatar(15.0)
	_assert_true(game.hero_health < game.VS_HERO_MAX_HEALTH, "Active-avatar damage should hurt the hero in combat class.")
	game._set_active_class("factory")
	var hp_before = float(game.player_health)
	game._damage_active_avatar(15.0)
	_assert_true(game.player_health < hp_before, "Active-avatar damage should hurt the drone in factory class.")
	_finish_game(game)

func _test_vs_build_panel_and_hud_gating() -> void:
	var game = _new_game()
	game._make_ui()
	var combat_ids = game._ids_for_category("combat")
	_assert_true(combat_ids.has("xp_sink"), "Combat category should include the XP sink.")
	_assert_true(combat_ids.has("resource_depot"), "Combat category should include the resource depot.")
	_assert_true(not combat_ids.has("turret"), "Combat category should not include factory buildings.")
	_assert_true(not game._ids_for_category("factories").has("xp_sink"), "XP sink should not appear in factory categories.")
	game._set_active_class("combat")
	game.vs_level = 4
	game.vs_inventory = 137
	game._update_hud()
	var hud = game._vs_hud_text()
	_assert_true(hud.contains("Lv 4"), "Combat HUD should show the hero level.")
	_assert_true(hud.contains("137") and hud.contains("200"), "Combat HUD should show orb inventory and cap.")
	_finish_game(game)

func _test_vs_spell_visuals_and_orbit() -> void:
	var game = _new_game()
	game._make_ui()
	game._set_active_class("combat")
	game.hero_alive = true
	game.hero_pos = Vector2(900, 800)
	# Orbiting Blades: multiple blades, positions match count, and they damage a ring enemy.
	game.owned_spells = {"orbiting_blades": 3}
	_assert_true(game._orbit_blade_count() >= 2, "Orbiting Blades should have multiple blades at level 3.")
	_assert_eq(game._orbit_blade_positions().size(), game._orbit_blade_count(), "Blade positions should match blade count.")
	var ring_pos = game.hero_pos + Vector2(game.ORBIT_RADIUS, 0.0)
	var e = game._make_enemy("bruiser", ring_pos)
	game.enemies.append(e)
	var hp0 = float(e.hp)
	for f in range(120):
		game._update_orbit_blades(0.05)
	_assert_true(e.hp < hp0, "Orbiting Blades should damage an enemy on the orbit ring.")
	# Pulse Nova: casting spawns a visible pulse ring that expires.
	game.owned_spells = {"pulse_nova": 1}
	game.nova_pulses.clear()
	game._cast_spell("pulse_nova", 1)
	_assert_eq(game.nova_pulses.size(), 1, "Casting Pulse Nova should spawn a visible pulse ring.")
	game._update_nova_pulses(1.0)
	_assert_eq(game.nova_pulses.size(), 0, "Nova pulse should expire after its lifetime.")
	# Arc Bolt: creates a spell-tagged projectile for a distinct visual.
	game.projectiles.clear()
	game._spell_projectile(game.hero_pos, game.hero_pos + Vector2(100, 0), 10.0, 400.0)
	_assert_true(game.projectiles.size() == 1 and bool(game.projectiles[0].get("spell", false)), "Arc Bolt should create a spell-tagged projectile.")
	_finish_game(game)

func _test_natural_walls_clean_ore_and_block_enemy() -> void:
	var game = _new_game()
	# Geodes are the new ore-core natural walls: they behave exactly like rock.
	var geode_cell = game.SPAWN_ORIGIN + Vector2i(5, 5)
	game.terrain[geode_cell] = "geode"
	game.ore[geode_cell] = "copper"
	game._cleanup_ore_in_natural_walls()
	_assert_true(not game.ore.has(geode_cell), "Ore on natural walls (geodes) should be removed.")
	_assert_true(not game._can_place("wall", geode_cell), "Buildings should not place on geodes.")
	_assert_true(not game._enemy_tile_passable(geode_cell, false), "Enemies should not pass geodes.")
	# A plain rock cell is still a natural wall too.
	var rock_cell = game.SPAWN_ORIGIN + Vector2i(6, 6)
	game.terrain[rock_cell] = "rock"
	_assert_true(not game._enemy_tile_passable(rock_cell, false), "Enemies should not pass rock.")
	_finish_game(game)

func _test_pathfinding_respects_and_ignores_player_blocks() -> void:
	var game = _new_game()
	# Build a self-contained arena: a rock-walled box (natural walls seal it from
	# the surrounding organic terrain) split by a full-height player-wall column.
	var o = game.SPAWN_ORIGIN
	var c = game.CHUNK
	for y in range(0, c):
		for x in range(0, c):
			var edge: bool = x == 0 or y == 0 or x == c - 1 or y == c - 1
			game.terrain[o + Vector2i(x, y)] = "rock" if edge else "ground"
	var wall_x = 5
	for y in range(1, c - 1):
		game._add_building("wall", o + Vector2i(wall_x, y), 0, true)
	var start = o + Vector2i(wall_x - 2, 6)
	var goal = o + Vector2i(wall_x + 2, 6)
	var blocked_path: Array[Vector2i] = game._find_enemy_path(start, goal, false)
	var fallback_path: Array[Vector2i] = game._find_enemy_path(start, goal, true)
	_assert_true(blocked_path.is_empty(), "Full wall line should block normal enemy pathing.")
	_assert_true(not fallback_path.is_empty(), "Fallback path should ignore player walls.")
	_finish_game(game)

func _test_enemy_target_bias_prefers_buildings() -> void:
	var game = _new_game()
	var wall = game._make_building("wall", Vector2i(10, 10), 0, true)
	var turret = game._make_building("turret", Vector2i(11, 10), 0, true)
	game.buildings[wall.pos] = wall
	game.buildings[turret.pos] = turret
	var e = game._make_enemy("grunt", game._cell_center(Vector2i(9, 10)))
	e.path = [Vector2i(9, 10), Vector2i(10, 10), Vector2i(11, 10)]
	var target: Dictionary = game._enemy_target(e)
	_assert_true(target.has("building") and target.building.id == "turret", "Enemy targeting should bias toward buildings over walls.")
	_finish_game(game)

func _test_damage_removes_destroyed_building() -> void:
	var game = _new_game()
	game._add_building("pipe", Vector2i(12, 12), 0, true)
	var pipe = game.buildings[Vector2i(12, 12)]
	game._damage_building(pipe, 999.0)
	_assert_true(not game.buildings.has(Vector2i(12, 12)), "Destroyed buildings should be removed.")
	_finish_game(game)

func _test_enemy_defs_have_fifteen_distinct_types() -> void:
	var game = _new_game()
	_assert_eq(game.enemy_defs.size(), 15, "There should be fifteen enemy types (5 originals + 10 new).")
	_assert_true(game.enemy_defs.scout.speed != game.enemy_defs.siege.speed, "Enemy variants should have distinct stats.")
	_assert_true(game.enemy_defs.ranger.range > game.enemy_defs.grunt.range, "Enemy guns should vary by range.")
	# The ten new archetypes must all exist and read as mechanically distinct.
	var new_kinds = ["swarmling", "wraith", "berserker", "marksman", "warden", "brood", "mender", "artillery", "juggernaut", "overseer"]
	for kind in new_kinds:
		_assert_true(game.enemy_defs.has(kind), "New enemy '%s' should be defined." % kind)
	# Distinct colors across every enemy type.
	var seen_colors = {}
	for kind in game.enemy_defs:
		var key = game.enemy_defs[kind].color.to_html()
		_assert_true(not seen_colors.has(key), "Enemy '%s' should have a unique color." % kind)
		seen_colors[key] = true
	# Role sanity: swarmling is the fastest and flimsiest; the boss is the beefiest.
	_assert_true(game.enemy_defs.swarmling.speed > game.enemy_defs.scout.speed, "Swarmlings should be faster than scouts.")
	_assert_true(game.enemy_defs.marksman.range > game.enemy_defs.ranger.range, "Marksman should out-range the ranger.")
	_assert_true(game.enemy_defs.juggernaut.hp > game.enemy_defs.siege.hp, "Juggernaut should be tankier than siege.")
	_assert_true(game.enemy_defs.overseer.hp >= game.enemy_defs.juggernaut.hp, "Overseer boss should be the toughest enemy.")
	_finish_game(game)

func _test_brood_splits_into_swarmlings_on_death() -> void:
	var game = _new_game()
	game.enemies.clear()
	var brood = game._make_enemy("brood", game._cell_center(Vector2i(10, 10)))
	game.enemies.append(brood)
	brood.hp = 0.0
	game._update_enemies(0.0)
	_assert_true(not game.enemies.is_empty(), "A dead brood should leave behind spawned swarmlings.")
	for e in game.enemies:
		_assert_eq(e.kind, "swarmling", "Brood should split into swarmlings.")
	_assert_eq(game.enemies.size(), 3, "Brood should spawn three swarmlings on death.")
	_finish_game(game)

func _test_mender_heals_nearby_wounded_enemies() -> void:
	var game = _new_game()
	game.enemies.clear()
	var mender = game._make_enemy("mender", game._cell_center(Vector2i(10, 10)))
	var patient = game._make_enemy("grunt", game._cell_center(Vector2i(10, 10)))
	patient.hp = 5.0
	game.enemies.append(mender)
	game.enemies.append(patient)
	game._enemy_heal_aura(mender, game.enemy_defs.mender.heal_aura, 1.0)
	_assert_true(patient.hp > 5.0, "Mender aura should heal a wounded ally in range.")
	_assert_true(patient.hp <= float(patient.max_hp), "Healing should not exceed the ally's max HP.")
	# An ally beyond the aura radius should not be healed.
	var far = game._make_enemy("grunt", game._cell_center(Vector2i(40, 30)))
	far.hp = 5.0
	game.enemies.append(far)
	game._enemy_heal_aura(mender, game.enemy_defs.mender.heal_aura, 1.0)
	_assert_eq(far.hp, 5.0, "Mender should not heal allies outside its aura radius.")
	_finish_game(game)

func _test_berserker_enrages_below_half_hp() -> void:
	var game = _new_game()
	game.enemies.clear()
	var b = game._make_enemy("berserker", game._cell_center(Vector2i(10, 10)))
	game.enemies.append(b)
	_assert_true(not b.enraged, "Berserker should start calm.")
	var calm_speed = game._enemy_speed(b, game.enemy_defs.berserker)
	b.hp = float(b.max_hp) * 0.4
	game._update_enemy_mechanics(b, game.enemy_defs.berserker, 0.016)
	_assert_true(b.enraged, "Berserker should enrage once below its HP threshold.")
	_assert_true(game._enemy_speed(b, game.enemy_defs.berserker) > calm_speed, "Enraged berserker should move faster.")
	_finish_game(game)

func _test_armor_reduces_incoming_damage() -> void:
	var game = _new_game()
	game.enemies.clear()
	var jug = game._make_enemy("juggernaut", game._cell_center(Vector2i(10, 10)))
	var grunt = game._make_enemy("grunt", game._cell_center(Vector2i(12, 10)))
	game.enemies.append(jug)
	game.enemies.append(grunt)
	var jug_hp = float(jug.hp)
	var grunt_hp = float(grunt.hp)
	game._damage_enemy(jug, 20.0, {})
	game._damage_enemy(grunt, 20.0, {})
	var jug_loss = jug_hp - float(jug.hp)
	var grunt_loss = grunt_hp - float(grunt.hp)
	_assert_true(jug_loss < grunt_loss, "Armored juggernaut should take less than an unarmored grunt from the same hit.")
	_assert_true(jug_loss > 0.0, "Armor should still let some damage through.")
	_finish_game(game)

func _test_warden_shield_blocks_frontal_damage() -> void:
	var game = _new_game()
	game.enemies.clear()
	var w = game._make_enemy("warden", game._cell_center(Vector2i(10, 10)))
	game.enemies.append(w)
	w.facing = Vector2.RIGHT
	var hp0 = float(w.hp)
	# A shot traveling LEFT strikes the warden's RIGHT-facing front -> shield absorbs.
	game._damage_enemy(w, 40.0, {"dir": Vector2.LEFT})
	var front_loss = hp0 - float(w.hp)
	w.hp = hp0
	# A shot traveling RIGHT hits its back -> only armor applies.
	game._damage_enemy(w, 40.0, {"dir": Vector2.RIGHT})
	var back_loss = hp0 - float(w.hp)
	_assert_true(front_loss < back_loss, "Warden should absorb more from its facing arc than from behind.")
	_finish_game(game)

func _test_splash_detonation_respects_radius() -> void:
	var game = _new_game()
	game.active_class = "combat"
	game.hero_alive = true
	game.hero_pos = Vector2(500, 500)
	var hp0 = float(game.hero_health)
	game._detonate_splash(Vector2(512, 500), 74.0, 30.0)
	_assert_true(game.hero_health < hp0, "Splash detonation should damage the avatar within its radius.")
	var hp1 = float(game.hero_health)
	game._detonate_splash(Vector2(900, 900), 74.0, 30.0)
	_assert_eq(game.hero_health, hp1, "Splash outside the radius should not damage the avatar.")
	_finish_game(game)

func _test_wraith_phase_ignores_damage() -> void:
	var game = _new_game()
	game.enemies.clear()
	var wr = game._make_enemy("wraith", game._cell_center(Vector2i(10, 10)))
	game.enemies.append(wr)
	wr.invuln = 0.5
	var hp0 = float(wr.hp)
	game._damage_enemy(wr, 30.0, {"dir": Vector2.LEFT})
	_assert_eq(wr.hp, hp0, "A phased (invulnerable) wraith should take no damage.")
	wr.invuln = 0.0
	game._damage_enemy(wr, 30.0, {"dir": Vector2.LEFT})
	_assert_true(wr.hp < hp0, "Once the phase ends the wraith takes damage again.")
	_finish_game(game)

func _test_waves_scale_to_ten_and_introduce_new_enemies() -> void:
	var game = _new_game()
	_assert_eq(game.MAX_WAVE, 10, "The campaign should run for ten waves.")
	# Late waves must be able to roll the toughest new archetypes.
	game.wave = 10
	var kinds = {}
	for n in 4000:
		kinds[game._enemy_kind_for_wave()] = true
	for kind in ["swarmling", "wraith", "berserker", "marksman", "warden", "brood", "mender", "artillery", "juggernaut", "overseer"]:
		_assert_true(kinds.has(kind), "Wave 10 spawn pool should be able to roll '%s'." % kind)
	# Early waves must not spawn late-game bosses.
	game.wave = 1
	var early = {}
	for n in 2000:
		early[game._enemy_kind_for_wave()] = true
	_assert_true(not early.has("overseer"), "Overseer boss should not appear on wave 1.")
	_assert_true(not early.has("juggernaut"), "Juggernaut should not appear on wave 1.")
	_finish_game(game)

func _test_open_pipes_spill_and_consumers_accept_water() -> void:
	var game = _new_game()
	game._add_building("pipe", Vector2i(20, 20), 0, true)
	game.liquids.append({"kind": "water", "cell": Vector2i(20, 20), "progress": 1.0, "dir": 0})
	game._update_liquids(0.0)
	_assert_eq(game.inventory.water, 0, "Open pipes should spill instead of adding global water.")
	_assert_eq(game.liquids.size(), 0, "Spilled water should leave the pipe network.")
	game._add_building("pipe", Vector2i(22, 20), 0, true)
	game._add_building("turret", Vector2i(23, 20), 0, true)
	game.liquids.append({"kind": "water", "cell": Vector2i(22, 20), "progress": 1.0, "dir": 0})
	game._update_liquids(0.0)
	var turret = game.buildings[Vector2i(23, 20)]
	_assert_eq(game._store_count(turret, "water"), 1, "Turrets should accept water from pipes.")
	_finish_game(game)

func _test_build_categories_and_details() -> void:
	var game = _new_game()
	_assert_eq(game.build_categories.size(), 9, "Build UI should expose eight factory categories plus the combat category.")
	_assert_true(game._ids_for_category("turrets").has("turret"), "Turrets category should include the base turret.")
	_assert_true(game._ids_for_category("turrets").has("lightning_turret"), "Turrets category should include the lightning turret.")
	_assert_true(game._ids_for_category("turrets").has("scatter_tower"), "Turrets category should include higher-tier towers.")
	_assert_true(game._ids_for_category("power").has("node"), "Power category should include power nodes.")
	_assert_true(game._ids_for_category("power").has("battery"), "Power category should include batteries.")
	var details = game._building_details("lightning_turret")
	_assert_true(details.contains("Health"), "Building hover details should include health.")
	_assert_true(details.contains("Power"), "Lightning turret details should include power stats.")
	_assert_true(details.contains("Charge"), "Lightning turret details should include charge stats.")
	_finish_game(game)

func _test_build_category_rail_stays_inside_panel_with_many_buildings() -> void:
	var game = _new_game()
	game._make_ui()
	game.selected_category = "turrets"
	game._refresh_build_grid()
	var hbox = game.category_rail.get_parent()
	var panel = hbox.get_parent().get_parent()
	var panel_width = panel.offset_right - panel.offset_left
	_assert_true(hbox.get_combined_minimum_size().x <= panel_width, "Build category rail should remain inside the panel when categories gain more buildings.")
	_finish_game(game)

func _test_progression_defs_include_new_ores_and_tiers() -> void:
	var game = _new_game()
	_assert_true(not game.defs.has("enhanced_graphite"), "Enhanced graphite should be removed once higher-tier progression exists.")
	_assert_true(game.inventory.has("lead") and game.inventory.has("titanium") and game.inventory.has("thorium"), "Inventory should track all new ore tiers.")
	_assert_true(game._ids_for_category("belts").has("fast_conveyor"), "Belts category should include a faster conveyor tier.")
	_assert_true(game._ids_for_category("drills").has("rotary_drill"), "Drills category should include a higher-tier drill.")
	_assert_true(game._ids_for_category("factories").has("carbon_refinery"), "Factories category should include a higher-tier factory.")
	_assert_true(game._ids_for_category("turrets").has("rail_tower"), "Turrets category should include a late-tier tower.")
	_assert_true(game._building_details("rotary_drill").contains("Mines up to"), "Higher-tier drill details should describe ore tier coverage.")
	_finish_game(game)

func _test_generated_level_contains_new_ore_tiers() -> void:
	var game = _new_game()
	# Higher tiers are biased into the further/newer chunks, so open the whole
	# world before checking the ore mix.
	while game._open_next_chunk():
		pass
	var counts := {"lead": 0, "titanium": 0, "thorium": 0}
	for kind in game.ore.values():
		if counts.has(kind):
			counts[kind] += 1
	_assert_true(counts.lead > 0, "Map generation should include lead ore.")
	_assert_true(counts.titanium > 0, "Map generation should include titanium ore.")
	_assert_true(counts.thorium > 0, "Map generation should include thorium ore.")
	_finish_game(game)

func _test_tiered_drills_respect_ore_hardness() -> void:
	var game = _new_game()
	var a = game.SPAWN_ORIGIN + Vector2i(3, 3)
	var b = game.SPAWN_ORIGIN + Vector2i(5, 3)
	# Clear the footprints so terrain never blocks the drill checks.
	for p in game._cells(a - Vector2i(1, 1), Vector2i(4, 4)):
		game.terrain[p] = "ground"
	for p in game._cells(b - Vector2i(1, 1), Vector2i(4, 4)):
		game.terrain[p] = "ground"
	game.ore[a] = "titanium"
	game.ore[b] = "thorium"
	_assert_true(not game._can_place("drill", a), "Base drill should not place on titanium.")
	_assert_true(game._can_place("impact_drill", a), "Impact drill should place on titanium.")
	_assert_true(not game._can_place("impact_drill", b), "Impact drill should not place on thorium.")
	_assert_true(game._can_place("blast_drill", b), "Blast drill should place on thorium.")
	_finish_game(game)

func _test_tiered_conveyors_move_items_at_different_speeds() -> void:
	var game = _new_game()
	game._add_building("conveyor", Vector2i(20, 20), 0, true)
	game._add_building("fast_conveyor", Vector2i(22, 20), 0, true)
	game.items.append({"kind": "copper", "cell": Vector2i(20, 20), "progress": 0.0, "dir": 0})
	game.items.append({"kind": "copper", "cell": Vector2i(22, 20), "progress": 0.0, "dir": 0})
	game._update_items(0.2)
	var base_progress = float(game.items[0].progress)
	var fast_progress = float(game.items[1].progress)
	_assert_true(fast_progress > base_progress, "Higher-tier conveyors should move items faster than base conveyors.")
	_finish_game(game)

func _test_power_networks_merge_and_scale_efficiency() -> void:
	var game = _new_game()
	game._add_building("generator", Vector2i(20, 20), 0, true)
	game._add_building("node", Vector2i(23, 20), 0, true)
	game._add_building("node", Vector2i(29, 20), 0, true)
	game._add_building("lightning_turret", Vector2i(32, 20), 0, true)
	var generator = game.buildings[Vector2i(20, 20)]
	generator.fuel = 10.0
	game._calculate_power_networks(1.0)
	var turret = game.buildings[Vector2i(32, 20)]
	_assert_true(game._power_efficiency_for(turret) > 0.65 and game._power_efficiency_for(turret) < 0.68, "A 60 power network feeding a 90 power turret should run at two-thirds efficiency.")
	_assert_true(turret.powered, "Underpowered but connected consumers should still be marked powered.")
	_finish_game(game)

func _test_battery_charges_and_discharges() -> void:
	var game = _new_game()
	game._add_building("generator", Vector2i(20, 20), 0, true)
	game._add_building("node", Vector2i(23, 20), 0, true)
	game._add_building("battery", Vector2i(25, 20), 0, true)
	var generator = game.buildings[Vector2i(20, 20)]
	var battery = game.buildings[Vector2i(25, 20)]
	generator.fuel = 10.0
	game._calculate_power_networks(1.0)
	_assert_eq(game._store_count(battery, "power"), 60, "Battery should store surplus generated power per second.")
	game._add_building("lightning_turret", Vector2i(26, 20), 0, true)
	game._calculate_power_networks(1.0)
	_assert_eq(game._store_count(battery, "power"), 30, "Battery should discharge to cover network deficits.")
	var turret = game.buildings[Vector2i(26, 20)]
	_assert_eq(game._power_efficiency_for(turret), 1.0, "Battery discharge should let the turret run at full efficiency while stored power remains.")
	_finish_game(game)

func _test_lightning_turret_charge_scales_with_power() -> void:
	var game = _new_game()
	game._add_building("lightning_turret", Vector2i(20, 20), 0, true)
	var turret = game.buildings[Vector2i(20, 20)]
	game.power_efficiency[game._power_key(turret)] = 0.5
	game._update_lightning_turret(turret, 2.0)
	_assert_eq(game._store_count(turret, "charge"), 1, "Half-powered lightning turret should charge one shot in two seconds.")
	game.power_efficiency[game._power_key(turret)] = 1.0
	game._update_lightning_turret(turret, 10.0)
	_assert_eq(game._store_count(turret, "charge"), 3, "Lightning turret should hold at most three charged shots.")
	_finish_game(game)

func _test_graphite_press_runs_without_power() -> void:
	var game = _new_game()
	game._add_building("press", Vector2i(20, 20), 0, true)
	var press = game.buildings[Vector2i(20, 20)]
	game._add_store(press, "coal", 2)
	game._update_buildings(2.0)
	_assert_true(press.timer == 0.0 and game._store_count(press, "coal") == 0, "Basic graphite press should run with coal input and no power network.")
	_assert_true(game._store_count(press, "graphite") > 0 or game.inventory.graphite > game.TEST_STARTING_RESOURCES.graphite, "Basic graphite press should produce graphite without power.")
	_finish_game(game)

func _test_advanced_factory_requires_power_and_produces_more_graphite() -> void:
	var game = _new_game()
	game._add_building("carbon_refinery", Vector2i(20, 20), 0, true)
	var refinery = game.buildings[Vector2i(20, 20)]
	game._add_store(refinery, "coal", 2)
	game._update_buildings(2.0)
	_assert_eq(game._store_count(refinery, "coal"), 2, "Carbon refinery should not consume coal while unpowered.")
	game._add_building("generator", Vector2i(15, 20), 0, true)
	game._add_building("node", Vector2i(18, 20), 0, true)
	var generator = game.buildings[Vector2i(15, 20)]
	generator.fuel = 10.0
	game._update_buildings(2.0)
	_assert_eq(game._store_count(refinery, "coal"), 0, "Carbon refinery should consume coal when powered.")
	_assert_true(game._store_count(refinery, "graphite") >= 2 or game.inventory.graphite >= game.TEST_STARTING_RESOURCES.graphite + 2, "Carbon refinery should produce 2 graphite for the same coal input.")
	game._update_buildings(0.5)
	game._update_buildings(0.5)
	_assert_eq(game._power_efficiency_for(refinery), 1.0, "Carbon refinery should still report full power after its timer advances.")
	_assert_true(game._power_status_text(refinery).begins_with("Power Excess:"), "Carbon refinery hover details should still show network power while crafting.")
	_finish_game(game)

func _test_generator_requires_stored_coal() -> void:
	var game = _new_game()
	game.inventory.coal = 999
	game._add_building("generator", Vector2i(20, 20), 0, true)
	var generator = game.buildings[Vector2i(20, 20)]
	game._update_buildings(1.0)
	_assert_eq(generator.fuel, 0.0, "Generator should not pull coal directly from global inventory.")
	game._add_store(generator, "coal", 1)
	game._update_buildings(0.1)
	_assert_true(generator.fuel > 0.0, "Generator should fuel itself from stored coal input.")
	_finish_game(game)

func _test_core_acts_as_power_battery() -> void:
	var game = _new_game()
	# Build next to the core (wherever the spawn chunk placed it) so the network connects.
	var gen_cell = game.CORE_POS + Vector2i(-4, 0)
	var node_cell = game.CORE_POS + Vector2i(-1, 0)
	game._add_building("generator", gen_cell, 0, true)
	game._add_building("node", node_cell, 0, true)
	var generator = game.buildings[gen_cell]
	var core = game.buildings[game.CORE_POS]
	generator.fuel = 10.0
	game._calculate_power_networks(1.0)
	_assert_eq(game._store_count(core, "power"), 60, "Core should store surplus power like a battery.")
	_finish_game(game)

func _test_power_links_only_relevant_minimal_connections() -> void:
	var game = _new_game()
	game._add_building("node", Vector2i(20, 20), 0, true)
	game._add_building("node", Vector2i(23, 20), 0, true)
	game._add_building("generator", Vector2i(21, 22), 0, true)
	game._add_building("drill", Vector2i(21, 18), 0, true)
	game._calculate_power_networks(0.0)
	var generator = game.buildings[Vector2i(21, 22)]
	var drill = game.buildings[Vector2i(21, 18)]
	_assert_eq(game._power_link_count_for(generator), 1, "A power participant in range of two same-network poles should connect only to the closest pole.")
	_assert_eq(game._power_link_count_for(drill), 0, "Power poles should not connect to buildings that do not use, store, or produce power.")
	_finish_game(game)

func _test_details_bubble_visibility_and_runtime_power() -> void:
	var game = _new_game()
	game._make_ui()
	game.selected = ""
	game._hide_details()
	_assert_true(not game.details_panel.visible, "Building details should be hidden when nothing is hovered.")
	game._add_building("generator", Vector2i(20, 20), 0, true)
	game._add_building("node", Vector2i(23, 20), 0, true)
	game._add_building("lightning_turret", Vector2i(26, 20), 0, true)
	var generator = game.buildings[Vector2i(20, 20)]
	var turret = game.buildings[Vector2i(26, 20)]
	generator.fuel = 10.0
	game._calculate_power_networks(1.0)
	var details = game._building_instance_details(turret)
	_assert_true(details.contains("Deficit") or details.contains("Excess"), "Placed building details should include network power excess or deficit.")
	_finish_game(game)

func _test_sand_magma_and_new_block_defs() -> void:
	var game = _new_game()
	_assert_true(game.inventory.has("sand") and game.inventory.has("silicon") and game.inventory.has("plastinium") and game.inventory.has("pyrite"), "Inventory should track sand, silicon, plastinium, and pyrite.")
	var sand_cell = Vector2i(12, 12)
	var magma_cell = Vector2i(16, 12)
	for p in game._cells(sand_cell, Vector2i(2, 2)):
		game.terrain[p] = "sand"
	for p in game._cells(magma_cell, Vector2i(2, 2)):
		game.terrain[p] = "magma"
	_assert_true(game._can_place("drill", sand_cell), "Base drills should be placeable on sand to mine sand.")
	_assert_true(game._can_place("oil_extractor", sand_cell), "Oil extractors should place only on sand.")
	_assert_true(not game._can_place("oil_extractor", Vector2i(14, 12)), "Oil extractors should reject non-sand terrain.")
	_assert_true(game._can_place("magmatic_generator", magma_cell), "Magmatic generators should place on magma.")
	_assert_true(not game._can_place("magmatic_generator", sand_cell), "Magmatic generators should reject non-magma terrain.")
	_assert_true(game._ids_for_category("factories").has("silicon_smelter"), "Factories should include the silicon smelter.")
	_assert_true(game._ids_for_category("factories").has("plastinium_compressor"), "Factories should include the plastinium compressor.")
	_assert_true(game._ids_for_category("walls").has("titanium_wall"), "Walls should include titanium wall.")
	_assert_true(game._ids_for_category("walls").has("plastinium_wall"), "Walls should include plastinium wall.")
	_finish_game(game)

func _test_new_factories_and_fluid_chain() -> void:
	var game = _new_game()
	for p in game._cells(Vector2i(25, 20), Vector2i(2, 2)):
		game.terrain[p] = "sand"
	game._add_building("silicon_smelter", Vector2i(20, 20), 0, true)
	var smelter = game.buildings[Vector2i(20, 20)]
	game._add_store(smelter, "coal", 1)
	game._add_store(smelter, "sand", 1)
	game._add_building("generator", Vector2i(15, 20), 0, true)
	game._add_building("node", Vector2i(18, 20), 0, true)
	var generator = game.buildings[Vector2i(15, 20)]
	generator.fuel = 10.0
	game._update_buildings(2.0)
	_assert_eq(game._store_count(smelter, "coal"), 0, "Silicon smelter should consume coal when powered.")
	_assert_eq(game._store_count(smelter, "sand"), 0, "Silicon smelter should consume sand when powered.")
	_assert_true(game._store_count(smelter, "silicon") >= 1 or game.inventory.silicon > game.TEST_STARTING_RESOURCES.silicon, "Silicon smelter should produce silicon.")

	game._add_building("oil_extractor", Vector2i(25, 20), 0, true)
	game._add_building("pipe", Vector2i(27, 20), 0, true)
	var extractor = game.buildings[Vector2i(25, 20)]
	game.buildings[Vector2i(27, 20)].rot = 0
	game.power_efficiency[game._power_key(extractor)] = 1.0
	game._update_buildings(1.0)
	_assert_true(game.liquids.size() > 0 and game.liquids[0].kind == "oil", "Oil extractor should emit oil into adjacent pipes.")

	game._add_building("plastinium_compressor", Vector2i(30, 20), 0, true)
	var compressor = game.buildings[Vector2i(30, 20)]
	_assert_true(game._deliver_liquid_to_building(compressor, "oil"), "Plastinium compressor should accept oil from pipes.")
	game._add_store(compressor, "titanium", 2)
	game._add_building("generator", Vector2i(26, 22), 0, true)
	game._add_building("node", Vector2i(29, 20), 0, true)
	game.buildings[Vector2i(26, 22)].fuel = 10.0
	game._update_buildings(3.0)
	_assert_eq(game._store_count(compressor, "titanium"), 0, "Plastinium compressor should consume two titanium.")
	_assert_true(game._store_count(compressor, "plastinium") >= 1 or game.inventory.plastinium > game.TEST_STARTING_RESOURCES.plastinium, "Plastinium compressor should produce plastinium.")
	_finish_game(game)

func _test_new_turrets_fire_with_required_inputs() -> void:
	var game = _new_game()
	for id in ["hail_turret", "wave_turret", "beam_turret", "salvo_turret", "ripple_turret"]:
		_assert_true(game._ids_for_category("turrets").has(id), "Turrets category should include %s." % id)
	game.enemies.append(game._make_enemy("grunt", game._cell_center(Vector2i(24, 20))))
	game._add_building("wave_turret", Vector2i(20, 20), 0, true)
	var wave_turret = game.buildings[Vector2i(20, 20)]
	_assert_true(not game._deliver_item_to_building_would_accept(wave_turret, "copper"), "Wave turret should not accept item ammo.")
	_assert_true(game._deliver_liquid_to_building(wave_turret, "water"), "Wave turret should accept liquid ammo.")
	game._update_buildings(1.0)
	_assert_true(game.projectiles.size() > 0, "Wave turret should fire using stored liquid.")
	game.projectiles.clear()
	game._add_building("beam_turret", Vector2i(20, 22), 0, true)
	game._add_building("generator", Vector2i(17, 22), 0, true)
	game._add_building("node", Vector2i(19, 22), 0, true)
	game.buildings[Vector2i(17, 22)].fuel = 10.0
	game._update_buildings(1.0)
	_assert_true(game.projectiles.size() > 0, "Beam turret should fire from power without ammo.")
	game.projectiles.clear()
	game._add_building("salvo_turret", Vector2i(22, 20), 0, true)
	var salvo = game.buildings[Vector2i(22, 20)]
	_assert_true(game._deliver_item_to_building(salvo, "copper"), "Salvo turret should accept copper ammo.")
	game._update_buildings(1.0)
	_assert_true(game.projectiles.size() > 0, "Salvo turret should fire item ammo.")
	_finish_game(game)

# Turrets that omit an explicit `ammo_types` list (turret, scatter_tower,
# rail_tower) must still accept their default copper/graphite ammo. Regression:
# delivery used an empty-array default while firing used copper/graphite.
func _test_base_turret_accepts_default_ammo() -> void:
	var game = _new_game()
	for id in ["turret", "scatter_tower", "rail_tower"]:
		var cell = game.CORE_POS + Vector2i(-6, 0)
		game._add_building(id, cell, 0, true)
		var b = game.buildings[cell]
		_assert_true(game._deliver_item_to_building_would_accept(b, "copper"), "%s should accept copper ammo." % id)
		_assert_true(game._deliver_item_to_building(b, "graphite"), "%s should take delivered graphite ammo." % id)
		_assert_true(game._store_count(b, "graphite") > 0, "%s should store the ammo it accepted." % id)
	_finish_game(game)

# --- Chunked / expanding world ---------------------------------------------

func _test_world_starts_with_one_chunk() -> void:
	var game = _new_game()
	_assert_eq(game.open_chunks.size(), 1, "The player should spawn with exactly one open chunk.")
	# The core lives inside that spawn chunk and is reachable from its spawn point.
	var spawn: Vector2i = game.chunk_meta[game.open_chunks[0]]["spawn"]
	var path: Array[Vector2i] = game._find_enemy_path(spawn, game.CORE_POS, false)
	_assert_true(not path.is_empty(), "Enemies must be able to path from the chunk spawn point to the core.")
	_finish_game(game)

func _test_map_expands_every_five_waves() -> void:
	var game = _new_game()
	_assert_eq(game.open_chunks.size(), 1, "World starts with one chunk.")
	game.wave = 6  # five waves defeated
	game._sync_open_chunks()
	_assert_eq(game.open_chunks.size(), 2, "Defeating five waves should open a second chunk.")
	game.wave = 11  # ten waves defeated
	game._sync_open_chunks()
	_assert_eq(game.open_chunks.size(), 3, "Every additional five waves should open another chunk.")
	# Newly opened chunks sit further out (higher ring) than the spawn chunk.
	var newest: Vector2i = game.open_chunks[game.open_chunks.size() - 1]
	_assert_true(int(game.chunk_meta[newest]["ring"]) >= 1, "Expansion chunks should be further from the core.")
	_finish_game(game)

func _test_only_furthest_chunks_spawn_enemies() -> void:
	var game = _new_game()
	for i in 16:
		game._open_next_chunk()
	var tiles: Array[Vector2i] = game._active_spawn_tiles()
	_assert_eq(tiles.size(), 10, "With more than ten open chunks, only the furthest ten spawn enemies.")
	# Every active spawn tile must be a real, distinct chunk spawn point.
	var unique := {}
	for t in tiles:
		unique[t] = true
	_assert_eq(unique.size(), 10, "Active spawn points should be distinct.")
	_finish_game(game)

func _test_ore_deposits_have_geode_cores() -> void:
	var game = _new_game()
	while game._open_next_chunk():
		pass
	var geodes := 0
	var geodes_in_ore := 0
	for p in game.terrain:
		if String(game.terrain[p]) == "geode":
			geodes += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if game.ore.has(p + d):
					geodes_in_ore += 1
					break
	_assert_true(geodes > 0, "Ore deposits should generate geode cores.")
	_assert_true(geodes_in_ore > 0, "Geodes should sit inside their ore deposit (ore around them).")
	_finish_game(game)

func _test_sand_and_magma_generate_in_terrain() -> void:
	var game = _new_game()
	while game._open_next_chunk():
		pass
	var kinds := {}
	for p in game.terrain:
		kinds[String(game.terrain[p])] = true
	_assert_true(kinds.has("sand"), "Terrain generation should place sand.")
	_assert_true(kinds.has("magma"), "Terrain generation should place magma.")
	_assert_true(kinds.has("water"), "Terrain generation should place water.")
	_finish_game(game)
