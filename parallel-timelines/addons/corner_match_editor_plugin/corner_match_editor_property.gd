extends EditorProperty

var current_value: PackedByteArray
var property_control: GridContainer = preload("res://addons/corner_match_editor_plugin/corner_match_grid_container.tscn").instantiate()
var updating = false

func _init():
	add_child(property_control)
	add_focusable(property_control)

	var button_template = property_control.get_child(0)
	for i in range(8):
		property_control.add_child(button_template.duplicate())

	assert(property_control.get_children().size() == 9)

	var index = 0
	for button: Button in property_control.get_children():
		button.pressed.connect(_on_button_pressed.bind(index))
		var stylebox: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		button.add_theme_stylebox_override("normal", stylebox)
		index += 1

func _on_button_pressed(index):
	if updating:
		return

	# Important: make a copy
	var new_value = current_value.duplicate()

	var new_tile_type = new_value[index] + 1
	if new_tile_type >= CornerMatch.TileType.COUNT:
		new_tile_type = 0

	new_value[index] = new_tile_type
	refresh_controls()
	emit_changed(get_edited_property(), new_value)

func _update_property() -> void:
	var new_value = get_edited_object()[get_edited_property()]

	# Fix invalid new_value
	if new_value.size() < 9:
		new_value.resize(9)
		new_value.fill(CornerMatch.TileType.ANY)
		get_edited_object()[get_edited_property()] = new_value
		emit_changed(get_edited_property(), new_value)

	if new_value == current_value:
		return

	updating = true
	current_value = new_value
	refresh_controls()
	updating = false

func refresh_controls():
	var index = 0
	for button: Button in property_control.get_children():
		var text = "?"
		var color = Color.PURPLE
		match current_value[index] as CornerMatch.TileType:
			CornerMatch.TileType.ANY: text = "_"; color = Color(0.15, 0.15, 0.15)
			CornerMatch.TileType.WALL: text = "W"; color = Color.GRAY
			CornerMatch.TileType.FLOOR: text = "F"; color = Color.DIM_GRAY

		button.text = text
		var stylebox: StyleBoxFlat = button.get_theme_stylebox("normal")
		stylebox.bg_color = color
		index += 1
