shader_type spatial;
render_mode specular_disabled;
// Skalní shader (přístupy B, C, D): ploché fazety, triplanární textura, vodorovné vrstvy (strata),
// praskliny (Worley), tmavší dutiny (AO z vrcholů), světlejší horní plochy. Toon světlo jako terrain_toon.
uniform bool use_vcol = true;          // barva z vrcholů (B, C); jinak base_col (D)
uniform vec4 base_col = vec4(0.88, 0.82, 0.68, 1.0);   // sRGB (převede se v shaderu)
uniform float mat_id = 0.0;            // > 0: index materiálu pro texturu (D); jinak UV2.x
uniform bool flat_facets = true;
uniform vec3 cell = vec3(0.5, 0.5, 0.5);   // velikost buňky (vrstvy a praskliny se škálují s ní)
uniform bool use_tex = true;
uniform sampler2DArray tex_arr : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.25;
uniform float tex_contrast = 1.0;
uniform float ground_ao = 0.22;     // ztmavení u země (kontaktní stín)
uniform float strata_strength = 1.0;
uniform float crack_strength = 1.0;
uniform float ramp_soft = 0.12;
uniform float shadow_level = 0.35;
uniform float light_gain = 0.75;
uniform float pastel = 0.12;
varying vec3 wpos;
varying vec3 wnrm_s;
varying flat float vmat;   // materiál bez interpolace (jinak by se mezi trávou a kamenem míchaly indexy textur)

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
vec3 h33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
// Worley: vrací F2 − F1 (malé = hrana buňky = prasklina)
float worley_edge(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	float f1 = 8.0; float f2 = 8.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 d = g + h33(i + g) - f;
		float dd = dot(d, d);
		if (dd < f1) { f2 = f1; f1 = dd; } else if (dd < f2) { f2 = dd; }
	}
	return sqrt(f2) - sqrt(f1);
}
vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm_s = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vmat = UV2.x;
}
void fragment() {
	vec3 wn = normalize(wnrm_s);
	if (flat_facets) {
		vec3 fn = normalize(cross(dFdy(wpos), dFdx(wpos)));
		if (dot(fn, wn) < 0.0) fn = -fn;
		wn = fn;
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	vec3 c = use_vcol ? lin(COLOR.rgb) : lin(base_col.rgb);
	float mid = mat_id > 0.5 ? mat_id : vmat;
	float stone = (mid > 4.5 && mid < 9.5) ? 1.0 : 0.0;   // vrstvy a praskliny jen u hornin (vápenec … železná ruda)
	vec3 q = wpos / cell;     // souřadnice v buňkách
	if (use_tex && mid > 0.5) {
		vec3 bw = pow(abs(wn), vec3(4.0)); bw /= (bw.x + bw.y + bw.z);
		float li = clamp(floor(mid + 0.5) - 1.0, 0.0, 9.0);
		vec3 tx = texture(tex_arr, vec3(wpos.zy * tex_scale, li)).rgb * bw.x
			+ texture(tex_arr, vec3(wpos.xz * tex_scale, li)).rgb * bw.y
			+ texture(tex_arr, vec3(wpos.xy * tex_scale, li)).rgb * bw.z;
		vec3 mn = max(textureLod(tex_arr, vec3(0.5, 0.5, li), 12.0).rgb, vec3(0.01));
		float d = dot(tx, vec3(0.333)) / dot(mn, vec3(0.333));
		c *= max(1.0 + (d - 1.0) * tex_contrast, 0.3);
	}
	float side = 1.0 - smoothstep(0.55, 0.8, abs(wn.y));
	// strata: 2 vrstvy na buňku výšky, mírně zvlněné, střídavě světlejší/tmavší, tenké tmavé spáry (jen boky)
	float sq = q.y * 2.0 + 0.5 * (vnoise(vec3(q.x, 0.0, q.z) * 0.7) - 0.5) + 0.15 * vnoise(q * 3.1);
	float band = floor(sq);
	float tone = 1.0 + 0.16 * (h31(vec3(band, 7.0, 3.0)) - 0.5) * 2.0;
	float fs = fract(sq);
	float seam = 1.0 - smoothstep(0.0, 0.05, min(fs, 1.0 - fs));
	c *= mix(1.0, tone * (1.0 - 0.35 * seam), side * strata_strength * stone);
	// praskliny: tenké Worley hrany jen v řídkých místech (maska ~20 % plochy), hlavně svislé na bocích
	float ce = worley_edge(q * vec3(0.9, 0.6, 0.9));
	float mask = smoothstep(0.62, 0.72, vnoise(q * 0.7 + 11.0));
	float crack = (1.0 - smoothstep(0.015, 0.04, ce)) * mask * mix(0.35, 1.0, side);
	c *= 1.0 - 0.5 * crack * crack_strength * stone;
	// drobné skvrny (lišejník/zvětrání) – velmi jemné
	c *= 1.0 - 0.07 * smoothstep(0.55, 0.8, vnoise(q * 2.2 + 3.0));
	c *= 1.0 - ground_ao * (1.0 - smoothstep(0.0, 1.5 * cell.y, wpos.y));
	// horní plochy světlejší (zvětralý vrch), mírně do teplejší
	c *= 1.0 + 0.04 * smoothstep(0.6, 0.95, wn.y);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), pastel);
	c = mix(c, vec3(1.0), pastel * 0.35);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(0.0, ramp_soft, ndl);
	float lit = mix(shadow_level * mix(0.55, 1.0, smoothstep(-1.0, 0.0, ndl)), 1.0, t * ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * light_gain;
}
