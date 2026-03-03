extends Node3D

@onready var sprite = $AnimatedSprite3D

const LAST_FRAME = 62

func _ready() -> void:
	$AnimatedSprite3D.play("default")
	sprite.animation_finished.connect(func (): queue_free())

func _process(_delta: float) -> void:
	if sprite.frame >= LAST_FRAME - 30:
		var frames_left = LAST_FRAME - sprite.frame
		var a = frames_left / 30.0
		sprite.material_override.albedo_color = Color(a, a, a)
