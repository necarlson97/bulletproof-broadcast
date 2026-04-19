shader_type spatial;
// Fullscreen pass: darken everywhere except where the mask RT shows limelight coverage and depth allows it.
// Binary: nearest-sampled mask + step(); overlapping limelights max() to white — same as one cone.
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D limelight_mask : source_color, filter_nearest;
uniform mat4 inv_projection_matrix;
uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.1;
/// Extra tolerance in meters (large scenes / depth buffer precision).
uniform float depth_test_slop_m : hint_range(0.0, 200.0, 0.1) = 8.0;
/// Added as a fraction of scene linear depth (scales with distance).
uniform float depth_test_slop_ratio : hint_range(0.0, 0.05, 0.0001) = 0.002;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float scene_linear_depth(vec2 uv) {
	float raw = textureLod(depth_texture, uv, 0.0).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw * 2.0 - 1.0);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void fragment() {
	vec3 base = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec4 m = textureLod(limelight_mask, SCREEN_UV, 0.0);
	float mask_ch = max(m.r, max(m.g, m.b));
	// Binary coverage: white in mask RT (HDR can be > 1; threshold mid-gray).
	float mask_hit = step(0.5, mask_ch);
	float mask_lin = m.a;
	float scene_lin = scene_linear_depth(SCREEN_UV);
	float slop = depth_test_slop_m + scene_lin * depth_test_slop_ratio;
	// Hole only if limelight surface is at least as close as the main-pass surface (occluders in front win).
	float depth_ok = step(mask_lin, scene_lin + slop);
	float on = mask_hit * depth_ok;
	float dim = mix(1.0 - darkness, 1.0, on);
	ALBEDO = base * dim;
}
