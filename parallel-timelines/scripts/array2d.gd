class_name Array2D
extends RefCounted

var width : int
var height : int
var _data: PackedByteArray
var _default_value: int

func _init(width_param: int, height_param: int, default_value: int):
	width = width_param
	height = height_param
	_default_value = default_value
	_data.resize(width * height)
	_data.fill(default_value)

func is_point_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 && pos.y >= 0 && pos.x < width && pos.y < height

func get_value(pos: Vector2i) -> int:
	if is_point_inside(pos):
		return _data[pos.y * width + pos.x]
	return _default_value

func set_value(pos: Vector2i, value) -> void:
	if is_point_inside(pos):
		_data[pos.y * width + pos.x] = value

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
