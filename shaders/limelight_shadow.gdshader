shader_type spatial;
// Fullscreen post pass: multiply the (already rendered) scene by darkness, using a white-on-black mask RT.
// The mask is not "linked" automatically — assign the SubViewport texture to `limelight_mask` (see LimelightShadowOverlay).
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D limelight_mask : source_color, filter_linear;
uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.65;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 base = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float m = texture(limelight_mask, SCREEN_UV).r;
	float lit = clamp(m, 0.0, 1.0);
	float dim = mix(1.0 - darkness, 1.0, lit);
	ALBEDO = base * dim;
}
