extends RefCounted

static func hero_respawn_time(level: int, per_level: float, cap: float) -> float:
	return minf(per_level * float(level), cap)

static func hero_max_health(base_health: float, owned_upgrades: Dictionary) -> float:
	return base_health + 25.0 * int(owned_upgrades.get("vitality", 0))

static func hero_move_speed(base_speed: float, owned_upgrades: Dictionary) -> float:
	return base_speed * (1.0 + 0.12 * int(owned_upgrades.get("swiftness", 0)))

static func hero_magnet_radius(base_radius: float, owned_upgrades: Dictionary) -> float:
	return base_radius * (1.0 + 0.25 * int(owned_upgrades.get("lodestone", 0)))

static func spell_cooldown_scale(owned_upgrades: Dictionary) -> float:
	return max(0.4, 1.0 - 0.10 * int(owned_upgrades.get("rapid_casting", 0)))

static func orbit_blade_count(owned_spells: Dictionary, max_blades: int) -> int:
	var lvl := int(owned_spells.get("orbiting_blades", 0))
	if lvl <= 0:
		return 0
	return min(1 + lvl, max_blades)
