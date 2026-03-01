extends RefCounted
class_name DropItemAction

var target_item_type: ItemType
var preferred_index: int

var progress: float = 0.0
var duration: float = 0.1

func _init(p_target_item_type: ItemType, p_preferred_index: int) -> void:
	target_item_type = p_target_item_type
	preferred_index = p_preferred_index

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	progress = min(1.0, progress + delta / duration)
	var done = progress >= 1.0
	if done:
		var index = preferred_index
		if index >= character.items.size() or character.items[index] != target_item_type:
			index = 4294967295
			for i in range(character.items.size()):
				if character.items[i] == target_item_type:
					index = i
					break
		if character.remove_item_at(game_manager, index):
			game_manager.game_state.create_item_at(target_item_type, character.map_position)

	return done

func clone() -> DropItemAction:
	return DropItemAction.new(target_item_type, preferred_index)
