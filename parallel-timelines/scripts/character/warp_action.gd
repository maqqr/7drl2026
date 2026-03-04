extends RefCounted
class_name WarpAction

var progress: float = 0.0
var duration: float = 0.25

var started = false

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	if not started:
		started = true
		character.visible = false
		var effect = preload("res://scenes/effects/warp_effect.tscn").instantiate() as Node3D
		effect.transform.origin = TileMap2D.to_scene_pos(character.map_position)
		game_manager.game_state.add_child(effect)

		if game_manager.game_state.player == character:
			duration = 2.2
			character.play_warp_audio()
		else:
			character.audio_player.stream = preload("res://audio/timewarp_other.ogg")
			character.audio_player.play()

	progress = min(1.0, progress + delta / duration)
	var done = progress >= 1.0
	if done:
		if game_manager.game_state.player == character:
			game_manager.timewarp()
		else:
			game_manager.game_state.remove_character(character)
			game_manager.need_sight_check = true
			for item in character.items:
				if item.is_keycard:
					game_manager.game_state.create_item_at(item, character.map_position, false)

	return done

func clone() -> WarpAction:
	return WarpAction.new()
