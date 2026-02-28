class_name CornerMatch
extends Resource

enum TileType {
	ANY,
	WALL,
	FLOOR,
	COUNT,
}

enum AllowedRotations {
	NONE,
	ROTATE90,
	ROTATE180,
}

@export var matching_tiles: PackedByteArray
@export var allowed_rotations: AllowedRotations
@export var mesh: Mesh
var rotation_90_count = 0
var dummy : int

func get_rotated_90() -> CornerMatch:
	assert(matching_tiles.size() == 9)
	var result: CornerMatch = duplicate()
	result.rotation_90_count = rotation_90_count + 1 # Only exported vars are duplicated
	result.matching_tiles = PackedByteArray()
	result.matching_tiles.resize(9)
	for y in range(3):
		for x in range(3):
			var old_index := (2 - x) * 3 + y
			var new_index := y * 3 + x
			result.matching_tiles[new_index] = matching_tiles[old_index]

	return result

func get_tile(pos: Vector2i) -> TileType:
	return matching_tiles[pos.y * 3 + pos.x] as TileType

func _tile_matches(subgrid_value: int, match_tile: TileType) -> bool:
	if match_tile == TileType.ANY:
		return true
	if match_tile == TileType.WALL and subgrid_value == 1:
		return true
	if match_tile == TileType.FLOOR and subgrid_value != 1:
		return true
	return false

func matches(wall_subgrid: Array2D, center_pos: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var subgrid_position = center_pos + Vector2i(dx, dy)
			var match_position = Vector2i(dx + 1, dy + 1)
			if not _tile_matches(wall_subgrid.get_value(subgrid_position), get_tile(match_position)):
				return false
	return true

static func load_all() -> Array[CornerMatch]:
	var corner_matches: Array[CornerMatch] = []
	var paths = _get_all_file_paths("res://data/corner_match")
	for path in paths:
		corner_matches.append(load(path))

	# Config validation
	for corner_match in corner_matches:
		assert(corner_match.mesh)
		assert(corner_match.matching_tiles.size() == 9)

	return corner_matches

static func _get_all_file_paths(path: String) -> Array[String]:
	var file_paths: Array[String] = []
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if dir.current_is_dir():
			file_paths += _get_all_file_paths(file_path)
		else:
			file_paths.append(file_path)
		file_name = dir.get_next()
	return file_paths
