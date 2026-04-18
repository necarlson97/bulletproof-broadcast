shader_type spatial;
// Dark dome: alpha = darkness everywhere, alpha = 0 where the opaque surface at this pixel (from depth)
// lies inside any limelight influence sphere (world-space distance to center).
render_mode unshaded, depth_draw_never, cull_front, blend_mix, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float cutout_radius : hint_range(1.0, 500.0, 1.0) = 100.0;
uniform int limelight_count = 0;
uniform vec3 limelight_centers[10];

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 world_h = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_pos = world_h.xyz / world_h.w;

	float a = darkness;
	float r2 = cutout_radius * cutout_radius;
	for (int i = 0; i < 10; i++) {
		if (i >= limelight_count) {
			break;
		}
		vec3 L = limelight_centers[i];
		vec3 d = world_pos - L;
		if (dot(d, d) < r2) {
			a = 0.0;
			break;
		}
	}

	ALBEDO = vec3(0.0);
	ALPHA = a;
}
