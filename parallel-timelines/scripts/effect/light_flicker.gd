extends Light3D
class_name LightFlicker

enum LightType { FIRE, ELECTRIC }

@export var light_type : LightType
@export var noise_texture : NoiseTexture3D
@export var speed = 0.0
@export var base_amount = 0.0
@export var flicker_amount = 0.0

@export_group("Electric Properties")
@export var cutoff_value = 0.0

var total_intensity = 0.0
var time_passed = 0.0

func _ready() -> void:
	time_passed = randf() * 10000.0

func _process(delta) -> void:
	time_passed += delta
	var sampled_noise = abs(noise_texture.noise.get_noise_1d(time_passed * speed))
	if light_type == LightType.ELECTRIC:
		sampled_noise = 0.0 if sampled_noise < cutoff_value else 1.0

	light_energy = total_intensity * (base_amount + flicker_amount * sampled_noise)
