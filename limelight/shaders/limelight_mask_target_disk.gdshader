shader_type spatial;
// Same path as limelight_mask_fill (no vertex hack): R = depth, G = 1 = full target hole lift.
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_disabled;

void fragment() {
	float d = max(-VERTEX.z, 0.0);
	const float ENC_FAR_M = 1500.0;
	float e = clamp(d / ENC_FAR_M, 0.0, 1.0);
	ALBEDO = vec3(e, 1.0, 0.0);
}
