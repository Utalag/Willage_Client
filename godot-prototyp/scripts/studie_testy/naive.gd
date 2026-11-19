extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/naive.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Srovnání: NEZÁVISLÉ bloky gen-v3 (lozika-studie, beze změny). Stejný povrch a STEJNÉ počty materiálů jako výsledek
## blueprintu, ale zásobník ze zástupce serveru (gen3_server.build_stack) a rozmístění gen-v3 v každém bloku zvlášť.

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const G = preload("res://scripts/teren/zaklad/gen_v3.gd")
const SRV = preload("res://scripts/teren/zaklad/gen3_server.gd")
const S = preload("res://scripts/teren/zaklad/gen3_stack.gd")

static func block(rec: Dictionary) -> Dictionary:
	var hm: PackedInt32Array = rec.hm
	var proto := PackedByteArray(); proto.resize(G.N)
	for i in 256:
		proto[i * 64 + hm[i] - 1] = Mat.GRASS
	var cnt := PackedInt32Array(); cnt.resize(Mat.COUNT)
	for c in rec.cells:
		cnt[c] += 1
	var s := {}
	for m in [Mat.DIRT, Mat.SAND, Mat.CLAY, Mat.CLAY_DEPOSIT, Mat.LIMESTONE, Mat.GRANITE, Mat.BASALT, Mat.COPPER, Mat.IRON]:
		if cnt[m] > 0:
			s[m] = cnt[m]
	# gen-v3: měď roste do žuly, železo do čediče → hostitel musí obsahovat i buňky rudy
	s[Mat.GRANITE] = s.get(Mat.GRANITE, 0) + cnt[Mat.COPPER]
	s[Mat.BASALT] = s.get(Mat.BASALT, 0) + cnt[Mat.IRON]
	var items := SRV.build_stack(s)
	var g := G.generate_bytes(proto, hm, int(rec.bp.seed), S.encode(items), 0)
	if not g.ok:
		push_error("naivní gen-v3: " + str(g.error))
	return {"cells": g.get("cells", PackedByteArray()), "hm": hm}
