extends RefCounted
## E89: jednotky na jednom místě. GDScript nemá vlastní číselné typy, proto platí pravidlo názvů:
##   *_m metry (float64), *_s sekundy, *_lps litry za sekundu, *_m3 krychlové metry   → fyzika a voda, NIKDY se nepřevádí
##   *_hj herní jednotky po 0,25 m (int)                                               → kopání, stavby, postava (7 hj = 1,75 m)
##   *_i celočíselné souřadnice mřížky s hustotou n (buněk na šířku bloku: 16 = 0,5 m, 32 = 0,25 m, 64, 128)
##   *_sc jednotky scény Godotu (jen vykreslení)
## Osy: geologie (x, y vodorovně, z nahoru) ↔ Godot (x, z vodorovně, y nahoru): geo (x, y, z) = godot (x, z, y).
## Index buňky v bloku je v obou konvencích stejné číslo: geo (x*n + y)*nz + z = godot (x*n + z)*nz + y.

const BLOK_M := 8.0          # šířka bloku (m)
const VYSKA_M := 32.0        # výška bloku (m)
const U_M := 0.5             # řídicí mřížka geologie (= geo_fn.U)
const HJ_M := 0.25           # herní jednotka (Jan 2026-11-19 20:12)
const HJ_NA_BLOK := 32       # 8 m / 0,25 m
const N_RIDICI := 16         # hustota řídicí mřížky
const L_NA_M3 := 1000.0      # 1 m³ = 1000 l
const POSTAVA_HJ := 7        # 1,75 m
const DVERE_HJ := 8

## měřítko scény: dnes buňka 1 × 1 × 0,5 jednotky scény (vodorovně 1 sc = 0,5 m); p89_meritko: 1 sc = 1 m všude
const SCENA_DNES_M_NA_SC := Vector3(0.5, 1.0, 0.5)
const SCENA_M_NA_SC := Vector3(1.0, 1.0, 1.0)

## velikost buňky (m) při hustotě n (buněk na šířku bloku); svisle stejně (krychle)
static func bunka_m(n: int) -> float:
	return BLOK_M / float(n)

## počet buněk na výšku bloku při hustotě n
static func nz(n: int) -> int:
	return n * int(VYSKA_M / BLOK_M)

## délka v metrech → index buňky (dolů zaokrouhleno), hustota n; hranice patří buňce nad ní
static func m_na_i(x_m: float, n: int) -> int:
	return floori(x_m * float(n) / BLOK_M)

## střed buňky i (m)
static func i_stred_m(i: int, n: int) -> float:
	return (float(i) + 0.5) * BLOK_M / float(n)

## spodní hrana buňky i (m)
static func i_m(i: int, n: int) -> float:
	return float(i) * BLOK_M / float(n)

## index při hustotě n → index při hustotě n2 (jemnější: první podbuňka; hrubší: rodič). n, n2 mocniny dvou.
static func prevzorkuj_i(i: int, n: int, n2: int) -> int:
	return i * (n2 / n) if n2 >= n else i / (n / n2)

## herní jednotky ↔ metry
static func hj_m(v_hj: int) -> float:
	return float(v_hj) * HJ_M

static func m_hj(v_m: float) -> int:
	return floori(v_m / HJ_M)

## svět (m) → [slot bloku, místní sloupec x, y při hustotě n]
static func svet_na_slot(x_m: float, y_m: float, n: int) -> Array:
	var s := Vector2i(floori(x_m / BLOK_M), floori(y_m / BLOK_M))
	return [s, m_na_i(x_m - s.x * BLOK_M, n), m_na_i(y_m - s.y * BLOK_M, n)]

## index buňky v bloku (stejné číslo v geologii i Godotu): sloupec (a, b) vodorovně, h svisle
static func idx(a: int, b: int, h: int, n: int) -> int:
	return (a * n + b) * nz(n) + h

static func idx_rozloz(i: int, n: int) -> Vector3i:   # (a, b, h)
	var z := nz(n)
	return Vector3i(i / (n * z), (i / z) % n, i % z)

## osy: bod geologie (x, y, z nahoru, m) → bod Godotu (x, y nahoru, z) v jednotkách scény podle měřítka
static func geo_na_scenu(p_m: Vector3, m_na_sc: Vector3) -> Vector3:
	return Vector3(p_m.x / m_na_sc.x, p_m.z / m_na_sc.y, p_m.y / m_na_sc.z)

static func scena_na_geo(p_sc: Vector3, m_na_sc: Vector3) -> Vector3:
	return Vector3(p_sc.x * m_na_sc.x, p_sc.z * m_na_sc.z, p_sc.y * m_na_sc.y)

## voda: objem buňky (m³) a převod průtoku; hydraulika zůstává v m, s, l/s
static func bunka_m3(n: int) -> float:
	var c := bunka_m(n)
	return c * c * c

static func lps_na_m3s(q_lps: float) -> float:
	return q_lps / L_NA_M3

static func m3_na_l(v_m3: float) -> float:
	return v_m3 * L_NA_M3
