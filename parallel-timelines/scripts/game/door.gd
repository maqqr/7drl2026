extends GameObject
class_name Door

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
var open_sound = preload("res://audio/door_open4.ogg")
var close_sound = preload("res://audio/door_close2.ogg")

@export var left_door: Node3D
@export var right_door: Node3D

var _map_position: Vector2i
var _is_open = false
var _open_state = 0.0

const ANIM_SPEED = 4.0

func _ready() -> void:
	_map_position = TileMap2D.to_tile_pos(transform.origin)

func _process(delta: float) -> void:
	if _is_open and _open_state < 1.0:
		_open_state = min(1.0, _open_state + delta * ANIM_SPEED)

	if not _is_open and _open_state > 0.0:
		_open_state = max(0.0, _open_state - delta * ANIM_SPEED * 0.5)

	left_door.transform.origin.x = -_open_state * 0.5
	right_door.transform.origin.x = _open_state * 0.5

func on_all_actions_finished() -> void:
	var players = []
	players.push_back(game_manager.game_state.player)
	players.append_array(game_manager.game_state.past_players)
	var was_open = _is_open
	_is_open = players.any(func (c: Character): return c.map_position == _map_position)

	if not _is_open and was_open and _open_state > 0.9:
		audio_player.stream = close_sound
		audio_player.play()

func on_action_started(_character: Character, action) -> void:
	if action is MoveAction:
		if action.to == _map_position:
			_is_open = true
			if is_zero_approx(_open_state):
				audio_player.stream = open_sound
				audio_player.play()
