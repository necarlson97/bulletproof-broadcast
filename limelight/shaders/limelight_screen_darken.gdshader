shader_type spatial;
// Fullscreen pass: darken everywhere except where the mask RT shows limelight coverage and depth allows it.
// Binary: nearest-sampled mask + step(); overlapping limelights max() to white — same as one cone.
//
// Ordering: spatial + hint_screen_texture vs alpha blend — see LimelightRender (web/Compatibility; no compositor fix).
//
// Mask RT: RGB = same normalized linear depth 0..1 (meters / mask_depth_decode_scale). Opaque GLES may not preserve ALPHA.
// Scene linear depth: use built-in INV_PROJECTION_MATRIX so depth buffer unpack matches the renderer.
//
// The mask SubViewport only draws limelight geometry — scene occlusion is applied here via depth_ok.
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D limelight_mask : source_color, filter_nearest;
uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.2;
/// Extra tolerance in meters (large maps / buffer precision).
uniform float depth_test_slop_m : hint_range(0.0, 200.0, 0.1) = 8.0;
/// Added as a fraction of reconstructed scene depth (scales with distance).
uniform float depth_test_slop_ratio : hint_range(0.0, 0.05, 0.0001) = 0.002;
/// Must match encoding in limelight_mask_*.gdshader (meters).
uniform float mask_depth_decode_scale : hint_range(100.0, 3000.0, 1.0) = 1500.0;
/// 0 = off. Keep depth sampling in fragment() (not a helper) for GLES compatibility.
uniform int debug_view : hint_enum("Normal,Occlusion_mask,Scene_depth,Mask_depth,Depth_OK,Cone_silhouette,Raw_Z") = 0;
/// Meters; scene/mask depth visualizations are clamped to this for grayscale.
uniform float debug_depth_vis_scale : hint_range(10.0, 3000.0, 1.0) = 500.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float raw_z = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_z * 2.0 - 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_lin = max(-view.z, 0.0);

	vec3 base = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec4 m = textureLod(limelight_mask, SCREEN_UV, 0.0);
	float mask_enc = max(m.r, max(m.g, m.b));
	// epsilon: clear is 0; near fragments can have small e (e.g. 5m/1500 ≈ 0.003).
	float mask_hit = step(1e-4, mask_enc);
	float mask_lin = mask_enc * mask_depth_decode_scale;
	float slop = depth_test_slop_m + scene_lin * depth_test_slop_ratio;
	float depth_ok = step(mask_lin, scene_lin + slop);
	float on = mask_hit * depth_ok;

	vec3 out_rgb = base * mix(1.0 - darkness, 1.0, on);
	// 1 = depth-gated mask (same as final hole); 5 = raw cone from mask RT only (no scene occlusion).
	if (debug_view == 1) {
		out_rgb = vec3(on);
	} else if (debug_view == 2) {
		float g = clamp(scene_lin / debug_depth_vis_scale, 0.0, 1.0);
		out_rgb = vec3(g);
	} else if (debug_view == 3) {
		float g = mask_hit > 0.5 ? clamp(mask_lin / debug_depth_vis_scale, 0.0, 1.0) : 0.0;
		out_rgb = vec3(g);
	} else if (debug_view == 4) {
		out_rgb = vec3(depth_ok);
	} else if (debug_view == 5) {
		out_rgb = vec3(mask_hit);
	} else if (debug_view == 6) {
		out_rgb = vec3(raw_z);
	}
	ALBEDO = out_rgb;
}
