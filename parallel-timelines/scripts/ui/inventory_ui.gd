extends Control
class_name InventoryUi

@export var action_button_panel: Control
@export var item_button_container: Control

@export var use_button: Button
@export var drop_button: Button
@export var throw_button: Button
@export var cancel_button: Button

var item_button: PackedScene = preload("res://scenes/ui/inventory/item_button.tscn")
var empty_slot: PackedScene = preload("res://scenes/ui/inventory/empty_slot.tscn")
var pressed_index = null

signal item_used(index: int)
signal item_dropped(index: int)
signal item_thrown(index: int)

func _ready() -> void:
	use_button.pressed.connect(on_use_pressed)
	drop_button.pressed.connect(on_drop_pressed)
	throw_button.pressed.connect(on_throw_pressed)
	cancel_button.pressed.connect(cancel_action_menu)

func on_use_pressed() -> void:
	if pressed_index == null:
		return
	item_used.emit(pressed_index)
	cancel_action_menu()

func on_drop_pressed() -> void:
	if pressed_index == null:
		return
	item_dropped.emit(pressed_index)
	cancel_action_menu()

func on_throw_pressed() -> void:
	if pressed_index == null:
		return
	item_thrown.emit(pressed_index)
	cancel_action_menu()

func on_item_button_pressed(character: Character, index: int) -> void:
	pressed_index = index
	var pressed_item: ItemType = character.items[index]
	use_button.visible = pressed_item.can_use
	drop_button.visible = pressed_item.can_drop
	throw_button.visible = pressed_item.can_throw
	action_button_panel.visible = true

func cancel_action_menu() -> void:
	pressed_index = null
	action_button_panel.visible = false

func update(character: Character) -> void:
	cancel_action_menu()
	for child in item_button_container.get_children():
		child.queue_free()

	var i = 0
	for item in character.items:
		var button = item_button.instantiate() as Button
		button.icon = item.inventory_icon
		button.pressed.connect(on_item_button_pressed.bind(character, i))
		button.tooltip_text = "[b]" + item.name[0].to_upper() + item.name.substr(1) + "[/b]"
		if item.tooltip_text.length() > 0:
			button.tooltip_text += "\n" + item.tooltip_text
		item_button_container.add_child(button)
		i += 1

	while i < GameManager.MAX_INVENTORY:
		var slot = empty_slot.instantiate()
		item_button_container.add_child(slot)
		i += 1
