extends RefCounted
class_name MoveAction

var from: Vector2i
var to: Vector2i
var direction: Vector2i

var progress: float = 0.0
var duration: float = 0.2
var target_angle: float

var started = false

func _init(p_from: Vector2i, p_to: Vector2i, p_direction: Vector2i):
	self.from = p_from
	self.to = p_to
	self.direction = p_direction
	var dir = Vector2(p_direction).normalized()
	self.target_angle = atan2(dir.x, dir.y)

func can_execute(game_manager: GameManager, _character: Character) -> bool:
	return game_manager.game_state.can_move_to(to)

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	if not started:
		started = true
		character.map_position = to
		character.look_direction = direction
		game_manager.need_sight_check = true
		game_manager.reveal_darkness()

		if character.anim_step_right:
			character.animation_player.play(character.WALK_ANIM)
		else:
			character.animation_player.play_backwards(character.WALK_ANIM)
		character.anim_step_right = !character.anim_step_right

	progress = min(1.0, progress + delta / duration)
	character.global_position = TileMap2D.to_scene_pos(from).lerp(TileMap2D.to_scene_pos(to), progress)
	character.global_rotation.y = lerp_angle(character.global_rotation.y, target_angle, progress)
	return progress >= 1.0

func clone() -> MoveAction:
	return MoveAction.new(from, to, direction)
