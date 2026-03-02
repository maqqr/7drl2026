extends GameObject
class_name ExplosionTrap

var _map_position: Vector2i

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func on_character_move_finish(character: Character) -> void:
	if character.map_position != _map_position:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = game_manager.game_state.current_seed + hash(TileMap2D.to_tile_pos(transform.origin))

	game_manager.game_state.remove_game_object(self)

	var target_tile: Vector2i
	var attempts = 0
	while true:
		attempts += 1
		if attempts > 50:
			return

		target_tile = Vector2i(
			rng.randi_range(0, game_manager.game_state.tile_map.width - 1),
			rng.randi_range(0, game_manager.game_state.tile_map.height - 10))

		if game_manager.game_state.safe_room.has_point(target_tile):
			continue

		if game_manager.game_state.tile_map.get_tile(target_tile) == Enum.TileType.EMPTY:
			continue
		
		break

	if game_manager.game_state.player == character:
		game_manager.add_message(MessageBuffer.MSG_EXPLOSION_TRAP)

	game_manager.explode_at(target_tile, 3)
