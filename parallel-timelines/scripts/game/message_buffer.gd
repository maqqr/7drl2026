class_name MessageBuffer
extends Control

const SHOW_MESSAGE_TIME = 8
const FADE_DELAY = 0.07

const MSG_NEW_GAME: String = "The self-destruct alarm wakes you up. Find and deliver {count} keycards to the escape shuttle."
const MSG_PICKUP: String = "[i]You pick up {a} {item}.[/i]"
const MSG_KEY_DELIVER: String = "[i]The {item} was delivered to the escape shuttle, {remain_count} remaining.[/i]"
const MSG_KEY_SELF_DELIVER: String = "[i]You deliver the {item} to the escape shuttle, {remain_count} remaining.[/i]"
const MSG_LOSE: String = "Your past self sees you and you both go insane, causing all timelines to collapse."
const MSG_OUT_OF_TURNS: String = "Just before the ship explodes, your suit's time travel module activates."
const MSG_DROP: String = "[i]You drop the {item}.[/i]"

func clear() -> void:
	for child in $VBoxContainer.get_children():
		child.queue_free()

func add_message(msg: String) -> void:
	var line = preload("res://scenes/ui/message_line.tscn").instantiate()
	line.text = msg
	$VBoxContainer.add_child(line)

	var tree = get_tree()
	if !tree:
		return

	var tween = tree.create_tween()
	tween.tween_interval(SHOW_MESSAGE_TIME)
	tween.tween_property(line, "self_modulate", Color(0.7, 0.7, 0.7), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.4, 0.4, 0.4), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.1, 0.1, 0.1), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.0, 0.0, 0.0, 0.0), 0.0)

	tween.tween_property(line, "custom_minimum_size:y", 0.0, 0.3)
	tween.tween_callback(line.queue_free)
