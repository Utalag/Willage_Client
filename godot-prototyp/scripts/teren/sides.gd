extends RefCounted
## KOPIE z blueprint-studie/scripts/bp/sides.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## Strany bloku jako block_gen.gd: 0 S (−y), 1 V (+x), 2 J (+y), 3 Z (−x). Sloupec = x · 16 + y.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NAMES := ["S", "V", "J", "Z"]

## vlastní okrajový sloupec strany d v pozici t (0–15)
static func own(d: int, t: int) -> Vector2i:
	match d:
		0: return Vector2i(t, 0)
		1: return Vector2i(15, t)
		2: return Vector2i(t, 15)
	return Vector2i(0, t)

## sloupec SOUSEDA přiléhající k naší straně d
static func nb(d: int, t: int) -> Vector2i:
	return own((d + 2) % 4, t)

## buňka obalu 18 × 18 (i, j) za naší stranou d
static func ghost(d: int, t: int) -> Vector2i:
	match d:
		0: return Vector2i(t, -1)
		1: return Vector2i(16, t)
		2: return Vector2i(t, 16)
	return Vector2i(-1, t)

## vzdálenost sloupce od strany d (0 = okrajový sloupec)
static func dist(d: int, x: int, y: int) -> int:
	match d:
		0: return y
		1: return 15 - x
		2: return 15 - y
	return x
