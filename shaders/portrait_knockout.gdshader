shader_type canvas_item;

// Battle VFX Polish §1: the SAME background-knockout math already proven and
// tuned in shaders/shadow_recolor.gdshader, extracted on its own WITHOUT the
// desaturate/shade/glow recolour -- for portraits that must keep their real
// colours (raw gate-monster art, hunter presets) but still lose the paper-white
// background. Knockout requires BOTH high value (near-white) AND low
// saturation, so a tinted highlight (fang / eye-glint) survives while the true
// white background punches through. Same default values as shadow_recolor.tres
// -- identical source art convention, so the identical threshold is the right
// starting point; retune this .tres independently if needed.

uniform float bg_knockout : hint_range(0.5, 1.0) = 0.86;
uniform float bg_softness : hint_range(0.01, 0.3) = 0.08;
uniform float bg_desat_max : hint_range(0.02, 0.4) = 0.2;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float whiteness = min(src.r, min(src.g, src.b));
	float maxc = max(src.r, max(src.g, src.b));
	float sat = maxc > 0.0001 ? (maxc - whiteness) / maxc : 0.0;
	float is_white = smoothstep(bg_knockout - bg_softness, bg_knockout + bg_softness, whiteness);
	float is_low_sat = 1.0 - smoothstep(bg_desat_max, bg_desat_max * 2.0, sat);
	float knock = is_white * is_low_sat;
	// Read rgb/a from the input COLOR (not the fresh src) so the node's modulate
	// tweens -- breathe / _tint_pulse / _white_flash -- take effect: canvas_item
	// shaders have no MODULATE built-in, but Godot bakes modulate * self_modulate
	// into the input COLOR (= that tint * texture(TEXTURE, UV)). Identity at rest.
	COLOR = vec4(COLOR.rgb, COLOR.a * (1.0 - knock));
}
