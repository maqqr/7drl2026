extends Node3D
class_name Character

var ongoing_action = null
var past_actions = []
var map_position: Vector2i
var spawn_position: Vector2i
var look_direction: Vector2i
var items: Array[ItemType]

var invisibility_turns = 0
var invisibility_effect_node: Node3D

@onready var spotlight = $SpotLight3D

signal inventory_changed(character: Character)

func make_invisible(turns: int) -> void:
	invisibility_turns = turns
	if invisibility_effect_node == null:
		invisibility_effect_node = preload("res://scenes/invisibility_effect.tscn").instantiate()
		add_child(invisibility_effect_node)

func teleport_to(pos: Vector2i) -> void:
	map_position = pos
	global_position = TileMap2D.to_scene_pos(map_position)

func execute_action(game_manager: GameManager, delta: float) -> void:
	if ongoing_action:
		if ongoing_action.execute(game_manager, self, delta):
			if ongoing_action is MoveAction:
				spotlight.light_energy = 0.0 if game_manager.game_state.safe_room.has_point(map_position) else 1.0
				_pickup_items_on_ground(game_manager)
				if invisibility_turns > 0:
					invisibility_turns -= 1
					if invisibility_turns == 0 and invisibility_effect_node:
						invisibility_effect_node.queue_free()
						invisibility_effect_node = null
				game_manager.game_state.on_character_move_finish(self)
			ongoing_action = null

func pickup_item(_game_manager: GameManager, item: ItemType) -> void:
	items.push_back(item)
	inventory_changed.emit(self)

func remove_item_at(_game_manager: GameManager, index: int) -> bool:
	if index < 0 or index >= items.size():
		return false

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
		if game_manager.game_state.player == self:
			game_manager.add_message(MessageBuffer.MSG_PICKUP.format({ "a": "an" if item_on_ground.item.an_article else "a", "item": item_on_ground.item.name }))
		game_manager.game_state.remove_item(item_on_ground)
