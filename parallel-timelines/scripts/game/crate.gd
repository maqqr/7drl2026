extends GameObject
class_name Crate

var open = false

func on_interact(character: Character) -> void:
	if open:
		return

	open = true

	var rng = RandomNumberGenerator.new()
	rng.seed = game_manager.game_state.current_seed + hash(TileMap2D.to_tile_pos(transform.origin))

	var found_item = preload("res://data/items/cloaking_device.tres") as ItemType \
		if rng.randf() < 0.5 else preload("res://data/items/mine.tres") as ItemType

	character.pickup_item(game_manager, found_item)

	if game_manager.game_state.player == character:
		game_manager.add_message(MessageBuffer.MSG_TAKE.format({ "a": "an" if found_item.an_article else "a", "item": found_item.name }))
