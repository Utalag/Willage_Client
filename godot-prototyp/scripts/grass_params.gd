extends RefCounted
## Parametry trávy C (převzato ze studie trava-studie/scripts/params.gd, varianta C). Vše laditelné:
## z příkazové řádky `-- --grass.klic=hodnota` (např. -- --grass.tufts_tall=30 --grass.tuft_short_h=0.15),
## nebo za běhu Grass.set_param(). Výšky jsou × hrana buňky (prototyp: hrana 1, výška vrstvy 0,5).

static var P := {
	"enabled": 1,            # 0 = původní vykreslení veg-v2 (jeden velký trs na sloupec), 1 = tráva C
	"cell_edge": 1.0,        # hrana buňky v jednotkách
	# --- vysoká / nízká tráva (jen vzhled; data vegetace a rarita se nemění) --------------------
	"tall_patch": 4.0,       # velikost skvrn vysoké trávy (sloupců), hodnotový šum ze seedu bloku (účel "GRASS")
	"tall_louka": 0.55,      # podíl travnatých sloupců s vysokou trávou podle receptu bloku
	"tall_kopec": 0.40,
	"tall_hora": 0.20,
	"tall_piscina": 0.15,
	# --- trsy ----------------------------------------------------------------------------------
	"tuft_tall_h": 0.30,     # výška vysokého trsu (× hrana buňky); 0,15 vypadalo jako mech
	"tuft_short_h": 0.12,    # výška nízkého trsu; 0,05 vypadalo jako mech
	"tufts_tall": 24,        # trsů na buňku (vysoká)
	"tufts_short": 50,       # trsů na buňku (nízká)
	"tuft_w_tall": 1.0,      # šířka trsu vůči výšce
	"tuft_w_short": 1.5,     # nízké trsy přikrčené
	"tuft_dry": 0.03,        # podíl suchých trsů v louce
	"flowers_tall": 0.5,     # kvítků na buňku ve vysoké trávě (navíc k rostlinám „květiny“ z dat vegetace)
	"flower_h": 0.34,        # výška kvítků z dat vegetace (× měřítko rostliny)
	"dry_h": 0.54,           # výška suché trávy na písčině (× měřítko rostliny), dříve 0,36 × 1,5
	# --- úroveň detailu podle přiblížení (ortho kamera: cam.size = šířka záběru v jednotkách) ------
	"lod_full_size": 20.0,   # do této velikosti záběru plná hustota trsů
	"lod_min": 0.125,        # nejmenší podíl kreslených trsů (po osminách; kvítky a rostliny z dat vždy celé)
	# --- vítr (sdílí všechny trsy, suchá tráva i květiny) ----------------------------------------
	"wind_dir_deg": 30.0,
	"wind_strength": 0.35,
	"wind_gust": 0.45,
	"wind_speed": 1.6,
	"wind_scale": 0.22,
	# --- rozhrnování (stopa) --------------------------------------------------------------------
	"trail_size": 32.0,      # velikost okna stopy (jednotky); okno se posouvá za první postavičkou
	"trail_px": 12,          # pixelů stopy na jednotku
	"trample_r": 0.42,       # poloměr rozhrnutí (× hrana buňky)
	"trample_hold": 0.35,    # jak dlouho zůstane ohnutá (s)
	"trample_recover": 1.6,  # návrat (s), s malým překmitem
	"trample_bend": 1.25,    # max. náklon při rozhrnutí (rad)
}

static var _parsed := false

static func parse_cli() -> void:
	if _parsed:
		return
	_parsed = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--grass.") and a.contains("="):
			var kv := a.substr(8).split("=", true, 1)
			if P.has(kv[0]):
				P[kv[0]] = int(kv[1]) if typeof(P[kv[0]]) == TYPE_INT else float(kv[1])
			else:
				push_warning("neznámý parametr trávy: " + kv[0])

static func g(k: String) -> float:
	return float(P[k])
