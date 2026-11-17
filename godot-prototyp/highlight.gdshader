shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// rámeček slotu: platné místo pro nový blok
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float strength = 0.6;
void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float e = min(d.x, d.y);
	float frame = 1.0 - smoothstep(0.012, 0.03, e);
	float fill = 0.06;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((frame + fill) * strength * pulse, 0.0, 1.0);
}
