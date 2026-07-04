extends RefCounted

static func center(b: Dictionary, tile_size: int) -> Vector2:
	return Vector2(b.pos) * tile_size + Vector2(b.size) * tile_size * 0.5

static func key(b: Dictionary) -> String:
	return "%d,%d" % [b.pos.x, b.pos.y]

static func power_key(b: Dictionary) -> String:
	return key(b)

static func power_efficiency_for(power_efficiency: Dictionary, b: Dictionary) -> float:
	return float(power_efficiency.get(power_key(b), 0.0))
