shader_type spatial;
render_mode specular_disabled;
// Kawaii toon (podle godot-prototyp/object_toon.gdshader): měkký dvoustupňový ramp, pastel.
uniform vec3 albedo : source_color = vec3(1.0);
uniform bool ground = false;       // zem: nahoře barva podkladu trávy + jemná mřížka buněk, boky hlína s pruhy
uniform vec3 side_col : source_color = vec3(0.66, 0.50, 0.40);
uniform float cell = 1.0;
uniform float grid_dark = 0.08;
uniform float light_gain = 0.32;
uniform float exposure = 0.74;     // ambient + slunce v Compatibility přepalovalo pastel  // jako object_toon v prototypu (Lambert 1/π)
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	vec3 c = albedo;
	if (ground) {
		if (wn.y > 0.5) {
			vec2 g = abs(fract(wp.xz / cell + 0.5) - 0.5);
			float line = 1.0 - smoothstep(0.0, 0.03, min(g.x, g.y));
			c *= 1.0 - grid_dark * line;
		} else {
			c = side_col * (0.92 + 0.08 * step(0.5, fract(wp.y / (cell * 0.25))));
		}
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.1);
	ALBEDO = c * exposure;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = mix(0.35 * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, smoothstep(0.0, 0.12, ndl) * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
