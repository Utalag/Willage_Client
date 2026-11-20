extends RefCounted
## E78: překryv změn po kopání nad definicí bloku. Definice (typ, seed, posun, sousedé) → buňky 0,5 m (BlockGen) →
## mřížka 0,25 m (každá buňka 0,5 m na 2 × 2 × 2) → překryv (buňka 0,25 m → materiál, 0 = vzduch) → skutečný stav.
## Překryv nese konečný stav buňky, ne historii: položka rovná definici se maže (kanonický tvar), operace na různých
## buňkách na pořadí nezávisí, na téže buňce vyhrává poslední (vykopat → zasypat = materiál, zasypat → vykopat = vzduch).
## Buňka 0,5 m je plná, dokud v ní zbývá aspoň jedna plná buňka 0,25 m; materiál = nejčastější plný (remíza: nižší id).
## Záznam bloku rozšiřuje E76 (typ, seed, slot, posun, prameny76): místo „vykopy“ po sloupcích nese „bunky“ (překryv),
## výška sloupců se z buněk odvodí.
const TR = preload("res://scripts/teren/tridy.gd")
const T = preload("res://scripts/teren/ostrov_teren.gd")
const FN = preload("res://scripts/teren/geo_fn.gd")
const MN = preload("res://scripts/teren/minerals.gd")
const BPV = preload("res://scripts/teren/blueprint.gd")
const N := 32          # buněk 0,25 m na stranu bloku
const NZ := 128        # buněk 0,25 m na výšku
const SIZE := N * N * NZ

static func fidx(fx: int, fy: int, fz: int) -> int:
	return (fx * N + fy) * NZ + fz

## definici si blok zapamatuje hned po vygenerování (před jakoukoli změnou)
static func attach(b) -> void:
	b.def78 = b.geo.duplicate()
	b.jemne78 = PackedByteArray()
	b.def85 = fine_fn(b) if FN.on85(T.p, "p85_jemne") and b.prenos76.is_empty() else PackedByteArray()

## E85 (Jan 2026-11-20 03:26, p85_jemne): definice 0,25 m = vzorek funkcí geo_fn při 32 × 32 × 128, pak minerály
## a dutina stejně jako pipeline (stejné pořadí, seed blueprintu, počty × 8 uvnitř mineral_one / cavity_one).
## Blok musí být ve světě studie (T.commit). Staré bloky se při načtení přepočítají stejně (překryv se položí na novou definici).
static func fine_fn(b) -> PackedByteArray:
	var ws := T.wslot(b.slot)
	if not T.world.slots.has(ws): return PackedByteArray()
	var wf := FN.world_fn(T.world.slots)
	var bp: Dictionary = T.world.slots[ws].bp
	var info := FN.block_info(wf, ws, bp, T.p)
	var c := FN.sample_all(wf, info, N)
	for m in MN.order(bp.minerals):
		if not FN.is_cavity(m): FN.mineral_one(c, N, wf, info, m, int(bp.minerals[m]), int(bp.seed))
	if BPV.validate(bp).ok:
		for m in MN.order(bp.minerals):
			if FN.is_cavity(m) and int(bp.minerals[m]) > 0: FN.cavity_one(c, N, wf, info, m, int(bp.minerals[m]), int(bp.seed))
	return c

## definice 0,25 m: z funkcí (E85) nebo zjemnění definice 0,5 m (E78)
static func deffine(b) -> PackedByteArray:
	return b.def85 if not b.def85.is_empty() else refine(b.def78)

## živá mřížka bez uložení: jemne78, jinak definice; u E85 se buňky 0,5 m změněné mimo překryv (kopání po 0,5 m) přenesou
static func _live(b) -> PackedByteArray:
	if not b.jemne78.is_empty(): return b.jemne78
	if b.def85.is_empty(): return refine(b.geo)
	var f: PackedByteArray = b.def85.duplicate()
	for ci in 256:
		for z in 64:
			var i := ci * 64 + z
			if b.geo[i] == b.def78[i]: continue
			var x := ci / 16; var y := ci % 16
			for dx in 2:
				for dy in 2:
					var o := fidx(2 * x + dx, 2 * y + dy, 2 * z)
					f[o] = b.geo[i]; f[o + 1] = b.geo[i]
	return f

static func refine(geo: PackedByteArray) -> PackedByteArray:
	var f := PackedByteArray(); f.resize(SIZE)
	for x in 16:
		for y in 16:
			var c := (x * 16 + y) * 64
			for z in 64:
				var m := geo[c + z]
				if m == 0: continue
				for dx in 2:
					for dy in 2:
						var o := fidx(2 * x + dx, 2 * y + dy, 2 * z)
						f[o] = m; f[o + 1] = m
	return f

static func fine(b) -> PackedByteArray:
	if b.jemne78.is_empty(): b.jemne78 = _live(b)
	return b.jemne78

static func inside(fx: int, fy: int, fz: int) -> bool:
	return fx >= 0 and fy >= 0 and fz >= 0 and fx < N and fy < N and fz < NZ

## jemná operace na živém bloku: mat 0 = vykopat; položit jde jen do vzduchu (jinak no-op, vrací false).
## E80: mimo blok (z < 0 pod dnem ostrova, z ≥ 128 nad stropem bloku, x/y mimo) → false; dřív index přetekl do sousedního sloupce.
static func op(b, fx: int, fy: int, fz: int, mat: int) -> bool:
	if not inside(fx, fy, fz): return false
	if mat == 0 and FN.on85(T.p, "p85_okraj") and chraneno85(b.slot, fx, fy, fz): return false
	var f := fine(b)
	var i := fidx(fx, fy, fz)
	if mat != 0 and f[i] != 0: return false
	if mat == 0 and f[i] == 0: return false
	f[i] = mat
	return true

## E85 (Jan 2026-11-20 03:26, p85_okraj): dno ostrova (vrstva z = 0) a obvodové sloupce ostrova (strana bloku bez souseda
## ve světě) se vykopat nedají; švy mezi bloky ostrova ano. Soused položený později udělá ze strany vnitřní šev.
static func chraneno85(slot: Vector2i, fx: int, fy: int, fz: int) -> bool:
	if fz == 0: return true
	var ws := T.wslot(slot)
	if fx == 0 and not T.world.slots.has(ws + Vector2i(-1, 0)): return true
	if fx == N - 1 and not T.world.slots.has(ws + Vector2i(1, 0)): return true
	if fy == 0 and not T.world.slots.has(ws + Vector2i(0, -1)): return true
	if fy == N - 1 and not T.world.slots.has(ws + Vector2i(0, 1)): return true
	return false

## buňky 0,5 m z jemné mřížky; vrací sloupce (ci), kterým se změnila výška
static func sync(b) -> Array:
	return sync79(b).hm

## E79: totéž, navíc sloupce (ci), ve kterých se změnila jakákoli buňka 0,5 m (i pod povrchem: chodba, dutina)
static func sync79(b) -> Dictionary:
	var f := fine(b)
	var d85: PackedByteArray = b.def85
	var changed := []; var geo_ch := []
	var cnt := PackedInt32Array(); cnt.resize(256)
	for x in 16:
		for y in 16:
			var ci := x * 16 + y
			var top := 0; var gch := false
			for z in 64:
				var best := 0; var bc := 0
				var ids := []; var cs := []
				var same := not d85.is_empty()   # E85: všech 8 buněk jako definice z funkcí → buňka 0,5 m = definice pipeline
				for dx in 2:
					for dy in 2:
						for dz in 2:
							var o := fidx(2 * x + dx, 2 * y + dy, 2 * z + dz)
							var m := f[o]
							if same and m != d85[o]: same = false
							if m == 0: continue
							var k := ids.find(m)
							if k < 0: ids.append(m); cs.append(1)
							else: cs[k] += 1
				for k in ids.size():
					if cs[k] > bc or (cs[k] == bc and ids[k] < best): best = ids[k]; bc = cs[k]
				if same: best = b.def78[ci * 64 + z]
				if b.geo[ci * 64 + z] != best: gch = true
				b.geo[ci * 64 + z] = best
				if best != 0: top = z + 1
			if top != b.hm[ci]: changed.append(ci)
			if gch: geo_ch.append(ci)
			b.hm[ci] = top
	b.cells = TR.to_classes(b.geo)
	return {"hm": changed, "geo": geo_ch}

## překryv = rozdíl živé mřížky proti definici (seřazené klíče)
static func overlay(b) -> Dictionary:
	var d := deffine(b)
	var f: PackedByteArray = _live(b)
	var o := {}
	for i in SIZE:
		if f[i] != d[i]: o[i] = f[i]
	return o

static func _uv(out: PackedByteArray, v: int) -> void:
	while v >= 128:
		out.append((v & 127) | 128); v >>= 7
	out.append(v)

static func _rv(a: PackedByteArray, p: Array) -> int:
	var v := 0; var sh := 0
	while true:
		var c := a[p[0]]; p[0] += 1
		v |= (c & 127) << sh; sh += 7
		if c < 128: break
	return v

## kódování A: počet, rozdíly seřazených klíčů (varint), pak materiály po řadě
static func enc_keys(o: Dictionary) -> PackedByteArray:
	var ks := o.keys(); ks.sort()
	var out := PackedByteArray()
	_uv(out, ks.size())
	var prev := -1
	for k in ks: _uv(out, k - prev - 1); prev = k
	for k in ks: out.append(o[k])
	return out

static func dec_keys(a: PackedByteArray) -> Dictionary:
	var p := [0]
	var n := _rv(a, p)
	var ks := []; var prev := -1
	for i in n: prev = prev + 1 + _rv(a, p); ks.append(prev)
	var o := {}
	for i in n: o[ks[i]] = a[p[0] + i]
	return o

## kódování B: úseky ve sloupcích [sloupec u16, z0 u8, délka u8, materiál u8]
static func enc_runs(o: Dictionary) -> PackedByteArray:
	var ks := o.keys(); ks.sort()
	var out := PackedByteArray()
	var i := 0
	while i < ks.size():
		var k: int = ks[i]; var m: int = o[k]; var j := i + 1
		while j < ks.size() and ks[j] == ks[j - 1] + 1 and o[ks[j]] == m and ks[j] / NZ == k / NZ and j - i < 255: j += 1
		var col: int = k / NZ
		out.append(col & 255); out.append(col >> 8); out.append(k % NZ); out.append(j - i); out.append(m)
		i = j
	return out

static func dec_runs(a: PackedByteArray) -> Dictionary:
	var o := {}
	for p in range(0, a.size(), 5):
		var col := a[p] | (a[p + 1] << 8)
		for t in a[p + 3]: o[col * NZ + a[p + 2] + t] = a[p + 4]
	return o

static func deflate(a: PackedByteArray) -> PackedByteArray:
	if a.is_empty(): return a
	return a.compress(FileAccess.COMPRESSION_DEFLATE)

## záznam bloků (E76 rozšířený o buňky): typ, seed, slot, posun, prameny, překryv (kódování A, deflate jen když je menší,
## base64); bunky_n = délka před kompresí (0 = nekomprimováno)
static func save(blocks: Dictionary, order: Array) -> Array:
	var out := []
	for s in order:
		var b = blocks[s]
		out.append({"kind": b.kind, "seed": b.seed, "slot": [s.x, s.y], "shift": b.shift, "prameny76": b.prameny76,
			"bunky": "", "bunky_n": 0})
		var e := enc_keys(overlay(b)); var z := deflate(e)
		if z.size() < e.size(): out[-1].bunky = Marshalls.raw_to_base64(z); out[-1].bunky_n = e.size()
		else: out[-1].bunky = Marshalls.raw_to_base64(e)
	return out

## načtení: blok znovu z definice (stejné pořadí = stejní sousedé), pak překryv; T je ostrov_teren (reset volá volající)
static func load_into(data: Array, Block, BlockGen, T) -> Dictionary:
	var blocks := {}
	for e in data:
		var b = Block.new(); b.kind = e.kind; b.seed = int(e.seed); b.slot = Vector2i(int(e.slot[0]), int(e.slot[1])); b.shift = int(e.shift)
		BlockGen.build(b, [null, null, null, null]); T.commit(b)
		attach(b)
		var raw := Marshalls.base64_to_raw(e.bunky)
		if int(e.bunky_n) > 0: raw = raw.decompress(int(e.bunky_n), FileAccess.COMPRESSION_DEFLATE)
		var o := dec_keys(raw)
		if not o.is_empty():
			var f := fine(b)
			for k in o: f[k] = o[k]
			sync(b)
		b.prameny76 = e.prameny76
		blocks[b.slot] = b
	return blocks

## otisk stavu bloků: SHA-256 přes jemné mřížky (nebo zjemněné buňky 0,5 m) v pořadí slotů
static func otisk(blocks: Dictionary, coarse := false) -> String:
	var ks := blocks.keys(); ks.sort()
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	for s in ks:
		var b = blocks[s]
		if coarse: h.update(b.geo)
		else: h.update(_live(b))
	return h.finish().hex_encode().substr(0, 16)
