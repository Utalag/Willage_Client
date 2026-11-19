extends RefCounted
## E64 K (+I, +R, +V): kapilární sestup prelivu bez závislosti na pořadí.
## Hodnota pásma = nejlepší úzké hrdlo cesty od vstupu: capv(b) = max přes cesty min(…) podle stejných pravidel hran
## jako E63 (_p1_edge). Hrana je monotónní funkce f(x) = (x > práh) ? min(x, strop) : −∞ a platí f(x) ≤ x.
## Zlepšení se přijme jen ostře (nc > capv), bez tolerance E → pevný bod je jediný (důkaz v PROP E64).
## Pořadí: halda (hodnota sestupně, id vzestupně). Na pořadí výsledek nezávisí, halda jen omezuje práci.
## Stav na volání (st): capv, par (strom rodičů), fch/nsib/psib (seznamy dětí), pos+cl (dosažená pásma), pool, mk/mg.
## Úloha (tento objekt) běží po krocích: run(budget) zpracuje nejvýš budget operací (počet, ne čas).
const HEAP = preload("res://scripts/alg64/heap64.gd")
const E := 1e-6

var c: Dictionary
var st: Dictionary
var ents: PackedInt32Array
var heap = HEAP.new()
var phase := 0          # 0 = S (BFS potomků), 1 = vynulování S, 2 = osazení, 3 = sestup, 4 = výběr pool, 5 = hotovo
var S := PackedInt32Array()
var k := 0
var newr := PackedInt32Array()
var use_v := false
var xi := 0          # fáze 0: index do S (rozbalení dětí)
var cheap = null     # fáze 0: kandidáti (děti zneplatněných), halda (hodnota sestupně, id)
var stats := {"S": 0, "seeds": 0, "pops": 0, "stale": 0, "chain": 0, "scan": 0, "inject": 0}

static func new_state(c: Dictionary, ents: PackedInt32Array) -> Dictionary:
	var n: int = c.lo.size()
	var capv := PackedFloat64Array(); capv.resize(n); capv.fill(-INF)
	var es := {}
	for e in ents: if e >= 0: es[e] = true
	var st := {"capv": capv, "ents": ents, "eset": es, "dirty": {}, "pfd": {}, "pfc": {}, "pool": -1, "cl": PackedInt32Array(), "mg": 0}
	var vb := PackedByteArray(); vb.resize(n); st.vb = vb   # navštívená pásma pro D (1 dosaženo, 2 tůň), udržuje se průběžně
	st.comp = PackedInt32Array()
	for nm in ["par", "fch", "nsib", "psib", "pos", "mk"]:
		var a := PackedInt32Array(); a.resize(n); a.fill(-1); st[nm] = a
	return st

static func state_bytes(st: Dictionary) -> int:
	return st.capv.size() * 8 + st.par.size() * 4 * 6 + st.cl.size() * 4 + st.vb.size()

## plný výpočet = oprava s prázdným stavem (stejný kód, jen osazení ze vstupů)
func setup_full(c_: Dictionary, st_: Dictionary, uv: bool) -> void:
	c = c_; st = st_; ents = st.ents; use_v = uv
	if c.has("_k64c"): stats = c._k64c   # společná počítadla (jen měření)
	S = PackedInt32Array(); phase = 2; k = 0
	st.mg = int(st.mg) + 1

## oprava po výkopech: cols = změněná pásma X
func setup_repair(c_: Dictionary, st_: Dictionary, cols: Array, uv: bool) -> void:
	c = c_; st = st_; ents = st.ents; use_v = uv
	if c.has("_k64c"): stats = c._k64c
	_begin_S(cols)

func _begin_S(xs: Array) -> void:
	xs = xs.duplicate(); xs.sort()   # X = změněná pásma (+ vstupy ve sloupci se změněným povrchem), kanonicky seřazená
	st.mg = int(st.mg) + 1
	var mg: int = 2 * int(st.mg); var mk: PackedInt32Array = st.mk
	S = PackedInt32Array()
	for b in xs:
		if mk[b] != mg: mk[b] = mg; S.append(b)
	phase = 0; k = 0; xi = 0; cheap = HEAP.new()

## nový výkop během běžící úlohy: přípravu (fáze 0–2) dokončí hned, pak přidá S2 do stejné haldy
func inject(cols: Array) -> void:
	stats.inject += 1
	if phase < 3: run_until(3)
	if phase >= 4: phase = 3   # sestup už doběhl, ale pool ještě ne: znovu otevřít (pool se přepočítá)
	_begin_S(cols)
	run_until(3)

func run_until(ph: int) -> void:
	while phase < ph: run(1 << 30, ph)

## zpracuje nejvýš budget operací, vrací spotřebu
func run(budget: int, stop_phase: int = 5) -> int:
	var ops := 0
	var capv: PackedFloat64Array = st.capv; var par: PackedInt32Array = st.par; var fch: PackedInt32Array = st.fch
	var nsib: PackedInt32Array = st.nsib; var psib: PackedInt32Array = st.psib; var pos: PackedInt32Array = st.pos
	var mk: PackedInt32Array = st.mk; var mg: int = 2 * int(st.mg)   # mk == mg: v S, mk == mg + 1: ponecháno
	var lo: PackedFloat64Array = c.lo; var hi: PackedFloat64Array = c.hi; var bcol: PackedInt32Array = c.bcol
	var body: PackedByteArray = c.body; var ns: PackedInt32Array = c.ns; var nb: PackedInt32Array = c.nb; var hh: PackedFloat64Array = c.h
	var chain: PackedByteArray = c.get("_chain64", PackedByteArray())
	while phase < stop_phase and ops < budget:
		if phase == 0:   # S = X + potomci, kteří nemají jinou bezpečnou oporu se stejnou hodnotou (prořezání)
			var es: Dictionary = st.eset
			while ops < budget:
				if xi < S.size():
					var b := S[xi]; xi += 1; ops += 1
					var ch := fch[b]
					while ch >= 0:
						if mk[ch] != mg and mk[ch] != mg + 1: cheap.push(capv[ch], ch)
						ch = nsib[ch]
					continue
				if cheap.size() == 0: phase = 1; k = 0; stats.S = int(stats.S) + S.size(); break
				var v: float = cheap.top_v(); var w: int = cheap.pop(); ops += 1
				if mk[w] == mg or mk[w] == mg + 1: continue
				var keep := false
				if es.has(w) and minf(hi[w], hh[bcol[w]]) == v:   # vstup mimo X: semínko se nezměnilo
					keep = true; _set_par(w, -1, par, fch, nsib, psib)
				elif body[w] == 1:
					var lb := lo[w]; var hb := hi[w]; var cbb := bcol[w]
					for j in range(ns[w], ns[w + 1]):
						var u := nb[j]
						var mu := mk[u]
						if mu == mg: continue
						var cu := capv[u]
						if cu == -INF or not (cu > v or mu == mg + 1): continue   # opora: ostře vyšší mimo S, nebo už ponechaná
						var lu := lo[u]; var hu := hi[u]
						var olo := maxf(lu, lb); var ohi := minf(hu, hb)
						var same := cbb == bcol[u]
						if same:
							if ohi < olo - E: continue
						elif ohi <= olo + E: continue
						var below := same and hb <= lu + E
						if not below and cu <= olo + E: continue
						var nc := minf(cu, hb) if below else minf(cu, ohi)
						if nc == v: keep = true; _set_par(w, u, par, fch, nsib, psib); break
				if keep: mk[w] = mg + 1; stats.kept = int(stats.get("kept", 0)) + 1
				else: mk[w] = mg; S.append(w)
		elif phase == 1:   # vynulování S (odpojit od rodiče mimo S, vyřadit z cl)
			var cl: PackedInt32Array = st.cl
			while k < S.size() and ops < budget:
				var b := S[k]; k += 1; ops += 1
				var p := par[b]
				if p >= 0 and mk[p] != mg: _unlink(b, p, fch, nsib, psib)
				par[b] = -1; fch[b] = -1; nsib[b] = -1; psib[b] = -1
				if capv[b] > -INF:
					capv[b] = -INF
					if st.vb[b] == 1: st.vb[b] = 0
					var i := pos[b]; var last := cl[cl.size() - 1]
					cl[i] = last; pos[last] = i; cl.resize(cl.size() - 1); pos[b] = -1
					if int(st.pool) == b: st.pool = -1
			if k >= S.size(): phase = 2; k = -1
		elif phase == 2:   # osazení: vstupy v S (u plného všechny) a hrany z dosažených pásem mimo S do S
			if k < 0: k = 0
			if k == 0:
				for e in ents:
					if e < 0: continue
					if not S.is_empty() and mk[e] != mg: continue
					var v := minf(hi[e], hh[bcol[e]])
					if v > capv[e]:
						if capv[e] == -INF: _add(e)
						capv[e] = v; _set_par(e, -1, par, fch, nsib, psib); heap.push(v, e)
					ops += 1
				k = 0 if S.is_empty() else 0
				if S.is_empty(): phase = 3; continue
				k = 1   # k-1 = index do S
			while k - 1 < S.size() and ops < budget:
				var b := S[k - 1]; k += 1; ops += 1
				if body[b] == 0: continue
				var lb := lo[b]; var hb := hi[b]; var cbb := bcol[b]
				for j in range(ns[b], ns[b + 1]):   # CSR je symetrická (ověřeno tools/alg64_info.gd) → sousedé = předchůdci
					var u := nb[j]
					if mk[u] == mg: continue
					var cu := capv[u]
					if cu == -INF: continue
					var lu := lo[u]; var hu := hi[u]
					var olo := maxf(lu, lb); var ohi := minf(hu, hb)
					var same := cbb == bcol[u]
					if same:
						if ohi < olo - E: continue
					elif ohi <= olo + E: continue
					var below := same and hb <= lu + E
					if not below and cu <= olo + E: continue
					var nc := minf(cu, hb) if below else minf(cu, ohi)
					if nc > capv[b]:
						if capv[b] == -INF: _add(b)
						capv[b] = nc; _set_par(b, u, par, fch, nsib, psib)
				if capv[b] > -INF: heap.push(capv[b], b); stats.seeds += 1
			if k - 1 >= S.size(): phase = 3
		elif phase == 3:   # sestup (halda, ostrá zlepšení)
			var stk := PackedInt32Array()
			while heap.size() > 0 and ops < budget:
				var v: float = heap.top_v(); var b0: int = heap.pop(); ops += 1
				if v != capv[b0]: stats.stale += 1; continue
				stats.pops += 1
				stk.append(b0)
				while not stk.is_empty():
					var b := stk[stk.size() - 1]; stk.resize(stk.size() - 1)
					var cb := capv[b]; var lb := lo[b]; var hb := hi[b]; var colb := bcol[b]
					for j in range(ns[b], ns[b + 1]):
						var b2 := nb[j]
						if body[b2] == 0: continue
						var lo2 := lo[b2]; var hi2 := hi[b2]
						var olo := maxf(lb, lo2); var ohi := minf(hb, hi2)
						var same := bcol[b2] == colb
						if same:
							if ohi < olo - E: continue
						elif ohi <= olo + E: continue
						var below := same and hi2 <= lb + E
						if not below and cb <= olo + E: continue
						var nc := minf(cb, hi2) if below else minf(cb, ohi)
						if nc > capv[b2]:
							if capv[b2] == -INF: _add(b2)
							capv[b2] = nc; _set_par(b2, b, par, fch, nsib, psib)
							if use_v and chain[b2] == 1: stk.append(b2); stats.chain += 1; ops += 1
							else: heap.push(nc, b2)
			if heap.size() == 0: phase = 4; k = -1
		elif phase == 4:   # pool = nejnižší (lo, id) mezi dosaženými; udržuje se, sken jen když zmizel
			var pool: int = st.pool
			if k < 0:
				if pool >= 0 and capv[pool] > -INF:
					for b in newr:
						if capv[b] > -INF and (lo[b] < lo[pool] or (lo[b] == lo[pool] and b < pool)): pool = b
					ops += newr.size()
					st.pool = pool; newr = PackedInt32Array(); phase = 5; continue
				st.pool = -1; k = 0
			var cl2: PackedInt32Array = st.cl
			while k < cl2.size() and ops < budget:
				var b := cl2[k]; k += 1; ops += 1; stats.scan += 1
				if pool < 0 or lo[b] < lo[pool] or (lo[b] == lo[pool] and b < pool): pool = b
			st.pool = pool
			if k >= cl2.size(): newr = PackedInt32Array(); phase = 5
	return ops

func _add(b: int) -> void:
	var cl: PackedInt32Array = st.cl
	st.pos[b] = cl.size(); cl.append(b); newr.append(b)
	if st.vb[b] == 0: st.vb[b] = 1
	c.lab[b] = int(c.gen)

static func _unlink(b: int, p: int, fch: PackedInt32Array, nsib: PackedInt32Array, psib: PackedInt32Array) -> void:
	var pv := psib[b]; var nx := nsib[b]
	if pv >= 0: nsib[pv] = nx
	else: fch[p] = nx
	if nx >= 0: psib[nx] = pv
	nsib[b] = -1; psib[b] = -1

static func _set_par(b: int, p: int, par: PackedInt32Array, fch: PackedInt32Array, nsib: PackedInt32Array, psib: PackedInt32Array) -> void:
	var old := par[b]
	if old == p: return
	if old >= 0: _unlink(b, old, fch, nsib, psib)
	par[b] = p
	if p >= 0:
		var nx := fch[p]
		nsib[b] = nx; psib[b] = -1
		if nx >= 0: psib[nx] = b
		fch[p] = b

## otisk stavu sestupu (capv všech pásem, −∞ = nedosaženo) + pool
static func digest(st: Dictionary) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256)
	h.update(st.capv.to_byte_array())
	h.update(PackedInt32Array([int(st.pool)]).to_byte_array())
	return h.finish().hex_encode().substr(0, 16)
