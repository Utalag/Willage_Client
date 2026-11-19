extends RefCounted
## E52 varianta 1 = základ: dnešní voda/podzemi.gd (slovníky dist / par / vz), jen obal s měřením času a s touched().

const UG = preload("res://scripts/voda/podzemi.gd")
const SELF = preload("res://scripts/podzemi52/ug_slovnik.gd")

static func make(W: int, H: int, NZ: int, mat, top: PackedInt32Array, wall: PackedByteArray, p: Dictionary) -> Dictionary:
	var c := UG.make(W, H, NZ, mat, top, wall, p)
	c.impl = SELF; c.stats = {"solve_ms": 0.0, "solves": 0, "cells": 0}
	return c

static func entry(ctx: Dictionary, col: int) -> int:
	return UG.entry(ctx, col)

static func solve(ctx: Dictionary, entries: PackedInt32Array, q: float, excl := {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var r := UG.solve(ctx, entries, q, excl)
	ctx.stats.solve_ms += (Time.get_ticks_usec() - t0) / 1000.0; ctx.stats.solves += 1; ctx.stats.cells += int(r.cells)
	return r

## změna povrchu ve sloupcích ch na výšky hv (jednotky buněk této mřížky): dotčené těleso → přepočet; buňky nad novým
## povrchem se vykopou (vzduch), top se sníží
static func touched(ctx: Dictionary, cache: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> bool:
	var hit := false
	var NZ: int = ctx.NZ
	for key in cache:
		var mem: Dictionary = cache[key].get("members", {})
		for c in ch:
			if mem.has(c * NZ + int(ctx.top[c]) - 1) or mem.has(c * NZ + int(ctx.top[c]) - 2): hit = true
	dig(ctx, ch, hv)
	return hit

static func dig(ctx: Dictionary, ch: PackedInt32Array, hv: PackedFloat64Array) -> void:
	var NZ: int = ctx.NZ
	for k in ch.size():
		var c := ch[k]; var nt := clampi(int(ceil(hv[k] - 1e-6)), 0, NZ)
		for z in range(nt, int(ctx.top[c])): ctx.mat[c * NZ + z] = 0
		ctx.top[c] = mini(int(ctx.top[c]), nt)
