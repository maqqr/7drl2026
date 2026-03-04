class_name MessageBuffer
extends Control

const SHOW_MESSAGE_TIME = 8
const FADE_DELAY = 0.07

const MSG_NEW_GAME: String = "[i]The ship's self-destruct alarm wakes you up.[/i]"
const MSG_NEW_GAME2: String = "[i]Find and deliver {count} keycards to the escape shuttle.[/i]"
const MSG_WAKE_UP: String = "[i]You wake up in a dark room with yourself.[/i]"
const MSG_PICKUP: String = "[i]You pick up {a} {item}.[/i]"
const MSG_TAKE: String = "[i]You take {a} {item}.[/i]"
const MSG_KEY_DELIVER: String = "[i]The {item} was delivered to the escape shuttle, {remain_count} remaining.[/i]"
const MSG_KEY_SELF_DELIVER: String = "[i]You deliver the {item} to the escape shuttle, {remain_count} remaining.[/i]"
const MSG_LOSE: String = "[i]Your past self sees you and you both go insane, causing all timelines to collapse.[/i]"
const MSG_OUT_OF_TURNS: String = "[i]Just before the ship explodes, your suit's time travel module activates.[/i]"
const MSG_DROP: String = "[i]You drop the {item}.[/i]"
const MSG_THROW: String = "[i]You throw the {item}.[/i]"
const MSG_USE_ITEM: String = "[i]You use the {item}.[/i]"
const MSG_EXPLODED: String = "[i]You exploded, but it caused your suit's time travel module to activate.[/i]"
const MSG_COMPUTER: String = "[i]You use the computer to delay the ship's self-destruct by {turn_count} turns.[/i]"
const MSG_EXPLOSION_TRAP: String = "[i]You stepped on a trap and hear an explosion somewhere.[/i]"
const MSG_HIDE: String = "[i]You hide in the empty storage unit.[/i]"
const MSG_DEAD: String = "[i]Just before you die, your suit's time travel module activates.[/i]"
const MSG_THROW_SELECT_TILE: String = "[i]Select tile where to throw.[/i]"
const MSG_WIN: String = "[i]You managed to escape with the shuttle.[/i]"
const MSG_WIN_OTHER: String = "[i]At least one of you managed to escape with the shuttle.[/i]"
const MSG_INV_FULL: String = "[i]You cannot take the {item}, your inventory is full.[/i]"

func clear() -> void:
	for child in $VBoxContainer.get_children():
		child.queue_free()

func add_message(msg: String, extra_time: float = 0.0) -> void:
	var line = preload("res://scenes/ui/message_line.tscn").instantiate()
	line.text = msg
	$VBoxContainer.add_child(line)

	var tree = get_tree()
	if !tree:
		return

	var tween = tree.create_tween()
	tween.tween_interval(SHOW_MESSAGE_TIME + extra_time)
	tween.tween_property(line, "self_modulate", Color(0.7, 0.7, 0.7), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.4, 0.4, 0.4), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.1, 0.1, 0.1), 0.0)
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(line, "self_modulate", Color(0.0, 0.0, 0.0, 0.0), 0.0)

	tween.tween_property(line, "custom_minimum_size:y", 0.0, 0.3)
	tween.tween_callback(line.queue_free)
