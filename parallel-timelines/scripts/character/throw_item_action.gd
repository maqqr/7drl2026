extends RefCounted
class_name ThrowItemAction

var target_tile: Vector2i
var target_item_type: ItemType
var preferred_index: int

var progress: float = 0.0
var duration: float = 0.2

var started = false
var throw_started = false

var flying_node: Node3D = null

func _init(p_target_tile: Vector2i, p_target_item_type: ItemType, p_preferred_index: int) -> void:
	target_tile = p_target_tile
	target_item_type = p_target_item_type
	preferred_index = p_preferred_index

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	if not started:
		started = true
		var index = preferred_index
		if index >= character.items.size() or character.items[index] != target_item_type:
			index = 4294967295
			for i in range(character.items.size()):
				if character.items[i] == target_item_type:
					index = i
					break
		if character.remove_item_at(game_manager, index):
			throw_started = true
			flying_node = target_item_type.visual_scene.instantiate()
			character.add_child(flying_node)

	progress = min(1.0, progress + delta / duration)
	if flying_node:
		flying_node.global_position = \
			TileMap2D.to_scene_pos(character.map_position).lerp(TileMap2D.to_scene_pos(target_tile), progress) + Vector3(0.0, 0.5, 0.0)

	var done = progress >= 1.0
	if done and throw_started:
		character.remove_child(flying_node)
		game_manager.game_state.create_item_at(target_item_type, target_tile)
		if game_manager.game_state.player == character:
				game_manager.add_message(MessageBuffer.MSG_THROW.format({ "item": target_item_type.name }))

	return done

func clone() -> ThrowItemAction:
	return ThrowItemAction.new(target_tile, target_item_type, preferred_index)
