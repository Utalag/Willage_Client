shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, specular_disabled;
// Voda – port napojeni-studie/shaders/water.gdshader: rovná hladina, průhlednost a barva podle hloubky
// (z pole výšek terénu, ne z hloubkového bufferu), pěna u břehu + vlnky k břehu ze vzdálenostního pole [15][16][17],
// slabší pěna u travnatého břehu (foam_bank). Čas = TIME (funguje i s --fixed-fps při natáčení).
#include "res://shaders/surface_common.gdshaderinc"
uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec4 rect = vec4(0.0, 0.0, 24.0, 24.0);
uniform float cell = 1.0;
uniform float water_level = 14.85;
uniform bool extras = true;
uniform vec3 col_shallow = vec3(0.52, 0.90, 0.90);
uniform vec3 col_deep = vec3(0.24, 0.60, 0.90);
uniform vec3 col_foam = vec3(0.97, 0.99, 1.0);
uniform float foam_w = 0.32;
uniform float wave_reach = 1.3;
uniform float wave_freq = 2.2;
uniform float wave_speed = 0.35;
uniform float foam_bank = 0.3;
uniform float water_alpha = 0.55;
varying vec3 wpos;
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
	float a = mix(water_alpha, 0.88, k);
	vec2 p = wpos.xz / cell;
	float st = TIME;
	float gl = vnoise(p * 1.3 + vec2(st * 0.25, st * 0.12));
	c = mix(c, vec3(1.0), 0.12 * smoothstep(0.72, 0.78, gl));
	if (extras && !side) {
		float dist = max(-f.g, 0.0);
		float n = vnoise(p * 2.7 + vec2(st * 0.2, -st * 0.15));
		float breathe = 0.06 * sin(st * 1.4);
		float core = 1.0 - smoothstep(foam_w * 0.7, foam_w, dist + (n - 0.5) * 0.18 - breathe);
		float r = fract(dist * wave_freq - st * wave_speed + n * 0.35);
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
