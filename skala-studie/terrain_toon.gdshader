shader_type spatial;
render_mode specular_disabled;
// Kawaii vzhled terénu: barva z vrcholů, měkký dvoustupňový toon ramp, obrysy na hranách srázů (z CUSTOM0)
uniform float ramp_soft = 0.12;      // šířka přechodu světlo/stín
uniform float shadow_level = 0.35;   // kolik přímého světla zůstane ve stínu
uniform float outline_w = 0.075;     // šířka obrysu (v buňce, 0..0,5)
uniform float outline_dark = 0.42;   // ztmavení barvy obrysu
uniform bool use_outline = true;
uniform bool use_bevel = false;       // „zaoblené“ hrany: světlý lem na horních hranách, tmavší na bočních (B přepíná)
uniform float bevel_w = 0.3;
uniform float light_gain = 0.75;
uniform float pastel = 0.18;          // posun k pastelu: méně sytosti, víc světla
uniform bool use_tex = false;         // textury materiálů (Gemini v2), X přepíná
uniform sampler2DArray tex_arr : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.25;       // 1 opakování textury na 4 m
uniform float tex_mix = 1.0;          // míra použití textury
uniform float tex_contrast = 1.8;     // zesílení detailu
uniform float tex_hue = 0.2;          // kolik odstínu převzít z textury (zbytek = barva materiálu)
varying vec4 edges;
varying vec3 lpos;
varying vec3 lnrm;
void vertex() {
	edges = CUSTOM0;
	lpos = VERTEX;
	lnrm = NORMAL;
}
void fragment() {
	vec3 c = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, COLOR.rgb));
	if (use_tex && UV2.x > 0.5) {
		vec2 tc = abs(lnrm.y) > 0.5 ? lpos.xz : (abs(lnrm.x) > 0.5 ? lpos.zy : lpos.xy);
		int li = clamp(int(UV2.x + 0.5) - 1, 0, 9);
		vec3 tx = texture(tex_arr, vec3(tc * tex_scale, float(li))).rgb;
		vec3 mn = max(textureLod(tex_arr, vec3(0.5, 0.5, float(li)), 12.0).rgb, vec3(0.01));  // nejmenší mip = průměr
		float lm = dot(mn, vec3(0.333));
		// detail = poměr k průměru textury; barva zůstane barvou materiálu (jas a stínování z vrcholů)
		vec3 detail = mix(vec3(dot(tx, vec3(0.333)) / lm), tx / mn, 0.5);
		vec3 hue = mn / lm * dot(c, vec3(0.333));
		vec3 base = mix(c, hue, tex_hue);
		detail = max(vec3(1.0) + (detail - vec3(1.0)) * tex_contrast, vec3(0.2));
		c = mix(c, base * detail, tex_mix);
	}
	float d = 1.0;
	if (edges.x > 0.5) d = min(d, UV.x);
	if (edges.y > 0.5) d = min(d, 1.0 - UV.x);
	if (edges.z > 0.5) d = min(d, UV.y);
	if (edges.w > 0.5) d = min(d, 1.0 - UV.y);
	if (use_bevel) {
		float bv = 1.0 - smoothstep(0.0, bevel_w, d);
		bv = bv * bv * (3.0 - 2.0 * bv);
		c *= lnrm.y > 0.5 ? 1.0 + 0.45 * bv : 1.0 - 0.28 * bv;
	}
	if (use_outline) {
		float o = 1.0 - smoothstep(outline_w * 0.6, outline_w, d);
		c = mix(c, c * (1.0 - outline_dark), o);
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), pastel);
	c = mix(c, vec3(1.0), pastel * 0.35);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(0.0, ramp_soft, ndl);
	// odvrácené stěny = stejná úroveň jako stín (dřív step() → jen ambient, při pohledu od SZ/S téměř černé)
	float lit = mix(shadow_level * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, t * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
