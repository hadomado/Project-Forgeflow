extends RefCounted

static func generate(map_w: int, map_h: int) -> Dictionary:
	var terrain := {}
	var ore := {}
	for y in map_h:
		for x in map_w:
			var p = Vector2i(x, y)
			terrain[p] = "ground"
			if randf() < 0.08:
				terrain[p] = "stone"
	for x in range(0, map_w):
		terrain[Vector2i(x, 0)] = "rock"
		terrain[Vector2i(x, map_h - 1)] = "rock"
	for y in range(0, map_h):
		terrain[Vector2i(0, y)] = "rock"
		terrain[Vector2i(map_w - 1, y)] = "rock"
	for p in _disc(Vector2i(23, 25), 4):
		ore[p] = "copper"
	for p in _disc(Vector2i(36, 20), 4):
		ore[p] = "coal"
	for p in _disc(Vector2i(18, 14), 3):
		ore[p] = "copper"
	for p in _disc(Vector2i(13, 26), 3):
		ore[p] = "lead"
	for p in _disc(Vector2i(47, 19), 3):
		ore[p] = "titanium"
	for p in _disc(Vector2i(50, 31), 3):
		ore[p] = "thorium"
	for p in _disc(Vector2i(43, 29), 4):
		if _inside(p, map_w, map_h):
			terrain[p] = "water"
	for p in _disc(Vector2i(38, 12), 5):
		if _inside(p, map_w, map_h):
			terrain[p] = "sand"
	for p in _disc(Vector2i(9, 31), 3):
		if _inside(p, map_w, map_h):
			terrain[p] = "sand"
	for p in _disc(Vector2i(51, 8), 3):
		if _inside(p, map_w, map_h):
			terrain[p] = "magma"
	for x in range(5, 16):
		terrain[Vector2i(x, 7)] = "rock"
	for y in range(6, 15):
		terrain[Vector2i(15, y)] = "rock"
	for p in _disc(Vector2i(48, 12), 4):
		if _inside(p, map_w, map_h) and p.x < 53:
			terrain[p] = "rock"
	for p in _disc(Vector2i(34, 34), 3):
		if _inside(p, map_w, map_h):
			terrain[p] = "rock"
	terrain[Vector2i(5, 5)] = "spawn"
	cleanup_ore_in_natural_walls(terrain, ore)
	return {"terrain": terrain, "ore": ore}

static func cleanup_ore_in_natural_walls(terrain: Dictionary, ore: Dictionary) -> void:
	var to_remove: Array[Vector2i] = []
	for p in ore.keys():
		if terrain.get(p, "rock") == "rock":
			to_remove.append(p)
	for p in to_remove:
		ore.erase(p)

static func _disc(center: Vector2i, radius: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var p = Vector2i(x, y)
			if center.distance_to(p) <= radius:
				pts.append(p)
	return pts

static func _inside(p: Vector2i, map_w: int, map_h: int) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < map_w and p.y < map_h
