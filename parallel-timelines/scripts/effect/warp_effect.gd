extends Node3D

func _ready() -> void:
	(get_child(0) as GPUParticles3D).emitting = true
	(get_child(0) as GPUParticles3D).finished.connect(func (): queue_free())
