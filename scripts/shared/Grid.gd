extends RefCounted

static func cells(pos: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			out.append(Vector2i(x, y))
	return out

static func inside(p: Vector2i, map_w: int, map_h: int) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < map_w and p.y < map_h

static func cell_center(p: Vector2i, tile: int) -> Vector2:
	return Vector2(p * tile) + Vector2(tile * 0.5, tile * 0.5)

static func world_cell(pos: Vector2, tile: int) -> Vector2i:
	return Vector2i(floori(pos.x / tile), floori(pos.y / tile))

static func disc(center: Vector2i, radius: int, map_w: int, map_h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var p = Vector2i(x, y)
			if inside(p, map_w, map_h) and Vector2(p - center).length() <= radius + randf():
				out.append(p)
	return out

static func cell_in_rect(p: Vector2i, pos: Vector2i, size: Vector2i) -> bool:
	return p.x >= pos.x and p.x < pos.x + size.x and p.y >= pos.y and p.y < pos.y + size.y

static func touches_rect(p: Vector2i, pos: Vector2i, size: Vector2i, dirs: Array) -> bool:
	for d in dirs:
		if cell_in_rect(p + d, pos, size):
			return true
	return false
