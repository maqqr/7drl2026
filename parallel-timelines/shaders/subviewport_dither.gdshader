shader_type spatial;
render_mode unshaded, fog_disabled;
#include "res://shaders/dither.gdshaderinc"
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

void vertex() {
	g_q_size = 0.0;
	g_model_matrix = MODEL_MATRIX;
	//g_texture_size = 1. / TEXTURE_PIXEL_SIZE;
	g_texture_size = 1. / vec2(800.0, 600.0);
	g_vertex = VERTEX.xy;
	g_flat_vertex = VERTEX.xy;

    //POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    ALBEDO.rgb = ditherTexture(SCREEN_TEXTURE, SCREEN_UV).rgb;
}
