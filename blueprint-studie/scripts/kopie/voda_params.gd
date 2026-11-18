extends RefCounted
## KOPIE kódu z voda-studie/scripts/params.gd; vodní vlastnosti materiálů z JEDINÉ sdílené tabulky ../sdilene/materialy_voda.json.
## VŠECHNY parametry studie vody na jednom místě. Každý jde přepsat z příkazové řádky: -- --klic=hodnota
## (např. -- --perm_sand=0.5 --res_grass=0.9 --rain=0.03 --scen=2)
## Rychlosti jsou „za tik“; délka tiku v sekundách je jen pro hraní v reálném čase (tick_s).

static var P := {
	# --- měřítko a běh --------------------------------------------------------------
	"cell_xy": 1.0,          # vodorovná hrana buňky (prototyp 1,0 m)
	"cell_z": 0.5,           # výška buňky / vrstvy (prototyp 0,5 m)
	"seed": 4242,            # seed scénářů (drobné nerovnosti); simulace sama je bez náhody
	"tick_s": 0.5,           # délka tiku v sekundách při hraní (play)
	"scen": 0,               # 0 = všechny scénáře, 1–5 = jen jeden
	"ticks": -1,             # krok snímků N (snímky v tiku 0 / N / 2N); -1 = výchozí scénáře
	# --- zdroje a ztráty (objem vody v jednotkách „plná buňka“ za tik) ------------------
	"rain": -1.0,            # déšť na každý sloupec za tik; -1 = výchozí scénáře
	"rain_ticks": -1,        # jak dlouho prší (tiků); -1 = pořád
	"spring": -1.0,          # vydatnost pramene za tik; -1 = výchozí scénáře
	"wet0": -1.0,            # počáteční nasycení půdy 0–1 (-1 = výchozí scénáře; scénář 2 = 0,95 „po dešti“)
	"evap": 0.0005,          # odpar z volné hladiny za tik a sloupec
	"evap_soil": 0.0005,     # odpar z mokrého povrchu půdy za tik a sloupec
	# --- zdroje vody jako entity bloku (Jan 15:51): top_flow / hillside_spring / underground_pocket ---
	"src_seed": 77,          # seed rozmístění zdrojů v bloku (scénář 6)
	"src_top": 1,            # počet přítoků shora / z bloku proti proudu (top_flow)
	"src_hill": 1,           # počet pramenů ve svahu (hillside_spring)
	"src_pocket": 1,         # počet podzemních kapes (underground_pocket)
	"top_rate": 0.20,        # vydatnost přítoku shora za tik
	"hill_rate": 0.12,       # vydatnost pramene ve svahu za tik
	"pocket_cells": 4,       # velikost kapsy (buněk)
	"pocket_recharge": 0.12, # dotok do kapsy za tik (jen dokud není plná = kapsa „pod tlakem“)
	"edge_drain": 1,         # 1 = otevřené strany vzorku odvádějí vodu mimo mapu (odtok)
	# --- proudění ----------------------------------------------------------------------
	"flow_air": 1.0,         # rychlost rozlévání volné vody do stran (0–1)
	"flow_ground": 1.0,      # rychlost proudění v pórech do stran (násobí se propustností)
	"infil": 0.10,           # nejvyšší vsak za tik (objem buňky) do plně propustného materiálu; skutečný = propustnost × infil
	"perm_scale": 1.0,       # globální násobek propustnosti (svisle i do stran)
	"film": 0.03,            # tenčí vrstva volné vody se už nerozlévá (kaluž), jen se odpaří
	"draw_min": 0.02,        # tenčí voda se nekreslí
	# --- materiály: propustnost (0 nepropustí – 1 jako vzduch), pórovitost (kolik vody buňka pojme, × objem),
	# --- odpor povrchu (0 hladký – 1 voda po něm skoro neteče) ------------------------------
	# perm_*, por_*, res_* NEJSOU tady: načtou se ze sdílené tabulky ../sdilene/materialy_voda.json (apply_shared_table)
	# --- průchodnost (backend: hledání cest a kopání) -------------------------------------
	"walk_slow_m": 0.05,     # od této hloubky vody (m) se jde pomaleji
	"walk_deep_m": 0.30,     # od této hloubky je buňka neprůchozí (plná vrstva vody = 0,5 m)
	"walk_mud_s": 0.95,      # nasycení povrchové buňky, od kterého je bláto (zpomalí)
	"walk_slow_cost": 2.5,   # násobek ceny kroku v mělké vodě / blátě
	# --- zobrazení -----------------------------------------------------------------------
	"panel_w": 800, "panel_h": 450,   # velikost dílku v souhrnných listech
}

static func parse_cli() -> void:
	apply_shared_table()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			if P.has(kv[0]):
				var old = P[kv[0]]
				P[kv[0]] = int(kv[1]) if typeof(old) == TYPE_INT else float(kv[1])
			else:
				push_warning("neznámý parametr " + kv[0])

static func g(k: String) -> float:
	return float(P[k])

static func i(k: String) -> int:
	return int(P[k])

## ---------- vodní vlastnosti materiálů ze SDÍLENÉ tabulky (Jan 19:18: jedna tabulka pro gen-v3 i voda-studie)
## zdroj: willage-ideas/sdilene/materialy_voda.json (vedle složky projektu); bez ní běh skončí chybou (žádná druhá kopie hodnot).
const SHARED_TABLE := "../sdilene/materialy_voda.json"

static func shared_table_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(SHARED_TABLE).simplify_path()

static func load_shared_table() -> Dictionary:
	var path := shared_table_path()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("chybí sdílená tabulka materiálů: " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not d.has("materials"):
		push_error("neplatná sdílená tabulka materiálů: " + path)
		return {}
	# ZMĚNA V KOPII (blueprint-studie 16:30): připojí rozšíření horniny_voda.json (nové horniny a minerály), původní tabulka beze změny
	var fx := FileAccess.open(path.get_base_dir().path_join("horniny_voda.json"), FileAccess.READ)
	if fx != null:
		var dx = JSON.parse_string(fx.get_as_text())
		if dx is Dictionary and dx.has("materials"):
			for k in dx.materials:
				if not d.materials.has(k):
					d.materials[k] = dx.materials[k]
	return d

## doplní perm_*, por_*, res_*, ret_* do P (volá se před parse_cli, takže CLI dál může hodnoty přepsat)
static func apply_shared_table() -> bool:
	var d := load_shared_table()
	if d.is_empty():
		return false
	for k in d.materials:
		var m: Dictionary = d.materials[k]
		P["perm_" + k] = float(m.perm); P["por_" + k] = float(m.por); P["res_" + k] = float(m.res)
		P["ret_" + k] = float(m.get("ret", 0.0))
	P["perm_leak"] = float(d.get("perm_leak", 0.05))
	P["table_version"] = int(d.get("version", 0))
	return true
