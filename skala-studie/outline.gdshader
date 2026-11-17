shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
// obrys „inverted hull“: obal posunutý po vyhlazené normále (mesh musí mít hladké normály), kreslený zevnitř
uniform vec4 color : source_color = vec4(0.35, 0.28, 0.32, 1.0);
uniform float width = 0.02;   // ve světových jednotkách
void vertex() {
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + wn * width;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}
void fragment() {
	ALBEDO = color.rgb;
}
