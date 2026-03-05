extends GameObject
class_name Crate

@export var open = false
@export var crate_lid: Node3D

func _ready() -> void:
	crate_lid.visible = not open

func on_interact(character: Character) -> void:
	if open:
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_CRATE_EMPTY)
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = game_manager.game_state.current_seed + hash(TileMap2D.to_tile_pos(transform.origin))

	var possible_items = [
		preload("res://data/items/cloaking_device.tres"),
		preload("res://data/items/mine.tres"),
		preload("res://data/items/teleball.tres"),
		preload("res://data/items/knife.tres"),
	]

	var found_item = possible_items[rng.randi_range(0, possible_items.size() - 1)]

	if character.items.size() < game_manager.MAX_INVENTORY:
		character.pickup_item(game_manager, found_item)

		open = true
		crate_lid.visible = false

		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_TAKE.format({ "a": "an" if found_item.an_article else "a", "item": found_item.name }))
	else:
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_INV_FULL.format({ "item": found_item.name }))
