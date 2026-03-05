extends Node

@export var level_size_group: ButtonGroup
@export var difficulty_group: ButtonGroup
@export var start_button: Button
@export var intro_button: Button
@export var show_tutorial_button: Button
@export var close_tutorial_button: Button
@export var intro_control: Control
@export var level_select_control: Control
@export var tutorial_control: Control
@export var debug_label: RichTextLabel

@export var camera_position: Vector3
@export var camera_rotation: Vector3

var scene3d: Node3D

var selected_level_size = 0
var selected_difficulty = 1

var level_sizes = [
	MapGenerator.SIZE_SMALL,
	MapGenerator.SIZE_MEDIUM,
	MapGenerator.SIZE_LARGE,
]

var difficulties = [
	MapGenerator.EASY,
	MapGenerator.NORMAL,
	MapGenerator.HARD,
	MapGenerator.ALMOST_IMPOSSIBLE,
	MapGenerator.IMPOSSIBLE,
]

func _ready() -> void:
	start_button.pressed.connect(start_game)
	intro_button.pressed.connect(skip_intro)
	show_tutorial_button.pressed.connect(func (): tutorial_control.visible = true)
	close_tutorial_button.pressed.connect(func (): tutorial_control.visible = false)
	level_size_group.pressed.connect(level_size_changed)
	difficulty_group.pressed.connect(difficulty_changed)
	update_debug()

	scene3d = preload("res://scenes/mainmenu_3d.tscn").instantiate()
	get_parent().add_child.call_deferred(scene3d)

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	camera.transform.origin = camera_position
	camera.rotation = camera_rotation

func skip_intro() -> void:
	intro_control.visible = false
	level_select_control.visible = true

func start_game() -> void:
	scene3d.queue_free()
	queue_free()
	var game = preload("res://scenes/game.tscn").instantiate() as GameManager
	game.chosen_parameters.merge(level_sizes[selected_level_size])
	game.chosen_parameters.merge(difficulties[selected_difficulty])
	get_parent().add_child(game)

func level_size_changed(button: Button):
	selected_level_size = button.get_index() - 1
	update_debug()

func difficulty_changed(button: Button):
	selected_difficulty = button.get_index() - 1
	update_debug()

func update_debug():
	debug_label.text = "Debug info:\n[i]"
	for k in level_sizes[selected_level_size]:
		debug_label.text += k + ": " + str(level_sizes[selected_level_size][k]) + "\n"
	for k in difficulties[selected_difficulty]:
		debug_label.text += k + ": " + str(difficulties[selected_difficulty][k]) + "\n"
