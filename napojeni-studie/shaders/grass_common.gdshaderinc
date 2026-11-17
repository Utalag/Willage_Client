// Společné funkce trávy: vítr (posouvaný šum + fáze stébla), rozhrnutí (stopa v textuře), stín postavičky.
uniform float sim_time = 0.0;              // deterministický čas simulace (s)
uniform sampler2D trail_tex : filter_linear, repeat_disable;  // R = čas otisku, GB = směr odhrnutí, A = síla
uniform vec4 trail_rect = vec4(0.0, 0.0, 1.0, 1.0);          // počátek XZ, velikost XZ (svět)
uniform sampler2D type_tex : filter_nearest, repeat_disable;  // výška trávy na buňku (1 = vysoká)
uniform vec4 patch_rect = vec4(0.0, 0.0, 10.0, 10.0);
uniform vec2 wind_dir = vec2(0.87, 0.5);
uniform float wind_strength = 0.35;
uniform float wind_gust = 0.45;
uniform float wind_speed = 1.6;
uniform float wind_scale = 0.22;
uniform float t_hold = 0.15;
uniform float t_recover = 1.4;
uniform float t_bend = 1.25;
uniform vec4 chars[4];                      // x, z, poloměr stínu, -
uniform vec3 sun_tint : source_color = vec3(1.0, 0.97, 0.9);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
// vektor náklonu ve větru (radiány); phase = náhodná fáze stébla 0..1
vec2 wind_at(vec2 p, float phase) {
	vec2 sp = p * wind_scale - wind_dir * sim_time * wind_speed * wind_scale;
	float n = vnoise(sp) * 0.65 + vnoise(sp * 2.3 + 7.1) * 0.35;
	float gust = smoothstep(0.35, 0.8, n);
	float flutter = sin(sim_time * 3.3 + phase * 6.2832 + hash12(floor(p * 3.0)) * 6.2832) * 0.06;
	vec2 perp = vec2(-wind_dir.y, wind_dir.x);
	return wind_dir * (wind_strength * (0.55 + 0.45 * n) + wind_gust * gust + flutter)
		+ perp * sin(sim_time * 2.1 + phase * 6.2832) * 0.05;
}
// xy = směr × míra rozhrnutí, z = míra 0..1 (může být lehce záporná = překmit)
vec3 trample_at(vec2 p) {
	vec2 uv = (p - trail_rect.xy) / trail_rect.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec3(0.0);
	vec4 t = textureLod(trail_tex, uv, 0.0);
	float dt = max(sim_time - t.r, 0.0);
	float x = clamp((dt - t_hold) / t_recover, 0.0, 1.0);
	float k = (1.0 - smoothstep(0.0, 1.0, x)) - 0.16 * sin(x * 9.4248) * (1.0 - x);  // pružný návrat s překmitem
	float a = t.a * k;
	vec2 d = t.gb;
	float dl = length(d);
	d = dl > 1e-4 ? d / dl : vec2(0.0);
	return vec3(d * a, a);
}
float char_shadow(vec2 p) {
	float s = 1.0;
	for (int i = 0; i < 4; i++) {
		float d = length(p - chars[i].xy) / max(chars[i].z, 1e-3);
		s = min(s, mix(0.62, 1.0, smoothstep(0.55, 1.0, d)));
	}
	return s;
}
vec3 to_pastel(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.12);
	return mix(c, vec3(1.0), 0.05);
}
