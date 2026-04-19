shader_type spatial;
// Mask fill + cone apex pinned to a world position (base follows node transform).
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_back;

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
	ALBEDO = vec3(1.0);
	ALPHA = -VERTEX.z;
}
