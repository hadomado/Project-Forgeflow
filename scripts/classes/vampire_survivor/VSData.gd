extends RefCounted

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
