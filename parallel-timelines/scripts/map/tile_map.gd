class_name TileMap2D
extends RefCounted

var width : int
var height : int
var _data: PackedByteArray

signal tile_changed(pos: Vector2i, old_tile: Enum.TileType, new_tile: Enum.TileType)

static func from_string(lines: Array[String]) -> TileMap2D:
	var tilemap = TileMap2D.new(lines[0].length(), lines.size(), Enum.TileType.EMPTY)
	var pos = Vector2i(0, 0)
	for line: String in lines:
		for c in line:
			match c:
				"#": tilemap.set_tile(pos, Enum.TileType.WALL)
				".": tilemap.set_tile(pos, Enum.TileType.FLOOR)
			pos.x += 1
		pos.x = 0
		pos.y += 1
	return tilemap

static func to_tile_pos(pos: Vector3) -> Vector2i:
	return Vector2i(round(pos.x), round(pos.z))

static func to_scene_pos(tile_pos: Vector2i) -> Vector3:
	return Vector3(tile_pos.x, 0.0, tile_pos.y)

func _init(width_param: int, height_param: int, initial_value: Enum.TileType):
	width = width_param
	height = height_param
	_data.resize(width * height)
	_data.fill(initial_value)

func is_point_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 && pos.y >= 0 && pos.x < width && pos.y < height

func get_tile(pos: Vector2i) -> Enum.TileType:
	if is_point_inside(pos):
		return _data[pos.y * width + pos.x] as Enum.TileType
	return Enum.TileType.EMPTY

func set_tile(pos: Vector2i, value: Enum.TileType) -> void:
	if !is_point_inside(pos):
		return
	var old_tile = get_tile(pos)
	_data[pos.y * width + pos.x] = value
	tile_changed.emit(pos, old_tile, value)

func rotate_cw() -> void:
	var new_data: PackedByteArray
	new_data.resize(width * height)
	var new_width = height

	for y in range(height):
		for x in range(width):
			var new_x = height - 1 - y
			var new_y = x
			var new_index = new_y * new_width + new_x
			var old_index = y * width + x
			new_data[new_index] = _data[old_index]

	# Swap width and height
	var temp_width = width
	width = height
	height = temp_width

	_data = new_data

func rotate_ccw() -> void:
	var new_data: PackedByteArray
	new_data.resize(width * height)
	var new_width = height

	for y in range(height):
		for x in range(width):
			var new_x = y
			var new_y = width - 1 - x
			var new_index = new_y * new_width + new_x
			var old_index = y * width + x
			new_data[new_index] = _data[old_index]

	# Swap width and height
	var temp_width = width
	width = height
	height = temp_width

	_data = new_data
