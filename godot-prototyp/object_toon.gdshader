shader_type spatial;
render_mode specular_disabled;
// Kawaii toon pro objekty (vegetace z Blenderu, domky, cesty): stejný ramp a pastel jako terrain_toon.gdshader
uniform vec4 albedo = vec4(1.0);      // lineární barva
uniform bool use_vcol = false;        // násobit barvou vrcholů (sRGB)
uniform bool toon_on = true;
uniform float ramp_soft = 0.12;
uniform float shadow_level = 0.35;
uniform float light_gain = 0.32;  // objekty: jako Lambert (1/π)
uniform float pastel = 0.06;   // objekty mají barvy už pastelové z Blenderu
void fragment() {
	vec3 c = albedo.rgb;
	if (use_vcol) {
		c *= mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, COLOR.rgb));
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
	float lit;
	if (toon_on) {
		lit = mix(shadow_level * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, smoothstep(0.0, ramp_soft, ndl) * ATTENUATION);  // odvrácené plochy plynule tmavší, nikdy jen ambient
	} else {
		lit = clamp(ndl, 0.0, 1.0) * ATTENUATION;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
