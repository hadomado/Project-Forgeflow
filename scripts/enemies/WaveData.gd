extends RefCounted

static func enemy_kind_for_wave(wave: int, max_wave: int) -> String:
	var pool := enemy_pool_for_wave(wave, max_wave)
	return pool[randi() % pool.size()]

static func enemy_pool_for_wave(wave: int, max_wave: int) -> Array[String]:
	# Repeated entries act as spawn weights while later waves add new archetypes.
	var pool: Array[String] = ["scout"]
	if wave >= 1:
		pool.append_array(["swarmling", "swarmling", "scout"])
	if wave >= 2:
		pool.append_array(["grunt", "grunt"])
	if wave >= 3:
		pool.append_array(["ranger", "ranger", "wraith"])
	if wave >= 4:
		pool.append_array(["bruiser", "berserker"])
	if wave >= 5:
		pool.append_array(["marksman", "warden"])
	if wave >= 6:
		pool.append_array(["brood", "brood", "mender"])
	if wave >= 7:
		pool.append_array(["artillery"])
	if wave >= 8:
		pool.append_array(["siege"])
	if wave >= 9:
		pool.append_array(["juggernaut"])
	if wave >= max_wave:
		pool.append_array(["overseer"])
	return pool
