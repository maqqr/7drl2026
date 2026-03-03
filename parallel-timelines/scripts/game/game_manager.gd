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

class ScreenShake:
	var intensity = 0.0
	var active_shake_time = 0.0
	var shake_decay = 1.0
	var shake_time = 0.0
	var shake_time_speed = 40.0
	var noise = FastNoiseLite.new()

	func shake(p_intensity: float, p_time: float) -> void:
		noise.seed = randi()
		noise.frequency = 2.0
		intensity = p_intensity
		active_shake_time = p_time
		shake_time = 0.0

@onready var message_buffer: MessageBuffer = $CanvasLayer_GUI/MessageBuffer
@onready var turns_label: RichTextLabel = $CanvasLayer_GUI/RichTextLabel_Turns
@onready var inventory_ui: InventoryUi = $CanvasLayer_GUI/Inventory
@onready var cursor: Node3D = $Cursor
@onready var aim_line: Node3D = $AimLine
var original_tilemap: TileMap2D
var map_generator: MapGenerator

var game_state: GameState = null

var parallel_timelines: Array[Timeline]

@export var camera_offset = Vector3(0.0, 7.0, 5.5)
var recorded_actions = []
var queued_action = null

var debug_rect_scene: PackedScene = preload("res://scenes/debug_rect.tscn")
var debug_rect_green_scene: PackedScene = preload("res://scenes/debug_rect_green.tscn")
var debug_rects: Node3D

var need_sight_check = false
var darkness: Array2D
var darkness_nodes: Dictionary[Vector2i, Node3D]

var need_action_finish_check = false
var game_over = false
var advance_game = false
var timewarp_queued = false

var targeting = false
var aim_line_unblocked = false
var item_throw_index = Vector2i.MAX.x
@export var green_aim_line_material: Material
@export var red_aim_line_material: Material

var screen_shake = ScreenShake.new()

var chosen_parameters: Dictionary

func _ready() -> void:
	debug_rects = Node3D.new()
	debug_rects.name = "DebugRects"
	add_child(debug_rects)

	inventory_ui.item_used.connect(_on_item_use)
	inventory_ui.item_dropped.connect(_on_item_drop)
	inventory_ui.item_thrown.connect(_on_item_throw)

	start_new_game()

func _process(delta: float) -> void:
	if not (game_state != null and game_state.is_initialized):
		return

	if timewarp_queued:
		timewarp_queued = false
		await get_tree().create_timer(3).timeout
		timewarp()
		game_over = false

	if game_state.player == null:
		return

	_update_camera(delta)

	# Update cursor
	var mouse_tile = get_mouse_tile()
	if game_state.tile_map.is_point_inside(mouse_tile):
		cursor.position = TileMap2D.to_scene_pos(mouse_tile)

	# Update aim line
	aim_line.visible = targeting
	if targeting:
		var start_tile = game_state.player.map_position
		var target_tile = mouse_tile
		if start_tile == target_tile:
			aim_line.visible = false
		else:
			aim_line.transform.origin = TileMap2D.to_scene_pos(start_tile)
			aim_line.look_at(TileMap2D.to_scene_pos(target_tile), Vector3.UP, true)
			var look_vec = TileMap2D.to_scene_pos(target_tile) - TileMap2D.to_scene_pos(start_tile)
			aim_line.scale.z = look_vec.length()
			aim_line_unblocked = game_state.can_see(game_state.player, target_tile, true)
			if not game_state.can_move_to(target_tile):
				aim_line_unblocked = false
			var aim_mesh = aim_line.get_child(0) as MeshInstance3D
			aim_mesh.set_surface_override_material(0, green_aim_line_material if aim_line_unblocked else red_aim_line_material)

	# Execute all actions
	game_state.player.execute_action(self, delta)
	for past_player in game_state.past_players:
		past_player.execute_action(self, delta)

	# Remove dead players
	var dead: Array[Character]
	for past_player in game_state.past_players:
		if past_player.health <= 0:
			dead.push_back(past_player)
	for past_player in dead:
		need_sight_check = true
		game_state.kill_character(past_player)
	if game_state.player.health <= 0 and not game_over:
		add_message(MessageBuffer.MSG_DEAD)
		game_over = true
		timewarp_queued = true

	if need_sight_check:
		game_state.update_seen_tiles()
		need_sight_check = false

	if is_input_enabled() and need_action_finish_check:
		need_action_finish_check = false
		# Trigger actions finish signal
		for obj in game_state.game_objects:
			obj.on_all_actions_finished()
		for door_pos in game_state.doors:
			game_state.doors[door_pos].on_all_actions_finished()
		# Check if any past players can see the current player
		for seen_pos in game_state.seen_tiles:
			if game_state.player.map_position == seen_pos and game_state.player.invisibility_turns <= 0:
				lose_due_to_sight()
				return
		# Check remaining turns
		if game_state.remaining_turns <= 0:
			add_message(MessageBuffer.MSG_OUT_OF_TURNS)
			game_over = true
			await get_tree().create_timer(3).timeout
			timewarp()
			game_over = false
			return

	# Cancel aim with move
	if targeting:
		for key_name in MOVE_KEYS:
			if Input.is_action_just_pressed(key_name):
				targeting = false
				break

	# Handle player movement
	if is_input_enabled():
		for key_name in MOVE_KEYS:
			if Input.is_action_pressed(key_name):
				var direction = MOVE_KEYS[key_name]
				var old_position = game_state.player.map_position
				var final_position = game_state.player.map_position + direction
				game_state.player.ongoing_action = MoveAction.new(old_position, final_position, direction)
				if game_state.player.ongoing_action.can_execute(self, game_state.player):
					recorded_actions.push_back(game_state.player.ongoing_action)
					_trigger_action_starts(game_state.player, game_state.player.ongoing_action)
					advance_game = true
				else:
					game_state.player.ongoing_action = null
					# Check if interaction can be done instead
					for game_obj in game_state.game_objects:
						if TileMap2D.to_tile_pos(game_obj.transform.origin) == final_position:
							game_state.player.ongoing_action = InteractAction.new(final_position, direction)
							recorded_actions.push_back(game_state.player.ongoing_action)
							_trigger_action_starts(game_state.player, game_state.player.ongoing_action)
							advance_game = true
							break
				break

		if Input.is_action_pressed("wait"):
			game_state.player.ongoing_action = WaitAction.new()
			recorded_actions.push_back(game_state.player.ongoing_action)
			_trigger_action_starts(game_state.player, game_state.player.ongoing_action)
			advance_game = true

		if Input.is_action_just_pressed("warp"):
			game_state.player.ongoing_action = WarpAction.new()
			recorded_actions.push_back(game_state.player.ongoing_action)

	if queued_action != null:
		game_state.player.ongoing_action = queued_action
		if game_state.player.ongoing_action.can_execute(self, game_state.player):
			recorded_actions.push_back(game_state.player.ongoing_action)
			_trigger_action_starts(game_state.player, game_state.player.ongoing_action)
			advance_game = true
		queued_action = null

	if advance_game:
		advance_game = false
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
				else:
					_trigger_action_starts(past_player, past_player.ongoing_action)

	if Input.is_action_just_pressed("debug"):
		for y in range(darkness.height):
			for x in range(darkness.width):
				var pos = Vector2i(x, y)
				if darkness.get_value(pos) == 1:
					darkness.set_value(pos, 0)
					remove_child(darkness_nodes[pos])
					darkness_nodes.erase(pos)
		for pos in map_generator.debug_path:
			var d = debug_rect_green_scene.instantiate() as DebugRect
			d.set_rect(Rect2i(pos, Vector2i.ONE))
			debug_rects.add_child(d)
		#game_state.player.pickup_item(self, preload("res://data/items/mine.tres"))

func is_input_enabled() -> bool:
	return not game_over and \
		not targeting and \
		queued_action == null and \
		game_state.player.ongoing_action == null and \
		game_state.past_players.all(func (c: Character): return c.ongoing_action == null)

func _trigger_action_starts(character: Character, action):
	for obj in game_state.game_objects:
		obj.on_action_started(character, action)
	for door_pos in game_state.doors:
		game_state.doors[door_pos].on_action_started(character, action)

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

	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == 1 or event.button_index == 2):
			if targeting:
				targeting = false
				var target_tile = get_mouse_tile()
				if event.button_index == 1 and aim_line_unblocked and game_state.player.map_position != target_tile:
					var item_type = game_state.player.items[item_throw_index]
					queued_action = ThrowItemAction.new(target_tile, item_type, item_throw_index)

	if DEV_MODE:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == 1:
				explode_at(get_mouse_tile(), 1)
			#if event.pressed:
				#var tile = Enum.TileType.WALL if event.button_index == 1 else Enum.TileType.FLOOR
				#game_state.tile_map.set_tile(get_mouse_tile(), tile)

func explode_at(pos: Vector2i, radius: int):
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tile_pos = pos + Vector2i(dx, dy)
			if tile_pos.distance_squared_to(pos) <= radius * radius:
				# Remove game objects under the explosion
				var remove_objs = []
				for game_obj in game_state.game_objects:
					if TileMap2D.to_tile_pos(game_obj.transform.origin) == tile_pos:
						remove_objs.push_back(game_obj)
				for game_obj in remove_objs:
					game_state.remove_game_object(game_obj)

				# Remove doors
				var door: Door = game_state.doors.get(tile_pos)
				if door != null:
					door.queue_free()
					game_state.doors.erase(tile_pos)

				# Convert tiles (except empty) into floors
				var tile = game_state.tile_map.get_tile(tile_pos)
				if tile != Enum.TileType.FLOOR and tile != Enum.TileType.EMPTY:
					game_state.tile_map.set_tile(tile_pos, Enum.TileType.FLOOR)
					# Remove doors with no support on both sides
					for dyy in range(-1, 2):
						for dxx in range(-1, 2):
							var extra_pos = tile_pos + Vector2i(dxx, dyy)
							var extra_door: Door = game_state.doors.get(extra_pos)
							if extra_door != null:
								extra_door.queue_free()
								game_state.doors.erase(extra_pos)
								game_state.tile_map.set_tile(extra_pos, Enum.TileType.FLOOR)

				# Create fire
				if tile_pos.distance_squared_to(pos) <= (radius - 1) * (radius - 1):
					tile = game_state.tile_map.get_tile(tile_pos)
					if tile == Enum.TileType.FLOOR:
						game_state.create_game_object_at(self, preload("res://scenes/gameobjects/fire.tscn"), tile_pos)

	var remove_players: Array[Character] = []
	for past_player in game_state.past_players:
		if past_player.map_position.distance_squared_to(pos) <= radius * radius:
			remove_players.push_back(past_player)
	for player: Character in remove_players:
		game_state.remove_character(player)
		for item in player.items:
			if item.is_keycard:
				game_state.create_item_at(item, player.map_position)

	need_sight_check = true

	var explosion_effect = preload("res://scenes/effects/explosion_effect.tscn").instantiate()
	explosion_effect.transform.origin = TileMap2D.to_scene_pos(pos)
	game_state.add_child(explosion_effect)

	# Screen shake
	var intensity = 1.2
	var distance = pos.distance_to(game_state.player.map_position)
	if distance > 12:
		intensity = max(0.1, intensity - (distance - 12) * 0.08)
	screen_shake.shake(intensity, 4.0)

	if game_state.player.map_position.distance_squared_to(pos) <= radius * radius:
		add_message(MessageBuffer.MSG_EXPLODED)
		game_over = true
		timewarp_queued = true

func reveal_darkness() -> void:
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var checked_pos = game_state.player.map_position + Vector2i(dx, dy)
			if darkness.get_value(checked_pos) == 1:
				if game_state.can_see(game_state.player, checked_pos, true):
					darkness.set_value(checked_pos, 0)
					remove_child(darkness_nodes[checked_pos])
					darkness_nodes.erase(checked_pos)

func add_message(msg: String, extra_time: float = 0.0) -> void:
	message_buffer.add_message(msg, extra_time)

func set_remaining_turns(turns: int) -> void:
	game_state.remaining_turns = turns
	turns_label.text = "Turns left: " + str(game_state.remaining_turns)

func lose_due_to_sight() -> void:
	add_message(MessageBuffer.MSG_LOSE)
	game_over = true
	await get_tree().create_timer(6).timeout
	# Reset game
	restart_game()

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

	add_message(MessageBuffer.MSG_WAKE_UP)

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
	darkness_nodes.clear()
	start_new_game()

func start_new_game() -> void:
	if map_generator:
		map_generator.queue_free()

	map_generator = MapGenerator.new()
	map_generator.name = "MapGenerator"
	add_child(map_generator)

	var parameters = {}
	parameters.merge(chosen_parameters)
	print(parameters)

	while true:
		map_generator.generate(parameters)
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
				if original_tilemap.get_tile(tile_pos) != Enum.TileType.EMPTY:
					var node = preload("res://scenes/effects/darkness.tscn").instantiate() as Node3D
					add_child(node)
					node.position = TileMap2D.to_scene_pos(tile_pos)
					darkness_nodes[tile_pos] = node
				else:
					darkness.set_value(tile_pos, 0)
	else:
		darkness = Array2D.new(original_tilemap.width, original_tilemap.height, 0)

	game_state = _create_game_state()
	add_child(game_state)
	set_remaining_turns(game_state.remaining_turns)

	add_message(MessageBuffer.MSG_NEW_GAME)

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

	await get_tree().create_timer(MessageBuffer.SHOW_MESSAGE_TIME + 1.0).timeout
	add_message(MessageBuffer.MSG_NEW_GAME2.format({ "count": game_state.remaining_keycards }))

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
	state.current_seed = map_generator.current_seed
	return state

func _update_camera(delta: float) -> void:
	if game_state.remaining_turns <= 10:
		screen_shake.intensity = 0.07
		screen_shake.active_shake_time = 1.0
		if game_state.remaining_turns <= 3:
			screen_shake.intensity = 0.1

	var shake_offset = Vector3.ZERO
	if screen_shake.active_shake_time > 0.0:
		screen_shake.shake_time += delta * screen_shake.shake_time_speed
		screen_shake.active_shake_time -= delta
		var z = screen_shake.noise.get_noise_2d(0.0, screen_shake.shake_time) * screen_shake.intensity
		shake_offset = Vector3(
			screen_shake.noise.get_noise_2d(screen_shake.shake_time, 0.0) * screen_shake.intensity,
			z,
			z,
		)
		screen_shake.intensity = max(0.0, screen_shake.intensity - screen_shake.shake_decay * delta)
	get_viewport().get_camera_3d().global_position = game_state.player.global_position + camera_offset + shake_offset

func _on_item_use(index: int) -> void:
	if not is_input_enabled():
		return
	var item_type = game_state.player.items[index]
	#game_state.player.ongoing_action = UseItemAction.new(item_type, index)
	#recorded_actions.push_back(game_state.player.ongoing_action)
	#advance_game = true
	queued_action = UseItemAction.new(item_type, index)

func _on_item_drop(index: int) -> void:
	if not is_input_enabled():
		return
	var item_type = game_state.player.items[index]
	#game_state.player.ongoing_action = DropItemAction.new(item_type, index)
	#recorded_actions.push_back(game_state.player.ongoing_action)
	#advance_game = true
	queued_action = DropItemAction.new(item_type, index)

func _on_item_throw(index: int) -> void:
	if not is_input_enabled():
		return

	add_message(MessageBuffer.MSG_THROW_SELECT_TILE)
	targeting = true
	item_throw_index = index
