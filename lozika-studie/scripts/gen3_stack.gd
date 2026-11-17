extends RefCounted
## Zásobník gen-v3 (dohoda s Willage-backend 18:59): binární kódování, tabulky parametrů tvarů, kontrola world.stack_invalid.
## Položka: u16 mat_id, u32 count, u8 shape, u16 params_len (= 4·n), params = n × i32 (vše little-endian).
## Zásobník: u16 počet položek + položky. stack_hash = SHA-256 přesných bajtů zásobníku.
## Parametry jen celá čísla: pravděpodobnosti 0..65535 (u16, porovnání rng.u16() < p) nebo promile (0..1000).
## lzMin/lzMax: ≥ 0 = absolutní výška buňky (lz); < 0 = hloubka pod povrchem VLASTNÍHO sloupce (od 19:18): d = povrch − lz,
##   d = 1 je nejvyšší buňka pod povrchem, pásmo d ∈ [|lzMax|, |lzMin|]; obě meze musí mít stejné znaménko.

const Mat = preload("res://scripts/mat.gd")

enum { SHAPE_POCKET = 1, SHAPE_LAYER = 2, SHAPE_VEIN = 3, SHAPE_CHAMBER = 4, SHAPE_STRATUM = 5 }
## tvar -> pořadí parametrů (pevné, kopírovat do katalogu backendu)
const SHAPES := {
	SHAPE_POCKET: {"name": "pocket", "params": ["maxHeap", "lzMin", "lzMax", "host"]},
	SHAPE_LAYER: {"name": "layer", "params": ["maxHeap", "lzMin", "lzMax", "pH_u16", "pV_u16"]},
	SHAPE_VEIN: {"name": "vein", "params": ["maxHeap", "lzMin", "lzMax", "inertia_permille", "branch_permille", "host"]},
	SHAPE_CHAMBER: {"name": "chamber", "params": ["maxHeap", "lzMin", "lzMax", "pH_u16", "pV_u16", "roof", "margin"]},
	## 19:19 (e): mocná vrstva po sloupcích – vyplní `count` nepřiřazených buněk v pořadí klíče z + vlna(x, y), zdola nahoru
	SHAPE_STRATUM: {"name": "stratum", "params": ["amp_tenths", "scale"]},
}
## rozsahy parametrů (včetně)
const RANGES := {"maxHeap": [1, 65536], "lzMin": [-63, 63], "lzMax": [-63, 63], "pH_u16": [0, 65535], "pV_u16": [0, 65535],
	"inertia_permille": [0, 1000], "branch_permille": [0, 1000], "roof": [0, 32], "margin": [0, 7],
	"host": [-1, 12], "amp_tenths": [0, 160], "scale": [1, 64]}

static func encode(items: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_u16(0, items.size())
	for it in items:
		var ps: Array = it.params
		var o := b.size()
		b.resize(o + 9 + 4 * ps.size())
		b.encode_u16(o, it.material); b.encode_u32(o + 2, it.count); b.encode_u8(o + 6, it.shape); b.encode_u16(o + 7, 4 * ps.size())
		for j in ps.size():
			b.encode_s32(o + 9 + 4 * j, ps[j])
	return b

static func _bad(reason: String, item := -1) -> Dictionary:
	return {"ok": false, "error": {"code": "world.stack_invalid", "reason": reason, "item": item}}

## dekódování + kontrola; vrací {ok, items: [{material, count, shape, params, …pojmenované parametry}]} nebo {ok:false, error}
static func decode(b: PackedByteArray) -> Dictionary:
	if b.size() < 2:
		return _bad("truncated")
	var n := b.decode_u16(0)
	var o := 2
	var items := []
	for i in n:
		if o + 9 > b.size():
			return _bad("truncated", i)
		var mat := b.decode_u16(o); var cnt := b.decode_u32(o + 2); var sh := b.decode_u8(o + 6); var pl := b.decode_u16(o + 7)
		o += 9
		if not SHAPES.has(sh):
			return _bad("unknown_shape", i)
		var names: Array = SHAPES[sh].params
		if pl != 4 * names.size():
			return _bad("params_len", i)
		if o + pl > b.size():
			return _bad("truncated", i)
		if mat >= Mat.COUNT or mat == Mat.FOG or mat >= Mat.VIEW_CAVE:   # hlína smí (varianta 2), mlha = vnitřní UNSET
			return _bad("material", i)
		var it := {"material": mat, "count": cnt, "shape": sh, "params": []}
		for j in names.size():
			var v := b.decode_s32(o + 4 * j)
			var r: Array = RANGES[names[j]]
			if v < r[0] or v > r[1]:
				return _bad("param_range:" + names[j], i)
			it.params.append(v); it[names[j]] = v
		o += pl
		if it.has("lzMin") and (it.lzMin > it.lzMax or (it.lzMin < 0) != (it.lzMax < 0)):
			return _bad("lz_band", i)
		if not it.has("lzMin"):
			it["lzMin"] = 0; it["lzMax"] = 63
		# 19:19 (c): host ≥ 0 = ruda roste jen do tohoto materiálu (přepíše ho); hostitel musí být v zásobníku dřív
		if it.get("host", -1) >= 0:
			var ok := false
			for prev in items:
				if prev.material == it.host:
					ok = true
			if not ok or it.host == mat:
				return _bad("host_order", i)
		items.append(it)
	if o != b.size():
		return _bad("trailing_bytes")
	return {"ok": true, "items": items}

static func hash(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()

static func to_json(items: Array) -> Array:
	return items.map(func(it):
		var d := {"material": Mat.NAMES[it.material] + ("" if it.material != Mat.AIR else " (jeskyně)"), "mat_id": it.material, "count": it.count, "shape": SHAPES[it.shape].name}
		if it.get("host", -1) >= 0:
			d["hostName"] = Mat.NAMES[it.host]
		var names: Array = SHAPES[it.shape].params
		for j in names.size():
			d[names[j]] = it.params[j]
		return d)
