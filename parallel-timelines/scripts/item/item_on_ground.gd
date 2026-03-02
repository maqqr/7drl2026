extends Node3D
class_name ItemOnGround

var item: ItemType
var map_position: Vector2i
var _scene: Node3D

var time: float

func _ready() -> void:
	transform.origin = TileMap2D.to_scene_pos(map_position)
	_scene = item.visual_scene.instantiate() as Node3D
	add_child(_scene)

func _process(delta: float) -> void:
	time += delta
	_scene.rotate(Vector3i(0, 1, 0), 8.0 * delta)
	transform.origin.y = 0.5 * (sin(time * 4.0) * 0.5 + 0.5)
