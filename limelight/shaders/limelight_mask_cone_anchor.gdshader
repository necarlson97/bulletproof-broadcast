shader_type spatial;
// Mask fill + cone apex pinned to a world position (base follows node transform).
// cull_disabled: mask when camera is inside the cone (inner faces draw).
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_disabled;

uniform vec3 tip_world;
uniform vec3 tip_local;
uniform float tip_snap_epsilon : hint_range(0.0001, 1.0, 0.0001) = 0.05;
uniform mat4 inv_model_matrix;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (distance(VERTEX, tip_local) < tip_snap_epsilon) {
		wp = tip_world;
	}
	VERTEX = (inv_model_matrix * vec4(wp, 1.0)).xyz;
}

void fragment() {
	// Single-channel encode: R1G0 (warm) was losing G in some HDR/viewport paths. RGB = linear 0..1 depth.
	float d = max(-VERTEX.z, 0.0);
	const float ENC_FAR_M = 1500.0;
	float e = clamp(d / ENC_FAR_M, 0.0, 1.0);
	ALBEDO = vec3(e);
}
