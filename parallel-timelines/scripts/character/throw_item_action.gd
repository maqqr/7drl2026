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
var kill_target: Character = null

func _init(p_target_tile: Vector2i, p_target_item_type: ItemType, p_preferred_index: int) -> void:
	target_tile = p_target_tile
	target_item_type = p_target_item_type
	preferred_index = p_preferred_index

func can_execute(game_manager: GameManager, _character: Character) -> bool:
	# HACK: Cheat a bit and stop the target already here from escaping
	if target_item_type.kill_on_throw:
		for past_player in game_manager.game_state.past_players:
			if past_player.map_position == target_tile:
				kill_target = past_player
				kill_target.ongoing_action = null
				kill_target.past_actions.clear()
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
			character.audio_player.stream = preload("res://audio/throw_item.ogg")
			character.audio_player.play()
			character.animation_player.play(character.USE_ANIM)

	progress = min(1.0, progress + delta / duration)
	if flying_node:
		flying_node.global_position = \
			TileMap2D.to_scene_pos(character.map_position).lerp(TileMap2D.to_scene_pos(target_tile), progress) + Vector3(0.0, 0.5, 0.0)

	var done = progress >= 1.0
	if done and throw_started:
		character.remove_child(flying_node)
		if game_manager.game_state.player == character:
			game_manager.add_message(MessageBuffer.MSG_THROW.format({ "item": target_item_type.name }))

		if target_item_type.spawn_game_object_on_throw != null:
			game_manager.game_state.create_game_object_at(game_manager, target_item_type.spawn_game_object_on_throw, target_tile)

		if target_item_type.teleport_on_throw:
			character.teleport_to(target_tile)
			character.visible = true
			if character == game_manager.game_state.player:
				game_manager.screen_shake.shake(0.4, 3.0)

		var killed_target = false
		if target_item_type.kill_on_throw and kill_target:
			kill_target.health = 0
			killed_target = true

		if not target_item_type.consumed_on_throw and not killed_target:
			game_manager.game_state.create_item_at(target_item_type, target_tile, true)

	return done

func clone() -> ThrowItemAction:
	return ThrowItemAction.new(target_tile, target_item_type, preferred_index)
