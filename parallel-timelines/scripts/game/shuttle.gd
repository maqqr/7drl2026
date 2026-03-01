extends GameObject
class_name Shuttle

var _map_position: Vector2i

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func on_character_move_finish(character: Character) -> void:
	if character.map_position.distance_squared_to(_map_position) <= 4:
		for i in range(character.items.size() - 1, -1, -1):
			if true: # TODO: if keycard
				game_manager.game_state.remaining_keycards -= 1
				var msg = MessageBuffer.MSG_KEY_SELF_DELIVER if character == game_manager.game_state.player else MessageBuffer.MSG_KEY_DELIVER
				game_manager.add_message(msg.format({ "item": character.items[i].name, "remain_count": game_manager.game_state.remaining_keycards }))
				character.items.remove_at(i)

				if game_manager.game_state.remaining_keycards == 0:
					game_manager.add_message("You escaped with the shuttle and won the game.")
