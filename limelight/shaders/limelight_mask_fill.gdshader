shader_type spatial;
// Draw anything on the mask render layer as solid white into the mask SubViewport (unlimited objects).
// Linear view depth (-VERTEX.z) encoded in RGB (same value); see limelight_screen_darken decode.
// cull_disabled: mask when camera is inside the volume (inner faces draw).
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_disabled;

void fragment() {
	float d = max(-VERTEX.z, 0.0);
	const float ENC_FAR_M = 1500.0;
	float e = clamp(d / ENC_FAR_M, 0.0, 1.0);
	ALBEDO = vec3(e, 0.0, 0.0);
}
