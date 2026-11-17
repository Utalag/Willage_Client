shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords, specular_disabled;
// B) Instancovaná stébla (MultiMesh): každé stéblo = zúžený pásek ze 3 segmentů (5 trojúhelníků).
// Ohyb ve vertex shaderu: náklon θ z větru (fáze stébla) + rozhrnutí ze stopy, oblouk se zachovanou délkou.
#include "res://shaders/grass_common.gdshaderinc"
uniform vec3 col_root : source_color = vec3(0.24, 0.45, 0.30);
uniform vec3 col_tip : source_color = vec3(0.72, 0.92, 0.55);
uniform vec3 col_tip_short : source_color = vec3(0.62, 0.86, 0.50);
uniform vec3 col_pressed : source_color = vec3(0.86, 0.93, 0.62);
uniform float tall_cut = 0.1;   // stébla delší než tohle jsou „vysoká“ (barva špiček)
varying float vt;
varying float vr;
varying float vtr;
varying float vtall;
varying vec2 vxz;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float t = UV.y;
	float L = length(MODEL_MATRIX[1].xyz);
	vec3 rel = VERTEX - root;
	vec2 side = rel.xz;
	vec3 tr = trample_at(root.xz);
	float tz = max(tr.z, 0.0);
	vec2 w = wind_at(root.xz, INSTANCE_CUSTOM.r);
	vec2 lean = (w + INSTANCE_CUSTOM.ba) * (1.0 - tz) + tr.xy * t_bend;
	float th = min(length(lean), 1.45);
	vec2 dn = th > 1e-4 ? lean / length(lean) : vec2(0.0);
	float hz = L * sin(th) * t * t;
	float vy = L * t * (1.0 - (1.0 - cos(th)) * t);
	VERTEX = root + vec3(side.x + dn.x * hz, vy, side.y + dn.y * hz);
	vt = t;
	vr = INSTANCE_CUSTOM.g;
	vtr = tz;
	vtall = step(tall_cut, L);
	vxz = root.xz;
}
void fragment() {
	vec3 tip = vtall > 0.5 ? col_tip : col_tip_short;
	vec3 c = mix(col_root, tip, smoothstep(0.0, 1.0, vt));
	c *= 0.86 + 0.26 * vr;
	c = mix(c, col_pressed, vtr * 0.6 * vt);
	c *= mix(0.62, 1.0, vt);
	c *= char_shadow(vxz);
	ALBEDO = to_pastel(c) * sun_tint;
}
