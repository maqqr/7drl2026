extends Node3D

@onready var mesh = $MeshInstance3D

var fade = false
var _alpha = 1.0

func _process(delta: float) -> void:
	if fade:
		_alpha = max(0.0, _alpha - delta * 3.0)
		var material = mesh.get_surface_override_material(0) as StandardMaterial3D
		material.albedo_color.a = _alpha
		if _alpha <= 0.0:
			free()
