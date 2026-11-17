shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, specular_disabled;
// Voda buněčné simulace. Převzato a zjednodušeno z napojeni-studie/shaders/water.gdshader:
// barva a průhlednost podle hloubky (tady hloubka sloupce vody z dat simulace ve COLOR.r, ne z hloubkového bufferu),
// odlesky ze šumu. COLOR.g = rychlost proudění (0–1) -> světlejší „peřeje“ na potocích.
uniform float sim_time = 0.0;
uniform vec3 col_shallow = vec3(0.52, 0.90, 0.90);
uniform vec3 col_deep = vec3(0.24, 0.60, 0.90);
uniform vec3 col_foam = vec3(0.97, 0.99, 1.0);
varying vec3 wpos;
varying vec4 vcol;
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
	vcol = COLOR;
}
void fragment() {
	float k = smoothstep(0.0, 0.8, vcol.r);
	vec3 c = mix(lin(col_shallow), lin(col_deep), k);
	float a = mix(0.55, 0.88, k);
	float gl = vnoise(wpos.xz * 1.3 + vec2(sim_time * 0.25, sim_time * 0.12));
	c = mix(c, vec3(1.0), 0.12 * smoothstep(0.72, 0.78, gl));
	float n = vnoise(wpos.xz * 3.0 + vec2(0.0, -sim_time * 0.8));
	float foam = vcol.g * smoothstep(0.45, 0.7, n);
	c = mix(c, lin(col_foam), foam * 0.7);
	a = max(a, foam * 0.8);
	ALBEDO = c * 0.95;
	ALPHA = a;
}
