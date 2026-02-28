extends Node
class_name MapGenerator

enum RoomPlanTile {
	EMPTY = 0,
	WALL = 1,
	FLOOR = 2,
	DOOR = 3,
}

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
signal completed

var cockpit: PremadeRoom
var main_corridor: PremadeRoom
var main_corridor_split: PremadeRoom
var main_corridor_end: PremadeRoom
var escape_pod: PremadeRoom

var tile_map: TileMap2D
var fail = false
var corridor_rects: Array[Rect2i]
var premade_room_rects: Array[Rect2i]
var random_room_rects: Array[Rect2i]
var door_positions: Array[Vector2i]
var escape_pod_position: Vector2i

class PremadeRoom:
	var plan_tiles: Array2D

func _init() -> void:
	rng = RandomNumberGenerator.new()
	cockpit = _read_premade_room("cockpit.tscn")
	main_corridor = _read_premade_room("main_corridor.tscn")
	main_corridor_split = _read_premade_room("main_corridor_split.tscn")
	main_corridor_end = _read_premade_room("main_corridor_end.tscn")
	escape_pod = _read_premade_room("escape_pod.tscn")

func _process(_delta: float) -> void:
	if task_id != null and WorkerThreadPool.is_task_completed(task_id):
		completed.emit()
		task_id = null

func generate(width: int, height: int) -> void:
	assert(task_id == null)
	if task_id != null:
		return

	tile_map = TileMap2D.new(width, height, Enum.TileType.EMPTY)
	fail = false
	corridor_rects.clear()
	premade_room_rects.clear()
	random_room_rects.clear()
	door_positions.clear()
	task_id = WorkerThreadPool.add_task(_run_task, true, "MapGenerator")

func _run_task() -> void:
	@warning_ignore_start("integer_division")
	print("Map generator running...")

	var map_center_x: int = tile_map.width / 2

	# Place cockpit at top
	_place_premade_room(Vector2i(map_center_x - cockpit.plan_tiles.width / 2, 1), cockpit)

	var cursor = Vector2i(map_center_x - main_corridor.plan_tiles.width / 2, cockpit.plan_tiles.height + 1)
	while true:
		var corridor = main_corridor_end
		var enough_space = cursor.y < tile_map.height - main_corridor.plan_tiles.height * 2 - escape_pod.plan_tiles.height
		if enough_space:
			corridor = main_corridor_split if randf() < 0.7 else main_corridor
		_place_premade_room(cursor, corridor)
		cursor += Vector2i(0, corridor.plan_tiles.height)
		if not enough_space:
			break

	# Place escape pod at bottom
	_place_premade_room(Vector2i(map_center_x - escape_pod.plan_tiles.width / 2, cursor.y), escape_pod)
	escape_pod_position = Vector2i(map_center_x, cursor.y)

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
	while placed_count < 10:
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

	# Place randomly sized rooms
	var consecutive_fails = 0
	var placed_room_count = 0
	while placed_room_count < 20 && consecutive_fails < 200:
		var pos = corridor_positions[randi_range(0, corridor_positions.size() - 1)] + DIR_VECTORS[randi_range(0, DIR_VECTORS.size() - 1)]
		var potential_room = Rect2i(pos, Vector2i(1, 1))
		if not _rect_intersects(potential_room):
			# Expand room in all directions
			for dir_enum in DIRECTIONS:
				while true:
					var too_wide = (dir_enum == Direction.LEFT or dir_enum == Direction.RIGHT) and potential_room.size.x >= 10
					var too_tall = (dir_enum == Direction.UP or dir_enum == Direction.DOWN) and potential_room.size.y >= 10
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
	_mirror_map()

	door_positions = _find_tiles_by_type(Enum.TileType.DOOR)
	@warning_ignore_restore("integer_division")

func _place_premade_room(pos: Vector2i, room: PremadeRoom) -> void:
	_place_tiles(pos, room.plan_tiles)
	premade_room_rects.push_back(Rect2i(pos, Vector2i(room.plan_tiles.width, room.plan_tiles.height)))

func _make_room(room: Rect2i) -> void:
	for y in range(room.size.y):
		for x in range(room.size.x):
			var tile = Enum.TileType.WALL if y == 0 || x == 0 || y == room.size.y - 1 || x == room.size.x - 1 else Enum.TileType.FLOOR
			tile_map.set_tile(Vector2i(room.position.x + x, room.position.y + y), tile)

func _convert_plan_tile(plan_tile: RoomPlanTile) -> Enum.TileType:
	match plan_tile:
		RoomPlanTile.EMPTY: return Enum.TileType.EMPTY
		RoomPlanTile.WALL: return Enum.TileType.WALL
		RoomPlanTile.DOOR: return Enum.TileType.DOOR
	return Enum.TileType.FLOOR

func _place_tiles(pos: Vector2i, tiles: Array2D):
	for y in range(tiles.height):
		for x in range(tiles.width):
			tile_map.set_tile(pos + Vector2i(x, y), _convert_plan_tile(tiles.get_value(Vector2i(x, y))))

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

func _find_tiles_by_type(tile_type: Enum.TileType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(tile_map.height):
		for x in range(tile_map.width):
			var pos = Vector2i(x, y)
			if tile_map.get_tile(pos) == tile_type:
				result.push_back(pos)
	return result

func _is_empty_for_corridor(pos: Vector2i) -> bool:
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
			#if tile_map.get_tile(pos) == Enum.TileType.FLOOR:
				#for dx in range(-1, 2):
					#for dy in range(-1, 2):
						#var empty_pos = pos + Vector2i(dx, dy)
						#if tile_map.get_tile(empty_pos) == Enum.TileType.EMPTY:
							#tile_map.set_tile(empty_pos, Enum.TileType.WALL)

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

	# Make sure there is a way from every room to escape pod
	for room_rect in random_room_rects:
		var start = room_rect.get_center()
		var end = escape_pod_position
		var path: Array[Vector2i] = astar.get_id_path(start, end)
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

func _mirror_map() -> void:
	for y in range(0, tile_map.height):
		@warning_ignore("integer_division")
		for x in range(0, tile_map.width / 2):
			var tile = tile_map.get_tile(Vector2i(x, y))
			tile_map.set_tile(Vector2i(tile_map.width - 1 - x, y), tile)
