extends RefCounted
## Generátor V1.0, krok 1: rozměry datového modelu jako parametry (docs/sjednoceni 1.1, 1.2, 1.3, 1.4).
## Délky v metrech (float64), počty buněk celá čísla. Dnešní konstanty hry (scripts/jednotky.gd: segment 8 m,
## sloupec 32 m) zůstávají beze změny, dokud hra nepřejde na V1.0.
##   blok     128 m  jednotka vkládání (blueprint)            1.1
##   segment    8 m  jednotka výpočtu a rozdílu (8 / 16 / 32)  1.1, 2.4
##   buňka    0,5 m  definice terénu                          1.1
##   jemná   0,25 m  slupka, kopání, překryv                  1.2, 2.3
##   sloupec  128 m  výčet 32 / 64 / 128, neutrální úroveň v polovině  1.3
##   svět      3×3 bloky výchozí, maximum 4096 m              1.4

const VYSKY_SLOUPCE_M := [32.0, 64.0, 128.0]
const SEGMENTY_M := [8.0, 16.0, 32.0]

static func vychozi() -> Dictionary:
	return {
		"blok_m": 128.0,
		"segment_m": 8.0,
		"bunka_m": 0.5,
		"jemna_m": 0.25,
		"sloupec_m": 128.0,
		"svet_max_m": 4096.0,
		"svet_start_bloku": 3,
		"slupka_bunek": 3,
	}

static func _je_mocnina2(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0

## počet buněk o hraně c_m na délku d_m; -1 když nejde beze zbytku
static func _pocet(d_m: float, c_m: float) -> int:
	var q := d_m / c_m
	var n := int(round(q))
	return n if absf(q - float(n)) < 1e-9 else -1

## kontrola pravidel 1.1 / 1.3 / 1.4; vrátí seznam chyb (prázdný = platné)
static func over(r: Dictionary) -> Array:
	var ch: Array = []
	var c: float = r.bunka_m
	var f: float = r.jemna_m
	if not VYSKY_SLOUPCE_M.has(float(r.sloupec_m)):
		ch.append("výška sloupce %s není ve výčtu 32/64/128 m" % r.sloupec_m)
	if not SEGMENTY_M.has(float(r.segment_m)):
		ch.append("segment %s není ve výčtu 8/16/32 m" % r.segment_m)
	for k in ["blok_m", "segment_m", "sloupec_m", "svet_max_m"]:
		var n := _pocet(float(r[k]), c)
		if n < 0: ch.append("%s = %s se nedělí buňkou %s m" % [k, r[k], c])
		elif not _je_mocnina2(n): ch.append("%s = %d buněk, není mocnina 2" % [k, n])
	var ns := _pocet(float(r.blok_m), float(r.segment_m))
	if ns < 0 or not _je_mocnina2(ns): ch.append("blok se nedělí na segmenty beze zbytku (mocnina 2)")
	var nf := _pocet(c, f)
	if nf < 0 or not _je_mocnina2(nf): ch.append("buňka se nedělí na jemné buňky (mocnina 2)")
	var nb := _pocet(float(r.svet_max_m), float(r.blok_m))
	if nb < 0 or not _je_mocnina2(nb): ch.append("maximum světa není mocnina 2 bloků")
	elif int(r.svet_start_bloku) < 1 or int(r.svet_start_bloku) > nb: ch.append("výchozí svět mimo maximum")
	if int(r.slupka_bunek) < 2 or int(r.slupka_bunek) > 3: ch.append("slupka mimo 2–3 buňky")
	return ch

## odvozené počty (jen pro platné rozměry)
static func odvozene(r: Dictionary) -> Dictionary:
	var c: float = r.bunka_m
	return {
		"blok_bunek": _pocet(r.blok_m, c),
		"segment_bunek": _pocet(r.segment_m, c),
		"segmentu_v_bloku": _pocet(r.blok_m, r.segment_m),
		"sloupec_bunek": _pocet(r.sloupec_m, c),
		"neutralni_m": float(r.sloupec_m) * 0.5,
		"neutralni_bunka": _pocet(r.sloupec_m, c) / 2,
		"jemnych_na_bunku": _pocet(c, r.jemna_m),
		"svet_max_bloku": _pocet(r.svet_max_m, r.blok_m),
		"segment_jemnych": _pocet(r.segment_m, r.jemna_m),
		"sloupec_jemnych": _pocet(r.sloupec_m, r.jemna_m),
	}

## index buňky v segmentu (a, b vodorovně, h svisle) při n buňkách na šířku a nz na výšku; stejné pořadí jako jednotky.gd
static func idx(a: int, b: int, h: int, n: int, nz: int) -> int:
	return (a * n + b) * nz + h

static func idx_rozloz(i: int, n: int, nz: int) -> Vector3i:
	return Vector3i(i / (n * nz), (i / nz) % n, i % nz)

## počet bitů indexu jemné buňky v segmentu (1.3: 128 m a segment 8 m → 19 bitů)
static func bity_indexu(r: Dictionary) -> int:
	var o := odvozene(r)
	var cnt: int = o.segment_jemnych * o.segment_jemnych * o.sloupec_jemnych
	var b := 0
	while (1 << b) < cnt: b += 1
	return b
