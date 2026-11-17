extends RefCounted
## gen-v3 v prototypu (Jan 20:14): napojení generátoru gen-v3-study-4 na BlockGen.
## Tvar povrchu, dorovnání stran, posun výšky a slupka (tráva, sníh) zůstávají z prototypu (block_gen.gd).
## Pod povrchem: ZÁSTUPCE SERVERU (jako v lozika-studie/gen3_tests.summary_for) spočítá souhrn, sestaví seřazený zásobník,
## přidělí vodu podle nejnižšího okraje bloku a zásobník zkontroluje; klient (gen_v3.generate_bytes) ho rozmístí:
## vrstvy hlíny, písku a jílu u povrchu, jeskyně (chamber), kameny po sloupcích (stratum), rudy v hostiteli, voda se zadržením.
## Souhrn ze serveru: hlína / písek / jíl = počty STRATA prototypu bez šumových rud; rudy ore-v0.2; jeskyně cave-v0; kámen = zbytek.

const Mat = preload("res://scripts/mat.gd")
const Ore = preload("res://scripts/gen3/ore_v0.gd")
const Cave = preload("res://scripts/gen3/cave_v0.gd")
const G = preload("res://scripts/gen3/gen_v3.gd")
const SRV = preload("res://scripts/gen3/gen3_server.gd")
const S = preload("res://scripts/gen3/gen3_stack.gd")
const H = preload("res://scripts/stable_hash.gd")
const BS := 16
const BH := 64
const VERSION := "gen-v3-study-4 + prototyp (SOIL_COLS)"
const POUR := {"louka": [60, 200], "kopec": [60, 220], "hora": [40, 160], "piscina": [80, 260]}
const BONUS_PCT := 50          # unikátní blok (ore_bonus > 0) = bonus 50 % na rudy, jeskyně a vodu (jako „bonus 50 %“ ve studii)

## validátor (jako na serveru) běží VŽDY po každém vygenerování / vložení bloku (Jan 20:39: „vždy, 4,5 ms není mnoho“), výsledek v b.gen3.valid
static var soil_filter := true         # false = položky u povrchu do všech sloupců (= vektory studie)

static func summary_for(kind: String, seed: int, bonus: int, cells: PackedByteArray, hm: PackedInt32Array) -> Dictionary:
	var cnt := Ore.count(cells)
	var s := {}
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY]:
		s[m] = cnt[m]
	var ot := Ore.server_target(seed, bonus, Ore.specs_for(kind))
	s[Mat.COPPER] = ot.get(Mat.COPPER, 0)
	s[Mat.IRON] = ot.get(Mat.IRON, 0)
	s[Mat.CLAY_DEPOSIT] = ot.get(Mat.CLAY_DEPOSIT, 0)
	s[G.CAVE_KEY] = Cave.server_target(kind, seed, bonus).cave_air
	var v_free := G.free_volume(cells, hm)
	var other := 0
	for k in s:
		if not SRV.ORE_IN_STONE or (k != Mat.COPPER and k != Mat.IRON):
			other += s[k]
	var rest := v_free - other
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY]:
		if rest < 0:
			var t := mini(s[m], -rest)
			s[m] -= t; rest += t
	var st := 0
	for m in G.STONES:
		st += cnt[m]
	var acc := 0
	for i in 3:
		var m: int = G.STONES[i]
		var v: int = (rest * cnt[m] / maxi(st, 1)) if i < 2 else rest - acc
		s[m] = v; acc += v
	var r := Ore.Rng.new(H.mix(seed, "POUR", 0))
	var pr: Array = POUR.get(kind, [60, 200])
	s["pour"] = r.range_i(pr[0], pr[1])
	s["water"] = s.pour
	return s

## sloupce s půdou v buňkách prototypu: nahoře tráva, hlína nebo písek (ne holý kámen, ne sníh)
static func soil_cols(cells: PackedByteArray, hm: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(BS * BS)
	for c in BS * BS:
		var h: int = hm[c]
		if h > 0:
			var m := cells[c * BH + h - 1]
			out[c] = 1 if (m == Mat.GRASS or m == Mat.DIRT or m == Mat.SAND) else 0
	return out

## b.hm je hotový, proto_cells = buňky prototypu bez šumových rud. Nastaví b.cells, b.water, b.gen3.
static func apply(b, proto_cells: PackedByteArray) -> void:
	var t0 := Time.get_ticks_usec()
	var bonus := BONUS_PCT if b.ore_bonus > 0.0 else 0
	var s := summary_for(b.kind, b.seed, bonus, proto_cells, b.hm)
	var items := SRV.build_stack(s)
	var allot := SRV.water_allotment(b.hm, items)
	var water := mini(int(s.pour), allot)
	var bytes := S.encode(items)
	var errs := SRV.check_stack(S.decode(bytes).items, G.free_volume(proto_cells, b.hm), water, allot)
	var t1 := Time.get_ticks_usec()
	G.SOIL_COLS = soil_cols(proto_cells, b.hm) if soil_filter else PackedByteArray()
	var g := G.generate_bytes(proto_cells, b.hm, b.seed, bytes, water)
	G.SOIL_COLS = PackedByteArray()
	var t2 := Time.get_ticks_usec()
	var info := {"version": VERSION, "ok": g.ok, "stack_hex": bytes.hex_encode(), "stack_hash": S.hash(bytes),
		"pour": s.pour, "allot": allot, "water": water, "server_errors": errs}
	if not g.ok:
		push_error("gen-v3: neplatný zásobník %s, blok zůstává podle prototypu" % str(g.error))
		info["error"] = g.error
		b.cells = proto_cells
		b.water = PackedInt32Array()
		b.gen3 = info
		return
	b.cells = g.cells
	b.water = g.water
	var rp := {"water_units": g.water_rep.get("runoff_units", 0)}
	for rep in g.reps:
		if rep.shortfall > 0:
			rp[rep.key] = rep.shortfall
	info["shortfall"] = rp
	info["retained"] = g.water_rep.get("retained", 0.0)
	info["runoff_units"] = rp.water_units
	info["ms_server"] = (t1 - t0) / 1000.0
	info["ms_generate"] = (t2 - t1) / 1000.0
	var t3 := Time.get_ticks_usec()
	info["valid"] = G.validate(g.cells, b.hm, g.water, G.summary_of(g.stack, water), rp)
	info["ms_validate"] = (Time.get_ticks_usec() - t3) / 1000.0
	b.gen3 = info

## validátor nad aktuálním stavem bloku (po vygenerování; po kopání už počty nesedí – to je delta)
static func validate_block(b) -> Dictionary:
	var d := S.decode(PackedByteArray(Array(b.gen3.stack_hex.hex_decode())))
	return G.validate(b.cells, b.hm, b.water, G.summary_of(d.items, int(b.gen3.water)), b.gen3.get("shortfall", {}))
