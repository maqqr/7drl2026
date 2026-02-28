shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform float threshold : hint_range(0.0, 2.0, 0.01);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 value = texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, 0.0)).rgb;
	if ((value.r + value.g + value.b) / 3.0 < threshold)
		value = vec3(0.0);

	ALBEDO.rgb = value;
}
