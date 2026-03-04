extends GameObject
class_name Fire

var _map_position: Vector2i
var turns_left = 0

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)
	var rng = RandomNumberGenerator.new()
	rng.seed = game_manager.game_state.current_seed + hash(TileMap2D.to_tile_pos(transform.origin))
	turns_left = rng.randi_range(2, 25)

func on_character_move_finish(character: Character) -> void:
	if game_manager.game_over:
		return

	if character.map_position == _map_position:
		character.health -= 1
		character.health_changed.emit(character)
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_FIRE_DAMAGE)

func on_all_actions_finished() -> void:
	turns_left -= 1
	if turns_left <= 0:
		game_manager.game_state.remove_game_object(self)
