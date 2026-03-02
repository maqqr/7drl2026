extends RefCounted
class_name WarpAction

var progress: float = 0.0
var duration: float = 0.1

var started = false

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	progress = min(1.0, progress + delta / duration)
	var done = progress >= 1.0
	if done:
		if game_manager.game_state.player == character:
			game_manager.timewarp()
		else:
			game_manager.game_state.remove_character(character)
			game_manager.need_sight_check = true
			for item in character.items:
				if item.is_keycard:
					game_manager.game_state.create_item_at(item, character.map_position)

	return done

func clone() -> WarpAction:
	return WarpAction.new()
