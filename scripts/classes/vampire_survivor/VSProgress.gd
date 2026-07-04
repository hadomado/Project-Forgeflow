extends RefCounted

static func xp_needed(level: int) -> int:
	# Rising curve: 5, 8, 12, 17, 23, 30, ... (differences +3, +4, +5, ...).
	# l*(l+5) is always even, so integer division is exact.
	var l := level - 1
	return 5 + l * (l + 5) / 2

static func xp_value(kind: String) -> int:
	match kind:
		"graphite":
			return 3
		"copper", "coal":
			return 1
		_:
			return 0

static func roll_level_up_choices(
	spell_defs: Dictionary,
	upgrade_defs: Dictionary,
	owned_spells: Dictionary,
	owned_upgrades: Dictionary
) -> Array:
	var pool: Array = []
	for id in spell_defs.keys():
		var lvl := int(owned_spells.get(id, 0))
		if lvl == 0:
			pool.append({"type": "spell", "id": id, "label": "New: " + String(spell_defs[id].name)})
		else:
			pool.append({"type": "spell", "id": id, "label": String(spell_defs[id].name) + " Lv " + str(lvl + 1)})
	for id in upgrade_defs.keys():
		var ulvl := int(owned_upgrades.get(id, 0))
		if ulvl < int(upgrade_defs[id].get("max", 4)):
			pool.append({"type": "upgrade", "id": id, "label": String(upgrade_defs[id].name) + " Lv " + str(ulvl + 1)})
	pool.shuffle()
	var out: Array = []
	for c in pool:
		if out.size() >= 3:
			break
		out.append(c)
	while out.size() < 3:
		out.append({"type": "heal", "id": "heal", "label": "Restore 25 Health"})
	return out
