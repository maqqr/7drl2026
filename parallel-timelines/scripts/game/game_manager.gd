extends Node3D
class_name GameManager

const MOVE_KEYS: Dictionary[String, Vector2i] = {
	"right": Vector2i(1, 0),
	"left": Vector2i(-1, 0),
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
}

@onready var cursor: Node3D = $Cursor
var tile_map: TileMap2D
var tile_map_renderer: TileMapRenderer
var map_generator: MapGenerator

var doors: Dictionary[Vector2i, Node3D]
var door_scene: PackedScene = preload("res://scenes/gameobjects/door.tscn")

var player: Character

var debug_rect_scene: PackedScene = preload("res://scenes/debug_rect.tscn")
var debug_rects: Node3D

func _ready() -> void:
	map_generator = MapGenerator.new()
	map_generator.name = "MapGenerator"
	add_child(map_generator)

	tile_map_renderer = TileMapRenderer.new()
	tile_map_renderer.name = "TileMapRenderer"
	add_child(tile_map_renderer)

	debug_rects = Node3D.new()
	debug_rects.name = "DebugRects"
	add_child(debug_rects)

	start_new_game()

func _process(_delta: float) -> void:
	if tile_map:
		var mouse_tile = get_mouse_tile()
		if tile_map.is_point_inside(mouse_tile):
			cursor.position = TileMap2D.to_scene_pos(mouse_tile)

	if Input.is_action_just_pressed("ui_accept"):
		start_new_game()

	for key_name in MOVE_KEYS:
		if Input.is_action_pressed(key_name):
			var direction = MOVE_KEYS[key_name]
			var old_position = player.map_position
			var final_position = player.map_position + direction
			player.map_position = final_position

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
	if not tile_map:
		return

	if event is InputEventMouseButton:
		if event.pressed:
			var tile = Enum.TileType.WALL if event.button_index == 1 else Enum.TileType.FLOOR
			tile_map.set_tile(get_mouse_tile(), tile)

func start_new_game():
	map_generator.generate(41, 70)
	await map_generator.completed
	if not map_generator.fail:
		print("Map generation done")
		tile_map = map_generator.tile_map
		# Delete old doors
		for door_pos in doors:
			doors[door_pos].queue_free()
		doors.clear()
		# Create and fix doors
		for door_pos in map_generator.door_positions:
			var is_horizontal = false
			var is_vertical = false
			if tile_map.get_tile(door_pos + Vector2i(-1, 0)) == Enum.TileType.WALL and tile_map.get_tile(door_pos + Vector2i(1, 0)) == Enum.TileType.WALL:
				is_horizontal = true
			elif tile_map.get_tile(door_pos + Vector2i(0, -1)) == Enum.TileType.WALL and tile_map.get_tile(door_pos + Vector2i(0, 1)) == Enum.TileType.WALL:
				is_vertical = true

			if is_horizontal or is_vertical:
				doors[door_pos] = door_scene.instantiate()
				add_child(doors[door_pos])
				doors[door_pos].position = TileMap2D.to_scene_pos(door_pos)
				if is_vertical:
					doors[door_pos].rotate(Vector3i(0, 1, 0), PI * 0.5)
			else:
				# Invalid door, replace with floor
				tile_map.set_tile(door_pos, Enum.TileType.FLOOR)
		tile_map_renderer.set_tile_map(tile_map)
	else:
		print("Map generation failed")

	debug_rects.get_children().map(func (c): c.queue_free())
	var rects = []
	#for door_pos in map_generator.door_positions:
	#	rects.push_back(Rect2i(door_pos, Vector2i.ONE))
	#rects.append_array(map_generator.corridor_rects)
	#rects.append_array(map_generator.premade_room_rects)
	#rects.append_array(map_generator.random_room_rects)
	for rect in rects:
		var d = debug_rect_scene.instantiate() as DebugRect
		d.set_rect(rect)
		debug_rects.add_child(d)

	player = preload("res://scenes/gameobjects/player.tscn").instantiate() as Character
	add_child(player)
