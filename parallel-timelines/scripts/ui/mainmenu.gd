extends Node

@export var start_button: Button

func _ready() -> void:
	start_button.pressed.connect(start_game)

func start_game() -> void:
	queue_free()
	get_parent().add_child(preload("res://scenes/game.tscn").instantiate())
