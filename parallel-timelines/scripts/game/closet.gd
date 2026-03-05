extends GameObject
class_name Closet

var _map_position: Vector2i

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func on_character_move_finish(character: Character) -> void:
	if character.map_position == _map_position:
		character.visible = false
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_HIDE)
