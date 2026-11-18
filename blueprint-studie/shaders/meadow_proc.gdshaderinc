// Převzato z trava-studie/shaders/meadow_proc.gdshaderinc (procedurální louka, varianta 3 „sladěná“), beze změn výpočtu.
// Procedurální louka: velké barevné fleky (světlejší/tmavší, do žluta), suchá místa a svěží tmavé skvrny (jetel).
// Sdílí zem (meadow_ground.gdshader) i trsy (grass_tuft.gdshader, uniform ground_match), takže trs má stejný tón jako zem pod ním.
// Vyžaduje hash12/vnoise z grass_common.gdshaderinc. Všechno je v buňkách (mp_cell), deterministické, bez textur.
uniform float mp_cell = 1.0;
uniform float mp_strength = 1.0;      // celková síla (0 = plochá barva)
uniform float mp_macro_scale = 0.16;  // velikost fleků (1/buňky): 0,16 ≈ flek přes ~6 buněk
uniform float mp_macro = 0.20;        // světlejší/tmavší (± podíl jasu)
uniform float mp_yellow = 0.45;       // posun do žlutozelena ve flecích
uniform float mp_dry = 0.55;          // síla suchých míst
uniform float mp_dry_cov = 0.16;      // podíl plochy suchých míst (přibližně)
uniform float mp_dry_scale = 0.22;
uniform float mp_lush = 0.6;          // síla svěžích tmavých skvrn (jetel)
uniform float mp_lush_cov = 0.12;
uniform float mp_lush_scale = 0.45;

float mp_fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 5.2) * 0.30 + vnoise(p * 4.1 + 11.7) * 0.15;
}
// x = jas -1..1, y = žlutost 0..1, z = sucho 0..1, w = jetel 0..1
vec4 meadow_field(vec2 p) {
	vec2 q = p / mp_cell;
	float light = (mp_fbm(q * mp_macro_scale) - 0.5) * 2.4;
	float yel = smoothstep(0.42, 0.78, vnoise(q * mp_macro_scale * 0.7 + 31.0));
	float dn = mp_fbm(q * mp_dry_scale + 57.0);
	float dry = smoothstep(0.66 - mp_dry_cov, 0.76 - mp_dry_cov, dn) * smoothstep(0.3, 0.6, yel + 0.2);
	float ln = mp_fbm(q * mp_lush_scale + 91.0);
	float lush = smoothstep(0.68 - mp_lush_cov, 0.74 - mp_lush_cov, ln) * (1.0 - dry);
	return vec4(clamp(light, -1.0, 1.0), yel, dry, lush);
}
// obarvení libovolné barvy podle pole (poměrově, takže sedí na zem i na světlé trsy)
vec3 meadow_tint(vec3 c, vec4 f, float s) {
	c *= vec3(1.0) + f.x * mp_macro * s * (f.x > 0.0 ? vec3(1.08, 1.0, 0.55) : vec3(1.3, 0.8, 1.3));   // světlejší flek = do žlutozelena, tmavší = sytější zelená (ne do šeda/modra)
	c = mix(c, c * vec3(1.16, 1.05, 0.66), f.y * mp_yellow * s);
	c = mix(c, c * vec3(0.74, 0.92, 0.78), f.w * mp_lush * s);
	float L = dot(c, vec3(0.333));
	c = mix(c, L * vec3(1.42, 1.2, 0.62), f.z * mp_dry * s);
	return c;
}
