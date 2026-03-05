extends RefCounted
class_name InteractAction

var target_tile: Vector2i
var direction: Vector2i

var progress: float = 0.0
var duration: float = 0.1
var target_angle: float

var started = false

func _init(p_target_tile: Vector2i, p_direction: Vector2i) -> void:
	target_tile = p_target_tile
	direction = p_direction
	var dir = Vector2(p_direction).normalized()
	self.target_angle = atan2(dir.x, dir.y)

func can_execute(_game_manager: GameManager, _character: Character) -> bool:
	return true

func execute(game_manager: GameManager, character: Character, delta: float) -> bool:
	if not started:
		started = true
		character.look_direction = direction
		character.animation_player.play(character.USE_ANIM)
		if game_manager.game_state.player == character:
			duration = 0.3

	progress = min(1.0, progress + delta / duration)
	character.global_rotation.y = lerp_angle(character.global_rotation.y, target_angle, progress)
	var done = progress >= 1.0
	if done:
		for game_obj in game_manager.game_state.game_objects:
			if TileMap2D.to_tile_pos(game_obj.transform.origin) == target_tile:
				game_obj.on_interact(character)
	return done

func clone() -> InteractAction:
	return InteractAction.new(target_tile, direction)
