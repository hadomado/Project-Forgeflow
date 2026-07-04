extends Node2D

const EnemyDrawing = preload("res://scripts/enemies/EnemyDrawing.gd")

var enemy: Dictionary = {}
var enemy_def: Dictionary = {}
var enemy_sheets: Dictionary = {}
var anim_time: float = 0.0

func sync_from(enemy_state: Dictionary, definition: Dictionary, sheets: Dictionary, time: float) -> void:
	enemy = enemy_state
	enemy_def = definition
	enemy_sheets = sheets
	anim_time = time
	position = Vector2(enemy_state.get("pos", Vector2.ZERO))
	queue_redraw()

func _draw() -> void:
	if enemy.is_empty() or enemy_def.is_empty():
		return
	var local_enemy := enemy.duplicate()
	local_enemy.pos = Vector2.ZERO
	EnemyDrawing.draw_enemy(self, local_enemy, enemy_def, enemy_sheets, anim_time)
