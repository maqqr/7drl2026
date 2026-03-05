extends Node3D

@export var amplitude: Vector3 = Vector3.ONE
@export var speed: Vector3 = Vector3.ONE
@export var noise_texture : NoiseTexture3D
var time_passed = 0.0

func _ready() -> void:
	($FlameSquare/OmniLight3D as LightFlicker).base_amount = 0.0
	($FlameSquare/OmniLight3D as LightFlicker).flicker_amount = 0.0

func _process(delta: float) -> void:
	time_passed += delta
	var noise_x = amplitude.x * noise_texture.noise.get_noise_1d(time_passed * speed.x)
	var noise_y = amplitude.y * noise_texture.noise.get_noise_1d((time_passed + 123) * speed.y)
	var noise_z = amplitude.z * noise_texture.noise.get_noise_1d((time_passed + 1234) * speed.z)
	transform.origin = Vector3(noise_x, noise_y, noise_z)
	rotation = Vector3(0.0, PI, -noise_x)
