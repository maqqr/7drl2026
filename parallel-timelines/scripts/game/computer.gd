extends GameObject
class_name Computer

@export var used = false
@export var screen_mesh: MeshInstance3D

func _ready() -> void:
	screen_mesh.visible = not used

func on_interact(character: Character) -> void:
	if used:
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_COMPUTER_USED)
		return

	used = true
	screen_mesh.visible = false

	var turn_count = 15
	game_manager.set_remaining_turns(game_manager.game_state.remaining_turns + turn_count)

	if game_manager.game_state.player == character:
		game_manager.add_message(MessageBuffer.MSG_COMPUTER.format({ "turn_count": turn_count }))
