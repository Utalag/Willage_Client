shader_type spatial;
render_mode specular_disabled, cull_disabled;
// Terén studie napojování: barva povrchu z materiálové mapy (splat: R tráva, G písek, B dno), boky z barvy vrcholů,
// kawaii toon ramp a obrysy (hrany srázů z CUSTOM0 jako v prototypu + čára na hranici materiálů).
// Doplněk „mokrý písek“: ztmavení v pásu u vody podle vzdálenostního pole (field: R výška, G vzdálenost k vodě v buňkách).
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec4 rect = vec4(0.0, 0.0, 20.0, 20.0);   // počátek XZ, velikost XZ (svět)
uniform float cell = 1.0;
uniform vec3 col_grass = vec3(0.56, 0.80, 0.47);
uniform vec3 col_sand = vec3(0.98, 0.89, 0.62);
uniform vec3 col_bed = vec3(0.86, 0.80, 0.60);
// nový vzhled písku (Jan 14:14: méně sytý, s texturou, přechod jako samostatný materiál)
uniform int sand_look = 1;                 // 0 původní, 1 šedobéžový
uniform vec3 col_sand2 = vec3(0.84, 0.78, 0.67);
uniform vec3 col_bed2 = vec3(0.78, 0.75, 0.65);
uniform int sand_detail = 1;               // 0 nic, 1 textura Gemini, 2 procedurální zrno + čeřiny
uniform sampler2D sand_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.25;
uniform float sand_tex_scale = 0.6;   // písek: 1 opakování textury na 1,7 m (drobnější čeřiny)
uniform float sand_tex_contrast = 2.6;
uniform bool bands = true;                 // přechodové pásy jako samostatný materiál
uniform float band_water = 0.75;
uniform float band_grass = 1.1;
uniform vec3 col_packed = vec3(0.72, 0.69, 0.62);   // uježděný mokrý písek u vody
uniform bool bank = false;                 // louka přímo u vody: travnatý břeh + bahno místo písečného proužku
uniform float bank_reach = 1.0;
uniform float mud_w = 0.22;
uniform vec3 col_mud = vec3(0.50, 0.46, 0.33);
uniform vec3 col_mixgrass = vec3(0.55, 0.72, 0.42); // drobné trsy / mech v písku před loukou
uniform float water_level = 0.85;
uniform bool extras = false;
uniform float wet_w = 0.9;
uniform float wet_h = 0.35;
uniform float wet_dark = 0.68;
uniform bool mat_line = true;       // obrys na hranici materiálů
uniform int grid_overlay = 0;       // 0 nic, 1 datová mřížka (bílá), 2 + duální dlaždice (červeně)
uniform float ramp_soft = 0.12;
uniform float shadow_level = 0.35;
uniform float outline_w = 0.075;
uniform float outline_dark = 0.42;
uniform float light_gain = 0.75;
uniform float pastel = 0.18;
varying vec4 edges;
varying vec3 wpos;
varying vec3 lnrm;
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}
float lum(vec3 c) { return dot(c, vec3(0.333)); }
// detail jako poměr k průměrné barvě textury (stejně jako terrain_toon v prototypu): barva zůstane barvou materiálu
float tex_detail(sampler2D t, vec2 p, float k) {
	float a = lum(texture(t, p).rgb);
	float m = max(lum(textureLod(t, vec2(0.5), 12.0).rgb), 0.01);
	return max(1.0 + (a / m - 1.0) * k, 0.3);
}
vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void vertex() {
	edges = CUSTOM0;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lnrm = NORMAL;
}
void fragment() {
	vec2 uv = (wpos.xz - rect.xy) / rect.zw;
	vec3 c;
	bool top = UV2.x > 0.5;
	if (top) {
		vec3 w = texture(splat_tex, uv).rgb;
		vec3 sandc = sand_look == 1 ? lin(col_sand2) : lin(col_sand);
		vec3 bedc = sand_look == 1 ? lin(col_bed2) : lin(col_bed);
		vec3 grassc = lin(col_grass);
		vec2 q = wpos.xz;
		float rip = 0.0;
		if (sand_detail == 1) {
			float dt = tex_detail(sand_tex, q * sand_tex_scale, sand_tex_contrast);
			sandc *= dt; bedc *= mix(1.0, dt, 0.6);
			grassc *= tex_detail(grass_tex, q * tex_scale, 0.8);
		} else if (sand_detail == 2) {
			float grain = hash12(floor(q / cell * 22.0)) - 0.5;
			rip = sin((q.x * 0.8 + q.y * 0.55) / cell * 7.0 + vnoise(q / cell * 1.3) * 4.0);
			float d2 = 1.0 + 0.16 * grain + 0.09 * rip;
			sandc *= d2; bedc *= d2;
		}
		vec4 fb = texture(field_tex, uv);
		if (bands) {
			float nb = vnoise(q / cell * 2.3);
			// pás u vody: uježděný mokrý písek, tmavší a chladnější, čeřiny souběžně s břehem
			float wb = (1.0 - smoothstep(band_water * 0.85, band_water, fb.g + (nb - 0.5) * 0.35)) * step(0.0, fb.g);
			vec3 packed = lin(col_packed) * (1.0 + 0.035 * sin(fb.g / cell * 26.0 + nb * 3.0));
			if (sand_detail == 1) packed *= mix(1.0, tex_detail(sand_tex, q * sand_tex_scale * 1.7, 1.2), 0.5);
			sandc = mix(sandc, packed, wb);
			// pás před loukou: písek prorostlý trávou (skvrny, hustší směrem k louce)
			float gb = 1.0 - smoothstep(0.0, band_grass, fb.a);
			float spots = vnoise(q / cell * 5.5) * 0.6 + vnoise(q / cell * 13.0) * 0.4;
			float gm = smoothstep(1.0 - gb * 0.75, 1.06 - gb * 0.75, spots) * step(0.001, fb.a);
			vec3 tint = mix(sandc, sandc * vec3(0.93, 0.95, 0.85), gb);   // písek do zelenošeda
			sandc = mix(tint, lin(col_mixgrass) * (0.9 + 0.2 * spots), gm);
		}
		if (sand_look == 1) bedc = mix(bedc, sandc, step(water_level, wpos.y));   // dno nad hladinou = písek pláže
		float bank_k = 0.0;
		if (bank) {
			// dno nad hladinou u louky = travnatý břeh; těsně u vody tmavý pás bahna (na trávě i na dně)
			float above = step(water_level, wpos.y);
			float nearg = 1.0 - smoothstep(bank_reach * 0.8, bank_reach, fb.a);
			bedc = mix(bedc, grassc * 0.92, above * nearg);
			bank_k = above * nearg;
			float nb2 = vnoise(q / cell * 3.1);
			float mud = (1.0 - smoothstep(mud_w * 0.3, mud_w, fb.g + (nb2 - 0.5) * 0.10)) * above * max(nearg, w.r) * (0.55 + 0.3 * nb2);
			vec3 mudc = lin(col_mud) * (0.9 + 0.2 * nb2);
			grassc = mix(grassc, mudc, mud);
			bedc = mix(bedc, mudc, mud);
		}
		c = grassc * w.r + sandc * w.g + bedc * w.b;
		// svislé stěny v duální mřížce (hybrid, strmé zkosení): hlína / písek jako boky kvádrů
		float steep = 1.0 - smoothstep(0.35, 0.6, lnrm.y);
		vec3 soil = mix(lin(vec3(0.90, 0.78, 0.55)), lin(vec3(0.66, 0.50, 0.40)), step(0.5, w.r));
		soil = mix(soil, lin(vec3(0.58, 0.46, 0.34)), bank_k);   // hliněný břeh louky místo písku
		if (sand_look == 1) soil = mix(soil, vec3(lum(soil)), 0.3);
		c = mix(c, soil * 0.92, steep);
		// jemná zrnitost po buňkách (stejná jako barevný šum prototypu)
		c *= 0.96 + 0.06 * hash12(floor(wpos.xz / cell * 4.0));
		if (mat_line) {
			float g = w.r - 0.5;
			float s = w.g - 0.5;
			float lg = 1.0 - smoothstep(0.6, 1.4, abs(g) / max(fwidth(g), 1e-4));
			lg *= 1.0 - bank_k;
			float ls = (1.0 - smoothstep(0.6, 1.4, abs(s) / max(fwidth(s), 1e-4))) * step(water_level, wpos.y);
			c *= 1.0 - 0.28 * max(lg, ls * 0.6);
		}
		// pod hladinou: dno do tyrkysova podle hloubky (základní vzhled vody, ne doplněk)
		float uw = smoothstep(0.0, 0.45, water_level - wpos.y);
		c = mix(c, c * vec3(0.55, 0.85, 0.88), uw);
		if (extras && !bands) {
			vec4 f = fb;
			float above = wpos.y - water_level;
			float wet = (1.0 - smoothstep(0.0, wet_w, f.g)) * (1.0 - smoothstep(0.0, wet_h, above)) * step(0.0, f.g);
			wet *= 1.0 - w.r;       // tráva nemokne
			c = mix(c, c * wet_dark * vec3(1.0, 0.93, 0.85), wet);
		}
	} else {
		c = lin(COLOR.rgb);
		if (sand_look == 1) c = mix(c, vec3(lum(c)), 0.3);
	}
	if (grid_overlay > 0 && top) {
		vec2 g = wpos.xz / cell;
		vec2 fw = fwidth(g);
		vec2 a = abs(fract(g + 0.5) - 0.5) / fw;
		float l1 = 1.0 - smoothstep(0.5, 1.5, min(a.x, a.y));
		c = mix(c, vec3(1.0), l1 * 0.85);
		if (grid_overlay > 1) {
			vec2 b = abs(fract(g) - 0.5) / fw;
			float dash = step(0.5, fract((g.x + g.y) * 4.0));
			float l2 = (1.0 - smoothstep(0.5, 1.5, min(b.x, b.y))) * dash;
			c = mix(c, vec3(0.85, 0.12, 0.18), l2);
			// středy buněk = rohy duálních dlaždic
			vec2 cc = (fract(g) - 0.5) * cell;
			c = mix(c, vec3(0.85, 0.12, 0.18), 1.0 - smoothstep(0.05, 0.07, length(cc)));
		}
	}
	float d = 1.0;
	if (edges.x > 0.5) d = min(d, UV.x);
	if (edges.y > 0.5) d = min(d, 1.0 - UV.x);
	if (edges.z > 0.5) d = min(d, UV.y);
	if (edges.w > 0.5) d = min(d, 1.0 - UV.y);
	float o = 1.0 - smoothstep(outline_w * 0.6, outline_w, d);
	c = mix(c, c * (1.0 - outline_dark), o);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), pastel);
	c = mix(c, vec3(1.0), pastel * 0.35);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(0.0, ramp_soft, ndl);
	float lit = mix(shadow_level * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, t * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
