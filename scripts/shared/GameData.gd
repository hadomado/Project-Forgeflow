extends RefCounted

static func build_categories() -> Array[Dictionary]:
	return [
		{"id": "turrets", "name": "Turrets"},
		{"id": "belts", "name": "Belts"},
		{"id": "drills", "name": "Drills"},
		{"id": "fluids", "name": "Fluids"},
		{"id": "power", "name": "Power"},
		{"id": "walls", "name": "Walls"},
		{"id": "factories", "name": "Factories"},
		{"id": "combat", "name": "Combat"},
		{"id": "misc", "name": "Misc"}
	]

static func ore_tiers() -> Dictionary:
	return {
		"copper": 1,
		"coal": 1,
		"sand": 1,
		"lead": 2,
		"titanium": 3,
		"thorium": 4
	}

static func ore_colors() -> Dictionary:
	return {
		"copper": Color("#c98d39"),
		"coal": Color("#424247"),
		"lead": Color("#94a0bf"),
		"titanium": Color("#70d6cf"),
		"thorium": Color("#d884d8"),
		"graphite": Color("#8ea0ad"),
		"water": Color("#69c9e8"),
		"sand": Color("#d9c27a"),
		"silicon": Color("#d7dbe5"),
		"oil": Color("#26242f"),
		"plastinium": Color("#b5e08c"),
		"pyrite": Color("#f09a38")
	}

static func spell_defs() -> Dictionary:
	return {
		"arc_bolt": {"name": "Arc Bolt", "kind": "projectile", "cooldown": 1.1, "damage": 16.0, "range": 260.0, "bullet_speed": 460.0},
		"orbiting_blades": {"name": "Orbiting Blades", "kind": "orbit", "cooldown": 0.25, "damage": 9.0, "radius": 46.0},
		"pulse_nova": {"name": "Pulse Nova", "kind": "nova", "cooldown": 2.2, "damage": 24.0, "radius": 120.0}
	}

static func upgrade_defs() -> Dictionary:
	return {
		"swiftness": {"name": "Swiftness", "desc": "+12% move speed", "max": 4},
		"lodestone": {"name": "Lodestone", "desc": "+25% magnet radius", "max": 4},
		"rapid_casting": {"name": "Rapid Casting", "desc": "-10% spell cooldowns", "max": 4},
		"vitality": {"name": "Vitality", "desc": "+25 max health", "max": 4}
	}
