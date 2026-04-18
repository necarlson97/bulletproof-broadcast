shader_type spatial;
// Draw anything on the mask render layer as solid white into the mask SubViewport (unlimited objects).
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_back;

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = 1.0;
}
