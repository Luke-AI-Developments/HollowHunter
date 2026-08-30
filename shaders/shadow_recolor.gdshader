shader_type canvas_item;

// §9b extracted-shadow portrait treatment: desaturate to luminance, remap
// dark->shade / bright->glow via smoothstep, then knock out the source art's
// near-white background (the portraits are RGB with no alpha). Uniform
// defaults are the values approved in the before/after tuning artifact and
// are baked into shadow_recolor.tres -- do not change them here without the
// same sign-off.

uniform vec4 shade_color : source_color = vec4(0.039216, 0.101961, 0.133333, 1.0);
uniform vec4 glow_color : source_color = vec4(0.498039, 0.941176, 1.0, 1.0);
uniform float low : hint_range(0.0, 1.0) = 0.12;
uniform float high : hint_range(0.0, 1.0) = 0.78;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float desaturate : hint_range(0.0, 1.0) = 1.0;
uniform float bg_knockout : hint_range(0.5, 1.0) = 0.86;
uniform float bg_softness : hint_range(0.01, 0.3) = 0.08;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(src.rgb, vec3(lum), desaturate);
	float t = smoothstep(low, high, lum);
	vec3 shaded = mix(shade_color.rgb, glow_color.rgb, t);
	vec3 out_rgb = mix(desat, shaded, intensity);
	float whiteness = min(src.r, min(src.g, src.b));
	float knock = 1.0 - smoothstep(bg_knockout - bg_softness, bg_knockout + bg_softness, whiteness);
	COLOR = vec4(out_rgb, src.a * knock);
}
