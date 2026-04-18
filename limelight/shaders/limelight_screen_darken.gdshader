shader_type spatial;
// Fullscreen pass: darken the scene where the mask RT is black; white in the mask = no darkening.
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D limelight_mask : source_color, filter_linear;
uniform float darkness : hint_range(0.0, 1.0, 0.01) = 0.65;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 base = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 m = texture(limelight_mask, SCREEN_UV).rgb;
	float lit = max(m.r, max(m.g, m.b));
	float dim = mix(1.0 - darkness, 1.0, lit);
	ALBEDO = base * dim;
}
