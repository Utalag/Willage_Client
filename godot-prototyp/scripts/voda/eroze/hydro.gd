extends RefCounted
## KOPIE z blueprint-studie/scripts/eroze51/hydro.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E51 hydraulika bez CFD: rychlost z průtoku, průřezu a sklonu. Koryto: Manning [31] pro široký obdélník,
## tůň: průtok tůní / (hloubka · √plocha). Prahy materiálů (ero_v, ero_vol, sed_v) ze sdílené tabulky (data, ne kód).

const VP = preload("res://scripts/teren/zaklad/voda_params.gd")
const CELL := 0.5   # m, buňka (U)

static var _E := {}
## MaterialId → [ero_v, ero_vol, sed_v, por]; chybí-li pole (horniny 20+), materiál je tvrdý (neeroduje, neusazuje se)
static func table() -> Dictionary:
	if _E.is_empty():
		var d := VP.load_shared_table()
		for k in d.materials:
			var e: Dictionary = d.materials[k]
			_E[int(e.id)] = [float(e.get("ero_v", 6.0)), float(e.get("ero_vol", 1e8)), float(e.get("sed_v", 0.0)), float(e.get("por", 0.0))]
	return _E

static func mat(m: int) -> Array:
	return table().get(m, [6.0, 1e8, 0.0, 0.0])

static func id_of(name: String) -> int:
	var d := VP.load_shared_table()
	return int(d.materials[name].id)

## koryto: Q v m³/s, S sklon → {v, h, b}
static func manning(q: float, s: float, p: Dictionary) -> Dictionary:
	var b := maxf(CELL, float(p.e51_kb) * sqrt(q))
	var h := pow(float(p.e51_n) * q / (b * sqrt(maxf(s, float(p.e51_s_min)))), 0.6)
	return {"v": q / (b * maxf(h, 1e-6)), "h": h, "b": b}

## tůň: Q m³/s, hloubka m, plocha m²
static func pond_v(q: float, depth: float, area: float) -> float:
	return q / (maxf(depth, 0.01) * sqrt(maxf(area, CELL * CELL)))
