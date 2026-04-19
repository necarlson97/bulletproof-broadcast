shader_type spatial;
// Cutout like Sprite3D alpha_cut — spatial shaders here reject render_mode alpha_scissor; discard matches scissor closely.
// blend_mix + smooth alpha often sorts wrong with ground/sky in GL Compatibility.
render_mode depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
/// Must match Sprite3D.pixel_size; flag.gd syncs from the sprite.
uniform float pixel_size = 0.1;
/// Tex width in pixels × pixel_size. Set from script; textureSize() in vertex is unreliable on GLES.
uniform float flag_world_width = 1.0;
/// Runtime-driven time from flag.gd (more reliable than TIME on some renderer paths).
uniform float wind_time = 0.0;
uniform float wind_speed : hint_range(0.0, 40.0) = 1.1;
/// Peak sway as a fraction of [uniform flag_world_width] at the free edge.
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.004;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float ripple_along_height : hint_range(0.0, 24.0) = 10.0;
uniform float ripple_along_width : hint_range(0.0, 12.0) = 3.0;
/// If true, UV.x = 0 is the pole (no motion); motion increases toward UV.x = 1.
uniform bool pole_on_left = true;

void vertex() {
	float world_w = max(flag_world_width, 0.0001);
	float edge = pole_on_left ? UV.x : (1.0 - UV.x);
	float t = wind_time * wind_speed;
	float phase = t + UV.y * ripple_along_height + UV.x * ripple_along_width;
	float w1 = sin(phase);
	float w2 = sin(phase * 0.55 + 1.7);
	float disp = wave_amplitude * world_w * edge;
	VERTEX.x += (w1 * 0.85 + w2 * 0.15) * disp;
	VERTEX.z += sin(phase * 0.9 + 0.8) * disp * 0.35;
}

void fragment() {
	vec4 c = texture(albedo_texture, UV);
	if (c.a < alpha_scissor_threshold) {
		discard;
	}
	ALBEDO = c.rgb;
}
