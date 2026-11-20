@tool
extends RefCounted
## E66: terén ostrova z blueprintů studie (blueprint-studie, generovani-masivu.md): povrch a hranice vrstev jako funkce
## v metrech na řídicí mřížce 0,5 m, navázání na už vložené sousedy v mocnostech (klíny), volná strana = regionální základ
## s podmnožinou hornin blueprintu, minerály v přesných počtech do hostitelů, nejvýš jedna dutina (jeskyně / rezervoár).
## Kroky vložení = scripts/teren/pipeline.gd (kopie studie beze změny logiky). Tady je jen převod bloku prototypu na blueprint
## a výsledku zpět na Block (třídy pro hru + plná id pro vzhled a vodu).
##
## Svět studie: sloty ostrova posunuté o OFF do kladných souřadnic (regionální funkce jsou ve světových metrech).
## Parametry: výchozí studie (scripts/teren/params.gd), přepsatelné z příkazové řádky --bp.klic=hodnota (např. --bp.taper_m=4).

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const PR = preload("res://scripts/teren/params.gd")
const PL = preload("res://scripts/teren/pipeline.gd")
const WD = preload("res://scripts/teren/world.gd")
const BP = preload("res://scripts/teren/blueprint.gd")
const TR = preload("res://scripts/teren/tridy.gd")
const BS := J.BS

static var OFF := Vector2i(3, 3)   # slot ostrova (0, 0) = slot světa (3, 3); ostrov má sloty −2..3
static var SIZE := 8               # svět studie SIZE × SIZE slotů (ostrov −2..3 + prstenec mlhy)
static var world = null            # svět studie (scripts/teren/world.gd)
static var p := {}

## typ bloku prototypu → tvar blueprintu (louka, kopec, hora, písčina) a minerály (Jan 16:02: počty, ne šum)
const SHAPE := {"louka": "louka", "kopec": "kopec", "hora": "hora_zvrasnena", "piscina": "prohlubeň",
	"svah": "svah", "prohlubeň": "prohlubeň", "hora_vyzdvizena": "hora_vyzdvizena", "hora_zvrasnena": "hora_zvrasnena", "sopka": "sopka"}
const C := 8; const FE := 9; const CD := 12
const COAL := 104; const LIG := 105; const GAR := 106; const AU := 107; const GEM := 101; const FETI := 103
const MINERALS := {
	"louka": {C: 10, FE: 14, COAL: 20},
	"kopec": {C: 20, FE: 24, GAR: 6, COAL: 30},
	"hora_zvrasnena": {C: 30, FE: 20, COAL: 20, GAR: 8},
	"hora_vyzdvizena": {C: 40, GEM: 8, AU: 6, GAR: 10},
	"prohlubeň": {FE: 30, LIG: 40, CD: 30},
	"svah": {C: 30, FE: 10, CD: 40},
	"sopka": {FE: 20, FETI: 10, AU: 4},
}
const WATER := {"louka": 150, "kopec": 120, "prohlubeň": 200, "svah": 120, "hora_zvrasnena": 80, "hora_vyzdvizena": 80, "sopka": 60}

## parametry hry nad parametry studie (studie je nezná; CLI --bp.<klíč>=hodnota)
const HRA := {
	"voda_ug_var": "A+B+C+D+K+I+P+R",   # varianta podzemí E58/E64 (jako studie: K + I + P + R)
	"voda_prikop_u": 0.0,                # dno příkopu (mlha kolem ostrova) v buňkách
	"voda_prikop_sklon": 0.01,           # sklon příkopu k okraji mapy (buněk na sloupec)
	"voda_r_kroku": 1,                   # kroků R podzemí na snímek
	"voda_e67": false,                   # E67 (studie, jen větev e67): podzemí jako přetoky ve 3D + výstup ve stěně ostrova
	"p67_min_vytok_render": 0.02,        # E67b: vývěr podzemní vody ve stěně / pramen slabší než tolik l/s se nekreslí (simulace beze změny)
	"p67_min_tok_render": 0.02,          # E67b: protékající větev podzemní vody slabší než tolik l/s se v řezech nekreslí
}

static func params() -> Dictionary:
	var a := PackedStringArray()
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--bp."): a.append("--" + s.substr(5))
	var d := PR.defaults()
	d.merge(HRA, true)
	d = PR.apply_args(d, a)
	if bool(d.get("voda_e67", false)):   # přepínač E67 = p67_okraj + p67_rezim pretok (jednotlivě jdou i --bp.p67_*)
		d.p67_okraj = true; d.p67_rezim = "pretok"
	return d

static func reset(off := Vector2i(3, 3), size := 8) -> void:
	OFF = off; SIZE = size
	world = WD.new()
	world.w = SIZE; world.h = SIZE
	p = params()

static func ensure() -> void:
	if world == null: reset(OFF, SIZE)

static func wslot(s: Vector2i) -> Vector2i:
	return s + OFF

static func islot(ws: Vector2i) -> Vector2i:
	return ws - OFF

## blueprint bloku: tvar podle typu, seed, minerály; každý třetí seed jeskyně, každý pátý rezervoár (nejvýš jedna dutina)
static func blueprint(b) -> Dictionary:
	var shape: String = SHAPE.get(b.kind, "louka")
	var mins: Dictionary = MINERALS.get(shape, {C: 10}).duplicate()
	if b.ore_bonus > 0.0:
		for k in mins.keys(): mins[k] = int(round(mins[k] * 1.5))
	if b.seed % 5 == 0: mins[TR.CAV_WATER] = 60
	elif b.seed % 3 == 0: mins[0] = 90
	return BP.make(shape, b.seed, mins, int(WATER.get(shape, 120)))

## vygeneruje blok (nevloží do světa; vloží commit() při Island.place). Posun výšky = surface_shift + b.shift.
static func build(b) -> void:
	ensure()
	var t0 := Time.get_ticks_usec()
	var bp := blueprint(b)
	var pp: Dictionary = p.duplicate()
	pp.surface_shift = float(p.surface_shift) + float(b.shift)
	var ctx := PL.new_ctx(world, wslot(b.slot), bp, pp)
	var st := PL.steps(ctx)
	var i := 0
	while i < st.size():
		var t1 := Time.get_ticks_usec()
		st[i][1].call()
		var key: String = st[i][0].split(":")[0]
		ctx.ms[key] = ctx.ms.get(key, 0.0) + (Time.get_ticks_usec() - t1) / 1000.0
		i += 1
	var rec := PL.record(ctx)
	b.bp_rec = rec
	b.geo = rec.cells
	b.cells = TR.to_classes(rec.cells)
	var hm := PackedInt32Array(); hm.resize(BS * BS)
	for k in BS * BS: hm[k] = int(rec.hm[k])
	b.hm = hm
	b.hm_gen = hm.duplicate()
	b.water = rec.water
	b.gen = "bp"
	b.gen3 = {"valid": rec.rep.get("valid", {}), "blueprint": bp, "minerals": rec.rep.get("minerals", []), "ms": rec.ms}
	b.edge_profiles = [null, null, null, null]
	b.gen_ms = (Time.get_ticks_usec() - t0) / 1000.0

## Island.place: blok se stane sousedem pro další vložení (pořadí vložení = pořadí commit)
static func commit(b) -> void:
	ensure()
	if b.bp_rec.is_empty() or world.slots.has(wslot(b.slot)): return
	world.commit(b.bp_rec)

## jemná data pro podzemí (ug_funkce.from_world): slot světa → {cells (plná id), hm}; po kopání aktuální buňky bloků
static func fine(blocks: Dictionary) -> Dictionary:
	var out := {}
	for s in blocks:
		var b = blocks[s]
		if b.gen != "bp" or b.geo.is_empty(): continue
		out[wslot(s)] = {"cells": b.geo, "hm": b.hm}
	return out
