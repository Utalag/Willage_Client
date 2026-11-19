extends RefCounted
## KOPIE z blueprint-studie/scripts/eroze51/scenare.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E51 scénáře na malých mřížkách (buňka 0,5 m, NZ buněk ve sloupci). Vrací {W, H, NZ, cells, wall, src, ...}.
## Materiály gen-v3: 1 tráva, 2 hlína, 3 písek, 4 jíl, 6 žula.

const DIRT := 2; const SAND := 3; const CLAY := 4; const GRANITE := 6

static func _base(W: int, H: int, NZ: int) -> Dictionary:
	var c := PackedByteArray(); c.resize(W * H * NZ)
	var wall := PackedByteArray(); wall.resize(W * H)
	var src := PackedFloat64Array(); src.resize(W * H)
	return {"W": W, "H": H, "NZ": NZ, "cells": c, "wall": wall, "src": src}

static func _col(s: Dictionary, i: int, layers: Array) -> void:   # layers = [[mat, do_z], ...] zdola
	var z := 0
	for L in layers:
		while z < int(L[1]) and z < s.NZ: s.cells[i * s.NZ + z] = int(L[0]); z += 1

## 1) dva souběžné pruhy (měkký: hlína 2 buňky na písku; tvrdý: hlína 1 buňka na žule), stejný pramen, odtok přes okraj x = W − 1
static func koryto(q_lps := 5.0) -> Dictionary:
	var W := 40; var H := 13; var s := _base(W, H, 32)
	s.yc = [3, 9]; s.name = "koryto"
	for x in W:
		for y in H:
			var i := x * H + y
			if x == 0 or y == 0 or y == H - 1 or y == 6: s.wall[i] = 1; continue
			var yc := 3 if y < 6 else 9
			var h := int(floor(20.0 - 0.15 * x + 0.6 * absi(y - yc)))
			if y < 6: _col(s, i, [[GRANITE, 4], [SAND, h - 2], [DIRT, h]])
			else: _col(s, i, [[GRANITE, h - 1], [DIRT, h]])
	for yc in s.yc: s.src[2 * H + yc] = q_lps
	return s

## 2) tůň v jílové misce, přítok po hlinitém svahu, odtok přes žulový práh k okraji
static func tun(q_lps := 2.0) -> Dictionary:
	var W := 30; var H := 20; var s := _base(W, H, 32)
	s.name = "tun"; s.cx = 13; s.cy = 10
	for x in W:
		for y in H:
			var i := x * H + y
			if x == 0 or y == 0 or y == H - 1: s.wall[i] = 1; continue
			var r := Vector2(x - 13, (y - 10) * 1.2).length()
			var h := 14
			if r < 8.0: h = 14 - int(round(4.0 * (1.0 - r / 8.0)))
			if x < 6: h = 14 + int((6 - x) * 0.5) + int(absi(y - 10) * 0.5)
			var out := x > 20 and absi(y - 10) <= 0
			if x > 20: h = 15 + absi(y - 10) if not out else 14 - (x - 20) / 3
			if out or x > 20: _col(s, i, [[GRANITE, h]])
			elif r < 8.0: _col(s, i, [[GRANITE, 6], [CLAY, h]])
			else: _col(s, i, [[GRANITE, 6], [CLAY, h - 2], [DIRT, h]])
	s.src[2 * H + 10] = q_lps
	return s

## 4) údolí s pískovou hrází: tůň na hlinitém (propustném) dně se ztrácí do podzemí (Jan 19:48), přeliv přes hráz
static func hraz(q_lps := 3.0) -> Dictionary:
	var W := 36; var H := 15; var s := _base(W, H, 32)
	s.name = "hraz"; s.dam_x = 16; s.yc = 7
	for x in W:
		for y in H:
			var i := x * H + y
			if x == 0 or y == 0 or y == H - 1: s.wall[i] = 1; continue
			var h := int(floor(18.0 - 0.2 * x + 0.8 * absi(y - 7)))
			if x == s.dam_x or x == s.dam_x + 1:
				_col(s, i, [[GRANITE, 6], [DIRT, h], [SAND, maxi(h, 18) + (1 if absi(y - 7) > 0 else 0)]])
			else:
				_col(s, i, [[GRANITE, 6], [DIRT, h]])
	s.src[2 * H + 7] = q_lps
	return s

## 5) výkon: N × N kopce (šum), 16 pramenů, hlína/písek na žule
static func perf(N: int, seed: int) -> Dictionary:
	var s := _base(N, N, 48)
	s.name = "perf"
	var nz := FastNoiseLite.new(); nz.seed = seed; nz.frequency = 0.03
	for x in N:
		for y in N:
			var i := x * N + y
			var h := clampi(int(24.0 + 12.0 * nz.get_noise_2d(x, y)), 6, 44)
			_col(s, i, [[GRANITE, h - 4], [SAND, h - 2], [DIRT, h]])
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	for k in 16:
		s.src[rng.randi_range(4, N - 5) * N + rng.randi_range(4, N - 5)] = 2.0 + rng.randf() * 4.0
	return s
