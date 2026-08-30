shader_type canvas_item;

// §9b extracted-shadow portrait treatment: desaturate to luminance, remap
// dark->shade / bright->glow via smoothstep, then knock out the source art's
// near-white background (the portraits are RGB with no alpha). Knockout requires
// BOTH high value (near-white) AND low saturation, so tinted highlights like
// fangs or eye-glints (saturated white) survive while pure-white background
// punches through. Uniform defaults are the values approved in the before/after
// tuning artifact and are baked into shadow_recolor.tres -- do not change them
// here without the same sign-off.

uniform vec4 shade_color : source_color = vec4(0.039216, 0.101961, 0.133333, 1.0);
uniform vec4 glow_color : source_color = vec4(0.498039, 0.941176, 1.0, 1.0);
uniform float low : hint_range(0.0, 1.0) = 0.12;
uniform float high : hint_range(0.0, 1.0) = 0.78;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float desaturate : hint_range(0.0, 1.0) = 1.0;
uniform float bg_knockout : hint_range(0.5, 1.0) = 0.86;
uniform float bg_softness : hint_range(0.01, 0.3) = 0.08;
uniform float bg_desat_max : hint_range(0.02, 0.4) = 0.2;  // tune on device: raise if white highlights thin out

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(src.rgb, vec3(lum), desaturate);
	float t = smoothstep(low, high, lum);
	vec3 shaded = mix(shade_color.rgb, glow_color.rgb, t);
	vec3 out_rgb = mix(desat, shaded, intensity);
	// Knock out a pixel only when it IS near-white AND low-saturation (the true
	// paper-white background). A dark or coloured body pixel keeps full alpha;
	// a tinted white highlight (fang / eye-glint) keeps alpha because its
	// saturation exceeds bg_desat_max.
	float whiteness = min(src.r, min(src.g, src.b));
	float maxc = max(src.r, max(src.g, src.b));
	float sat = maxc > 0.0001 ? (maxc - whiteness) / maxc : 0.0;
	float is_white = smoothstep(bg_knockout - bg_softness, bg_knockout + bg_softness, whiteness);
	float is_low_sat = 1.0 - smoothstep(bg_desat_max, bg_desat_max * 2.0, sat);
	float knock = is_white * is_low_sat;
	COLOR = vec4(out_rgb, src.a * (1.0 - knock));
}
