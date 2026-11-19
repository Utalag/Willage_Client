extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/hostitele.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Tabulka minerál → povolení hostitelé (Jan 16:02) z data/mineraly_hostitele.json. Klíče hostitelů = klíče hornin
## z data/poradi_hornin.json, záložně klíče sdílené tabulky vody (granite, basalt, limestone, clay …). MaterialId minerálu
## je v tabulce (staré 8, 9, 12; nové 100+). Výstup = specifikace růstu ore_v0 (tvar a parametry jako gen-v3 _spec),
## relax = [] → žádné záložní hostitele, nedostatek = schodek.

const Mat = preload("res://scripts/teren/zaklad/mat.gd")
const VPar = preload("res://scripts/teren/zaklad/voda_params.gd")
const PATH := "res://data/teren/mineraly_hostitele.json"
const ROCKS := "res://data/teren/poradi_hornin.json"

static var _T := {}
static var _N := {}

static func ids() -> Dictionary:
	var out := {}
	var d: Dictionary = VPar.load_shared_table()
	for k in d.get("materials", {}):
		out[k] = int(d.materials[k].id)
	var r = JSON.parse_string(FileAccess.open(ROCKS, FileAccess.READ).get_as_text())
	for e in r.rocks:
		out[e.key] = int(e.id)
	return out

static func table() -> Dictionary:
	if _T.is_empty():
		var raw: Dictionary = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
		var id := ids()
		for k in raw.minerals:
			var m: Dictionary = raw.minerals[k]
			var mat: int = int(m.id)
			var hosts := []
			for h in m.hosts:
				if not (int(id[h]) in hosts):
					hosts.append(int(id[h]))
			var heap := int(m.maxHeap)
			var sp := {"name": k, "key": mat, "material": mat, "host": hosts, "seeds": [1, 1],
				"supply": [maxi(heap * 6 / 10, 1), heap], "lz": [int(m.lz[0]), int(m.lz[1])], "shape": m.shape, "relax": [],
				"label": m.get("name", k), "score": float(m.get("score", 0)), "color": m.get("color", "")}
			match m.shape:
				"vein":
					sp["keep"] = int(m.inertia_permille) * 65536 / 1000
					sp["branch"] = int(m.branch_permille) * 65536 / 1000
					sp["dirW"] = {"horiz": 2, "vert": 3}
				"layer":
					sp["pH"] = int(m.pH_u16); sp["pV"] = int(m.pV_u16)
			_T[mat] = sp
	return _T

## jména materiálů (horniny z tabulky pořadí, minerály z tabulky hostitelů, jinak Mat.NAMES)
static func name_of(m: int) -> String:
	if _N.is_empty():
		var r = JSON.parse_string(FileAccess.open(ROCKS, FileAccess.READ).get_as_text())
		for e in r.rocks:
			if not _N.has(int(e.id)): _N[int(e.id)] = e.name
		for k in table():
			_N[k] = table()[k].label
	if m < Mat.NAMES.size() and not _N.has(m):
		return Mat.NAMES[m]
	return _N.get(m, "?%d" % m)

static func hosts_text(mat: int) -> String:
	return "/".join(table()[mat].host.map(func(h): return name_of(h)))
