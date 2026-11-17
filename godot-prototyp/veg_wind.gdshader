shader_type spatial;
render_mode cull_disabled, specular_disabled;
// trsy trávy / květiny: barva z vrcholů (× barva instance), houpání ve větru podle výšky vrcholu
uniform float sway = 0.10;
uniform float speed = 1.8;
uniform bool toon_on = true;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float k = max(VERTEX.y, 0.0);
	float ph = TIME * speed + w.x * 0.45 + w.z * 0.3;
	VERTEX.x += sin(ph) * sway * k * 2.0;
	VERTEX.z += cos(ph * 0.8 + 1.3) * sway * k;
	NORMAL = vec3(0.0, 1.0, 0.0);  // měkké, jednotné stínování stébel
}
void fragment() {
	vec3 c = COLOR.rgb;
	if (toon_on) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(l), 0.12);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = toon_on ? mix(0.35, 1.0, smoothstep(0.0, 0.12, ndl) * ATTENUATION)
		: clamp(ndl, 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * 0.32;
}
