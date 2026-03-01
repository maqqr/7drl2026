extends Node3D
class_name GameObject

var game_manager: GameManager

func set_game_manager(p_game_manager: GameManager):
	if p_game_manager != null:
		assert(p_game_manager is GameManager)

	game_manager = p_game_manager
	pass

func on_character_move_finish(_character: Character) -> void:
	pass
