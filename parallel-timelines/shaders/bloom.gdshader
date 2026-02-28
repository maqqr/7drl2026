shader_type canvas_item;

uniform float blur_amount : hint_range(-2.0, 10.0);
uniform float mix_amount : hint_range(0.0, 5.0);
uniform float glow_threshold : hint_range(0.0, 1.0);
uniform vec4 color_over : source_color;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	blurred -= vec4(glow_threshold);
	blurred = clamp(blurred, vec4(0.0), vec4(1.0));
	//if (blurred.r + blurred.g + blurred.b < glow_threshold)
	//	blurred = vec4(0, 0, 0, 0);

	blurred.a = 255.0;
	vec4 final = texture(SCREEN_TEXTURE, SCREEN_UV) + (blurred * mix_amount);
	COLOR = final;
}