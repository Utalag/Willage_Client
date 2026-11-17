shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, specular_disabled;
// A) Shell texturing: N průhledných vrstev nad sebou, chlup = sloupec pixelů přes vrstvy (hash na mřížce).
// Vítr a rozhrnutí posouvají vyhledání kořene v horních vrstvách → chlupy se ohýbají, při rozhrnutí se i sklopí.
#include "res://shaders/grass_common.gdshaderinc"
uniform float max_h = 0.15;          // výška nejvyšší vrstvy (= vysoká tráva)
uniform float density = 34.0;        // chlupů / jednotku (vysoká)
uniform float density_short = 46.0;  // chlupů / jednotku (nízká)
uniform float rad_root = 0.62;      // poloměr chlupu u kořene (× rozteč)
uniform float rad_tip = 0.08;       // poloměr u špičky
uniform float fill = 1.0;           // podíl obsazených míst (A2 koberec < 1 → mezery)
uniform vec3 col_root : source_color = vec3(0.24, 0.45, 0.30);
uniform vec3 col_tip : source_color = vec3(0.72, 0.92, 0.55);
uniform vec3 col_tip_short : source_color = vec3(0.62, 0.86, 0.50);
uniform vec3 col_pressed : source_color = vec3(0.86, 0.93, 0.62);
varying vec3 wp;
varying float lay;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lay = UV2.x;
}
void fragment() {
	vec2 p = wp.xz;
	float y = lay * max_h;
	vec3 tr = trample_at(p);
	float tz = max(tr.z, 0.0);
	vec2 w = wind_at(p, 0.0);
	vec2 lean = w * (1.0 - tz) + tr.xy * t_bend;
	float th = min(length(lean), 1.45);
	// vodorovný posun chlupu ve výšce y ≈ y·tan(θ) (omezeno), roste ke špičce
	vec2 off = (th > 1e-4 ? lean / length(lean) : vec2(0.0)) * y * min(tan(th), 2.5) * (0.6 + 0.4 * lay);
	vec2 q = p - off;
	vec2 tuv = (q - patch_rect.xy) / patch_rect.zw;
	float hcell = textureLod(type_tex, clamp(tuv, vec2(0.001), vec2(0.999)), 0.0).r;
	bool tall = hcell > 0.6;
	float dens = tall ? density : density_short;
	vec2 g = q * dens;
	vec2 id = floor(g);
	float rnd = hash12(id + 0.37);
	vec2 jit = (vec2(hash12(id + 17.1), hash12(id + 3.7)) - 0.5) * 0.6;
	vec2 f = fract(g) - 0.5 - jit;
	float L = hcell * max_h * (0.62 + 0.38 * rnd);
	float Lv = L * cos(th * 0.8);                 // sklopený chlup je nižší
	float hr = y / max(Lv, 1e-4);
	if (lay > 0.001) {
		if (hr > 1.0) discard;
		float rad = mix(rad_root, rad_tip, hr);           // kužel: u kořene tlustý, na špičce tenký
		// LOD proti moaré: když je chlup menší než ~3 px, chlupy se rozšíří a splynou v plochu
		float fw = length(fwidth(g));
		rad = mix(rad, max(rad, 0.8 - 0.5 * hr) , smoothstep(0.38, 0.85, fw) * step(0.99, fill));
		if (length(f) > rad || hash12(id + 91.7) > fill) discard;
	}
	hr = clamp(hr, 0.0, 1.0);
	vec3 tip = tall ? col_tip : col_tip_short;
	vec3 c = mix(col_root, tip, smoothstep(0.0, 1.0, hr));
	c *= 0.86 + 0.26 * rnd;
	c = mix(c, col_pressed, tz * 0.45 * hr);      // přeleželá tráva je světlejší (vidíme boky stébel)
	c *= mix(0.62, 1.0, hr);                      // ambientní okluze u kořenů
	c *= char_shadow(p);
	ALBEDO = to_pastel(c) * sun_tint;
}
