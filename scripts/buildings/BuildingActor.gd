extends Node2D

const TILE := 32
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var building: Dictionary = {}
var building_def: Dictionary = {}
var flags: Dictionary = {}

func sync_from(building_state: Dictionary, definition: Dictionary, runtime_flags: Dictionary) -> void:
	building = building_state
	building_def = definition
	flags = runtime_flags
	position = Vector2(Vector2i(building.get("pos", Vector2i.ZERO)) * TILE)
	queue_redraw()

func _draw() -> void:
	if building.is_empty():
		return
	var size: Vector2i = building.get("size", Vector2i.ONE)
	var rect := Rect2(Vector2.ZERO, Vector2(size * TILE))
	var alpha := 1.0
	var col := _building_color(alpha)
	draw_rect(rect.grow(-3), Color("#1b1e22", alpha))
	draw_rect(rect.grow(-6), col)
	if String(building.get("id", "")) == "pipe":
		_draw_arrow(rect.get_center(), int(building.get("rot", 0)), Color("#7fe3ff", alpha))
	elif bool(flags.get("is_drill", false)):
		draw_circle(rect.get_center(), 8, Color("#f5c05a", alpha))
	elif String(building.get("id", "")) == "battery":
		_draw_battery_level(rect, alpha)
	_draw_runtime_inventory(rect, alpha)

func _building_color(alpha: float) -> Color:
	var id := String(building.get("id", ""))
	var powered := bool(building.get("powered", false))
	match id:
		"core":
			return Color("#416e89", alpha)
		"drill":
			return Color("#7e6d46", alpha)
		"rotary_drill":
			return Color("#7d7a52", alpha)
		"impact_drill":
			return Color("#4f7d61", alpha) if powered else Color("#4d5b4f", alpha)
		"blast_drill":
			return Color("#7d525f", alpha) if powered else Color("#5a464c", alpha)
		"wall":
			return Color("#8a929a", alpha)
		"turret":
			return Color("#4d9cc6", alpha) if powered else Color("#526675", alpha)
		"scatter_tower":
			return Color("#5c8fb6", alpha) if powered else Color("#586470", alpha)
		"generator":
			return Color("#7a5d35", alpha)
		"node":
			return Color("#75b772", alpha) if powered else Color("#4c6350", alpha)
		"battery":
			return Color("#3a4a52", alpha)
		"lightning_turret":
			return Color("#b98af0", alpha) if powered else Color("#5c4d6b", alpha)
		"rail_tower":
			return Color("#80a5cf", alpha) if powered else Color("#586678", alpha)
		"press":
			return Color("#777087", alpha) if powered else Color("#575160", alpha)
		"carbon_refinery":
			return Color("#8291b9", alpha) if powered else Color("#576073", alpha)
		"pump":
			return Color("#3b9dbb", alpha)
		"pipe":
			return Color("#4d8fb0", alpha)
		"powered_pump":
			return Color("#51acc5", alpha) if powered else Color("#416b78", alpha)
		"magmatic_generator":
			return Color("#ba6840", alpha)
		"silicon_smelter":
			return Color("#a99b71", alpha) if powered else Color("#6d6651", alpha)
		"oil_extractor":
			return Color("#5c4d39", alpha) if powered else Color("#4a453d", alpha)
		"plastinium_compressor":
			return Color("#6fa8a0", alpha) if powered else Color("#566e6a", alpha)
		"pyrite_mixer":
			return Color("#b8893d", alpha) if powered else Color("#725d3d", alpha)
		"hail_turret", "salvo_turret", "ripple_turret":
			return Color("#78a6d0", alpha) if powered else Color("#576777", alpha)
		"wave_turret":
			return Color("#4fb6c8", alpha)
		"beam_turret":
			return Color("#9cb5ff", alpha) if powered else Color("#59627a", alpha)
		"xp_sink":
			return Color("#8b63c7", alpha) if powered else Color("#5f5270", alpha)
		"resource_depot":
			return Color("#5fa37b", alpha) if powered else Color("#51685a", alpha)
		_:
			return Color("#6f7f8e", alpha)

func _draw_runtime_inventory(rect: Rect2, alpha: float) -> void:
	if not _should_draw_inventory():
		return
	var coal_count := mini(_store_count("coal"), 4)
	var graphite_count := mini(_store_count("graphite"), 4)
	var copper_count := mini(_store_count("copper"), 4)
	var water_count := mini(_store_count("water"), 4)
	if bool(flags.get("is_ammo_turret", false)):
		for i in range(copper_count):
			draw_circle(rect.position + Vector2(9 + i * 7, rect.size.y - 9), 3, Color("#e0a13f", alpha))
		for i in range(graphite_count):
			draw_circle(rect.position + Vector2(9 + (i + copper_count) * 7, rect.size.y - 9), 3, Color("#8ea0ad", alpha))
		for i in range(water_count):
			draw_circle(rect.position + Vector2(rect.size.x - 9 - i * 7, 9), 3, Color("#69c9e8", alpha))
	elif bool(flags.get("is_drill", false)):
		for i in range(water_count):
			draw_circle(rect.position + Vector2(9 + i * 7, rect.size.y - 8), 3, Color("#69c9e8", alpha))
	elif String(building.get("id", "")) == "lightning_turret":
		var charge_count := int(_store_count("charge"))
		for i in range(charge_count):
			draw_circle(rect.position + Vector2(9 + i * 9, rect.size.y - 9), 3.5, Color("#f5e04a", alpha))
	else:
		for i in range(coal_count):
			draw_circle(rect.position + Vector2(11 + i * 8, 12), 3, Color("#202025", alpha))
		for i in range(graphite_count):
			draw_circle(rect.position + Vector2(11 + i * 8, 22), 3, Color("#8ea0ad", alpha))
	if String(building.get("id", "")) == "generator" and float(building.get("fuel", 0.0)) > 0.0:
		draw_circle(rect.end - Vector2(13, 13), 5, Color("#ffb84d", alpha))
	if bool(flags.get("is_factory", false)) and float(building.get("timer", 0.0)) > 0.0:
		var craft_time := float(flags.get("craft_time", 1.8))
		var w: float = clamp(float(building.get("timer", 0.0)) / craft_time, 0.0, 1.0) * (rect.size.x - 16)
		draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 13), Vector2(w, 4)), Color("#8ea0ad", alpha))

func _draw_battery_level(rect: Rect2, alpha: float) -> void:
	var cap := float(building_def.get("power_storage", 100.0))
	var stored := float(building.get("store", {}).get("power", 0))
	var ratio: float = 0.0 if cap <= 0.0 else clamp(stored / cap, 0.0, 1.0)
	var inner: Rect2 = rect.grow(-9)
	var h: float = ratio * inner.size.y
	draw_rect(Rect2(inner.position.x, inner.position.y + (inner.size.y - h), inner.size.x, h), Color("#f5e04a", alpha))

func _draw_arrow(pos: Vector2, rot: int, col: Color) -> void:
	var d: Vector2 = Vector2(DIRS[rot % 4])
	var side: Vector2 = Vector2(-d.y, d.x)
	draw_line(pos - d * 10, pos + d * 10, col, 3)
	draw_polygon([pos + d * 12, pos + side * 6, pos - side * 6], [col])

func _should_draw_inventory() -> bool:
	return bool(flags.get("is_factory", false)) \
		or String(building.get("id", "")) == "generator" \
		or bool(flags.get("is_ammo_turret", false)) \
		or bool(flags.get("is_fluid_turret", false)) \
		or bool(flags.get("is_drill", false)) \
		or String(building.get("id", "")) == "lightning_turret"

func _store_count(kind: String) -> int:
	return int(building.get("store", {}).get(kind, 0))
