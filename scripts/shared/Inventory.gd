extends RefCounted

static func can_afford(inventory: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if inventory.get(k, 0) < cost[k]:
			return false
	return true

static func pay(inventory: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		inventory[k] = inventory.get(k, 0) - cost[k]

static func cost_text(cost: Dictionary) -> String:
	var bits: Array[String] = []
	for k in cost:
		bits.append("%s %s" % [cost[k], String(k).capitalize()])
	return ", ".join(bits)
