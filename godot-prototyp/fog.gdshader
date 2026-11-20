shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float layer_alpha = 0.16;
uniform float seed = 0.0;
uniform float noise_k = 0.12;   // E94: frekvence šumu na jednotku scény (0,12 na buňku; v metrech 0,24)
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = UV;
	float e = 0.18;
	float edge = smoothstep(0.0, e, uv.x) * smoothstep(0.0, e, 1.0 - uv.x) * smoothstep(0.0, e, uv.y) * smoothstep(0.0, e, 1.0 - uv.y);
	float n = fbm(wpos.xz * noise_k + vec2(seed * 3.7, seed * 1.3));
	ALBEDO = vec3(0.96, 0.97, 1.0);
	ALPHA = clamp(layer_alpha * edge * (0.25 + 1.3 * n), 0.0, 1.0);
}
