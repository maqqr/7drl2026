extends Node3D
class_name GameManager

const DEV_MODE = false
const FILL_DARKNESS = not DEV_MODE

const MOVE_KEYS: Dictionary[String, Vector2i] = {
	"right": Vector2i(1, 0),
	"left": Vector2i(-1, 0),
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
}

class Timeline:
	var spawn_position: Vector2i
	var actions = []

@onready var message_buffer: MessageBuffer = $CanvasLayer_GUI/MessageBuffer
@onready var turns_label: RichTextLabel = $CanvasLayer_GUI/RichTextLabel_Turns
@onready var cursor: Node3D = $Cursor
var original_tilemap: TileMap2D
var map_generator: MapGenerator

var game_state: GameState = null

var parallel_timelines: Array[Timeline]

@export var camera_offset = Vector3(0.0, 7.0, 5.5)
var recorded_actions = []

var debug_rect_scene: PackedScene = preload("res://scenes/debug_rect.tscn")
var debug_rects: Node3D

var need_sight_check = false
var darkness: Array2D
var darkness_nodes: Dictionary[Vector2i, Node3D]

var need_action_finish_check = false
var game_over = false

func _ready() -> void:
	map_generator = MapGenerator.new()
	map_generator.name = "MapGenerator"
	add_child(map_generator)

	debug_rects = Node3D.new()
	debug_rects.name = "DebugRects"
	add_child(debug_rects)

	start_new_game()

func _process(delta: float) -> void:
	if not (game_state != null and game_state.is_initialized):
		return

	# Update cursor
	var mouse_tile = get_mouse_tile()
	if game_state.tile_map.is_point_inside(mouse_tile):
		cursor.position = TileMap2D.to_scene_pos(mouse_tile)

	get_viewport().get_camera_3d().global_position = game_state.player.global_position + camera_offset

	# Execute all actions
	game_state.player.execute_action(self, delta)
	for past_player in game_state.past_players:
		past_player.execute_action(self, delta)

	if need_sight_check:
		game_state.update_seen_tiles()
		need_sight_check = false

	if is_input_enabled() and need_action_finish_check:
		need_action_finish_check = false
		# Check if any past players can see the current player
		for seen_pos in game_state.seen_tiles:
			if game_state.player.map_position == seen_pos:
				add_message(MessageBuffer.MSG_LOSE)
				game_over = true
				await get_tree().create_timer(6).timeout
				# Reset game
				restart_game()
				return
		# Check remaining turns
		if game_state.remaining_turns <= 0:
			add_message(MessageBuffer.MSG_OUT_OF_TURNS)
			game_over = true
			await get_tree().create_timer(3).timeout
			timewarp()
			game_over = false
			return

	# Handle player movement
	if is_input_enabled():
		var advance_game = false
		for key_name in MOVE_KEYS:
			if Input.is_action_pressed(key_name):
				var direction = MOVE_KEYS[key_name]
				var old_position = game_state.player.map_position
				var final_position = game_state.player.map_position + direction
				game_state.player.ongoing_action = MoveAction.new(old_position, final_position, direction)
				if game_state.player.ongoing_action.can_execute(self, game_state.player):
					recorded_actions.push_back(game_state.player.ongoing_action)
					advance_game = true
				else:
					game_state.player.ongoing_action = null
				break

		if Input.is_action_pressed("wait"):
			game_state.player.ongoing_action = WaitAction.new()
			recorded_actions.push_back(game_state.player.ongoing_action)
			advance_game = true

		if Input.is_action_just_pressed("warp"):
			game_state.player.ongoing_action = WarpAction.new()
			recorded_actions.push_back(game_state.player.ongoing_action)

		if advance_game:
			set_remaining_turns(game_state.remaining_turns - 1)
			need_action_finish_check = true
			for past_player in game_state.past_players:
				if not past_player.past_actions.is_empty():
					past_player.ongoing_action = past_player.past_actions[0]
					past_player.past_actions.remove_at(0)
					assert(past_player.ongoing_action)
					# Stop the whole timeline if execution fails
					if not past_player.ongoing_action.can_execute(self, past_player):
						past_player.ongoing_action = null
						past_player.past_actions.clear()

func is_input_enabled() -> bool:
	return not game_over and \
		game_state.player.ongoing_action == null and \
		game_state.past_players.all(func (c: Character): return c.ongoing_action == null)

func get_mouse_tile() -> Vector2i:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var direction = camera.project_ray_normal(mouse_pos)
	if direction.y == 0.0:
		return Vector2i.ZERO
	var distance = -origin.y / direction.y
	var pos = origin + direction * distance
	return TileMap2D.to_tile_pos(pos)

func _unhandled_input(event: InputEvent) -> void:
	if game_state == null:
		return

	if DEV_MODE:
		if event is InputEventMouseButton:
			if event.pressed:
				var tile = Enum.TileType.WALL if event.button_index == 1 else Enum.TileType.FLOOR
				game_state.tile_map.set_tile(get_mouse_tile(), tile)

func reveal_darkness() -> void:
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var checked_pos = game_state.player.map_position + Vector2i(dx, dy)
			if darkness.get_value(checked_pos) == 1:
				if game_state.can_see(game_state.player, checked_pos, true):
					darkness.set_value(checked_pos, 0)
					remove_child(darkness_nodes[checked_pos])
					darkness_nodes.erase(checked_pos)

func add_message(msg: String) -> void:
	message_buffer.add_message(msg)

func set_remaining_turns(turns: int) -> void:
	game_state.remaining_turns = turns
	turns_label.text = "Turn left: " + str(game_state.remaining_turns)

func timewarp() -> void:
	# Store current timeline
	var timeline = Timeline.new()
	timeline.spawn_position = game_state.player.spawn_position
	timeline.actions = recorded_actions
	recorded_actions = []
	parallel_timelines.push_back(timeline)

	# Clear old game state
	remove_child(game_state)
	game_state = null

	# Create new game state
	game_state = _create_game_state()
	add_child(game_state)
	set_remaining_turns(game_state.remaining_turns)

	# Create old timelines
	for old_timeline in parallel_timelines:
		var character = game_state.create_character_at(old_timeline.spawn_position)
		for action in old_timeline.actions:
			character.past_actions.push_back(action.clone())
		game_state.past_players.push_back(character)

	add_message("You wake up in a dark room with yourself.")

	print("Time warp done")

func restart_game() -> void:
	remove_child(game_state)
	game_state = null
	game_over = false
	recorded_actions.clear()
	parallel_timelines.clear()
	message_buffer.clear()
	for node_pos in darkness_nodes:
		darkness_nodes[node_pos].queue_free()
	start_new_game()

func start_new_game() -> void:
	while true:
		map_generator.generate(MapGenerator.SMALL)
		await map_generator.completed
		if not map_generator.fail:
			break
		else:
			print("Map generation failed, trying again...")

	print("Map generation done")
	original_tilemap = map_generator.tile_map

	# Create and fix doors
	for door_pos in map_generator.door_positions:
		var is_horizontal = false
		var is_vertical = false
		if original_tilemap.get_tile(door_pos + Vector2i(-1, 0)) == Enum.TileType.WALL and original_tilemap.get_tile(door_pos + Vector2i(1, 0)) == Enum.TileType.WALL:
			is_horizontal = true
		elif original_tilemap.get_tile(door_pos + Vector2i(0, -1)) == Enum.TileType.WALL and original_tilemap.get_tile(door_pos + Vector2i(0, 1)) == Enum.TileType.WALL:
			is_vertical = true

		if not (is_horizontal or is_vertical):
			# Invalid door, replace with floor
			original_tilemap.set_tile(door_pos, Enum.TileType.FLOOR)

	if FILL_DARKNESS:
		darkness = Array2D.new(original_tilemap.width, original_tilemap.height, 1)
		darkness._default_value = 0

		for y in range(darkness.height):
			for x in range(darkness.width):
				var tile_pos = Vector2i(x, y)
				var node = preload("res://scenes/darkness.tscn").instantiate() as Node3D
				add_child(node)
				node.position = TileMap2D.to_scene_pos(tile_pos)
				darkness_nodes[tile_pos] = node
	else:
		darkness = Array2D.new(original_tilemap.width, original_tilemap.height, 0)

	#game_state = GameState.new(map_generator.spawn_room_position)
	#game_state.name = "GameState"
	#game_state.tile_map = TileMap2D.new(0, 0, Enum.TileType.EMPTY)
	#original_tilemap.copy_to(game_state.tile_map)
	#game_state.planned_objects = map_generator.planned_objects
	#game_state.planned_items = map_generator.planned_items
	#game_state.safe_room = map_generator.spawn_room_rect
	#add_child(game_state)
	game_state = _create_game_state()
	add_child(game_state)
	set_remaining_turns(game_state.remaining_turns)

	add_message(MessageBuffer.MSG_NEW_GAME.format({ "count": game_state.remaining_keycards }))

	# Look in all directions to see the initial room
	for key in MOVE_KEYS:
		game_state.player.look_direction = MOVE_KEYS[key]
		reveal_darkness()

	debug_rects.get_children().map(func (c): c.queue_free())
	var rects = []
	#rects.append(map_generator.spawn_room_rect)
	#for door_pos in map_generator.door_positions:
	#	rects.push_back(Rect2i(door_pos, Vector2i.ONE))
	#rects.append_array(map_generator.corridor_rects)
	#rects.append_array(map_generator.premade_room_rects)
	#rects.append_array(map_generator.random_room_rects)
	for rect in rects:
		var d = debug_rect_scene.instantiate() as DebugRect
		d.set_rect(rect)
		debug_rects.add_child(d)

func _create_game_state() -> GameState:
	var state = GameState.new(map_generator.spawn_room_position)
	state.name = "GameState"
	state.tile_map = TileMap2D.new(0, 0, Enum.TileType.EMPTY)
	original_tilemap.copy_to(state.tile_map)
	state.planned_objects = map_generator.planned_objects
	state.planned_items = map_generator.planned_items
	state.safe_room = map_generator.spawn_room_rect
	state.remaining_keycards = map_generator.parameters.keycard_count
	state.remaining_turns = map_generator.turns_until_game_over
	return state
