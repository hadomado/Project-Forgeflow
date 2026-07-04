extends RefCounted

const EMPTY_TILE := Vector2i(-1, -1)

static func make_color_atlas(tile_size: int, specs: Array[Dictionary]) -> Dictionary:
	var image := Image.create(tile_size * specs.size(), tile_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var coords_by_id := {}
	for i in range(specs.size()):
		var spec: Dictionary = specs[i]
		var base := Vector2i(i * tile_size, 0)
		if spec.get("shape", "fill") == "circle":
			_draw_circle_tile(image, base, tile_size, spec)
		else:
			_draw_fill_tile(image, base, tile_size, spec)
		coords_by_id[String(spec["id"])] = Vector2i(i, 0)

	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_size, tile_size)
	for i in range(specs.size()):
		source.create_tile(Vector2i(i, 0))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	var source_id := tile_set.add_source(source)
	return {"tile_set": tile_set, "source_id": source_id, "coords": coords_by_id}

static func make_layer(layer_name: String, tile_set: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = z
	layer.rendering_quadrant_size = 24
	layer.collision_enabled = false
	layer.navigation_enabled = false
	layer.occlusion_enabled = false
	return layer

static func make_conveyor_atlas(tile_size: int, ids: Array[String]) -> Dictionary:
	var variants: Array[Dictionary] = []
	for id in ids:
		if id == "cross":
			variants.append({"id": id, "rot": 0, "input_mask": 0, "kind": "cross", "color": Color("#506c86")})
		else:
			for rot in range(4):
				for input_mask in range(16):
					variants.append({"id": id, "rot": rot, "input_mask": input_mask, "kind": ("pipe" if id == "pipe" else "belt"), "color": _conveyor_color(id)})
	var image := Image.create(tile_size * variants.size(), tile_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var coords_by_key := {}
	for i in range(variants.size()):
		var spec: Dictionary = variants[i]
		var base := Vector2i(i * tile_size, 0)
		if spec.kind == "cross":
			_draw_cross_tile(image, base, tile_size, spec.color)
		else:
			_draw_directional_tile(image, base, tile_size, spec.color, int(spec.rot), spec.kind == "pipe", int(spec.input_mask))
		coords_by_key[_conveyor_key(String(spec.id), int(spec.rot), int(spec.input_mask))] = Vector2i(i, 0)

	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_size, tile_size)
	for i in range(variants.size()):
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	var source_id := tile_set.add_source(source)
	return {"tile_set": tile_set, "source_id": source_id, "coords": coords_by_key}

static func repaint_world(
	terrain_layer: TileMapLayer,
	ore_layer: TileMapLayer,
	terrain_source_id: int,
	ore_source_id: int,
	terrain_coords: Dictionary,
	ore_coords: Dictionary,
	terrain: Dictionary,
	ore: Dictionary,
	open_chunks: Array[Vector2i],
	chunk_meta: Dictionary
) -> void:
	terrain_layer.clear()
	ore_layer.clear()
	for cc in open_chunks:
		var tiles: Array = chunk_meta[cc].get("tiles", [])
		for pv in tiles:
			var p: Vector2i = pv
			var terrain_id := String(terrain.get(p, "rock"))
			terrain_layer.set_cell(p, terrain_source_id, terrain_coords.get(terrain_id, EMPTY_TILE))
			if ore.has(p):
				var ore_id := String(ore[p])
				ore_layer.set_cell(p, ore_source_id, ore_coords.get(ore_id, EMPTY_TILE))

static func repaint_conveyors(
	conveyor_layer: TileMapLayer,
	source_id: int,
	coords: Dictionary,
	buildings: Dictionary,
	belt_ids: Array[String]
) -> void:
	conveyor_layer.clear()
	var seen := {}
	for b in buildings.values():
		var id := String(b.get("id", ""))
		if not belt_ids.has(id):
			continue
		var cell: Vector2i = b.get("pos", Vector2i.ZERO)
		if seen.has(cell):
			continue
		seen[cell] = true
		var input_mask := _belt_input_mask(cell, buildings, belt_ids) if id != "cross" else 0
		var rot := 0 if id == "cross" else int(b.get("rot", 0))
		var key := _conveyor_key(id, rot, input_mask)
		conveyor_layer.set_cell(cell, source_id, coords.get(key, EMPTY_TILE))

static func _conveyor_key(id: String, rot: int, input_mask: int) -> String:
	return "%s:%d:%d" % [id, rot % 4, input_mask & 15]

static func _belt_input_mask(cell: Vector2i, buildings: Dictionary, belt_ids: Array[String]) -> int:
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var mask := 0
	for i in range(dirs.size()):
		var np: Vector2i = cell + dirs[i]
		var nb = buildings.get(np)
		if nb == null:
			continue
		var id := String(nb.get("id", ""))
		if not belt_ids.has(id):
			continue
		var from_neighbor_to_cell := (i + 2) % 4
		if id == "cross" or int(nb.get("rot", 0)) == from_neighbor_to_cell:
			mask |= 1 << i
	return mask

static func _draw_fill_tile(image: Image, base: Vector2i, tile_size: int, spec: Dictionary) -> void:
	var color: Color = spec["color"]
	var grid: Color = spec.get("grid", Color(0, 0, 0, 0.18))
	for y in range(tile_size):
		for x in range(tile_size):
			var edge := x == 0 or y == 0
			image.set_pixel(base.x + x, base.y + y, grid if edge else color)

static func _draw_circle_tile(image: Image, base: Vector2i, tile_size: int, spec: Dictionary) -> void:
	var color: Color = spec["color"]
	var radius: float = float(spec.get("radius", 10.0))
	var center := Vector2(tile_size * 0.5, tile_size * 0.5)
	for y in range(tile_size):
		for x in range(tile_size):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(base.x + x, base.y + y, color)

static func _conveyor_color(id: String) -> Color:
	match id:
		"fast_conveyor":
			return Color("#4a7188")
		"titan_conveyor":
			return Color("#3d7b7a")
		"thorium_conveyor":
			return Color("#70548d")
		"pipe":
			return Color("#4d8fb0")
		_:
			return Color("#355f7a")

static func _draw_directional_tile(image: Image, base: Vector2i, tile_size: int, color: Color, rot: int, is_pipe: bool, input_mask: int) -> void:
	_draw_fill_tile(image, base, tile_size, {"color": Color("#1b1e22"), "grid": Color(0, 0, 0, 0)})
	var center: Vector2 = Vector2(tile_size * 0.5, tile_size * 0.5)
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var belt_width: float = 4.0 if is_pipe else 6.0
	var inner_color: Color = Color("#7fe3ff") if is_pipe else Color("#83cdf3")
	var arrow_color: Color = Color("#7fe3ff") if is_pipe else Color("#f5d76a")
	var arms: Array[int] = [rot % 4]
	if input_mask == 0:
		arms.append((rot + 2) % 4)
	else:
		for i in range(4):
			if (input_mask & (1 << i)) != 0 and not arms.has(i):
				arms.append(i)
	for y in range(tile_size):
		for x in range(tile_size):
			var local: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			for arm in arms:
				var dir: Vector2 = dirs[arm]
				var side: Vector2 = Vector2(-dir.y, dir.x)
				if abs(local.dot(side)) <= belt_width and local.dot(dir) >= -2.0 and local.dot(dir) < 13.0:
					image.set_pixel(base.x + x, base.y + y, color)
				if abs(local.dot(side)) <= 2.0 and local.dot(dir) >= -2.0 and local.dot(dir) < 12.0:
					image.set_pixel(base.x + x, base.y + y, inner_color)
	var dir: Vector2 = dirs[rot % 4]
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = center + dir * 11.0
	for y in range(tile_size):
		for x in range(tile_size):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var rel: Vector2 = p - tip
			if rel.dot(dir) <= 0.0 and rel.dot(dir) >= -8.0 and abs(rel.dot(side)) <= 5.0 + rel.dot(dir) * 0.55:
				image.set_pixel(base.x + x, base.y + y, arrow_color)

static func _draw_cross_tile(image: Image, base: Vector2i, tile_size: int, color: Color) -> void:
	_draw_fill_tile(image, base, tile_size, {"color": Color("#1b1e22"), "grid": Color(0, 0, 0, 0)})
	var center: Vector2 = Vector2(tile_size * 0.5, tile_size * 0.5)
	for y in range(tile_size):
		for x in range(tile_size):
			var local: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if abs(local.y) <= 6.0 or abs(local.x) <= 6.0:
				image.set_pixel(base.x + x, base.y + y, color)
			if abs(local.y) <= 2.0:
				image.set_pixel(base.x + x, base.y + y, Color("#f5d76a"))
			if abs(local.x) <= 2.0:
				image.set_pixel(base.x + x, base.y + y, Color("#7fe3ff"))
