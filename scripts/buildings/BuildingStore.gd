extends RefCounted

const BuildingRules = preload("res://scripts/buildings/BuildingRules.gd")

static func add(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = b.store.get(kind, 0) + amount

static func take(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = max(0, b.store.get(kind, 0) - amount)

static func count(b: Dictionary, kind: String) -> int:
	return int(b.store.get(kind, 0))

static func turret_ammo_types(defs: Dictionary, b: Dictionary) -> Array:
	return BuildingRules.turret_ammo_types(defs, b)

static func turret_ammo_count(defs: Dictionary, b: Dictionary) -> int:
	var total = 0
	for kind in turret_ammo_types(defs, b):
		total += count(b, String(kind))
	return total

static func take_turret_ammo(defs: Dictionary, b: Dictionary) -> String:
	var priority: Array = ["pyrite", "graphite", "copper"]
	for kind in priority:
		if kind in turret_ammo_types(defs, b) and count(b, String(kind)) > 0:
			take(b, String(kind), 1)
			return String(kind)
	for kind in turret_ammo_types(defs, b):
		if count(b, String(kind)) > 0:
			take(b, String(kind), 1)
			return String(kind)
	return ""

static func take_turret_liquid(defs: Dictionary, b: Dictionary) -> String:
	var d: Dictionary = defs.get(b.id, {})
	for kind in d.get("accepts_liquids", []):
		if count(b, String(kind)) > 0:
			take(b, String(kind), 1)
			return String(kind)
	return ""

static func deliver_item(defs: Dictionary, b: Dictionary, kind: String, xp_value: int) -> bool:
	if not BuildingRules.item_delivery_would_accept(defs, b, kind, xp_value):
		return false
	if BuildingRules.is_ammo_turret_id(defs, b.id) and turret_ammo_count(defs, b) >= 3:
		return false
	if count(b, kind) >= BuildingRules.building_item_capacity(defs, b, kind):
		return false
	add(b, kind, 1)
	return true

static func deliver_liquid(defs: Dictionary, b: Dictionary, kind: String) -> bool:
	if not BuildingRules.accepts_liquid(defs, b, kind):
		return false
	if count(b, kind) >= BuildingRules.building_liquid_capacity(defs, b, kind):
		return false
	add(b, kind, 1)
	return true

static func factory_has_inputs(b: Dictionary, recipe: Dictionary) -> bool:
	var inputs := BuildingRules.recipe_inputs(recipe)
	for kind in inputs:
		if count(b, String(kind)) < int(inputs[kind]):
			return false
	var liquid_input: Dictionary = recipe.get("liquid_input", {})
	if not liquid_input.is_empty():
		var liquid_kind := String(liquid_input.get("kind", ""))
		if count(b, liquid_kind) < int(liquid_input.get("amount", 1)):
			return false
	return true

static func take_factory_inputs(b: Dictionary, recipe: Dictionary) -> void:
	var inputs := BuildingRules.recipe_inputs(recipe)
	for kind in inputs:
		take(b, String(kind), int(inputs[kind]))
	var liquid_input: Dictionary = recipe.get("liquid_input", {})
	if not liquid_input.is_empty():
		var liquid_kind := String(liquid_input.get("kind", ""))
		take(b, liquid_kind, int(liquid_input.get("amount", 1)))
