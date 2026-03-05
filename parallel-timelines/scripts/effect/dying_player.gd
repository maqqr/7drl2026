extends Node3D

@onready var animation_player = $character_model/AnimationPlayer

func _ready() -> void:
	animation_player.play(&"Die")
