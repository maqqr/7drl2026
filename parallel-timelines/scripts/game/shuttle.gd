extends GameObject
class_name Shuttle

var _map_position: Vector2i

var moving = false
var speed = 0.0

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func _process(delta: float) -> void:
	if moving:
		speed += delta
		transform.origin.z += speed * delta

func on_character_move_finish(character: Character) -> void:
	if character.map_position.distance_squared_to(_map_position) <= 5:
		for i in range(character.items.size() - 1, -1, -1):
			if character.items[i].is_keycard:
				game_manager.game_state.remaining_keycards -= 1
				var msg = MessageBuffer.MSG_KEY_SELF_DELIVER if character == game_manager.game_state.player else MessageBuffer.MSG_KEY_DELIVER
				game_manager.add_message(msg.format({ "item": character.items[i].name, "remain_count": game_manager.game_state.remaining_keycards }))
				character.items.remove_at(i)
				character.inventory_changed.emit(character)

				if game_manager.game_state.remaining_keycards == 0:
					character.visible = false
					var win_msg = MessageBuffer.MSG_WIN if game_manager.game_state.player == character else MessageBuffer.MSG_WIN_OTHER
					game_manager.add_message(win_msg, 120.0)
					game_manager.game_over = true
					game_manager.quit_to_menu_timer = 8.0
					moving = true
