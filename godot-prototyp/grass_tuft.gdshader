shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords, specular_disabled;
// Tráva C (ze studie trava-studie/shaders/grass_tuft.gdshader). Trsy trávy z prototypu (veg-v2) jako instance MultiMesh. Ohyb celého trsu stejně jako stéblo v B:
// náklon θ z větru + rozhrnutí ze stopy, oblouk se zachovanou výškou; barva z vrcholů modelu (× barva instance u kvítků).
#include "res://grass_common.gdshaderinc"
#include "res://shaders/meadow_proc.gdshaderinc"
uniform float ground_match = 0.0;   // 0 = trsy beze změny, 1 = tón trsu z procedurální louky pod ním (varianta 3 „sladěná“)
uniform vec3 col_pressed : source_color = vec3(0.86, 0.93, 0.62);
uniform float tint = 1.0;   // celkový jas
varying float vt;
varying float vr;
varying float vtr;
varying vec2 vxz;
varying vec3 vcol;
varying vec4 vfield;
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
	vt = clamp(t, 0.0, 1.0);
	vr = INSTANCE_CUSTOM.g;
	vtr = tz;
	vxz = root.xz;
	vfield = ground_match > 0.0 ? meadow_field(root.xz) : vec4(0.0);
	vec3 c = COLOR.rgb;
	vcol = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}
void fragment() {
	vec3 c = vcol;
	c *= 0.86 + 0.26 * vr;
	c = mix(c, col_pressed, vtr * 0.5 * vt);
	c *= mix(0.62, 1.0, vt);
	if (ground_match > 0.0) c = meadow_tint(c, vfield, mp_strength * ground_match);
	c *= char_shadow(vxz);
	ALBEDO = to_pastel(c) * tint * sun_tint;
}
