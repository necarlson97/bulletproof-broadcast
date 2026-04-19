shader_type spatial;
// Fullscreen pass: darken everywhere except where cone and disk mask RTs pass the depth test.
// Two separate SubViewports: limelight_mask_cone (layer 10), limelight_mask_disk (layer 11).
// Lift: disk buffer applies target_hole_lift where valid; else cone buffer applies cone_hole_lift.
//
// Ordering: spatial + hint_screen_texture vs alpha blend — see LimelightRender (web/Compatibility; no compositor fix).
//
// Mask RTs: R = normalized linear depth (see limelight_mask_*.gdshader). Scene linear depth via INV_PROJECTION_MATRIX.
//
// The mask SubViewports only draw limelight geometry — scene occlusion is applied here via depth_ok per buffer.
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D limelight_mask_cone : source_color, filter_nearest;
uniform sampler2D limelight_mask_disk : source_color, filter_nearest;
uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.2;
/// Extra tolerance in meters (large maps / buffer precision).
uniform float depth_test_slop_m : hint_range(0.0, 200.0, 0.1) = 8.0;
/// Added as a fraction of reconstructed scene depth (scales with distance).
uniform float depth_test_slop_ratio : hint_range(0.0, 0.05, 0.0001) = 0.002;
/// Must match encoding in limelight_mask_*.gdshader (meters).
uniform float mask_depth_decode_scale : hint_range(100.0, 3000.0, 1.0) = 1500.0;
/// Hole lift when pixel is covered by cone mask RT only (after depth test).
uniform float cone_hole_lift : hint_range(0.0, 1.0, 0.01) = 0.8;
/// Hole lift when pixel is covered by disk mask RT (after depth test); wins over cone.
uniform float target_hole_lift : hint_range(0.0, 1.0, 0.01) = 1.0;
/// 0 = off. Keep depth sampling in fragment() (not a helper) for GLES compatibility.
uniform int debug_view : hint_enum("Normal,Occlusion_mask,Scene_depth,Mask_depth_cone,Depth_OK,Cone_silhouette,Raw_Z,Cone_mask_buffer,Disk_mask_buffer") = 0;
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
	vec4 mcone = textureLod(limelight_mask_cone, SCREEN_UV, 0.0);
	vec4 mdisk = textureLod(limelight_mask_disk, SCREEN_UV, 0.0);
	float enc_c = mcone.r;
	float enc_d = mdisk.r;
	float cone_hit = step(1e-4, enc_c);
	float disk_hit = step(1e-4, enc_d);
	float cone_lin = enc_c * mask_depth_decode_scale;
	float disk_lin = enc_d * mask_depth_decode_scale;
	float slop = depth_test_slop_m + scene_lin * depth_test_slop_ratio;
	float cone_depth_ok = step(cone_lin, scene_lin + slop);
	float disk_depth_ok = step(disk_lin, scene_lin + slop);
	float cone_lit = cone_hit * cone_depth_ok;
	float disk_lit = disk_hit * disk_depth_ok;
	float lift = 0.0;
	if (disk_lit > 0.5) {
		lift = target_hole_lift;
	} else if (cone_lit > 0.5) {
		lift = cone_hole_lift;
	}
	float dim = mix(1.0 - darkness, 1.0, lift);

	vec3 out_rgb = base * dim;
	if (debug_view == 1) {
		out_rgb = vec3(lift);
	} else if (debug_view == 2) {
		float g = clamp(scene_lin / debug_depth_vis_scale, 0.0, 1.0);
		out_rgb = vec3(g);
	} else if (debug_view == 3) {
		out_rgb = cone_hit > 0.5 ? vec3(clamp(enc_c, 0.0, 1.0)) : vec3(0.0);
	} else if (debug_view == 4) {
		out_rgb = vec3(max(cone_hit * cone_depth_ok, disk_hit * disk_depth_ok));
	} else if (debug_view == 5) {
		out_rgb = vec3(cone_hit);
	} else if (debug_view == 6) {
		out_rgb = vec3(raw_z);
	} else if (debug_view == 7) {
		out_rgb = vec3(enc_c);
	} else if (debug_view == 8) {
		out_rgb = vec3(enc_d);
	}
	ALBEDO = out_rgb;
}
