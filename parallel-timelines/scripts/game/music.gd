extends AudioStreamPlayer

var muted = false
var _volume = 0.4

func _ready() -> void:
	volume_linear = _volume
	play()
	#if not OS.has_feature("editor"):
	#	play()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mute"):
		muted = !muted
		volume_linear = 0.0 if muted else _volume
