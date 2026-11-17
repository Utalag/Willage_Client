extends RefCounted
## Export testovacích vektorů pro VY-070 (porovnání C# generátoru s GDScript): hash objemu + kontrolní buňky.

const Mat = preload("res://scripts/mat.gd")
const Block = preload("res://scripts/block.gd")
const BlockGen = preload("res://scripts/block_gen.gd")
const H = preload("res://scripts/stable_hash.gd")

const CASES := [
	# recept, seed, zrcadlení, rotace, posun, ore_bonus
	["louka", 101, false, 0, 0, 0.0],
	["louka", 404, false, 0, 0, 0.0],
	["kopec", 303, false, 0, 0, 0.0],
	["kopec", 2302, false, 0, 0, 0.0],
	["hora", 202, false, 0, 0, 0.0],
	["hora", 1000, false, 0, 0, 0.0],
	# navíc: transformace (bez sousedů, tedy bez dorovnání stran)
	["hora", 202, true, 1, 2, 0.0],
	["louka", 101, false, 3, -3, 0.0],
]

const GENERATOR_VERSION := "proto-v2.2"
const VOLUME_HASH_ALGO := "FNV-1a 64 (offset 0xcbf29ce484222325, prime 0x100000001b3, mod 2^64) over the 16384 material bytes (1 byte = MaterialId) in index order (lx*16+ly)*64+lz, lx,ly in 0..15, lz in 0..63; lowercase 16-digit hex"
const TRANSFORM_FORMAT := "mirror: bool (lx -> 15-lx, applied first); rotation: degrees 0/90/180/270, each 90 deg step (lx,ly) -> (15-ly,lx), applied after mirror; heightShift: -4..4 cells; sides: N(-ly) E(+lx) S(+ly) W(-lx) = auto | blend1..blend4 | keep (no neighbours in vectors, so sides have no effect)"

static func _sides(sd: PackedInt32Array) -> Dictionary:
	var out := {}
	var keys := ["N", "E", "S", "W"]
	for i in 4:
		var m: int = sd[i]
		out[keys[i]] = "auto" if m == 0 else ("keep" if m == 5 else "blend%d" % m)
	return out

static func export_to(path: String) -> void:
	var keep := BlockGen.gen_version
	BlockGen.gen_version = "proto"   # vectors.json = smlouva proto-v2.2 (STRATA se šumovými rudami), nezávisle na --gen
	_export_proto(path)
	BlockGen.gen_version = keep

static func _export_proto(path: String) -> void:
	var out := []
	for c in CASES:
		var b := Block.new()
		b.kind = c[0]; b.seed = c[1]; b.mirror = c[2]; b.rot = c[3]; b.shift = c[4]; b.ore_bonus = c[5]
		BlockGen.build(b, [null, null, null, null])
		var spots := []
		for i in 20:
			var r := H.mix(b.seed, "SPOT", i)
			var lx := r & 15
			var ly := H.shr(r, 4) & 15
			var lz: int
			if i < 10:
				lz = b.hm[lx * 16 + ly] - 1 - (H.shr(r, 8) & 3)  # u povrchu
			else:
				lz = H.shr(r, 8) & 63                             # kdekoli v objemu
			lz = clampi(lz, 0, 63)
			var m := b.get_cell(lx, ly, lz)
			spots.append({"lx": lx, "ly": ly, "lz": lz, "material": m, "name": Mat.NAMES[m]})
		var summ := {}
		for m in Mat.COUNT:
			if b.summary[m] > 0:
				summ[Mat.NAMES[m]] = b.summary[m]
		var hmb := PackedByteArray()
		for v in b.hm:
			hmb.append(v)
		out.append({
			"recipe": b.kind, "seed": b.seed,
			"transform": {"mirror": b.mirror, "rotation": b.rot * 90, "heightShift": b.shift, "sides": _sides(b.sides)},
			"volume_fnv1a64": H.hex(H.fnv1a64_bytes(b.cells)),
			"surface_fnv1a64": H.hex(H.fnv1a64_bytes(hmb)),
			"material_summary": summ,
			"material_rarity": {"formula": "rarity-v2", "score": snappedf(Mat.score_of(b.summary), 0.0001), "class": Mat.rarity_of(b.summary), "name": Mat.RARITY_NAMES[Mat.rarity_of(b.summary)]},
			"spot_cells": spots,
		})
	var doc := {
		"generatorVersion": GENERATOR_VERSION,
		"volumeHashAlgo": VOLUME_HASH_ALGO,
		"transformFormat": TRANSFORM_FORMAT,
		"generator_version": BlockGen.GENERATOR_VERSION,
		"engine": "Godot %s FastNoiseLite" % Engine.get_version_info().string,
		"dims": {"lx": 16, "ly": 16, "lz": 64},
		"rarityFormula": "rarity-v2: R = sum(n_i*w_i*s_i)/sum(n_i*w_i) over materials (air, fog excluded); s = catalog score, w = catalog weight (default s^2); thresholds class0..4 = %s" % [str(Mat.thresholds())],
		"materialScore": Mat.SCORE, "materialWeight": Mat.WEIGHT,
		"cell_index": "(lx * 16 + ly) * 64 + lz; smyčky lx, ly, lz; 1 bajt = MaterialId",
		"volume_hash": "FNV-1a 64 přes 16384 bajtů v pořadí indexu",
		"surface_hash": "FNV-1a 64 přes 256 bajtů výšky povrchu (lx * 16 + ly)",
		"noise_seed": "mix(seed, purpose, layer) & 0x7FFFFFFF; mix = splitmix64(splitmix64(splitmix64(seed) ^ fnv1a64(purpose)) ^ layer)",
		"spot_cells_rule": "r = mix(seed, 'SPOT', i); lx = r & 15; ly = (r >>> 4) & 15; i < 10: lz = surface - 1 - ((r >>> 8) & 3), jinak lz = (r >>> 8) & 63",
		"materials": Mat.NAMES,
		"cases": out,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	# surový objem prvního případu pro kontrolu hashe mimo Godot
	var b0 := Block.new()
	b0.kind = CASES[0][0]; b0.seed = CASES[0][1]
	BlockGen.build(b0, [null, null, null, null])
	var fb := FileAccess.open(path.get_base_dir() + "/case0_volume.bin", FileAccess.WRITE)
	fb.store_buffer(b0.cells)
	fb.close()
	print("vektory uloženy: ", path)

## Vektory vegetace (samostatný soubor, vectors.json zůstává beze změny).
## recordsHash = FNV-1a 64 nad UTF-8 řetězcem, kde každý záznam (pořadí lx 0..15, uvnitř ly 0..15) je
## "s,lx,ly,lz,ox,oy,yaw,scale;" a desetinná čísla mají 4 místa (invariantní formát, tečka).
const VEG_VERSION := "veg-v2"  # v2: písčina kaktus 0,08 -> 0,11, suchá tráva 0,30 -> 0,42

static func _veg_line(v: Dictionary) -> String:
	return "%d,%d,%d,%d,%.4f,%.4f,%.4f,%.4f;" % [v.s, v.lx, v.ly, v.lz, v.ox, v.oy, v.yaw, v.scale]

static func export_veg(path: String) -> void:
	var keep := BlockGen.gen_version
	BlockGen.gen_version = "proto"   # vegetační vektory jsou nad proto-v2.2 (vegetace závisí jen na povrchu a slupce)
	_export_veg(path)
	BlockGen.gen_version = keep

static func _export_veg(path: String) -> void:
	const Veg = preload("res://scripts/veg.gd")
	var out := []
	for c in CASES + [["piscina", 4504, false, 0, 0, 0.0], ["kopec", 2302, true, 2, 1, 0.0]]:
		var b := Block.new()
		b.kind = c[0]; b.seed = c[1]; b.mirror = c[2]; b.rot = c[3]; b.shift = c[4]; b.ore_bonus = c[5]
		BlockGen.build(b, [null, null, null, null])
		var s := ""
		for v in b.veg:
			s += _veg_line(v)
		var sm := Veg.summary(b.veg)
		var counts := {}
		for i in range(1, Veg.COUNT):
			if sm[i] > 0:
				counts[Veg.NAMES[i]] = sm[i]
		var first := []
		for i in mini(12, b.veg.size()):
			first.append(_veg_line(b.veg[i]))
		out.append({
			"recipe": b.kind, "seed": b.seed,
			"transform": {"mirror": b.mirror, "rotation": b.rot * 90, "heightShift": b.shift},
			"volume_fnv1a64": H.hex(H.fnv1a64_bytes(b.cells)),
			"plants": b.veg.size(), "counts": counts,
			"meanScore": snappedf(Veg.mean_score(sm), 0.0001), "rarity": Veg.rarity_of(sm),
			"recordsHash": H.hex(H.fnv1a64(s)),
			"firstRecords": first,
		})
	var doc := {"vegVersion": VEG_VERSION, "generatorVersion": GENERATOR_VERSION,
		"recordFormat": "s,lx,ly,lz,ox,oy,yaw,scale; floats with 4 decimals; order lx-major then ly",
		"cases": out}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", false))
	f.close()
	print("vegetace: vektory uloženy do ", path)


# ---------------------------------------------------------------- gen-v3 (Jan 20:14): vectors/gen_v3_vectors.json
const Gen3 = preload("res://scripts/gen3/gen3_proto.gd")
const G3 = preload("res://scripts/gen3/gen_v3.gd")
const S3 = preload("res://scripts/gen3/gen3_stack.gd")
const WT = preload("res://scripts/gen3/water_table.gd")
const STUDY_VECTORS := "../lozika-studie/vectors/gen_v3_vectors.json"
const GEN3_CASES := [
	# recept, seed, zrcadlení, rotace, posun, ore_bonus (unikátní = 0.12 → bonus 50 %)
	["louka", 101, false, 0, 0, 0.0], ["louka", 404, false, 0, 0, 0.0], ["kopec", 303, false, 0, 0, 0.0],
	["kopec", 2302, false, 0, 0, 0.0], ["hora", 202, false, 0, 0, 0.0], ["hora", 1000, false, 0, 0, 0.0],
	["piscina", 4504, false, 0, 0, 0.0], ["hora", 202, true, 1, 2, 0.0], ["louka", 101, false, 3, -3, 0.0],
	["hora", 7777, false, 0, 0, 0.12],
]

static func sha256(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return h.finish().hex_encode()

static func water_bytes(w: PackedInt32Array) -> PackedByteArray:
	var wb := PackedByteArray()
	for v in w:
		wb.append(v & 255); wb.append(v >> 8)
	return wb

static func gen3_block(c: Array, soil := true) -> Block:
	var keep := BlockGen.gen_version
	var keep_soil := Gen3.soil_filter
	BlockGen.gen_version = "v3"
	Gen3.soil_filter = soil
	var b := Block.new()
	b.kind = c[0]; b.seed = c[1]; b.mirror = c[2]; b.rot = c[3]; b.shift = c[4]; b.ore_bonus = c[5]
	BlockGen.build(b, [null, null, null, null])
	BlockGen.gen_version = keep
	Gen3.soil_filter = keep_soil
	return b

static func export_gen3(path: String) -> void:
	var study := {}
	var sf := FileAccess.open(ProjectSettings.globalize_path("res://").path_join(STUDY_VECTORS).simplify_path(), FileAccess.READ)
	if sf:
		var d = JSON.parse_string(sf.get_as_text())
		if d is Dictionary:
			for cs in d.get("cases", []):
				study[str(cs.id)] = cs
	var out := []
	for c in GEN3_CASES:
		var b := gen3_block(c)
		var again := gen3_block(c)
		var summ := {}
		for m in Mat.COUNT:
			if b.summary[m] > 0:
				summ[Mat.NAMES[m]] = b.summary[m]
		var wb := water_bytes(b.water)
		var e := {"recipe": b.kind, "seed": b.seed, "oreBonus": c[5],
			"transform": {"mirror": b.mirror, "rotation": b.rot * 90, "heightShift": b.shift},
			"stackBytesHex": b.gen3.stack_hex, "stackHash": b.gen3.stack_hash,
			"water": {"pouredByRecipe": b.gen3.pour, "allotmentByRim": b.gen3.allot, "issued": b.gen3.water,
				"runoffUnits": b.gen3.runoff_units, "retained": snappedf(b.gen3.retained, 0.001)},
			"serverStackCheck": b.gen3.server_errors, "wvb1Header": {"shortfall": b.gen3.shortfall},
			"validator": {"ok": b.gen3.valid.ok, "errorCount": b.gen3.valid.error_count, "firstErrors": b.gen3.valid.errors.slice(0, 3)},
			"material_summary": summ,
			"material_rarity": {"formula": "rarity-v2", "score": snappedf(Mat.score_of(b.summary), 0.0001), "class": Mat.rarity_of(b.summary, Mat.RARITY_THRESHOLDS_V3)},
			"volume_fnv1a64": H.hex(H.fnv1a64_bytes(b.cells)), "sha256MaterialLayer": sha256(b.cells), "sha256WaterLayer": sha256(wb),
			"deterministic": b.cells == again.cells and b.water == again.water and b.gen3.stack_hash == again.gen3.stack_hash}
		# křížová kontrola se studií: bez SOIL_COLS a bez transformace musí vyjít bit po bitu stejně jako lozika-studie
		var key := "%s_%d" % [b.kind, b.seed]
		if study.has(key) and not c[2] and c[3] == 0 and c[4] == 0 and c[5] == 0.0:
			var bs := gen3_block(c, false)
			var cs: Dictionary = study[key]
			e["studyCrossCheck"] = {"stackHash": bs.gen3.stack_hash == cs.in.stackHash,
				"materialLayer": sha256(bs.cells) == cs.sha256MaterialLayer, "waterLayer": sha256(water_bytes(bs.water)) == cs.sha256WaterLayer}
		out.append(e)
	var doc := {
		"genVersion": Gen3.VERSION,
		"note": "gen-v3 v prototypu: tvar povrchu a slupka z proto-v2.2, podzemí ze zásobníku zástupce serveru (lozika-studie). SOIL_COLS: položky s lzMin < 0 jen ve sloupcích, kde má prototyp nahoře trávu, hlínu nebo písek.",
		"sharedTable": WT.source(), "sharedTableCopyInSync": WT.same_as_shared(),
		"rarityThresholdsV3": Mat.RARITY_THRESHOLDS_V3,
		"shapes": S3.SHAPES, "waterUnit": "u16, 4096 = plná buňka objemu",
		"cell_index": "(lx * 16 + ly) * 64 + lz; 1 bajt = MaterialId; vrstva vody 2 bajty LE na buňku",
		"engine": "Godot %s" % Engine.get_version_info().string,
		"cases": out}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("uloženo ", path)
