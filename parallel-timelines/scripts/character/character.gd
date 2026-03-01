extends Node3D
class_name Character

var ongoing_action = null
var past_actions = []
var map_position: Vector2i
var spawn_position: Vector2i
var look_direction: Vector2i
var items: Array[ItemType]

@onready var spotlight = $SpotLight3D

signal inventory_changed(character: Character)

func teleport_to(pos: Vector2i) -> void:
	map_position = pos
	global_position = TileMap2D.to_scene_pos(map_position)

func execute_action(game_manager: GameManager, delta: float) -> void:
	if ongoing_action:
		if ongoing_action.execute(game_manager, self, delta):
			if ongoing_action is MoveAction:
				spotlight.light_energy = 0.0 if game_manager.game_state.safe_room.has_point(map_position) else 1.0
				_pickup_items_on_ground(game_manager)
				game_manager.game_state.on_character_move_finish(self)
			ongoing_action = null

func pickup_item(game_manager: GameManager, item: ItemType) -> void:
	if game_manager.game_state.player == self:
		game_manager.add_message(MessageBuffer.MSG_PICKUP.format({ "a": "an" if item.an_article else "a", "item": item.name }))

	items.push_back(item)
	inventory_changed.emit(self)

func remove_item_at(game_manager: GameManager, index: int) -> bool:
	if index < 0 or index >= items.size():
		return false

	var item = items[index]

	if game_manager.game_state.player == self:
		game_manager.add_message(MessageBuffer.MSG_DROP.format({ "item": item.name }))

	items.remove_at(index)
	inventory_changed.emit(self)
	return true

func _pickup_items_on_ground(game_manager: GameManager) -> void:
	var pickup: Array[ItemOnGround] = []
	for item_on_ground in game_manager.game_state.items:
		if item_on_ground.map_position == map_position:
			pickup.push_back(item_on_ground)

	for item_on_ground in pickup:
		pickup_item(game_manager, item_on_ground.item)
		game_manager.game_state.remove_item(item_on_ground)
