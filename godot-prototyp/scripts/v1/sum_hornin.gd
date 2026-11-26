extends RefCounted
## Šum mocnosti podle horniny (A10, krok 3b). Parametry z tabulky `data/v1/sum_hornin_v1.csv`:
## měřítko (m), amplituda (0–1 rozsahu mocnosti thick0…thick1), počet oktáv, persistence.
## Pole 0–1 = fBm z hodnotového šumu nad hashem světa (svet._u). Oktáva 0 má seed „V1_THICK“ jako
## dřívější jediné pole, takže řádek 180 m / 1,0 / 1 oktáva je bitově původní chování.
## Horniny bez řádku v tabulce dostanou původní hodnoty (LEGACY). Čistá funkce, bez stavu mimo tabulku.
const CESTA := "res://data/v1/sum_hornin_v1.csv"
const UCEL := "V1_THICK"
const LACUNARITA := 2.0                # každá další oktáva má poloviční měřítko
const LEGACY := {"meritko_m": 180.0, "amplituda": 1.0, "oktavy": 1, "persistence": 0.5}

var svet
var povoleno := true                   # přepínač a10_sum_hornin (vypnuto = všude LEGACY)
var tabulka := {}                      # id horniny → {meritko_m, amplituda, oktavy, persistence, key}

func _init(s, zapnuto := true) -> void:
	svet = s
	povoleno = zapnuto
	_nacti()

func _nacti() -> void:
	var f := FileAccess.open(CESTA, FileAccess.READ)
	if f == null:
		push_error("sum_hornin: nelze otevřít " + CESTA)
		return
	var h := f.get_csv_line()
	var ix := {}
	for c in ["key", "id", "meritko_m", "amplituda", "oktavy", "persistence"]:
		ix[c] = h.find(c)
		if ix[c] < 0:
			push_error("sum_hornin: chybí sloupec " + c)
			return
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() <= int(ix.persistence) or not String(r[ix.id]).is_valid_int(): continue
		tabulka[int(r[ix.id])] = {
			"key": String(r[ix.key]),
			"meritko_m": maxf(float(r[ix.meritko_m]), 1.0),
			"amplituda": clampf(float(r[ix.amplituda]), 0.0, 1.0),
			"oktavy": clampi(int(r[ix.oktavy]), 1, 6),
			"persistence": clampf(float(r[ix.persistence]), 0.0, 1.0),
		}

## parametry šumu horniny `id` (LEGACY, když je přepínač vypnutý nebo řádek chybí)
func parametry(id: int) -> Dictionary:
	if not povoleno or not tabulka.has(id): return LEGACY
	return tabulka[id]

## jedna oktáva hodnotového šumu 0–1 na buňce `s` m (smoothstep; shodné s dřívějším `_n01`)
func oktava(ucel: String, k: int, x: float, y: float, s: float) -> float:
	var i0 := floori(x / s); var j0 := floori(y / s)
	var tx := x / s - i0; var ty := y / s - j0
	tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = svet._u(ucel, i0, j0, k); var b: float = svet._u(ucel, i0 + 1, j0, k)
	var c: float = svet._u(ucel, i0, j0 + 1, k); var d: float = svet._u(ucel, i0 + 1, j0 + 1, k)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

## fBm 0–1: součet oktáv s vahami persistence^o, normalizovaný na [0, 1]
func fbm(ucel: String, k: int, x: float, y: float, meritko: float, oktavy: int, persistence: float) -> float:
	if oktavy <= 1: return oktava(ucel, k, x, y, meritko)
	var suma := 0.0
	var vahy := 0.0
	var w := 1.0
	var s := meritko
	for o in oktavy:
		var u := ucel if o == 0 else "%s_O%d" % [ucel, o]
		suma += w * oktava(u, k, x, y, s)
		vahy += w
		w *= persistence
		s /= LACUNARITA
	return suma / vahy

## pole mocnosti horniny 0–1 se středem 0,5 a rozkmitem amplituda (1 = celý rozsah thick0…thick1)
func mocnost_n01(id: int, k: int, x: float, y: float) -> float:
	var p: Dictionary = parametry(id)
	var n := fbm(UCEL, k, x, y, float(p.meritko_m), int(p.oktavy), float(p.persistence))
	var a := float(p.amplituda)
	if a >= 1.0: return n            # bitově původní hodnota (bez zaokrouhlení 0,5 + (n − 0,5))
	return 0.5 + (n - 0.5) * a
