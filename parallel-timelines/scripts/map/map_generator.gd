extends Node
class_name MapGenerator

static var SIZE_SMALL: Dictionary = {
	"width": 31,
	"height": 30,
	"extra_corridor_count": 2,
	"traps": 2,
}
static var SIZE_MEDIUM: Dictionary = {
	"width": 31,
	"height": 40,
	"extra_corridor_count": 4,
	"traps": 3,
}
static var SIZE_LARGE: Dictionary = {
	"width": 41,
	"height": 50,
	"extra_corridor_count": 8,
	"traps": 5,
}

static var EASY: Dictionary = {
	"time_multiplier": 1.6,
	"max_computers": 4,
	"keycard_count": 3,
}
static var NORMAL: Dictionary = {
	"time_multiplier": 1.4,
	"max_computers": 3,
	"keycard_count": 4,
}
static var HARD: Dictionary = {
	"time_multiplier": 1.2,
	"max_computers": 2,
	"keycard_count": 5,
}
static var ALMOST_IMPOSSIBLE: Dictionary = {
	"time_multiplier": 1.0,
	"max_computers": 0,
	"keycard_count": 5,
}
static var IMPOSSIBLE: Dictionary = {
	"time_multiplier": 0.8,
	"max_computers": 0,
	"keycard_count": 5,
}

enum RoomPlanTile {
	EMPTY = 0,
	WALL = 1,
	FLOOR = 2,
	DOOR = 3,
	BED = 4,
	BLOCKING_OBJECT = 5,
	SHUTTLE = 6,
	COMPUTER = 7,
	CLOSET = 8,
	CRATE = 9,
	WALL_LIGHT = 10,
}

const PLAN_TO_OBJECT: Dictionary[RoomPlanTile, PackedScene] = {
	RoomPlanTile.BED: preload("res://scenes/gameobjects/bed.tscn"),
	RoomPlanTile.SHUTTLE: preload("res://scenes/gameobjects/shuttle.tscn"),
	RoomPlanTile.COMPUTER: preload("res://scenes/gameobjects/computer.tscn"),
	RoomPlanTile.CLOSET: preload("res://scenes/gameobjects/closet.tscn"),
	RoomPlanTile.CRATE: preload("res://scenes/gameobjects/crate.tscn"),
	RoomPlanTile.WALL_LIGHT: preload("res://scenes/gameobjects/wall_light.tscn"),
}

enum RoomTheme {
	TECH,
	STORAGE,
	LIVING_ROOM,
}

func _get_random_room_theme() -> RoomTheme:
	var themes = [RoomTheme.TECH, RoomTheme.STORAGE, RoomTheme.LIVING_ROOM]
	return themes[rng.randi_range(0, themes.size() - 1)]

const KEYCARD_ITEMS: Array[ItemType] = [
	preload("res://data/items/keycards/green_keycard.tres"),
	preload("res://data/items/keycards/red_keycard.tres"),
	preload("res://data/items/keycards/cyan_keycard.tres"),
	preload("res://data/items/keycards/purple_keycard.tres"),
	preload("res://data/items/keycards/orange_keycard.tres"),
]

class PlannedObject:
	var packed_scene: PackedScene
	var tile_position: Vector2i

	func _init(p_packed_scene: PackedScene, p_tile_position: Vector2i) -> void:
		packed_scene = p_packed_scene
		tile_position = p_tile_position

class PlannedItem:
	var item_type: ItemType
	var tile_position: Vector2i

	func _init(p_item_type: ItemType, p_tile_position: Vector2i) -> void:
		item_type = p_item_type
		tile_position = p_tile_position

static func _convert_plan_tile(plan_tile: RoomPlanTile) -> Enum.TileType:
	match plan_tile:
		RoomPlanTile.EMPTY: return Enum.TileType.EMPTY
		RoomPlanTile.WALL: return Enum.TileType.WALL
		RoomPlanTile.FLOOR: return Enum.TileType.FLOOR
		RoomPlanTile.DOOR: return Enum.TileType.DOOR
		RoomPlanTile.BED: return Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT
		RoomPlanTile.BLOCKING_OBJECT: return Enum.TileType.OBJECT_BLOCKING_TRANSPARENT
		RoomPlanTile.SHUTTLE: return Enum.TileType.OBJECT_BLOCKING_TRANSPARENT
		RoomPlanTile.COMPUTER: return Enum.TileType.OBJECT_BLOCKING_TRANSPARENT
		RoomPlanTile.CLOSET: return Enum.TileType.OBJECT_NONBLOCKING_OPAQUE
		RoomPlanTile.CRATE: return Enum.TileType.OBJECT_BLOCKING_TRANSPARENT
		RoomPlanTile.WALL_LIGHT: return Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT
	assert(false) # Missing tile handling
	return Enum.TileType.FLOOR

enum Direction { LEFT, UP, RIGHT, DOWN }

const DIRECTIONS = [Direction.LEFT, Direction.UP, Direction.RIGHT, Direction.DOWN]
const DIR_VECTORS = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
const DIR_VECTORS_AROUND = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
							Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
							Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

static func _dir_enum_to_side(dir: Direction) -> Side:
	return int(dir) as Side

static func _dir_to_side(dir: Vector2i) -> Side:
	for dir_enum in DIRECTIONS:
		if dir == DIR_VECTORS[dir_enum]:
			return _dir_enum_to_side(dir_enum)
	assert(false)
	return Side.SIDE_LEFT

var task_id = null
var rng: RandomNumberGenerator
var parameters: Dictionary
signal completed

var cockpit: PremadeRoom
var main_corridor: PremadeRoom
var main_corridor_split: PremadeRoom
var main_corridor_split_item: PremadeRoom
var main_corridor_end: PremadeRoom
var main_corridor_hide: PremadeRoom
var escape_pod: PremadeRoom
var bunk_room: PremadeRoom

var tile_map: TileMap2D
var fail = false
var corridor_rects: Array[Rect2i]
var premade_room_rects: Array[Rect2i]
var random_room_rects: Array[Rect2i]
var door_positions: Array[Vector2i]
var escape_pod_position: Vector2i
var spawn_room_position: Vector2i
var spawn_room_rect: Rect2i

var planned_objects: Array[PlannedObject]
var planned_items: Array[PlannedItem]
var keycard_positions: Array[Vector2i]
var turns_until_game_over: int = 0
var placed_computers = 0

var current_seed = 0

var debug_path: Array[Vector2i]

class PremadeRoom:
	var plan_tiles: Array2D

func _init() -> void:
	rng = RandomNumberGenerator.new()
	cockpit = _read_premade_room("cockpit.tscn")
	main_corridor = _read_premade_room("main_corridor.tscn")
	main_corridor_split = _read_premade_room("main_corridor_split.tscn")
	main_corridor_split_item = _read_premade_room("main_corridor_split_item.tscn")
	main_corridor_end = _read_premade_room("main_corridor_end.tscn")
	main_corridor_hide = _read_premade_room("main_corridor_hide.tscn")
	escape_pod = _read_premade_room("escape_pod.tscn")
	bunk_room = _read_premade_room("bunk_room.tscn")

func _process(_delta: float) -> void:
	if task_id != null and WorkerThreadPool.is_task_completed(task_id):
		task_id = null
		completed.emit()

func generate(param: Dictionary) -> void:
	assert(task_id == null)
	if task_id != null:
		return

	parameters = param
	tile_map = TileMap2D.new(parameters.width, parameters.height, Enum.TileType.EMPTY)
	fail = false
	corridor_rects.clear()
	premade_room_rects.clear()
	random_room_rects.clear()
	door_positions.clear()
	planned_objects.clear()
	planned_items.clear()
	current_seed = rng.randi()
	task_id = WorkerThreadPool.add_task(_run_task, true, "MapGenerator")

func _run_task() -> void:
	@warning_ignore_start("integer_division")
	print("Map generator running...")

	var map_center_x: int = tile_map.width / 2

	# Place cockpit at top
	_place_premade_room(Vector2i(map_center_x - cockpit.plan_tiles.width / 2, 1), cockpit)

	var cursor = Vector2i(map_center_x - main_corridor.plan_tiles.width / 2, cockpit.plan_tiles.height + 1)
	while true:
		var corridor: PremadeRoom = main_corridor_end
		var enough_space = cursor.y < tile_map.height - main_corridor.plan_tiles.height * 2 - escape_pod.plan_tiles.height
		if enough_space:
			corridor = (main_corridor_split_item if rng.randf() < 0.5 else main_corridor_split) if rng.randf() < 0.7 else \
				(main_corridor if rng.randf() < 0.5 else main_corridor_hide)

		cursor.x = map_center_x - corridor.plan_tiles.width / 2
		_place_premade_room(cursor, corridor)
		cursor += Vector2i(0, corridor.plan_tiles.height)
		if not enough_space:
			break

	# Place escape pod at bottom
	_place_premade_room(Vector2i(map_center_x - escape_pod.plan_tiles.width / 2, cursor.y), escape_pod)
	escape_pod_position = Vector2i(map_center_x, cursor.y + 4)

	var corridor_positions: Array[Vector2i] = []

	# Place small horizontal corridors starting from main corridors
	var initial_door_positions = _find_tiles_by_type(Enum.TileType.DOOR).filter(func (pos): return pos.x < map_center_x)
	if initial_door_positions.is_empty():
		fail = true
		return

	for door_pos in initial_door_positions:
		for dir in DIR_VECTORS:
			if tile_map.get_tile(door_pos + dir) == Enum.TileType.EMPTY:
				cursor = door_pos + dir
				var corridor_length = rng.randi_range(10, 16)
				corridor_rects.push_back(Rect2i(cursor, Vector2i(1, 1)).grow_side(_dir_to_side(dir), corridor_length - 1))
				for i in range(corridor_length):
					tile_map.set_tile(cursor, Enum.TileType.FLOOR)
					corridor_positions.push_back(cursor)
					cursor += dir

	if corridor_positions.is_empty():
		fail = true
		return

	# Randomly place more corridors branching from existing corridors
	var placed_count = 0
	while placed_count < parameters.extra_corridor_count:
		var pos = corridor_positions[rng.randi_range(0, corridor_positions.size() - 1)]
		var dir: Vector2i = DIR_VECTORS[randi_range(0, DIR_VECTORS.size() - 1)]
		var dir_cw = Vector2i(dir.y, -dir.x)
		var dir_ccw = Vector2i(-dir.y, dir.x)
		cursor = pos + dir
		var c_rect = Rect2i(cursor, Vector2i(1, 1))
		if _is_empty_for_corridor(cursor) and _is_empty_for_corridor(cursor + dir_cw) and _is_empty_for_corridor(cursor + dir_ccw) \
				and _is_empty_for_corridor(cursor + dir) and _is_empty_for_corridor(cursor + dir + dir_cw) and _is_empty_for_corridor(cursor + dir + dir_ccw):
			placed_count += 1
			var actual_length = 0
			for ci in range(rng.randi_range(6, 16)):
				tile_map.set_tile(cursor, Enum.TileType.FLOOR)
				corridor_positions.push_back(cursor)
				actual_length += 1
				cursor += dir
				if not (_is_empty_for_corridor(cursor) and _is_empty_for_corridor(cursor + dir_cw) and _is_empty_for_corridor(cursor + dir_ccw)
						and _is_empty_for_corridor(cursor + dir) and _is_empty_for_corridor(cursor + dir + dir_cw) and _is_empty_for_corridor(cursor + dir + dir_ccw)):
					break
			assert(actual_length >= 1)
			if actual_length >= 2:
				c_rect = c_rect.grow_side(_dir_to_side(dir), actual_length - 1)
			corridor_rects.push_back(c_rect)

	# Place spawn room
	var bunk_result = _find_position_for_premade_room(bunk_room)
	if bunk_result[&"success"]:
		_place_premade_room(bunk_result[&"position"], bunk_room)
	else:
		fail = true
		return
	spawn_room_rect = Rect2i(bunk_result[&"position"], Vector2i(bunk_room.plan_tiles.width, bunk_room.plan_tiles.height))
	spawn_room_position = bunk_result[&"position"] + Vector2i(bunk_room.plan_tiles.width / 2, bunk_room.plan_tiles.height / 2)
	# Randomly choose the mirrored room
	if rng.randf() < 0.5:
		spawn_room_rect = _mirror_rect(spawn_room_rect)
		spawn_room_position.x = tile_map.width - 1 - spawn_room_position.x

	# Fill the rest of the map with random rooms
	var consecutive_fails = 0
	var placed_room_count = 0
	while placed_room_count < 20 && consecutive_fails < 200:
		var pos = corridor_positions[randi_range(0, corridor_positions.size() - 1)] + DIR_VECTORS[randi_range(0, DIR_VECTORS.size() - 1)]
		var potential_room = Rect2i(pos, Vector2i(1, 1))
		if not _rect_intersects(potential_room):
			# Expand room in all directions
			for dir_enum in DIRECTIONS:
				while true:
					var too_wide = (dir_enum == Direction.LEFT or dir_enum == Direction.RIGHT) and potential_room.size.x >= 8
					var too_tall = (dir_enum == Direction.UP or dir_enum == Direction.DOWN) and potential_room.size.y >= 8
					if too_wide or too_tall:
						break

					var new_rect = potential_room.grow_side(_dir_enum_to_side(dir_enum), 1)
					if not _rect_intersects(new_rect):
						potential_room = new_rect
					else:
						break

		if potential_room.size.x >= 3 and potential_room.size.y >= 3:
			_make_room(potential_room)
			random_room_rects.push_back(potential_room.grow(-1))
			placed_room_count += 1
			consecutive_fails = 0
		else:
			consecutive_fails += 1

	_cover_floors()
	_make_doors_for_rooms()
	_cover_floors()
	_mirror_map()
	
	for random_room in random_room_rects:
		_decorate_random_room(random_room, _get_random_room_theme())
	
	_make_keycards()
	_calculate_allowed_turns()

	if turns_until_game_over < 15:
		# Something went wrong
		fail = true
		return

	# Place traps
	var potential_trap_positions = _find_tiles_by_type(Enum.TileType.FLOOR)
	for i in range(parameters.traps):
		var index = rng.randi_range(0, potential_trap_positions.size() - 1)
		var tile_pos = potential_trap_positions[index]
		potential_trap_positions.remove_at(index)
		planned_objects.push_back(PlannedObject.new(preload("res://scenes/gameobjects/explosion_trap.tscn"), tile_pos))

	door_positions = _find_tiles_by_type(Enum.TileType.DOOR)
	@warning_ignore_restore("integer_division")

# Returns { "success": bool, "position": Vector2i }
func _find_position_for_premade_room(room: PremadeRoom) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = { &"success": false, &"position": Vector2i.ZERO }
	@warning_ignore("integer_division")
	var potential_rect = Rect2i(
		Vector2i(tile_map.width / 2, rng.randi_range(5, tile_map.height - room.plan_tiles.height)),
		Vector2i(room.plan_tiles.width, room.plan_tiles.height))
	var attempts = 0
	while _rect_intersects(potential_rect):
		# Slide the room left until it fits
		potential_rect.position.x -= 1
		if potential_rect.position.x < 0:
			# Try another position
			@warning_ignore("integer_division")
			potential_rect.position = Vector2i(tile_map.width / 2, rng.randi_range(5, tile_map.height - room.plan_tiles.height))
		attempts += 1
		if attempts > 150:
			return result

	result[&"success"] = true
	result[&"position"] = potential_rect.position
	return result

func _make_room(room: Rect2i) -> void:
	for y in range(room.size.y):
		for x in range(room.size.x):
			var tile = Enum.TileType.WALL if y == 0 || x == 0 || y == room.size.y - 1 || x == room.size.x - 1 else Enum.TileType.FLOOR
			tile_map.set_tile(Vector2i(room.position.x + x, room.position.y + y), tile)

func _place_premade_room(pos: Vector2i, room: PremadeRoom) -> void:
	_place_plan_tiles(pos, room.plan_tiles)
	premade_room_rects.push_back(Rect2i(pos, Vector2i(room.plan_tiles.width, room.plan_tiles.height)))

func _place_plan_tiles(pos: Vector2i, plan_tiles: Array2D):
	for y in range(plan_tiles.height):
		for x in range(plan_tiles.width):
			var plan_tile = plan_tiles.get_value(Vector2i(x, y))
			var tile_pos = pos + Vector2i(x, y)
			tile_map.set_tile(tile_pos, _convert_plan_tile(plan_tile))
			var packed_scene: PackedScene = PLAN_TO_OBJECT.get(plan_tile)
			if packed_scene != null:
				planned_objects.push_back(PlannedObject.new(packed_scene, tile_pos))

func _read_premade_room(path: StringName) -> PremadeRoom:
	var packed_scene = load("res://data/rooms/" + path)
	var room_object = packed_scene.instantiate() as Node2D
	var tilemap_layer = room_object.get_child(0) as TileMapLayer
	var used_rect = tilemap_layer.get_used_rect()
	var array = Array2D.new(used_rect.size.x, used_rect.size.y, 0)
	for y in range(used_rect.size.y):
		for x in range(used_rect.size.x):
			var tile_data = tilemap_layer.get_cell_tile_data(Vector2i(used_rect.position.x + x, used_rect.position.y + y))
			if tile_data != null:
				var tile_type = tile_data.get_custom_data("type_enum")
				assert(tile_type is int)
				array.set_value(Vector2i(x, y), tile_type)
	var room = PremadeRoom.new()
	room.plan_tiles = array
	return room

func _make_keycards() -> void:
	var astar = _make_normal_astar()

	var potential_rooms: Array[Rect2i] = []
	potential_rooms.append_array(random_room_rects)
	while keycard_positions.size() < parameters.keycard_count and not potential_rooms.is_empty():
		var index = rng.randi_range(0, potential_rooms.size() - 1)
		var room = potential_rooms[index]
		var floors: Array[Vector2i] = []
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				var pos = Vector2i(x, y)
				if tile_map.get_tile(pos) == Enum.TileType.FLOOR:
					floors.push_back(pos)

		while not floors.is_empty():
			var floor_index = rng.randi_range(0, floors.size() - 1)
			var path = astar.get_id_path(floors[floor_index], escape_pod_position)
			if not path.is_empty():
				keycard_positions.push_back(floors[floor_index])
				break
			else:
				floors.remove_at(floor_index)

		potential_rooms.remove_at(index)

	# Just find any random floor if needed
	if keycard_positions.size() < parameters.keycard_count:
		var attempts = 0
		var floor_positions = _find_tiles_by_type(Enum.TileType.FLOOR)
		while keycard_positions.size() < parameters.keycard_count or attempts > 100:
			attempts += 1
			var pos = floor_positions[rng.randi_range(0, floor_positions.size() - 1)]
			var path = astar.get_id_path(pos, escape_pod_position)
			if not path.is_empty():
				keycard_positions.push_back(pos)

	assert(keycard_positions.size() == parameters.keycard_count)
	assert(KEYCARD_ITEMS.size() >= keycard_positions.size())
	for i in range(keycard_positions.size()):
		planned_items.push_back(PlannedItem.new(KEYCARD_ITEMS[i], keycard_positions[i]))

func _find_tiles_by_type(tile_type: Enum.TileType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(tile_map.height):
		for x in range(tile_map.width):
			var pos = Vector2i(x, y)
			if tile_map.get_tile(pos) == tile_type:
				result.push_back(pos)
	return result

func _is_empty_for_corridor(pos: Vector2i) -> bool:
	# Too left
	if pos.x <= 1:
		return false
	# Too high
	if pos.y < cockpit.plan_tiles.height + 2:
		return false
	if tile_map.is_point_inside(pos):
		return tile_map.get_tile(pos) == Enum.TileType.EMPTY
	return false

func _rect_intersects(rect: Rect2i) -> bool:
	if rect.position.x < 0 || rect.position.y < 0 || rect.position.x + rect.size.x >= tile_map.width || rect.position.y + rect.size.y >= tile_map.height:
		return true
	return corridor_rects.any(func (r: Rect2i): return r.intersects(rect)) or \
		premade_room_rects.any(func (r: Rect2i): return r.intersects(rect)) or \
		random_room_rects.any(func (r: Rect2i): return r.intersects(rect))

func _cover_floors() -> void:
	for y in range(0, tile_map.height):
		@warning_ignore("integer_division")
		for x in range(0, tile_map.width / 2):
			var pos = Vector2i(x, y)
			if tile_map.get_tile(pos) == Enum.TileType.FLOOR:
				for delta in DIR_VECTORS_AROUND:
					var empty_pos = pos + delta
					if tile_map.get_tile(empty_pos) == Enum.TileType.EMPTY:
						tile_map.set_tile(empty_pos, Enum.TileType.WALL)
						if x == 0 or y == 0 or y == tile_map.height - 1:
							tile_map.set_tile(pos, Enum.TileType.WALL)

func _make_doors_for_rooms() -> void:
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, tile_map.width, tile_map.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in range(0, tile_map.height):
		for x in range(0, tile_map.width):
			var pos = Vector2i(x, y)
			if tile_map.get_tile(pos) == Enum.TileType.EMPTY:
				astar.set_point_solid(pos, true)
			elif tile_map.get_tile(pos) == Enum.TileType.WALL:
				astar.set_point_weight_scale(pos, 30.0)

	var room_centers = []
	for room_rect in random_room_rects:
		room_centers.push_back(room_rect.get_center())

	for room_rect in premade_room_rects:
		room_centers.push_back(room_rect.get_center())

	# Make sure there is a way from every room to escape pod
	for room_center in room_centers:
		var end = escape_pod_position
		var path: Array[Vector2i] = astar.get_id_path(room_center, end)
		for pos in path:
			# Make a door at every wall on the path
			if tile_map.get_tile(pos) == Enum.TileType.WALL:
				# Must not have existing door next to it already
				var found_existing_door = false
				for delta in DIR_VECTORS_AROUND:
					if tile_map.get_tile(pos + delta) == Enum.TileType.DOOR:
						found_existing_door = true
						break

				var tile = Enum.TileType.DOOR if not found_existing_door else Enum.TileType.FLOOR
				tile_map.set_tile(pos, tile)

func _mirror_rect(r: Rect2i) -> Rect2i:
	return Rect2i(Vector2i(tile_map.width - r.position.x - r.size.x, r.position.y), r.size)

func _mirror_map() -> void:
	# Mirror tiles
	for y in range(0, tile_map.height):
		@warning_ignore("integer_division")
		for x in range(0, tile_map.width / 2):
			var tile = tile_map.get_tile(Vector2i(x, y))
			tile_map.set_tile(Vector2i(tile_map.width - 1 - x, y), tile)

	# Mirror objects
	var new_objs = []
	for obj in planned_objects:
		# Do not mirror objects in the center
		@warning_ignore("integer_division")
		if obj.tile_position.x == tile_map.width / 2:
			continue

		var mirrored_pos = Vector2i(tile_map.width - 1 - obj.tile_position.x, obj.tile_position.y)
		new_objs.push_back(PlannedObject.new(obj.packed_scene, mirrored_pos))
	planned_objects.append_array(new_objs)

	# Mirror room rects
	var new_rects = []
	for rect in random_room_rects:
		new_rects.push_back(_mirror_rect(rect))
	random_room_rects.append_array(new_rects)
	new_rects.clear()
	for rect in premade_room_rects:
		new_rects.push_back(_mirror_rect(rect))
	premade_room_rects.append_array(new_rects)

func _calculate_allowed_turns() -> void:
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, tile_map.width, tile_map.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in range(0, tile_map.height):
		for x in range(0, tile_map.width):
			var pos = Vector2i(x, y)
			match tile_map.get_tile(pos):
				Enum.TileType.EMPTY: astar.set_point_solid(pos, true)
				Enum.TileType.WALL: astar.set_point_solid(pos, true)
				Enum.TileType.OBJECT_BLOCKING_OPAQUE: astar.set_point_solid(pos, true)
				Enum.TileType.OBJECT_BLOCKING_TRANSPARENT: astar.set_point_solid(pos, true)

	assert(not keycard_positions.is_empty())
	var most_turns = 0
	for keycard_pos in keycard_positions:
		var path_to_keycard: Array[Vector2i] = astar.get_id_path(spawn_room_position, keycard_pos)
		var path_to_shuttle: Array[Vector2i] = astar.get_id_path(keycard_pos, escape_pod_position)
		var turns_to_key = path_to_keycard.size() + path_to_shuttle.size()
		if turns_to_key > most_turns:
			most_turns = turns_to_key
			debug_path.clear()
			debug_path.append_array(path_to_keycard)
			debug_path.append_array(path_to_shuttle)

	turns_until_game_over = floor(10 + most_turns * parameters.time_multiplier)

# Assumes room includes just the floors, not surrounding walls
# { "success": bool, "position": Vector2i, "free_position": Vector2i }
func _find_free_pos_next_to_wall(room: Rect2i) -> Dictionary:
	var attempts_left = 40
	while attempts_left > 0:
		attempts_left -= 1
		var potential_pos = null
		var free_pos: Vector2i
		if rng.randf() < 0.5:
			# Check top or bottom wall
			var pos = Vector2i(
				rng.randi_range(room.position.x, room.position.x + room.size.x - 1),
				room.position.y if rng.randf() < 0.5 else room.position.y + room.size.y - 1)
			if tile_map.get_tile(pos) == Enum.TileType.FLOOR:
				# Wall on top
				if tile_map.get_tile(pos + Vector2i(0, -1)) == Enum.TileType.WALL and tile_map.get_tile(pos + Vector2i(0, 1)) == Enum.TileType.FLOOR:
					potential_pos = pos
					free_pos = pos + Vector2i(0, 1)
				# Wall on bottom
				if tile_map.get_tile(pos + Vector2i(0, 1)) == Enum.TileType.WALL and tile_map.get_tile(pos + Vector2i(0, -1)) == Enum.TileType.FLOOR:
					potential_pos = pos
					free_pos = pos + Vector2i(0, -1)
		else:
			# Check left or right wall
			var pos = Vector2i(
				room.position.x if rng.randf() < 0.5 else room.position.x + room.size.x - 1,
				rng.randi_range(room.position.y, room.position.y + room.size.y - 1))
			if tile_map.get_tile(pos) == Enum.TileType.FLOOR:
				# Wall on left
				if tile_map.get_tile(pos + Vector2i(-1, 0)) == Enum.TileType.WALL and tile_map.get_tile(pos + Vector2i(1, 0)) == Enum.TileType.FLOOR:
					potential_pos = pos
					free_pos = pos + Vector2i(1, 0)
				# Wall on right
				if tile_map.get_tile(pos + Vector2i(1, 0)) == Enum.TileType.WALL and tile_map.get_tile(pos + Vector2i(-1, 0)) == Enum.TileType.FLOOR:
					potential_pos = pos
					free_pos = pos + Vector2i(-1, 0)
		if potential_pos != null:
			# Must not have doors near to allow moving into room
			for dir in DIR_VECTORS_AROUND:
				if tile_map.get_tile(potential_pos + dir) == Enum.TileType.DOOR:
					potential_pos = null
					break

			if potential_pos != null:
				return { "success": true, "position": potential_pos, "free_position": free_pos }

	return { "success": false }

# Pathfinding suitable for characters
func _make_normal_astar() -> AStarGrid2D:
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, tile_map.width, tile_map.height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in range(0, tile_map.height):
		for x in range(0, tile_map.width):
			var pos = Vector2i(x, y)
			match tile_map.get_tile(pos):
				Enum.TileType.EMPTY: astar.set_point_solid(pos, true)
				Enum.TileType.WALL: astar.set_point_solid(pos, true)
				Enum.TileType.OBJECT_BLOCKING_OPAQUE: astar.set_point_solid(pos, true)
				Enum.TileType.OBJECT_BLOCKING_TRANSPARENT: astar.set_point_solid(pos, true)
	return astar

func _can_find_path_to_escape_pod(room: Rect2i, extra_wall: Vector2i):
	var astar = _make_normal_astar()
	#var astar = AStarGrid2D.new()
	#astar.region = Rect2i(0, 0, tile_map.width, tile_map.height)
	#astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	#astar.update()
	#for y in range(0, tile_map.height):
		#for x in range(0, tile_map.width):
			#var pos = Vector2i(x, y)
			#match tile_map.get_tile(pos):
				#Enum.TileType.EMPTY: astar.set_point_solid(pos, true)
				#Enum.TileType.WALL: astar.set_point_solid(pos, true)
				#Enum.TileType.OBJECT_BLOCKING_OPAQUE: astar.set_point_solid(pos, true)
				#Enum.TileType.OBJECT_BLOCKING_TRANSPARENT: astar.set_point_solid(pos, true)

	astar.set_point_solid(extra_wall, true)
	for y in range(room.position.y, room.position.y + room.size.y - 1):
		for x in range(room.position.x, room.position.x + room.size.x - 1):
			var path: Array[Vector2i] = astar.get_id_path(Vector2i(x, y), escape_pod_position)
			if path.is_empty():
				return false
	return true

func _is_rect_floor(rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if tile_map.get_tile(Vector2i(x, y)) != Enum.TileType.FLOOR:
				return false
	return true

func _decorate_random_room(room: Rect2i, theme: RoomTheme) -> void:
	var computer = preload("res://scenes/gameobjects/computer.tscn")
	var used_computer = preload("res://scenes/gameobjects/used_computer.tscn")
	var crate = preload("res://scenes/gameobjects/crate.tscn")
	var crate_open = preload("res://scenes/gameobjects/crate_open.tscn")
	var closet = preload("res://scenes/gameobjects/closet.tscn")
	var table = preload("res://scenes/gameobjects/table.tscn")
	var chair_left = preload("res://scenes/gameobjects/chair_left.tscn")
	var chair_right = preload("res://scenes/gameobjects/chair_right.tscn")
	var wall_light = preload("res://scenes/gameobjects/wall_light.tscn")
	match theme:
		RoomTheme.TECH:
			for i in range(max(room.size.x, room.size.y)):
				var result = _find_free_pos_next_to_wall(room)
				if result.success and _can_find_path_to_escape_pod(room, result.position):
					var obj = computer if randf() < 0.3 else used_computer
					if placed_computers >= parameters.max_computers:
						obj = used_computer

					var pos = result.position
					tile_map.set_tile(pos, Enum.TileType.OBJECT_BLOCKING_TRANSPARENT)
					planned_objects.push_back(PlannedObject.new(obj, pos))
					if obj == computer:
						placed_computers += 1

		RoomTheme.STORAGE:
			for i in range(max(room.size.x, room.size.y)):
				var result = _find_free_pos_next_to_wall(room)
				if result.success and _can_find_path_to_escape_pod(room, result.position):
					var pos = result.position
					var obj = crate if rng.randf() < 0.5 else crate_open
					tile_map.set_tile(pos, Enum.TileType.OBJECT_BLOCKING_TRANSPARENT)
					planned_objects.push_back(PlannedObject.new(obj, pos))

		RoomTheme.LIVING_ROOM:
			var attempts = 0
			while attempts < 100:
				attempts += 1
				var pos = Vector2i(rng.randi_range(room.position.x, room.position.x + room.size.x - 3),
									rng.randi_range(room.position.y, room.position.y + room.size.y - 3))
				if _is_rect_floor(Rect2i(pos, Vector2i(3, 3))):
					tile_map.set_tile(pos + Vector2i(1, 1), Enum.TileType.OBJECT_BLOCKING_TRANSPARENT)
					planned_objects.push_back(PlannedObject.new(table, pos + Vector2i(1, 1)))
					tile_map.set_tile(pos + Vector2i(0, 1), Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT)
					planned_objects.push_back(PlannedObject.new(chair_right, pos + Vector2i(0, 1)))
					tile_map.set_tile(pos + Vector2i(2, 1), Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT)
					planned_objects.push_back(PlannedObject.new(chair_left, pos + Vector2i(2, 1)))

	# Place a closet randomly regardless of theme
	if rng.randf() < 0.3:
		var result = _find_free_pos_next_to_wall(room)
		if result.success:
			var pos = result.position
			tile_map.set_tile(pos, Enum.TileType.OBJECT_NONBLOCKING_OPAQUE)
			planned_objects.push_back(PlannedObject.new(closet, pos))

	# Try to place a light
	var light_result = _find_free_pos_next_to_wall(room)
	if light_result.success:
		var pos = light_result.position
		tile_map.set_tile(pos, Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT)
		planned_objects.push_back(PlannedObject.new(wall_light, pos))
