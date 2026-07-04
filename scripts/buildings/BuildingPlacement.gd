extends RefCounted

const BuildingRules = preload("res://scripts/buildings/BuildingRules.gd")
const Grid = preload("res://scripts/shared/Grid.gd")

static func can_place(
	defs: Dictionary,
	terrain: Dictionary,
	ore: Dictionary,
	ore_tiers: Dictionary,
	buildings: Dictionary,
	id: String,
	cell: Vector2i,
	map_w: int,
	map_h: int
) -> bool:
	if not defs.has(id):
		return false
	var def: Dictionary = defs[id]
	var size: Vector2i = def.size
	var place_on = String(def.get("place_on", ""))
	for p in Grid.cells(cell, size):
		if not Grid.inside(p, map_w, map_h):
			return false
		var t: String = terrain.get(p, "rock")
		if place_on != "":
			if t != place_on:
				return false
		elif t == "water" or t == "rock" or t == "magma" or t == "geode":
			return false
		var existing = buildings.get(p)
		if existing != null:
			if BuildingRules.is_belt_id(defs, id) and BuildingRules.is_belt_building(defs, existing):
				continue
			return false
	if BuildingRules.is_drill_id(defs, id):
		if ore.has(cell):
			var ore_kind = String(ore.get(cell, "copper"))
			if int(ore_tiers.get(ore_kind, 1)) > int(def.get("mine_tier", 1)):
				return false
		elif terrain.get(cell, "ground") != "sand":
			return false
	return true
