extends GameObject

func _ready() -> void:
	game_manager.game_state.tile_map.tile_changed.connect(_on_tile_changed)

func _on_tile_changed(pos: Vector2i, _old_tile: Enum.TileType, new_tile: Enum.TileType):
	var behind_pos = TileMap2D.to_tile_pos(transform.translated_local(Vector3(0, 0, -1)).origin)
	if pos == behind_pos and new_tile == Enum.TileType.FLOOR:
		game_manager.game_state.remove_game_object(self)
