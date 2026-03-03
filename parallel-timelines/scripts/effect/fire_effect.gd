extends Node3D
class_name FireEffect

@export var light: LightFlicker
@export var fire_mesh_instances: Array[MeshInstance3D]

var intensity = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if intensity < 1.0:
		intensity = min(1.0, intensity + delta * 0.5)

	light.total_intensity = intensity

	for fire_mesh in fire_mesh_instances:
		fire_mesh.set_instance_shader_parameter("Intensity", intensity)
