extends "res://scripts/voda/ostrov_voda.gd"
## E95 (jen měření): povrchová voda celého bloku 128 m z funkce světa E90 (tools/svah92 best_tile), buňky 0,5 m →
## 256 × 256 sloupců. Stejný model jako ostrov (tok.gd + E68 hydro68.update / tok60, prameny prameny.gd, obsazování E74),
## ale BEZ podzemí (funkce vrstev pro blok 128 m zatím nejsou – to staví E96). Výkop = edit() ostrova (lokální přepočet).
## Materiál pro prameny a ztráty: sníh nad hranicí sněhu (L90.mat = 2), jinde žula (nepropustná).
const L90 = preload("res://scripts/teren/lod90.gd")
const S92 = preload("res://scripts/teren/svah92.gd")
const PR = preload("res://scripts/teren/params.gd")
const MatC = preload("res://scripts/mat.gd")

var dlazdice := Vector2i.ZERO
var mat_top := PackedInt32Array()

func gi_of(_s: Vector2i, x: int, y: int) -> int:
	return x * H + y

func slot_of(gi: int) -> Array:
	return [Vector2i.ZERO, gi / H, gi % H]

## postavit z výšek h (m, N × N bodů po 0,5 m; bere se prvních 256 × 256), výšky se zaokrouhlí na buňky 0,5 m
func build128(f: Dictionary, h: PackedFloat64Array, N: int, pram_max := 16) -> void:
	var t0 := Time.get_ticks_usec()
	T.ensure()
	p = V64.scaled(T.p, 16)
	p.pram_max = pram_max
	W = 256; H = 256
	var n := W * H
	hm = PackedFloat64Array(); hm.resize(n)
	mat_top = PackedInt32Array(); mat_top.resize(n)
	for x in W:
		for y in H:
			var hv: float = h[x * N + y]
			hm[x * H + y] = roundf(hv / 0.5)
			var gx := absf(h[mini(x + 1, N - 1) * N + y] - h[x * N + y]) / 0.5
			var gy := absf(h[x * N + mini(y + 1, N - 1)] - h[x * N + y]) / 0.5
			mat_top[x * H + y] = MatC.SNOW if L90.mat(f, hv, maxf(gx, gy)) == 2 else MatC.GRANITE
	wall = PackedByteArray(); wall.resize(n)
	island = PackedByteArray(); island.resize(n); island.fill(1)
	blocks = {Vector2i.ZERO: null}   # edit() kontroluje jen přítomnost slotu
	var md := func(gi: int, _d: int) -> int: return mat_top[gi]
	springs = PRM.find(hm, W, H, wall, md, p)
	var src := PRM.src(springs, hm, n)
	var mats := PackedInt32Array(); mats.resize(n); mats.fill(MatC.GRANITE)
	st = TOK.make(hm.duplicate(), W, H, wall, mats, src, TOK.losses(p, true), true)
	st.claim74 = claims
	ug = {}
	var t1 := Time.get_ticks_usec()
	_route(st)
	ms["povrch: plný výpočet"] = (Time.get_ticks_usec() - t1) / 1000.0
	_falls()
	ms["celkem"] = (Time.get_ticks_usec() - t0) / 1000.0

## blok 128 m s největším převýšením (jako E92) → model
static func z_funkce(pram_max := 16):
	var bt: Dictionary = S92.best_tile()
	var th: Dictionary = S92.tile_heights(bt.f, bt.tile, 0.0)
	var v = load("res://scripts/voda/blok128_voda95.gd").new()
	v.dlazdice = bt.tile
	v.build128(bt.f, th.h, int(th.N), pram_max)
	return v
