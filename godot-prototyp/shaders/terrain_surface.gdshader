shader_type spatial;
render_mode specular_disabled, cull_disabled;
// Povrch duální mřížky (louka / písek / dno) – port napojeni-studie/shaders/terrain.gdshader (přístup 2, dual_shape 0).
// Materiál: textura tříd buněk (R tráva, G písek, B dno) vzorkovaná lineárně = bilineární váhy 4 rohů dlaždice
// (marching squares), + šum hranice a ostrý práh (dual_soft) – stejně jako ShoreFields.weights() na CPU.
// Pole (field_tex): R výška, G vzdálenost k vodě (+ souš, − voda), B od okraje louky, A k louce (v buňkách).
// Písek šedobéžový s procedurálním zrnem a čeřinami, pásy mokrého písku a trávy v písku, travnatý břeh s bahnem,
// procedurální louka (varianta 3). Boky (lem mezi duální a kostkovou částí) z barvy vrcholů.
#include "res://shaders/surface_common.gdshaderinc"
#include "res://shaders/meadow_proc.gdshaderinc"
#include "res://shaders/surface_look.gdshaderinc"
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec4 rect = vec4(0.0, 0.0, 24.0, 24.0);   // počátek XZ, velikost XZ (svět) okna ShoreFields
uniform float cell = 1.0;
uniform float dual_noise = 0.12;
uniform float dual_soft = 0.06;
uniform vec3 col_bed = vec3(0.86, 0.80, 0.60);
uniform vec3 col_bed2 = vec3(0.78, 0.75, 0.65);
uniform bool bands = true;
uniform float band_water = 0.75;
uniform float band_grass = 1.1;
uniform vec3 col_packed = vec3(0.72, 0.69, 0.62);
uniform vec3 col_mixgrass = vec3(0.55, 0.72, 0.42);
uniform bool bank = true;
uniform float bank_reach = 2.2;
uniform float mud_w = 0.16;
uniform vec3 col_mud = vec3(0.50, 0.46, 0.33);
uniform vec3 col_bank_soil = vec3(0.58, 0.46, 0.34);
uniform float water_level = 14.85;
uniform bool mat_line = true;
uniform int grid_overlay = 0;       // 0 nic, 1 datová mřížka (bílá), 2 + duální dlaždice (červeně)
uniform float ramp_soft = 0.12;
uniform float shadow_level = 0.35;
uniform float light_gain = 0.75;
uniform float pastel = 0.18;
uniform bool toon_on = true;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = NORMAL;
}
void fragment() {
	vec2 uv = (wpos.xz - rect.xy) / rect.zw;
	vec3 c;
	bool top = UV2.x > 0.5;
	vec2 q = wpos.xz / cell;
	if (top) {
		vec4 sp = texture(splat_tex, uv);
		vec3 w = sp.rgb / max(sp.r + sp.g + sp.b, 1e-4);
		float nv = vnoise(wpos.xz * 0.9) * 2.0 - 1.0;
		w.r += dual_noise * nv;
		w.g -= dual_noise * nv * 0.5;
		float wm = max(w.r, max(w.g, w.b));
		w = clamp((w - vec3(wm) + vec3(dual_soft)) / dual_soft, 0.0, 1.0);
		w /= max(w.r + w.g + w.b, 1e-5);
		vec3 sandc = sand_look == 1 ? lin(col_sand2) : lin(col_sand);
		vec3 bedc = sand_look == 1 ? lin(col_bed2) : lin(col_bed);
		vec3 grassc = meadow_ground(lin(col_grass), wpos.xz);
		float d2 = sand_mod(q);
		sandc *= d2; bedc *= d2;
		vec4 fb = texture(field_tex, uv);
		if (bands) {
			float nb = vnoise(q * 2.3);
			float wb = (1.0 - smoothstep(band_water * 0.85, band_water, fb.g + (nb - 0.5) * 0.35)) * step(0.0, fb.g);
			vec3 packed = lin(col_packed) * (1.0 + 0.035 * sin(fb.g * 26.0 + nb * 3.0));
			sandc = mix(sandc, packed, wb);
			float gb = 1.0 - smoothstep(0.0, band_grass, fb.a);
			float spots = vnoise(q * 5.5) * 0.6 + vnoise(q * 13.0) * 0.4;
			float gm = smoothstep(1.0 - gb * 0.75, 1.06 - gb * 0.75, spots) * step(0.001, fb.a);
			vec3 tint = mix(sandc, sandc * vec3(0.93, 0.95, 0.85), gb);
			sandc = mix(tint, lin(col_mixgrass) * (0.9 + 0.2 * spots), gm);
		}
		if (sand_look == 1) bedc = mix(bedc, sandc, step(water_level, wpos.y));   // dno nad hladinou = písek pláže
		float bank_k = 0.0;
		if (bank) {
			float above = step(water_level, wpos.y);
			float nearg = 1.0 - smoothstep(bank_reach * 0.8, bank_reach, fb.a);
			bedc = mix(bedc, grassc * 0.92, above * nearg);
			bank_k = above * nearg;
			float nb2 = vnoise(q * 3.1);
			float mud = (1.0 - smoothstep(mud_w * 0.3, mud_w, fb.g + (nb2 - 0.5) * 0.10)) * above * max(nearg, w.r) * (0.55 + 0.3 * nb2);
			vec3 mudc = lin(col_mud) * (0.9 + 0.2 * nb2);
			grassc = mix(grassc, mudc, mud);
			bedc = mix(bedc, mudc, mud);
		}
		c = grassc * w.r + sandc * w.g + bedc * w.b;
		float steep = 1.0 - smoothstep(0.35, 0.6, wnrm.y);
		vec3 soil = mix(lin(vec3(0.90, 0.78, 0.55)), lin(vec3(0.66, 0.50, 0.40)), step(0.5, w.r));
		soil = mix(soil, lin(col_bank_soil), bank_k);
		if (sand_look == 1) soil = mix(soil, vec3(lum(soil)), 0.3);
		c = mix(c, soil * 0.92, steep);
		c *= 0.96 + 0.06 * hash12(floor(q * 4.0));
		if (mat_line) {
			float g = w.r - 0.5;
			float s = w.g - 0.5;
			float lg = 1.0 - smoothstep(0.6, 1.4, abs(g) / max(fwidth(g), 1e-4));
			lg *= 1.0 - bank_k;
			float ls = (1.0 - smoothstep(0.6, 1.4, abs(s) / max(fwidth(s), 1e-4))) * step(water_level, wpos.y);
			c *= 1.0 - 0.28 * max(lg, ls * 0.6);
		}
		float uw = smoothstep(0.0, 0.45, water_level - wpos.y);
		c = mix(c, c * vec3(0.55, 0.85, 0.88), uw);
	} else {
		c = lin(COLOR.rgb);
		if (sand_look == 1) c = mix(c, vec3(lum(c)), 0.3);
	}
	if (grid_overlay > 0 && top) {
		vec2 g = q;
		vec2 fw = fwidth(g);
		vec2 a = abs(fract(g + 0.5) - 0.5) / fw;
		c = mix(c, vec3(1.0), (1.0 - smoothstep(0.5, 1.5, min(a.x, a.y))) * 0.85);
		if (grid_overlay > 1) {
			vec2 b = abs(fract(g) - 0.5) / fw;
			float dash = step(0.5, fract((g.x + g.y) * 4.0));
			c = mix(c, vec3(0.85, 0.12, 0.18), (1.0 - smoothstep(0.5, 1.5, min(b.x, b.y))) * dash);
		}
	}
	if (toon_on) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(l), pastel);
		c = mix(c, vec3(1.0), pastel * 0.35);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(0.0, ramp_soft, ndl);
	float lit = mix(shadow_level * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, t * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
