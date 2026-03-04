extends Node3D

@onready var sprite = $AnimatedSprite3D

var debris_sound = preload("res://audio/exp_debris.ogg")

const LAST_FRAME = 62

func _ready() -> void:
	$AnimatedSprite3D.play("default")
	sprite.animation_finished.connect(func (): queue_free())

	var extra = AudioStreamPlayer3D.new()
	extra.stream = debris_sound
	extra.max_db = -6
	extra.unit_size = 5.0
	extra.max_distance = 10.0
	extra.transform.origin = transform.origin
	get_parent().add_child(extra)
	extra.finished.connect(func (): extra.queue_free())
	extra.play()

func _process(_delta: float) -> void:
	if sprite.frame >= LAST_FRAME - 30:
		var frames_left = LAST_FRAME - sprite.frame
		var a = frames_left / 30.0
		sprite.material_override.albedo_color = Color(a, a, a)
