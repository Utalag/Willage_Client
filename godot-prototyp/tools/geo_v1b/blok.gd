extends RefCounted
## Průchod celým blokem 128 m z funkce světa (krok 3b). Bez stavu; používají ho testy a obrázky.
const BLOK_M := 128.0

## pro každý bod mřížky zavolá cb(x, y, z, bunka) s bunka = {vm, um, sm, z_pov, hr}; cb vrací nic
## (bx, by) = index bloku 128 m; krok_xy, krok_z v metrech; z_max = horní mez (m)
static func prochod(svet, bx: int, by: int, krok_xy: float, krok_z: float, z_max: float, cb: Callable) -> int:
	var n := int(BLOK_M / krok_xy)
	var sloupcu := 0
	for i in n:
		for j in n:
			var x := bx * BLOK_M + (i + 0.5) * krok_xy
			var y := by * BLOK_M + (j + 0.5) * krok_xy
			var w: PackedFloat64Array = svet.vahy(x, y)
			var z_pov: float = float(svet.vyska_w(x, y, w, true))
			var hr: Array = svet.geo.hranice(x, y, w)
			var feats: Array = svet.geo.utv.features_u(x, y)
			sloupcu += 1
			var nz := int(ceil(minf(z_pov, z_max) / krok_z))
			for iz in nz:
				var z := (iz + 0.5) * krok_z
				if z > z_pov: break
				var sm: int = svet.geo.sopka_mat(x, y, z)
				var vm: int = svet.geo.vrstva_mat(x, y, z, hr)
				var um := -1
				if sm < 0:
					um = int(svet.geo.utv.mat_feats(feats, x, y, z, vm, z_pov, hr))
				cb.call(x, y, z, {"vm": vm, "um": um, "sm": sm, "z_pov": z_pov, "hr": hr})
	return sloupcu

## otisk materiálů bloku (SHA-256, prvních 16 hex) přes stabilní API `vypln_sloupec`; funguje i na kódu kroku 3
static func otisk(svet, bx: int, by: int, krok_xy: float, krok_z: float, zmax: float) -> Dictionary:
	var n := int(BLOK_M / krok_xy)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var bunek := 0
	for i in n:
		for j in n:
			var x := bx * BLOK_M + (i + 0.5) * krok_xy
			var y := by * BLOK_M + (j + 0.5) * krok_xy
			var a: PackedByteArray = svet.geo.vypln_sloupec(x, y, krok_z, zmax)
			ctx.update(a)
			bunek += a.size()
	return {"hash": ctx.finish().hex_encode().substr(0, 16), "bunek": bunek}
