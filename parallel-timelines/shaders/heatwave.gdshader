shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform sampler2D noise_texture;
uniform sampler2D mask_texture;

uniform float noise_speed : hint_range(0.0, 2.0, 0.1) = 0.5;
uniform float noise_scale : hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float distortion_strength : hint_range(0.0, 0.2, 0.001) = 0.01;

void vertex() {
	mat4 n_out2p0;
	{
		mat4 __wm = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		__wm = __wm * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		__wm = __wm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = VIEW_MATRIX * __wm;
	}
	MODELVIEW_MATRIX = n_out2p0;
}

void fragment() {
	float mask = min(texture(mask_texture, UV).r, texture(mask_texture, UV.yx).r);
	float noise = mask * (texture(noise_texture, UV * noise_scale + TIME * noise_speed).r * 0.5 - 0.5);
	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV + noise * distortion_strength).rgb;
	//ALBEDO = vec3(mask);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
