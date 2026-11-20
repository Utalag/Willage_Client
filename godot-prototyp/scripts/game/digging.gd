extends Node
## Kopání a pokládání buněk (režim M): kop = odebere nejvyšší buňku sloupce do inventáře, položení = materiál
## z inventáře na vrch. Materiál se zachovává, změny se zapisují jako delta (index buňky, starý / nový materiál).
## Po otevření buňky spustí tok vody (uzel WaterFlow).

signal cell_inspected(g: Vector2i)   # panel vpravo má ukázat blok pod sloupcem g

const J = preload("res://scripts/jednotky.gd")   # E94: mřížka a metry z jednoho místa
const Mat = preload("res://scripts/mat.gd")
const VegG = preload("res://scripts/veg.gd")
const Block = preload("res://scripts/block.gd")
const H = preload("res://scripts/stable_hash.gd")
const TerenBP = preload("res://scripts/teren/ostrov_teren.gd")
const FN = preload("res://scripts/teren/geo_fn.gd")
const BS := J.BS

@export var island_path: NodePath
@export var ui_path: NodePath
@export var water_path: NodePath
@onready var island = get_node(island_path)
@onready var ui = get_node(ui_path)
@onready var water = get_node(water_path)

var dig_mode := false
var inventory := PackedInt32Array()
var deltas := {}                 # slot -> [{i, lx, ly, lz, old, new}] v pořadí operací
var place_mat := -1              # materiál k položení (klávesy 1–9 v režimu kopání)

func _ready() -> void:
	inventory.resize(Mat.COUNT)

func inv_list() -> Array:
	var out := []
	for m in range(1, Mat.COUNT):
		if inventory[m] > 0: out.append(m)
	return out

func refresh_inv() -> void:
	if place_mat >= 0 and inventory[place_mat] <= 0:
		place_mat = -1
	if place_mat < 0 and not inv_list().is_empty():
		place_mat = inv_list()[0]
	ui.set_inventory(inventory, "(M kopání: klik kopat, Shift+klik položit, 1–9 materiál)" if dig_mode else "", place_mat)

## kop / položení na globálním sloupci g; vrací text pro nápovědu
func dig(g: Vector2i, place := false, mat := -1) -> String:
	var sl := Vector2i(floori(g.x / float(BS)), floori(g.y / float(BS)))
	if not island.blocks.has(sl):
		return "mlha: kopat ani stavět nelze"
	if island.occupied.has(g):
		return "pod stavbou nebo cestou: nelze"
	var b: Block = island.blocks[sl]
	water.finish_all()   # rozběhnutý tok se před další změnou dokončí (výsledek nezávisí na snímcích)
	island.water_finish()   # E66: rozpracované kroky podzemí taky
	var lx := g.x - sl.x * BS
	var ly := g.y - sl.y * BS
	var h: int = b.hm[lx * BS + ly]
	var lz: int
	var old: int
	var nw: int
	if place:
		if mat < 0 and place_mat >= 0 and inventory[place_mat] > 0:
			mat = place_mat
		if mat < 0:
			for m in range(1, Mat.COUNT):
				if inventory[m] > 0: mat = m; break
		if mat < 0 or inventory[mat] <= 0:
			return "inventář je prázdný"
		if h >= 64:
			return "strop bloku (lz 63)"
		lz = h; old = b.cells[(lx * BS + ly) * 64 + lz]; nw = mat
		inventory[mat] -= 1
		b.hm[lx * BS + ly] = h + 1
	else:
		if h <= 0:
			return "dno bloku: pod lz 0 kopat nelze"
		lz = h - 1; old = b.cells[(lx * BS + ly) * 64 + lz]; nw = Mat.AIR
		if old == Mat.FOG or old == Mat.AIR:
			return "nelze"
		if FN.on85(TerenBP.p, "p85_okraj"):   # E85 (Jan 2026-11-20 03:26): dno a obvod ostrova se neprokopají, švy bloků ano
			if lz == 0: return "dno ostrova: nelze"
			if (lx == 0 and not island.blocks.has(sl + Vector2i(-1, 0))) or (lx == BS - 1 and not island.blocks.has(sl + Vector2i(1, 0))) \
				or (ly == 0 and not island.blocks.has(sl + Vector2i(0, -1))) or (ly == BS - 1 and not island.blocks.has(sl + Vector2i(0, 1))):
				return "okraj ostrova: nelze"
		inventory[old] += 1
		# gen-v3: pod vykopanou buňkou může být jeskyně – povrch sloupce klesne na její dno (jeskyně se tím odkryje)
		var nh := h - 1
		while nh > 0 and b.cells[(lx * BS + ly) * 64 + nh - 1] == Mat.AIR:
			nh -= 1
		b.hm[lx * BS + ly] = nh
	var idx := (lx * BS + ly) * 64 + lz
	b.cells[idx] = nw
	if b.gen == "bp" and b.geo.size() == b.cells.size():
		b.geo[idx] = nw   # E66: plné id (položená buňka = id třídy, ta jsou ve studii stejná)
	var w_old := 0
	if b.water.size() == b.cells.size():
		w_old = b.water[idx]; b.water[idx] = 0   # voda v pórech odejde s materiálem (bez simulace; položená buňka je suchá)
	if not deltas.has(sl): deltas[sl] = []
	var dl := {"i": idx, "lx": lx, "ly": ly, "lz": lz, "old": old, "new": nw}
	if w_old > 0: dl["water_old"] = w_old
	deltas[sl].append(dl)
	b.recount()
	if b.gen == "bp":
		var wr: Dictionary = island.water_edit(sl, lx, ly)   # E66: kop i položení → lokální přepočet vody ostrova
		if not wr.is_empty(): dl["voda_ms"] = wr.get("ms", 0.0)
	elif not place:
		water.start(b, sl, lx, ly, lz, dl, w_old)
	var kept := []
	for r in b.veg:   # rostlina na změněném sloupci zmizí
		if not (r.lx == lx and r.ly == ly): kept.append(r)
	b.veg = kept
	b.veg_summary = VegG.summary(b.veg)
	island.refresh_after_edit(sl, lx, ly)   # kostky, duální povrch a vegetace bloku (a sousedů u hrany)
	cell_inspected.emit(g)
	refresh_inv()
	return "%s %s (lz %d)" % ["položeno" if place else "vykopáno", Mat.NAMES[nw if place else old], lz]

## klávesy 1–9: materiál k položení
func select_mat(k: int) -> void:
	var li := inv_list()
	if dig_mode and k < li.size():
		place_mat = li[k]; refresh_inv()
		ui.set_hint("KOPÁNÍ: k položení vybrán %s · Shift+klik položit" % Mat.NAMES[place_mat])

## ukázka formátu delty pro backend -> vectors/delta_sample.json
func export_deltas(path: String) -> void:
	var blocks := []
	for sl in deltas:
		var b: Block = island.blocks[sl]
		var base := b.cells.duplicate()
		var ops: Array = deltas[sl]
		for k in range(ops.size() - 1, -1, -1):   # zpětně: původní objem bloku
			base[ops[k].i] = ops[k].old
		var out_ops := []
		for o in ops:
			out_ops.append({"i": o.i, "lx": o.lx, "ly": o.ly, "lz": o.lz, "old": o.old, "new": o.new,
				"oldName": Mat.NAMES[o.old], "newName": Mat.NAMES[o.new]})
		blocks.append({
			"slot": [sl.x, sl.y], "recipe": b.kind, "seed": b.seed,
			"transform": {"mirror": b.mirror, "rotation": b.rot * 90, "heightShift": b.shift},
			"sides": _sides_json(b.sides),
			"neighborEdgeProfiles": _edges_json(b.edge_profiles),
			"placedVolumeHash": H.hex(H.fnv1a64_bytes(base)),
			"resultVolumeHash": H.hex(H.fnv1a64_bytes(b.cells)),
			"ops": out_ops,
		})
	var inv := {}
	for m in range(1, Mat.COUNT):
		if inventory[m] > 0: inv[Mat.NAMES[m]] = inventory[m]
	var doc := {
		"deltaFormat": "delta-v0",
		"generatorVersion": "proto-v2.2",
		"cellIndex": "i = (lx*16+ly)*64+lz; materials: 0 air .. 10 snow, 11 fog",
		"semantics": "Baseline = volume right after placement: regenerate from recipe+seed, apply transform (mirror, rotation, heightShift), then side blending using sides + neighborEdgeProfiles stored at placement time (later changes to neighbours do not affect it). placedVolumeHash = FNV-1a 64 of the 16384 bytes of that baseline (check). ops apply in order; old must match current cell, else reject. resultVolumeHash = after all ops.",
		"edgeProfileOrder": "neighborEdgeProfiles keys N,E,S,W (DIRS (0,-1),(1,0),(0,1),(-1,0)); 16 surface heights of the neighbour cells touching the shared edge, index t along the edge (t = lx for N/S edges, t = ly for E/W edges, in the new block's coordinates); null = no neighbour",
		"sidesValues": "auto | blend1..blend4 | keep",
		"islandInventory": inv,
		"blocks": blocks,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	print("delta: uloženo ", path)

func _sides_json(sd: PackedInt32Array) -> Dictionary:
	var k := ["N", "E", "S", "W"]
	var out := {}
	for i in 4:
		out[k[i]] = "auto" if sd[i] == 0 else ("keep" if sd[i] == 5 else "blend%d" % sd[i])
	return out

func _edges_json(ep: Array) -> Dictionary:
	var k := ["N", "E", "S", "W"]
	var out := {}
	for i in 4:
		out[k[i]] = null if ep[i] == null else Array(ep[i])
	return out
