extends Node
class_name GameState

const LOS_ANGLE = deg_to_rad(45.0)
const LOS_PERMISSIVE_ANGLE = deg_to_rad(95.0)
const LOS_RADIUS = 6

var tile_map: TileMap2D
var tile_map_renderer: TileMapRenderer

var planned_objects: Array[MapGenerator.PlannedObject]
var planned_items: Array[MapGenerator.PlannedItem]

var player_spawn_position: Vector2i
var player: Character
var past_players: Array[Character]

var doors: Dictionary[Vector2i, Door]
var door_scene: PackedScene = preload("res://scenes/gameobjects/door.tscn")

var items: Array[ItemOnGround]
var game_objects: Array[GameObject]

var seen_tiles: Dictionary[Vector2i, bool]
var see_markers: Array[Node3D]
var safe_room: Rect2i

var remaining_keycards = 0
var remaining_turns = 0

var is_initialized = false

signal initialized

func _init(p_player_spawn_position: Vector2i) -> void:
	player_spawn_position = p_player_spawn_position
	tile_map_renderer = TileMapRenderer.new()
	tile_map_renderer.name = "TileMapRenderer"
	add_child(tile_map_renderer)

func _ready() -> void:
	assert(tile_map and tile_map_renderer)
	tile_map_renderer.set_tile_map(tile_map)

	var game_manager = get_parent()
	assert(game_manager != null and game_manager is GameManager)

	player = create_character_at(player_spawn_position)
	player.inventory_changed.connect(game_manager.inventory_ui.update)
	game_manager.inventory_ui.update(player)

	# Create door objects
	for y in range(tile_map.height):
		for x in range(tile_map.width):
			var door_pos = Vector2i(x, y)
			if tile_map.get_tile(door_pos) == Enum.TileType.DOOR:
				var is_horizontal = false
				var is_vertical = false
				if tile_map.get_tile(door_pos + Vector2i(-1, 0)) == Enum.TileType.WALL and tile_map.get_tile(door_pos + Vector2i(1, 0)) == Enum.TileType.WALL:
					is_horizontal = true
				elif tile_map.get_tile(door_pos + Vector2i(0, -1)) == Enum.TileType.WALL and tile_map.get_tile(door_pos + Vector2i(0, 1)) == Enum.TileType.WALL:
					is_vertical = true

				if is_horizontal or is_vertical:
					doors[door_pos] = door_scene.instantiate()
					doors[door_pos].transform.origin = TileMap2D.to_scene_pos(door_pos)
					doors[door_pos].set_game_manager(game_manager)
					add_child(doors[door_pos])
					if is_vertical:
						doors[door_pos].rotate(Vector3i(0, 1, 0), PI * 0.5)

	# Create other objects
	for planned_obj in planned_objects:
		var obj = planned_obj.packed_scene.instantiate() as Node3D
		obj.transform.origin = TileMap2D.to_scene_pos(planned_obj.tile_position)
		add_child(obj)
		if obj is GameObject:
			obj.set_game_manager(game_manager)
			game_objects.push_back(obj)

	# Create items
	for planned_item in planned_items:
		create_item_at(planned_item.item_type, planned_item.tile_position)

	is_initialized = true
	initialized.emit()

func create_character_at(pos: Vector2i) -> Character:
	var character = preload("res://scenes/gameobjects/player.tscn").instantiate() as Character
	character.spawn_position = pos
	add_child(character)
	character.teleport_to(pos)
	return character

func remove_character(character: Character):
	if player == character:
		player = null

	past_players.erase(character)
	remove_child(character)

func create_item_at(item_type: ItemType, pos: Vector2i) -> ItemOnGround:
	var item_on_ground = ItemOnGround.new()
	item_on_ground.item = item_type
	item_on_ground.map_position = pos
	items.push_back(item_on_ground)
	add_child(item_on_ground)
	return item_on_ground

func remove_item(item_on_ground: ItemOnGround):
	items.erase(item_on_ground)
	remove_child(item_on_ground)

func can_see(character: Character, pos: Vector2i, more_permissive = false):
	if not more_permissive and safe_room.has_point(pos):
		return false

	var dir = pos - character.map_position
	if dir == Vector2i.ZERO:
		return true

	if more_permissive and character.map_position.distance_squared_to(pos) < 4.0:
		return true

	var angle = LOS_PERMISSIVE_ANGLE if more_permissive else LOS_ANGLE
	if abs(Vector2(character.look_direction).angle_to(dir)) >= angle:
		return false

	var line_positions = Geometry2D.bresenham_line(character.map_position, pos)
	for i in range(line_positions.size()):
		# Allow seeing the last tile of the line to allow seeing walls and obstacles
		if more_permissive and i == line_positions.size() - 1:
			continue

		if i > 0:
			var line_dir = line_positions[i] - line_positions[i - 1]
			var diff = line_dir.abs()
			# Check if movement was diagonal
			if diff.x == 1 and diff.y == 1:
				# Prevent seeing between two diagonal walls
				var check_x = line_positions[i - 1] + Vector2i(line_dir.x, 0)
				var check_y = line_positions[i - 1] + Vector2i(0, line_dir.y)
				if not is_transparent(check_x) and not is_transparent(check_y):
					return false

		if not is_transparent(line_positions[i]):
			return false

	return true

func update_seen_tiles() -> void:
	seen_tiles.clear()
	for past_player in past_players:
		for dy in range(-LOS_RADIUS, LOS_RADIUS + 1):
			for dx in range(-LOS_RADIUS, LOS_RADIUS + 1):
				var checked_pos = past_player.map_position + Vector2i(dx, dy)
				if can_see(past_player, checked_pos):
					seen_tiles[checked_pos] = true

	for node in see_markers:
		remove_child(node)

	see_markers.clear()
	for pos in seen_tiles:
		var marker = preload("res://scenes/debug_rect.tscn").instantiate() as DebugRect
		marker.set_rect(Rect2i(pos, Vector2i.ONE))
		see_markers.push_back(marker)
		add_child(marker)

func can_move_to(pos: Vector2i) -> bool:
	match tile_map.get_tile(pos):
		Enum.TileType.WALL: return false
		Enum.TileType.OBJECT_BLOCKING_OPAQUE: return false
		Enum.TileType.OBJECT_BLOCKING_TRANSPARENT: return false
	return true

func is_transparent(pos: Vector2i) -> bool:
	match tile_map.get_tile(pos):
		Enum.TileType.EMPTY: return true
		Enum.TileType.FLOOR: return true
		Enum.TileType.OBJECT_BLOCKING_TRANSPARENT: return true
		Enum.TileType.OBJECT_NONBLOCKING_TRANSPARENT: return true
		Enum.TileType.DOOR:
			return player.map_position == pos or past_players.any(func (c: Character): return c.map_position == pos)
	return false

func on_character_move_finish(character: Character) -> void:
	for door_pos in doors:
		doors[door_pos].on_character_move_finish(character)

	for game_obj in game_objects:
		game_obj.on_character_move_finish(character)
