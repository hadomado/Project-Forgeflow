extends RefCounted

const BuildingRules = preload("res://scripts/buildings/BuildingRules.gd")
const BuildingRuntime = preload("res://scripts/buildings/BuildingRuntime.gd")
const InventoryHelper = preload("res://scripts/shared/Inventory.gd")

static func ids_for_category(defs: Dictionary, category_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in defs.keys():
		if id == "core":
			continue
		if defs[id].get("category", "misc") == category_id:
			out.append(id)
	return out

static func building_details(
	defs: Dictionary,
	building_health: Dictionary,
	id: String,
	lightning_max_charge: int,
	lightning_charge_time: float,
	node_range: float
) -> String:
	if not defs.has(id):
		return ""
	var d: Dictionary = defs[id]
	var lines: Array[String] = []
	lines.append(d.name)
	lines.append("Cost: %s" % InventoryHelper.cost_text(d.cost))
	lines.append("Health: %.0f" % building_health.get(id, 100.0))
	if BuildingRules.is_ammo_turret_id(defs, id):
		lines.append("Ammo capacity: 3 shots (copper or graphite)")
	if BuildingRules.is_drill_id(defs, id):
		lines.append("Drill speed: %.2fs per ore (1.5x with water)" % float(d.get("drill_time", 1.45)))
		lines.append("Mines up to %s tier ore" % ["", "copper/coal", "lead", "titanium", "thorium"][int(d.get("mine_tier", 1))])
	if d.has("fluid_output"):
		lines.append("Fluid output: %s every %.1fs" % [String(d.fluid_output).capitalize(), float(d.get("fluid_interval", 0.6))])
	if d.has("belt_speed"):
		lines.append("Belt speed: %.1f tiles/s" % float(d.belt_speed))
	if d.has("power_production"):
		lines.append("Power production: %.0f/s" % d.power_production)
	if d.has("power_consumption"):
		lines.append("Power consumption: %.0f/s" % d.power_consumption)
	if d.has("power_storage"):
		lines.append("Battery storage: %.0f power" % d.power_storage)
	if d.has("factory_recipe"):
		var recipe: Dictionary = d.factory_recipe
		var parts: Array[String] = []
		var inputs := BuildingRules.recipe_inputs(recipe)
		for kind in inputs:
			parts.append("%d %s" % [int(inputs[kind]), String(kind).capitalize()])
		var liquid_input: Dictionary = recipe.get("liquid_input", {})
		if not liquid_input.is_empty():
			parts.append("%d %s" % [int(liquid_input.get("amount", 1)), String(liquid_input.get("kind", "")).capitalize()])
		var input_text = " + ".join(parts)
		lines.append("Recipe: %s -> %d %s in %.1fs" % [input_text, int(recipe.get("output_amount", 1)), String(recipe.get("output", "")).capitalize(), float(recipe.get("craft_time", 1.8))])
	if id == "lightning_turret":
		lines.append("Charge: up to %d shots, %.0fs per shot at full power" % [lightning_max_charge, lightning_charge_time])
	if id == "node":
		lines.append("Connects producers, consumers, and other nodes within %.0f tiles" % node_range)
	return "\n".join(lines)

static func building_instance_details(
	defs: Dictionary,
	building_health: Dictionary,
	b: Dictionary,
	power_network_status: Dictionary,
	lightning_max_charge: int,
	lightning_charge_time: float,
	node_range: float
) -> String:
	var lines: Array[String] = []
	lines.append(building_details(defs, building_health, b.id, lightning_max_charge, lightning_charge_time, node_range))
	if BuildingRules.is_power_participant(defs, b):
		lines.append(power_status_text(b, power_network_status))
	if b.id == "battery" or b.id == "core":
		lines.append("Stored power: %.0f / %.0f" % [float(b.store.get("power", 0)), BuildingRules.power_storage_capacity(defs, b)])
	if b.id == "lightning_turret":
		lines.append("Charged shots: %.1f / %d" % [float(b.store.get("charge", 0)), lightning_max_charge])
	return "\n".join(lines)

static func power_status_text(b: Dictionary, power_network_status: Dictionary) -> String:
	var key = BuildingRuntime.power_key(b)
	if not power_network_status.has(key):
		return "Power network: none"
	var status: Dictionary = power_network_status[key]
	if float(status["deficit"]) > 0.01:
		return "Power Deficit: %.0f/s (%.0f%% speed)" % [float(status["deficit"]), float(status["efficiency"]) * 100.0]
	return "Power Excess: %.0f/s" % float(status["excess"])
