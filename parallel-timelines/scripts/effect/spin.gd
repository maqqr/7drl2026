extends Node3D

func _process(delta: float) -> void:
	global_rotate(Vector3(0, 1, 0), 30.0 * delta)
