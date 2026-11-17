extends RefCounted
## Scénáře studie (vzorky ~10 × 10 × 4 buněk). Každý vrací slovník:
## { sim, key, title, N (krok snímků), digs: [{tick, cells:[Vector3i], label}], phases: [tiky snímků], note }
const M = preload("res://scripts/materials.gd")
const Sim = preload("res://scripts/water_sim.gd")
const Sources = preload("res://scripts/sources.gd")

const LIST := [
	[1, "jilova_misa", "1 · jílová mísa pod pískem (déšť)"],
	[2, "svah_trava_pisek", "2 · svah: louka vs. holý písek (přítok shora, mokrá půda)"],
	[3, "hraz_porezni", "3 · hráz z porézní skály (pomalý průsak)"],
	[4, "skalni_panev", "4 · skalní pánev přetéká"],
	[5, "kopani_u_vody", "5 · kopání u vody"],
	[6, "prameny", "6 · prameny: přítok shora, ve svahu, podzemní kapsa"],
]

static func _pv(P: Dictionary, k: String, def: float) -> float:
	return def if float(P[k]) < 0.0 else float(P[k])

static func make(n: int, P: Dictionary) -> Dictionary:
	match n:
		1: return _s1(P)
		2: return _s2(P)
		3: return _s3(P)
		4: return _s4(P)
		5: return _s5(P)
		_: return _s6(P)

static func _fill(s, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, m: int) -> void:
	for z in range(z0, z1 + 1):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				s.set_mat(x, y, z, m)

## 1: dno z jílu (z0) + jílový val po obvodu (z1), uvnitř písek (z1, z2); uprostřed prohlubeň 4 × 4 až na jílové dno.
## Prší 60 tiků: déšť se vsákne pískem, nad jílem stoupá podzemní voda a v prohlubni vznikne rybník.
## Po dešti voda nad valem odteče stranami, rybník v jílové míse zůstane (jen pomalu ubývá odparem).
static func _s1(P: Dictionary) -> Dictionary:
	var s = Sim.new(10, 10, 4, P)
	_fill(s, 0, 9, 0, 9, 0, 0, M.CLAY)
	_fill(s, 0, 9, 0, 9, 1, 1, M.CLAY)
	_fill(s, 1, 8, 1, 8, 1, 1, M.SAND)
	_fill(s, 0, 9, 0, 9, 2, 2, M.SAND)
	_fill(s, 3, 6, 3, 6, 1, 2, M.AIR)          # prohlubeň až na jílové dno
	s.open_sides = 15
	s.rain = _pv(P, "rain", 0.02)
	s.rain_ticks = int(P["rain_ticks"]) if int(P["rain_ticks"]) >= 0 else 60   # prší 60 tiků, pak schne
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 40
	return {"sim": s, "N": N, "phases": [0, N, 2 * N, 4 * N], "digs": [], "cut": 5}

## 2: svah 11 × 12 × 6 (širší kvůli dvěma pruhům a rozestupu): vlevo louka (tráva na hlíně), uprostřed žulový hřbet,
## vpravo holý písek. Pod vším jíl. Nahoře na obou pruzích stejný přítok (top_flow), bez deště. Odtok jen dole (jih).
static func _s2(P: Dictionary) -> Dictionary:
	var s = Sim.new(11, 12, 6, P)
	for y in 12:
		var top := maxi(3 - y / 3, 1)           # 3, 2, 1, 1 po třech řadách (dole rovina z materiálu pruhu)
		for x in 11:
			s.set_mat(x, y, 0, M.CLAY)
			for z in range(1, top + 1):
				if x < 5:
					s.set_mat(x, y, z, M.GRASS if z == top else M.DIRT)
				elif x > 5:
					s.set_mat(x, y, z, M.SAND)
				else:
					s.set_mat(x, y, z, M.GRANITE)
			if x == 5 and top + 1 < 5:
				s.set_mat(x, y, top + 1, M.GRANITE)   # hřbet o vrstvu výš odděluje pruhy
	var wet := _pv(P, "wet0", 0.95)            # půda po dešti: porovnává se hlavně povrchový odtok
	for i in s.w.size():
		if s.mat[i] != M.AIR:
			s.w[i] = s.cap[i] * wet
	s.initial = s.total()
	s.open_sides = 8
	s.rain = _pv(P, "rain", 0.0)
	s.rain_ticks = int(P["rain_ticks"])
	var r := _pv(P, "spring", 0.25)
	s.add_source({"type": "top_flow", "x": 2, "y": 0, "rate": r})
	s.add_source({"type": "top_flow", "x": 8, "y": 0, "rate": r})
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 60
	return {"sim": s, "N": N, "phases": [0, N, 2 * N, 4 * N], "digs": [], "cut": 6, "compare_x": [[0, 4], [6, 10]]}

## 3: údolí s jílovým dnem; nahoře pramen plní nádrž, kterou drží hráz z vápence (porézní skála) přes celé údolí.
## Hrází voda pomalu prosakuje a pod ní teče malý potok k jižnímu okraji.
static func _s3(P: Dictionary) -> Dictionary:
	var s = Sim.new(10, 10, 4, P)
	_fill(s, 0, 9, 0, 9, 0, 0, M.CLAY)
	_fill(s, 0, 0, 0, 9, 1, 3, M.CLAY)          # boky údolí
	_fill(s, 9, 9, 0, 9, 1, 3, M.CLAY)
	_fill(s, 1, 8, 0, 0, 1, 3, M.CLAY)          # horní konec
	_fill(s, 1, 8, 5, 5, 1, 3, M.LIMESTONE)     # hráz (1 buňka silná)
	_fill(s, 1, 2, 6, 9, 1, 1, M.CLAY)          # pod hrází koryto x 3–6 na jílovém dně (z0) …
	_fill(s, 7, 8, 6, 9, 1, 1, M.CLAY)
	_fill(s, 1, 2, 6, 9, 2, 2, M.GRASS)         # … a travnaté břehy
	_fill(s, 7, 8, 6, 9, 2, 2, M.GRASS)
	s.open_sides = 8
	s.add_source({"type": "top_flow", "x": 4, "y": 2, "rate": _pv(P, "spring", 0.2)})
	s.rain = _pv(P, "rain", 0.0)
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 100
	return {"sim": s, "N": N, "phases": [0, N, 2 * N, 4 * N], "digs": [], "cut": 4}

## 4: žulové podloží, uprostřed žulová pánev 4 × 4 se stěnou 2 vrstvy a zářezem na východní straně.
## Kolem pánve písek. Pramen pánev naplní, voda přeteče zářezem a po písku teče k východnímu okraji.
static func _s4(P: Dictionary) -> Dictionary:
	var s = Sim.new(10, 10, 4, P)
	_fill(s, 0, 9, 0, 9, 0, 0, M.GRANITE)
	_fill(s, 0, 9, 0, 9, 1, 1, M.SAND)
	_fill(s, 1, 6, 2, 7, 1, 2, M.GRANITE)       # pánev
	_fill(s, 2, 5, 3, 6, 1, 2, M.AIR)           # vnitřek 4 × 4 × 2
	s.set_mat(6, 5, 2, M.AIR)                   # zářez (přeliv)
	s.open_sides = 2
	s.add_source({"type": "top_flow", "x": 3, "y": 4, "rate": _pv(P, "spring", 0.35)})
	s.rain = _pv(P, "rain", 0.0)
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 50
	return {"sim": s, "N": N, "phases": [0, N, 2 * N, 4 * N], "digs": [], "cut": 5}

## 5: rybník na jílu (z1), břeh z písku a louky na východě. Pod jílem stará chodba (vzduch, z0) v žule.
## Tik N: vykopeme příkop do břehu pod úrovní hladiny -> voda ho zaplaví.
## Tik 2N: prokopeme jíl pode dnem rybníka -> rybník vyteče do chodby.
static func _s5(P: Dictionary) -> Dictionary:
	var s = Sim.new(10, 10, 4, P)
	_fill(s, 0, 9, 0, 9, 0, 0, M.GRANITE)
	_fill(s, 1, 8, 1, 8, 0, 0, M.AIR)           # dutina / chodba pod jílem
	_fill(s, 0, 9, 0, 9, 1, 1, M.CLAY)
	_fill(s, 0, 9, 0, 9, 2, 3, M.CLAY)          # okraje
	_fill(s, 1, 5, 1, 8, 2, 3, M.AIR)           # rybník
	_fill(s, 6, 8, 1, 8, 2, 2, M.SAND)          # břeh: písek …
	_fill(s, 7, 8, 1, 8, 3, 3, M.GRASS)         # … a louka nahoře
	_fill(s, 6, 6, 1, 8, 3, 3, M.AIR)           # nízká pláž
	for y in range(1, 9):
		for x in range(1, 6):
			s.w[s.idx(x, y, 2)] = 0.9            # hladina 0,45 m
		for x in range(6, 9):
			var i: int = s.idx(x, y, 2)
			s.w[i] = s.cap[i] * 0.9              # břeh nasycený (rovnováha s rybníkem)
	s.initial = s.total()
	s.open_sides = 0
	s.rain = _pv(P, "rain", 0.0)
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 30
	var trench := []
	for x in range(6, 9):
		trench.append(Vector3i(x, 4, 2))
		trench.append(Vector3i(x, 5, 2))
	for x in range(7, 9):
		trench.append(Vector3i(x, 4, 3))
		trench.append(Vector3i(x, 5, 3))
	return {"sim": s, "N": N, "phases": [0, N, N + N / 2, 2 * N, 2 * N + N / 2, 4 * N], "cut": 6,
		"digs": [{"tick": N, "cells": trench, "label": "příkop do břehu"},
			{"tick": 2 * N, "cells": [Vector3i(3, 5, 1)], "label": "průkop jílem pod rybníkem"}]}

## 6: kopec 10 × 10 × 5: horní plošina (4 vrstvy) a svahová stěna, dole louka (3 vrstvy). Pod loukou žula s kapsou.
## Zdroje se rozmístí ze seedu bloku (sources.gd). Tik 2N: někdo prokope louku a jíl až ke kapse.
static func _s6(P: Dictionary) -> Dictionary:
	var s = Sim.new(10, 10, 5, P)
	for y in 10:
		var top := 3 if y < 4 else 2
		for x in 10:
			s.set_mat(x, y, 0, M.GRANITE)
			s.set_mat(x, y, 1, M.CLAY)
			for z in range(2, top + 1):
				s.set_mat(x, y, z, M.GRASS if z == top else (M.SAND if z == 2 else M.DIRT))
	s.open_sides = 8
	s.rain = _pv(P, "rain", 0.0)
	var src: Array = Sources.place(s, int(P["src_seed"]), P)
	var N := int(P["ticks"]) if int(P["ticks"]) > 0 else 30
	var digs := []
	for so in src:
		if so.type == "underground_pocket":
			var c: Vector3i = so.cells[0]
			var shaft := []
			for z in range(c.z + 1, s.surface_z(c.x, c.y) + 1):
				shaft.append(Vector3i(c.x, c.y, z))
			digs.append({"tick": 2 * N, "cells": shaft, "label": "šachta ke kapse"})
	return {"sim": s, "N": N, "phases": [0, N, 2 * N, 2 * N + N / 2, 4 * N], "digs": digs, "cut": 0, "sources": src}
