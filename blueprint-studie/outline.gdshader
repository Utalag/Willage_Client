shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
// obrys objektů metodou „inverted hull“: zvětšený obal kreslený zevnitř, barva = ztmavená barva objektu
uniform vec4 color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float width = 0.025;
uniform bool enabled = true;
uniform vec3 pivot = vec3(0.0, 0.6, 0.0);
void vertex() {
	// průměr normály a směru od středu objektu: obal se uzavře i u ostrých hran (kostky, low-poly)
	vec3 dir;
	if (CUSTOM0.w > 0.5) {
		dir = normalize(CUSTOM0.xyz);   // vyhlazená normála z Toon.with_smooth_normals
	} else {
		vec3 r = VERTEX - pivot;
		dir = normalize(normalize(NORMAL) + (length(r) > 0.001 ? normalize(r) : vec3(0.0)));
	}
	VERTEX += dir * width;
}
void fragment() {
	if (!enabled) discard;
	ALBEDO = color.rgb;
}
