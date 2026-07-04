extends RefCounted

static func add(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = b.store.get(kind, 0) + amount

static func take(b: Dictionary, kind: String, amount: int) -> void:
	b.store[kind] = max(0, b.store.get(kind, 0) - amount)

static func count(b: Dictionary, kind: String) -> int:
	return int(b.store.get(kind, 0))

static func turret_ammo_types(defs: Dictionary, b: Dictionary) -> Array:
	return defs.get(b.id, {}).get("ammo_types", ["copper", "graphite"])

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
