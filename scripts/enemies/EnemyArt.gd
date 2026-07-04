extends RefCounted

const BASE_PATH := "res://assets/cc0_factory_defense_pack/art/"
const ENEMY_SHEET_KEYS: Array[String] = ["scout", "crawler", "runner", "bruiser", "boss_seed"]
const EFFECT_SHEETS: Dictionary = {
	"hit": "small_hit_sheet",
	"burst": "ore_burst_sheet",
	"core": "core_damage_sheet",
}

static func load_sheets() -> Dictionary:
	return {
		"enemy_sheets": _load_enemy_sheets(),
		"fx_sheets": _load_effect_sheets(),
	}

static func _load_enemy_sheets() -> Dictionary:
	var sheets: Dictionary = {}
	for key in ENEMY_SHEET_KEYS:
		var tex = load(BASE_PATH + "enemies/%s_walk_sheet.png" % key)
		if tex != null:
			sheets[key] = tex
	return sheets

static func _load_effect_sheets() -> Dictionary:
	var sheets: Dictionary = {}
	for key in EFFECT_SHEETS:
		var tex = load(BASE_PATH + "effects/%s.png" % EFFECT_SHEETS[key])
		if tex != null:
			sheets[key] = tex
	return sheets
