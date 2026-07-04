extends Node2D

var item_color := Color.WHITE
@onready var box: Polygon2D = $Box

func sync_from(pos: Vector2, color: Color) -> void:
	position = pos
	if item_color != color:
		item_color = color
		box.color = item_color
