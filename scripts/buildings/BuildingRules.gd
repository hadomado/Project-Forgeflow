extends RefCounted

static func is_belt_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).has("belt_speed") or id == "cross"

static func is_belt_building(defs: Dictionary, b: Dictionary) -> bool:
	return b != null and is_belt_id(defs, b.id)

static func is_drill_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).has("mine_tier")

static func is_ammo_turret_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).get("ammo_turret", false)

static func is_fluid_turret_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).get("fluid_turret", false)

static func is_power_turret_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).get("power_turret", false)

static func is_factory_id(defs: Dictionary, id: String) -> bool:
	return defs.get(id, {}).has("factory_recipe")

static func is_power_producer(defs: Dictionary, b: Dictionary) -> bool:
	return defs.get(b.id, {}).has("power_production")

static func is_power_consumer(defs: Dictionary, b: Dictionary) -> bool:
	return defs.get(b.id, {}).has("power_consumption")

static func is_power_storage(_defs: Dictionary, b: Dictionary) -> bool:
	return b.id == "battery" or b.id == "core"

static func is_power_participant(defs: Dictionary, b: Dictionary) -> bool:
	return is_power_producer(defs, b) or is_power_consumer(defs, b) or is_power_storage(defs, b)

static func power_storage_capacity(defs: Dictionary, b: Dictionary) -> float:
	if b.id == "core":
		return float(defs["battery"]["power_storage"])
	return float(defs.get(b.id, {}).get("power_storage", 0.0))

static func accepts_water(defs: Dictionary, b: Dictionary) -> bool:
	return defs.get(b.id, {}).get("accepts_water", false)

static func accepts_liquid(defs: Dictionary, b: Dictionary, kind: String) -> bool:
	var d: Dictionary = defs.get(b.id, {})
	if kind == "water" and d.get("accepts_water", false):
		return true
	if d.has("accepts_liquids") and kind in d.accepts_liquids:
		return true
	if d.has("factory_recipe"):
		var liquid_input: Dictionary = d.factory_recipe.get("liquid_input", {})
		return kind == String(liquid_input.get("kind", ""))
	return false

static func belt_speed_for(defs: Dictionary, b: Dictionary) -> float:
	return float(defs.get(b.id, {}).get("belt_speed", 2.6))

static func factory_recipe(defs: Dictionary, b: Dictionary) -> Dictionary:
	return defs.get(b.id, {}).get("factory_recipe", {})

static func recipe_inputs(recipe: Dictionary) -> Dictionary:
	if recipe.has("inputs"):
		return recipe.inputs
	var input_kind = String(recipe.get("input", ""))
	if input_kind == "":
		return {}
	return {input_kind: int(recipe.get("input_amount", 1))}

static func drill_output_kind(terrain: Dictionary, ore: Dictionary, b: Dictionary) -> String:
	if ore.has(b.pos):
		return String(ore[b.pos])
	if terrain.get(b.pos, "ground") == "sand":
		return "sand"
	return "copper"
