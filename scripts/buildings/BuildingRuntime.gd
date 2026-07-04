extends RefCounted

static func make(defs: Dictionary, building_health: Dictionary, id: String, cell: Vector2i, rot: int, built: bool) -> Dictionary:
	var size: Vector2i = defs.get(id, {}).get("size", Vector2i(1, 1))
	return {"id": id, "pos": cell, "rot": rot, "size": size, "built": built, "timer": 0.0, "health": building_health.get(id, 100.0), "fuel": 0.0, "powered": false, "store": {}, "output_cursor": 0, "produced": 0}

static func center(b: Dictionary, tile_size: int) -> Vector2:
	return Vector2(b.pos) * tile_size + Vector2(b.size) * tile_size * 0.5

static func key(b: Dictionary) -> String:
	return "%d,%d" % [b.pos.x, b.pos.y]

static func power_key(b: Dictionary) -> String:
	return key(b)

static func power_efficiency_for(power_efficiency: Dictionary, b: Dictionary) -> float:
	return float(power_efficiency.get(power_key(b), 0.0))
