extends RefCounted
## E53 A: mělká voda jako „virtuální trubky“ (Mei a kol. 2007 [34], styl Stam): výška vody d a toky f po 4 hranách
## v KAŽDÉ buňce, všechna pole se mění každý krok (explicitně). Buňka l = 0,5 m. Okraj mapy = odtok (hladina −∞).
## f ← max(0, f · (1 − c_f·dt) + dt · g · l · ΔH) (průřez trubky l², délka l), pak škálování, aby buňka nevydala víc,
## než má; d += dt · (přítoky − odtoky + pramen) / l². Rychlost z toků přes hrany / (l · d).
## Volitelně okno [ax..bx]×[ay..by]: mimo okno se nic nemění (lokální přepočet po změně hráče).

const DX4 := [1, -1, 0, 0]
const DY4 := [0, 0, 1, -1]
const G := 9.81

static func make(W: int, H: int, b: PackedFloat64Array, wall: PackedByteArray, src_m3s: PackedFloat64Array, l: float) -> Dictionary:
	var n := W * H
	var d := PackedFloat64Array(); d.resize(n)
	var f := PackedFloat64Array(); f.resize(4 * n)
	return {"W": W, "H": H, "b": b, "wall": wall, "src": src_m3s, "l": l, "d": d, "f": f, "out": 0.0, "steps": 0}

## kroky do ustálení: max |Δd| za krok < tol_m a |výtok − přítok| < tol_q · přítok. Vrací {steps, ms, steady, out, inq}.
static func run(st: Dictionary, o: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var W: int = st.W; var H: int = st.H; var n := W * H
	var dt := float(o.get("dt", 0.05)); var cf := float(o.get("cf", 2.0))
	var maxs := int(o.get("max_steps", 4000)); var tol := float(o.get("tol_m", 1e-6)); var tolq := float(o.get("tol_q", 0.01))
	var ax := int(o.get("ax", 0)); var bx := int(o.get("bx", W - 1)); var ay := int(o.get("ay", 0)); var by := int(o.get("by", H - 1))
	var b: PackedFloat64Array = st.b; var wall: PackedByteArray = st.wall; var src: PackedFloat64Array = st.src
	var d: PackedFloat64Array = st.d; var f: PackedFloat64Array = st.f
	var l: float = st.l; var A := l * l
	var inq := 0.0
	for x in range(ax, bx + 1):
		for y in range(ay, by + 1): inq += src[x * H + y]
	var steps := 0; var steady := false; var out := 0.0; var calm := 0
	var nd := PackedFloat64Array(); nd.resize(n)
	while steps < maxs:
		steps += 1
		# průchod 1: toky (každá buňka čte jen hladiny sousedů)
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				if wall[i] == 1: continue
				var hi := b[i] + d[i]; var s := 0.0
				for e in 4:
					var qx: int = x + DX4[e]; var qy: int = y + DY4[e]
					var dh: float
					if qx < 0 or qy < 0 or qx >= W or qy >= H: dh = d[i]   # okraj: voda odtéká přes hranu
					else:
						var j := qx * H + qy
						if wall[j] == 1: f[4 * i + e] = 0.0; continue
						dh = hi - b[j] - d[j]
					var v := maxf(0.0, f[4 * i + e] * (1.0 - cf * dt) + dt * G * l * dh)
					f[4 * i + e] = v; s += v
				if s * dt > d[i] * A and s > 0.0:
					var kk := d[i] * A / (s * dt)
					for e in 4: f[4 * i + e] *= kk
		# průchod 2: objemy
		var mx := 0.0; out = 0.0
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				if wall[i] == 1: continue
				var vin := src[i]; var vout := 0.0
				for e in 4:
					vout += f[4 * i + e]
					var qx: int = x + DX4[e]; var qy: int = y + DY4[e]
					if qx < 0 or qy < 0 or qx >= W or qy >= H: out += f[4 * i + e]; continue
					var j := qx * H + qy
					vin += f[4 * j + (e ^ 1)]   # protisměrná hrana souseda (0↔1, 2↔3)
				var dd := dt * (vin - vout) / A
				nd[i] = maxf(0.0, d[i] + dd); mx = maxf(mx, absf(dd))
		for x in range(ax, bx + 1):
			for y in range(ay, by + 1):
				var i := x * H + y
				if wall[i] == 0: d[i] = nd[i]
		if mx < tol and absf(out - inq) < tolq * maxf(inq, 1e-9): calm += 1
		else: calm = 0
		if calm >= 20: steady = true; break
	st.steps = int(st.steps) + steps; st.out = out
	return {"steps": steps, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "steady": steady, "out": out, "inq": inq}

## průtok buňkou (m³/s, polovina součtu přítoků a odtoků přes hrany) a rychlost (m/s)
static func flow(st: Dictionary, i: int) -> Vector2:
	var W: int = st.W; var H: int = st.H; var f: PackedFloat64Array = st.f
	var x := i / H; var y := i % H
	var fx := f[4 * i] - f[4 * i + 1]; var fy := f[4 * i + 2] - f[4 * i + 3]   # odtoky buňky (+x, −x, +y, −y)
	if x > 0: fx += f[4 * (i - H)]            # přítok zleva (soused posílá +x)
	if x < W - 1: fx -= f[4 * (i + H) + 1]    # přítok zprava (soused posílá −x)
	if y > 0: fy += f[4 * (i - 1) + 2]
	if y < H - 1: fy -= f[4 * (i + 1) + 3]
	return Vector2(fx, fy) * 0.5
