extends RefCounted
## Generátor V1.0, krok 1: verze generátoru ve tvaru Vmajor.minor (docs/sjednoceni 6.2).
## Velké V, hlavní číslo = nekompatibilní změna, vedlejší = drobná změna, přičítá se postupně.
## V datech se ukládá jako u16: major * 256 + minor (major 0–255, minor 0–255).

const AKTUALNI := "V1.0"

## "V1.0" → Vector2i(1, 0); chybný zápis → Vector2i(-1, -1)
static func cti(s: String) -> Vector2i:
	if s.length() < 4 or s[0] != "V": return Vector2i(-1, -1)
	var t := s.substr(1).split(".")
	if t.size() != 2: return Vector2i(-1, -1)
	for x in t:
		if x.is_empty() or not x.is_valid_int() or (x.length() > 1 and x[0] == "0"): return Vector2i(-1, -1)
		if int(x) < 0 or int(x) > 255: return Vector2i(-1, -1)
	return Vector2i(int(t[0]), int(t[1]))

static func platna(s: String) -> bool:
	return cti(s).x >= 0

static func text(v: Vector2i) -> String:
	return "V%d.%d" % [v.x, v.y]

## -1 / 0 / 1
static func porovnej(a: String, b: String) -> int:
	var x := cti(a)
	var y := cti(b)
	if x.x != y.x: return -1 if x.x < y.x else 1
	if x.y != y.y: return -1 if x.y < y.y else 1
	return 0

## kompatibilní = stejné hlavní číslo
static func kompatibilni(a: String, b: String) -> bool:
	return cti(a).x >= 0 and cti(a).x == cti(b).x

static func na_u16(s: String) -> int:
	var v := cti(s)
	return -1 if v.x < 0 else v.x * 256 + v.y

static func z_u16(u: int) -> String:
	return text(Vector2i(u >> 8, u & 255))
