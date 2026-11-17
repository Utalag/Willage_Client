shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, specular_disabled;
// Voda: rovná hladina, průhlednost a barva podle hloubky (z výškového pole terénu, ne z hloubkového bufferu).
// Doplněk: pevný pás pěny u břehu + vlnky postupující k břehu (vzdálenostní pole), lehké „dýchání“ čáry pěny.
uniform sampler2D field_tex : filter_linear, repeat_disable;   // R výška terénu, G vzdálenost (− = voda, v buňkách)
uniform vec4 rect = vec4(0.0, 0.0, 20.0, 20.0);
uniform float cell = 1.0;
uniform float water_level = 0.85;
uniform float sim_time = 0.0;
uniform bool extras = false;
uniform vec3 col_shallow = vec3(0.52, 0.90, 0.90);
uniform vec3 col_deep = vec3(0.24, 0.60, 0.90);
uniform vec3 col_foam = vec3(0.97, 0.99, 1.0);
uniform float foam_w = 0.32;
uniform float wave_reach = 1.6;
uniform float wave_freq = 2.2;
uniform float wave_speed = 0.35;
uniform float foam_bank = 1.0;   // síla pěny u travnatého břehu (field A = vzdálenost k louce)
varying vec3 wpos;
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}
vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = clamp((wpos.xz - rect.xy) / rect.zw, vec2(0.0005), vec2(0.9995));
	vec4 f = texture(field_tex, uv);
	bool side = UV2.x < 0.5;
	float depth = side ? (water_level - wpos.y) + 0.3 : water_level - f.r;
	if (!side && depth < 0.0) discard;
	float k = smoothstep(0.0, 0.55, depth);
	vec3 c = mix(lin(col_shallow), lin(col_deep), k);
	float a = mix(0.55, 0.88, k);
	// jemné odlesky (toon „proužky“)
	vec2 p = wpos.xz / cell;
	float gl = vnoise(p * 1.3 + vec2(sim_time * 0.25, sim_time * 0.12));
	c = mix(c, vec3(1.0), 0.12 * smoothstep(0.72, 0.78, gl));
	if (extras && !side) {
		float dist = max(-f.g, 0.0);              // vzdálenost od břehu (buňky)
		float n = vnoise(p * 2.7 + vec2(sim_time * 0.2, -sim_time * 0.15));
		float breathe = 0.06 * sin(sim_time * 1.4);
		float core = 1.0 - smoothstep(foam_w * 0.7, foam_w, dist + (n - 0.5) * 0.18 - breathe);
		float r = fract(dist * wave_freq - sim_time * wave_speed + n * 0.35);
		float lines = smoothstep(0.80, 0.86, r) * (1.0 - smoothstep(0.92, 0.98, r)) * step(0.38, n)
			* (1.0 - smoothstep(wave_reach * 0.5, wave_reach, dist));
		float grassy = 1.0 - smoothstep(0.25, 0.6, f.a - dist);   // nejbližší souš je louka
		float fk = mix(1.0, foam_bank, grassy);
		float foam = max(core, lines * 0.6) * fk;
		c = mix(c, lin(col_foam), foam);
		a = max(a, foam * 0.95);
	}
	if (side) a = 0.75;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.1);
	ALBEDO = c * 0.95;
	ALPHA = a;
}
