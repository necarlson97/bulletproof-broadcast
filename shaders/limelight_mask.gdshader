shader_type spatial;
// Unshaded white for the mask pass. Optional UV disk cutout (good for quads); leave off for SphereMesh silhouettes.
render_mode unshaded, fog_disabled, depth_draw_opaque, cull_back;

uniform bool use_radial_uv_cutout = false;
uniform float disk_radius : hint_range(0.01, 0.49, 0.01) = 0.48;

void fragment() {
	if (use_radial_uv_cutout) {
		vec2 p = UV - vec2(0.5);
		float d = length(p);
		// Hard cartoon edge (same idea as alpha scissor: in/out, no semi-transparency in the mask RT).
		if (d > disk_radius) {
			discard;
		}
	}
	ALBEDO = vec3(1.0);
	ALPHA = 1.0;
}
