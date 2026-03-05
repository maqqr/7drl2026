extends AnimationPlayer

@export var animation: StringName

func _ready() -> void:
	play(animation)
