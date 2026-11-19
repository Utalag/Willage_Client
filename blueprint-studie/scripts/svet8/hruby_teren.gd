extends RefCounted
## E49 fáze 1: hrubá výšková mapa celého světa naráz. Mřížka R × R, R = dlaždic × s8_px (1 bod = 1 m = 2 řídicí body bloku).
## Výška v buňkách (0,5 m): nížina kolem surf_ref, pohoří = hřbetový šum v masce, pánve jezer (šum, mimo hory), jedna sopka (kužel s kráterem) ve středu dlaždice
## mimo pohoří. Tektonika = znaménko pomalého šumu (vyzdvižená / zvrásněná hora).

const BG = preload("res://scripts/kopie/block_gen.gd")

static func run(seed: int, p: Dictionary) -> Dictionary:
	var T: int = int(p.s8_tiles); var PX: int = int(p.s8_px); var R := T * PX
	var nb := BG.noise(seed, "S8_BASE", 0, 0.03, 4)
	var nr := BG.noise(seed, "S8_RIDGE", 0, 0.045, 3)
	var nm := BG.noise(seed, "S8_MTN", 0, 0.018, 2)
	var nt := BG.noise(seed, "S8_TECT", 0, 0.03, 1)
	var nl := BG.noise(seed, "S8_LAKE", 0, 0.04, 2)
	var hm := PackedFloat64Array(); hm.resize(R * R)
	var mtn := PackedFloat64Array(); mtn.resize(R * R)
	var ref := float(p.surf_ref)
	var on56 := bool(p.get("s56_on", false))   # E56 mírnější přechody (výchozí vypnuto → E49 beze změny)
	var lo56 := 0.05 - (float(p.get("s56_paty", 0.0)) if on56 else 0.0)
	var hr56 := float(p.get("s56_hreben", 2.0)) if on56 else 2.0
	for x in R:
		for y in R:
			var m := smoothstep(lo56, 0.45, nm.get_noise_2d(x, y) + float(p.s8_mtn_bias))
			var rd := 1.0 - absf(nr.get_noise_2d(x, y))
			mtn[x * R + y] = m
			var lk := smoothstep(0.35, 0.7, nl.get_noise_2d(x, y)) * (1.0 - m)   # pánve jezer mimo hory
			hm[x * R + y] = ref + float(p.s8_base_amp) * nb.get_noise_2d(x, y) + m * float(p.s8_mtn_amp) * (rd * rd if hr56 == 2.0 else pow(rd, hr56)) - float(p.s8_lake_amp) * lk
	# sopka: dlaždice mimo pohoří a mimo okraj s nejvyšším skóre šumu
	var nv := BG.noise(seed, "S8_VOLC", 0, 0.3, 1)
	var best := -1e9; var vt := Vector2i(-1, -1)
	for tx in range(1, T - 1):
		for ty in range(1, T - 1):
			var c := (tx * PX + PX / 2) * R + ty * PX + PX / 2
			var sc := nv.get_noise_2d(tx, ty) - 3.0 * mtn[c]
			if sc > best: best = sc; vt = Vector2i(tx, ty)
	if int(p.s8_volcano) == 1 and vt.x >= 0:
		var cx := vt.x * PX + PX * 0.5 - 0.5; var cy := vt.y * PX + PX * 0.5 - 0.5
		for x in range(vt.x * PX - 2, vt.x * PX + PX + 2):
			for y in range(vt.y * PX - 2, vt.y * PX + PX + 2):
				if x < 0 or y < 0 or x >= R or y >= R: continue
				var r := Vector2(x - cx, y - cy).length() * 2.0   # v řídicích bodech (jako šablona sopky)
				var c := 22.0 * pow(clampf(1.0 - r / 8.5, 0.0, 1.0), 1.15) - (4.0 if r < 1.8 else 0.0)
				hm[x * R + y] += c
	var s56 := {}
	if on56:
		var SV = load("res://scripts/svah56/svah.gd")
		SV.smooth(hm, R, int(p.get("s56_hladit", 0)), float(p.get("s56_hladit_w", 0.5)))
		if float(p.get("s56_max_slope", 0.0)) > 0.0: s56 = SV.limit(hm, R, float(p.s56_max_slope), int(p.get("s56_pasy", 200)))
	var tect := PackedFloat64Array(); tect.resize(R * R)
	for x in R:
		for y in R:
			hm[x * R + y] = clampf(hm[x * R + y], 28.0, 60.0)
			tect[x * R + y] = nt.get_noise_2d(x, y)
	return {"R": R, "T": T, "PX": PX, "hm": hm, "mtn": mtn, "tect": tect, "volcano": vt, "s56": s56}
