extends Node3D
class_name ItemOnGround

var item: ItemType
var map_position: Vector2i
var _scene: Node3D

func _ready() -> void:
	transform.origin = TileMap2D.to_scene_pos(map_position)
	_scene = item.visual_scene.instantiate() as Node3D
	add_child(_scene)

func _process(delta: float) -> void:
	_scene.rotate(Vector3i(0, 1, 0), 10.0 * delta)
