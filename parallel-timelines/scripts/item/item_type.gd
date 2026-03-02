@icon("res://icons/bag.svg")
extends Resource
class_name ItemType

@export var name: String
@export var an_article: bool
@export var inventory_icon: Texture2D
@export var visual_scene: PackedScene
@export var is_keycard: bool
@export var can_use: bool
@export var can_drop: bool
@export var can_throw: bool

@export var invisibility_turns_on_use: int
@export var spawn_game_object_on_throw: PackedScene
