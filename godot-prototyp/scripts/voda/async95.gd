extends RefCounted
## E95 (p95_async_voda): výpočet vody po kopání ve vlákně na pozadí. Výkop (buňka, síť terénu) se provede hned v hlavním
## vlákně; model vody (ostrov_voda.gd) po celou dobu patří jen pracovnímu vláknu – hlavní vlákno ho nečte ani nemění
## (vlastnictví místo hluboké kopie). Úloha = edit + všechny kroky R (+ vodopády, plocha gw). Na konci vlákno připraví
## POHLED (jen pole, která čte vykreslení) a hlavní vlákno ho převezme v deterministickém tiku t_kopu + zpozdeni.
##
## Režimy: "fronta" = každý výkop zvlášť, v pořadí (= dnešní water_finish před dalším výkopem → stejný výsledek jako
## synchronně); "slouceni" = nový výkop přeruší rozpracované kroky R starého a zavolá edit hned (zbytek se dopočítá jednou,
## povrch se nakonec přepočítá kolem všech sloučených výkopů).
## zpozdeni < 0 = převzít hned, jak je hotovo (nedeterministické, jen pro měření latence).

const H68 = preload("res://scripts/voda/hydro68.gd")

## pohled pro vykreslení (stejné rozhraní, jaké čte ostrov_voda_render.gd: W, H, island, st, falls, level, is_pond)
class Pohled:
	extends RefCounted
	var W := 0
	var H := 0
	var island := PackedByteArray()
	var st := {}
	var falls := []
	var springs := []
	var job := -1
	var otisk := ""
	func level(gi: int) -> float:
		if st.is_empty(): return -1.0
		if st.fill[gi] > st.hm[gi] + 0.01: return st.fill[gi]
		if st.eff[gi] >= float(st.L.thr): return st.hm[gi] + 0.12
		return -1.0
	func is_pond(gi: int) -> bool:
		return not st.is_empty() and st.fill[gi] > st.hm[gi] + 0.01
	func bytes() -> int:   # paměť pohledu (pole + odhad slovníků výstupů a vodopádů)
		if st.is_empty(): return 0
		return st.fill.size() * 8 + st.eff.size() * 8 + st.hm.size() * 8 + st.to.size() * 4 + island.size() + (st.under.size() + falls.size()) * 200

static func pohled(v, job := -1, s_otiskem := false) -> Pohled:
	var o := Pohled.new()
	o.W = v.W; o.H = v.H; o.island = v.island   # island se po postavení nemění (Packed = kopie při zápisu)
	o.job = job
	if v.st.is_empty(): return o
	o.st = {"fill": v.st.fill.duplicate(), "eff": v.st.eff.duplicate(), "hm": v.st.hm.duplicate(), "to": v.st.to.duplicate(),
		"L": {"thr": float(v.st.L.thr)}, "under": (v.st.get("under", []) as Array).duplicate(true)}
	o.falls = v.falls.duplicate(true)
	o.springs = v.springs.duplicate(true)
	if s_otiskem: o.otisk = H68.otisk(v.st)
	return o

var v = null              # model vody (ostrov_voda.gd) – vlastní ho vlákno, dokud běží
var rezim := "fronta"
var zpozdeni := 30        # tiků od výkopu do převzetí výsledku
var s_otiskem := false    # testy: otisk H68 po každé úloze (na vlákně)
var front: Pohled = null  # to, co hra kreslí (jen hlavní vlákno)
var okamzite := true      # okamžité doplnění vody u výkopu do pohledu (jen vzhled)

var _thr: Thread = null
var _mx := Mutex.new()
var _sem := Semaphore.new()
var _queue := []          # čekající úlohy {id, tick, s, lx, ly, nh}
var _done := {}           # id → {pohled, ms, ...}
var _pending := []        # odeslané a nepřevzaté úlohy v pořadí {id, tick}
var _busy := false
var _quit := false
var _next := 0
var zaznam := []           # hotové úlohy (statistiky pro testy)

func _init(model, mode := "fronta", lat := 30) -> void:
	v = model; rezim = mode; zpozdeni = lat
	front = pohled(v)
	_thr = Thread.new()
	_thr.start(_loop)

## hlavní vlákno: výkop sloupce (buňka už je změněná) → úloha do fronty; vrací id. Okamžitý krok jen v pohledu.
func submit(tick: int, s: Vector2i, lx: int, ly: int, nh: int) -> int:
	var id := _next; _next += 1
	_mx.lock()
	_queue.append({"id": id, "tick": tick, "s": s, "lx": lx, "ly": ly, "nh": nh, "t_us": Time.get_ticks_usec()})
	_mx.unlock()
	_pending.append({"id": id, "tick": tick})
	_sem.post()
	if okamzite: okamzity_krok(v.gi_of(s, lx, ly), float(nh))
	return id

## okamžité doplnění: vykopaný sloupec sousedí (8 sousedů) s tůní / korytem s hladinou nad novým dnem → v pohledu dostane
## nejnižší takovou hladinu (voda „steče“ do díry hned). Model vody se nemění, přepíše to výsledek úlohy. Vrací true, když se
## něco doplnilo.
func okamzity_krok(gi: int, hv: float) -> bool:
	var f := front
	if f.st.is_empty(): return false
	f.st.hm[gi] = hv
	var W := f.W; var H := f.H
	var gx := gi / H; var gy := gi % H
	var best := INF
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			var x: int = gx + dx; var y: int = gy + dy
			if x < 0 or y < 0 or x >= W or y >= H: continue
			var j := x * H + y
			var lv := f.level(j)
			if lv > hv + 0.01 and lv < best: best = lv
	if best == INF: return false
	f.st.fill[gi] = best
	return true

## hlavní vlákno, každý tik: převzít výsledky úloh, kterým nastal tik převzetí (deterministicky). Když výsledek ještě
## není, počká (vrátí čekání v ms ve "ceka_ms"). Vrací {"zmena": bool, "ceka_ms": float, "prevzato": [id]}.
func poll(tick: int) -> Dictionary:
	var out := {"zmena": false, "ceka_ms": 0.0, "prevzato": []}
	while not _pending.is_empty():
		var e: Dictionary = _pending[0]
		var ready := false
		_mx.lock(); ready = _done.has(e.id); _mx.unlock()
		if zpozdeni < 0:
			if not ready: break
		elif tick < int(e.tick) + zpozdeni: break
		if not ready:
			var t0 := Time.get_ticks_usec()
			while true:
				OS.delay_usec(200)
				_mx.lock(); ready = _done.has(e.id); _mx.unlock()
				if ready: break
			out.ceka_ms += (Time.get_ticks_usec() - t0) / 1000.0
		_mx.lock(); var d: Dictionary = _done[e.id]; _done.erase(e.id); _mx.unlock()
		_pending.pop_front()
		d.prevzato_tick = tick
		d.prevzato_us = Time.get_ticks_usec()
		zaznam.append(d)
		if d.has("pohled"):
			front = d.pohled
			d.erase("pohled")   # do logu jen čísla
			out.zmena = true
		out.prevzato.append(e.id)
	return out

func busy() -> bool:
	_mx.lock(); var b := _busy or not _queue.is_empty(); _mx.unlock()
	return b

## počkat na všechny úlohy a převzít je (uložení hry, testy, konec)
func finish_all() -> void:
	while busy(): OS.delay_usec(500)
	var z := zpozdeni; zpozdeni = -1
	poll(1 << 40)
	zpozdeni = z

## konec: vlákno doběhne (rozpracovaná úloha se dokončí), model se vrátí volajícímu
func stop():
	_mx.lock(); _quit = true; _mx.unlock()
	_sem.post()
	_thr.wait_to_finish()
	return v

func bytes_pohledy() -> int:
	var n := front.bytes()
	_mx.lock()
	for k in _done:
		if _done[k].has("pohled"): n += _done[k].pohled.bytes()
	_mx.unlock()
	return n

# ---------------- pracovní vlákno ----------------
func _pop():
	_mx.lock()
	var j = null
	if not _queue.is_empty(): j = _queue.pop_front(); _busy = true
	_mx.unlock()
	return j

func _has_queued() -> bool:
	_mx.lock(); var b := not _queue.is_empty(); _mx.unlock()
	return b

func _loop() -> void:
	var merged := []   # režim slouceni: sloupce výkopů, jejichž kroky R se přerušily
	while true:
		_sem.wait()
		_mx.lock(); var q := _quit; _mx.unlock()
		var j = _pop()
		if j == null:
			if q: return
			continue
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = v.edit(j.s, j.lx, j.ly, j.nh)
		var t1 := Time.get_ticks_usec()
		var steps := 0; var smax := 0.0; var cut := false
		merged.append(v.gi_of(j.s, j.lx, j.ly))
		while v.pending():
			if rezim == "slouceni" and _has_queued(): cut = true; break
			var ts := Time.get_ticks_usec()
			v.step(); steps += 1
			smax = maxf(smax, (Time.get_ticks_usec() - ts) / 1000.0)
		if rezim == "slouceni" and not cut and merged.size() > 1:
			_dosloucit(merged)
		var d := {"id": j.id, "tick": j.tick, "edit_ms": (t1 - t0) / 1000.0, "r_kroku": steps, "r_max_ms": smax, "slouceno": cut,
			"cekal_ms": (t0 - int(j.t_us)) / 1000.0}
		if not cut:
			merged = []
			d.pohled = pohled(v, j.id, s_otiskem)
			d.otisk = d.pohled.otisk
		d.prace_ms = (Time.get_ticks_usec() - t0) / 1000.0
		d.hotovo_us = Time.get_ticks_usec()
		d.od_vykopu_ms = (d.hotovo_us - int(j.t_us)) / 1000.0
		_mx.lock(); _done[j.id] = d; _busy = false; _mx.unlock()

## režim slouceni: ostrov_voda.step po dokončení R přepočítá povrch jen kolem POSLEDNÍHO výkopu; sloučené výkopy potřebují
## přepočet kolem všech (stejné volání jako step, jen se všemi sloupci)
func _dosloucit(gis: Array) -> void:
	var ch := PackedInt32Array(); var hh := PackedFloat64Array()
	for gi in gis:
		if not ch.has(gi): ch.append(gi); hh.append(v.st.hm[gi])
	v._add_drains(ch, hh)
	v._update(ch, hh, v.st.src)
	v._claim_update(-1)
	v._falls()
	v._gw()
