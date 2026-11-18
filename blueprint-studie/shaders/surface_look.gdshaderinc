// Vzhled písku a louky sdílený povrchem duální mřížky (terrain_surface) i kostkovým terénem (terrain_toon),
// aby louka a písek vypadaly stejně na duální i na kostkové části. Barvy a síly nastavuje SurfaceRenderer ze SurfaceParams.
uniform int sand_look = 1;                 // 0 původní, 1 šedobéžový
uniform vec3 col_sand = vec3(0.98, 0.89, 0.62);
uniform vec3 col_sand2 = vec3(0.84, 0.78, 0.67);
uniform int sand_detail = 2;               // 0 nic, 2 procedurální zrno + čeřiny
uniform float sand_grain = 0.16;
uniform float sand_ripple = 0.09;
uniform float sand_ripple_freq = 7.0;
uniform vec3 col_grass = vec3(0.56, 0.80, 0.47);
uniform bool pg_enabled = true;
uniform float pg_streak = 0.12;
uniform float pg_streak_w = 30.0;
uniform float pg_streak_len = 7.0;
uniform float pg_grain = 0.07;
uniform float pg_clover = 0.7;
uniform vec2 wind_dir_s = vec2(0.87, 0.5);

// procedurální zrno + čeřiny písku (napojeni-studie terrain.gdshader, sand_detail 2)
float sand_mod(vec2 q) {
	if (sand_detail != 2) return 1.0;
	float grain = hash12(floor(q * 22.0)) - 0.5;
	float rip = sin((q.x * 0.8 + q.y * 0.55) * sand_ripple_freq + vnoise(q * 1.3) * 4.0);
	return 1.0 + sand_grain * grain + sand_ripple * rip;
}
// procedurální zem louky (trava-studie meadow_ground.gdshader): fleky, sucho, jetel, žíhání stébel, zrno
vec3 meadow_ground(vec3 c, vec2 p) {
	if (!pg_enabled) return c;
	vec2 q = p / mp_cell;
	float s = mp_strength;
	vec4 f = meadow_field(p);
	c = meadow_tint(c, f, s);
	vec2 wd = wind_dir_s;
	vec2 r = vec2(dot(q, wd), dot(q, vec2(-wd.y, wd.x)));
	float aa = clamp(1.6 - fwidth(r.y * pg_streak_w) * 1.2, 0.0, 1.0);
	float st = vnoise(vec2(r.x * pg_streak_len, r.y * pg_streak_w)) * 0.65 + vnoise(vec2(r.x * pg_streak_len * 2.1 + 3.0, r.y * pg_streak_w * 2.3)) * 0.35;
	c *= 1.0 + (st - 0.5) * 2.0 * pg_streak * s * (1.0 + f.z * 0.8) * aa;
	float gr = hash12(floor(q * 22.0)) - 0.5;
	c *= 1.0 + gr * pg_grain * s * clamp(1.6 - fwidth(q.x * 22.0) * 1.2, 0.0, 1.0);
	if (pg_clover > 0.0 && f.w > 0.01) {
		vec2 g = q * 5.0;
		vec2 id = floor(g);
		vec2 o = vec2(hash12(id + 7.0), hash12(id + 13.0)) * 0.4 - 0.2;
		vec2 lp = fract(g) - 0.5 - o;
		float a0 = hash12(id) * 6.2832;
		float leaf = 0.0;
		for (int k = 0; k < 3; k++) {
			float a = a0 + float(k) * 2.0944;
			leaf = max(leaf, 1.0 - smoothstep(0.11, 0.15, length(lp - vec2(cos(a), sin(a)) * 0.13)));
		}
		leaf *= step(0.55, hash12(id + 3.0));
		float ca = clamp(1.6 - fwidth(g.x) * 2.0, 0.0, 1.0);
		c = mix(c, c * vec3(0.92, 1.12, 0.98) * 1.18, leaf * f.w * pg_clover * s * ca);
	}
	return c;
}
