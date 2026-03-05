extends RefCounted
class_name WaitAction

var progress: float = 0.0
var duration: float = 0.1

var started = false

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(_game_manager: GameManager, character: Character, delta: float) -> bool:
	if not started:
		started = true
		character.animation_player.play(character.IDLE_ANIM)

	progress = min(1.0, progress + delta / duration)
	return progress >= 1.0

func clone() -> WaitAction:
	return WaitAction.new()
