extends Node3D
class_name DebugRect

@onready var visual: Node3D = $Visual
var rect: Rect2i

func _ready() -> void:
	visual.global_scale(Vector3(rect.size.x, 1, rect.size.y))

func set_rect(new_rect: Rect2i):
	rect = new_rect
	position = TileMap2D.to_scene_pos(rect.position)
	if visual:
		visual.global_scale(Vector3(rect.size.x, 1, rect.size.y))
