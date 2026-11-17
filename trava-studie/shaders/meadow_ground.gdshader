shader_type spatial;
render_mode specular_disabled;
// Procedurální zem louky pod trsy C (analogicky k procedurálnímu písku v napojeni-studie/terrain.gdshader):
// méně sytá zelená, velké fleky + suchá místa + jetel (meadow_proc), drobné žíhání stébel po směru větru,
// zrno po buňkách, světlejší sklopená tráva ve stopě, stín postavičky. Osvětlení = toon.gdshader (stejný ramp jako zem studie).
#include "res://shaders/grass_common.gdshaderinc"
#include "res://shaders/meadow_proc.gdshaderinc"
uniform vec3 albedo : source_color = vec3(0.33, 0.49, 0.31);
uniform float desat = 0.18;           // ubrání sytosti (toon.gdshader má 0,1)
uniform float streak = 0.12;          // síla žíhání stébel
uniform float streak_w = 30.0;        // žíhání napříč větrem (pruhů na buňku)
uniform float streak_len = 7.0;       // podél větru (1/délka v buňkách): 7 = čárky ~0,15 buňky, delší vypadaly jako déšť
uniform float grain = 0.07;           // zrno po buňkách (jako písek: 22 zrn na buňku)
uniform float clover = 0.7;           // kreslit lístky jetele v svěžích skvrnách
uniform float trampled = 0.10;        // zesvětlení sklopené trávy ve stopě
uniform float light_gain = 0.32;
uniform float exposure = 0.74;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz;
	vec2 q = p / mp_cell;
	float s = mp_strength;
	vec3 c = albedo;
	vec4 f = meadow_field(p);
	c = meadow_tint(c, f, s);
	// žíhání stébel: anizotropní šum protažený po směru větru (stébla polehlá větrem)
	vec2 wd = wind_dir;
	vec2 r = vec2(dot(q, wd), dot(q, vec2(-wd.y, wd.x)));
	float aa = clamp(1.6 - fwidth(r.y * streak_w) * 1.2, 0.0, 1.0);        // z dálky útlum (bez blikání)
	float st = vnoise(vec2(r.x * streak_len, r.y * streak_w)) * 0.65 + vnoise(vec2(r.x * streak_len * 2.1 + 3.0, r.y * streak_w * 2.3)) * 0.35;
	c *= 1.0 + (st - 0.5) * 2.0 * streak * s * (1.0 + f.z * 0.8) * aa;
	float gr = hash12(floor(q * 22.0)) - 0.5;
	c *= 1.0 + gr * grain * s * clamp(1.6 - fwidth(q.x * 22.0) * 1.2, 0.0, 1.0);
	// jetel: trojlístky na mřížce 5 × 5 na buňku, jen ve svěžích skvrnách
	if (clover > 0.0 && f.w > 0.01) {
		vec2 g = q * 5.0;
		vec2 id = floor(g);
		vec2 o = vec2(hash12(id + 7.0), hash12(id + 13.0)) * 0.4 - 0.2;
		vec2 lp = fract(g) - 0.5 - o;
		float a0 = hash12(id) * 6.2832;
		float leaf = 0.0;
		for (int k = 0; k < 3; k++) {
			float a = a0 + float(k) * 2.0944;
			leaf = max(leaf, 1.0 - smoothstep(0.11, 0.15, length(lp - vec2(cos(a), sin(a)) * 0.13)));
		}
		leaf *= step(0.55, hash12(id + 3.0));
		float ca = clamp(1.6 - fwidth(g.x) * 2.0, 0.0, 1.0);
		c = mix(c, c * vec3(0.92, 1.12, 0.98) * 1.18, leaf * f.w * clover * s * ca);
	}
	// sklopená tráva ve stopě je světlejší (rub stébel)
	float tz = max(trample_at(p).z, 0.0);
	c *= 1.0 + trampled * tz;
	c *= char_shadow(p);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desat);
	ALBEDO = c * exposure;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = mix(0.35 * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, smoothstep(0.0, 0.12, ndl) * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
