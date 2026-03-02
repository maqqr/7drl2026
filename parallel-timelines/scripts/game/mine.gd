extends GameObject
class_name Mine

var _map_position: Vector2i

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func on_character_move_finish(character: Character) -> void:
	if character.map_position == _map_position:
		game_manager.game_state.remove_game_object(self)
		game_manager.explode_at(_map_position, 3)
