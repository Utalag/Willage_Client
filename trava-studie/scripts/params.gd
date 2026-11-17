extends RefCounted
## VŠECHNY parametry studie na jednom místě. Každý jde přepsat z příkazové řádky: -- --klic=hodnota
## (např. -- --tall_h=0.2 --cell_edge=0.5 --blades_tall=800)

static var P := {
	# --- měřítko -----------------------------------------------------------
	"cell_edge": 1.0,        # hrana buňky v jednotkách (prototyp 1.0; pokusné rozlišení 0.5)
	"tall_h": 0.15,          # vysoká tráva = 0,15 × hrana buňky
	"short_h": 0.05,         # nízká tráva  = 0,05 × hrana buňky
	"patch_cells": 10,       # záhon 10 × 10 buněk
	"tall_rows": 5,          # kolik zadních řad buněk má vysokou trávu (zbytek nízká)
	"seed": 1337,            # deterministické rozmístění
	# --- A: shell texturing (vrstvy) ----------------------------------------
	"shell_layers": 24,      # počet vrstev (pokrývají výšku vysoké trávy)
	"shell_density": 34.0,   # chlupů na jednotku délky (vysoká tráva)
	"shell_density_short": 46.0,
	# --- A2: řidší „koberec“ (shell texturing, méně a tlustších vláken s mezerami) --------
	"carpet_density": 15.0,       # vláken / jednotku (vysoká)
	"carpet_density_short": 20.0,
	"carpet_rad_root": 0.36,      # poloměr vlákna u kořene (× rozteč)
	"carpet_rad_tip": 0.22,       # poloměr u špičky (vlákno je skoro válec jako vlas koberce)
	"carpet_fill": 0.8,           # podíl obsazených míst (zbytek = viditelné mezery)
	# --- B: stébla (MultiMesh) ----------------------------------------------
	"blades_tall": 800,      # stébel na buňku (vysoká, „srst“)
	"blades_short": 650,     # stébel na buňku (nízká)
	"blade_w_tall": 0.042,   # šířka stébla u kořene (× hrana buňky)
	"blade_w_short": 0.032,
	# --- C: trsy z prototypu (veg-v2 „trs trávy“, suchá tráva, květiny) jako instance ------
	"tuft_tall_h": 0.30,     # výška vysokého trsu (× hrana buňky); model v prototypu má 0,42 × 0,8–1,2
	"tuft_short_h": 0.12,    # výška nízkého trsu; při 0,15/0,05 vypadají trsy znovu jako mech (shots/27_trava_trsy_C_vysky_0.15_0.05.png)
	"tufts_tall": 24,        # trsů na buňku (vysoká); veg-v2 v prototypu: 0,45 trsu na buňku (louka)
	"tufts_short": 50,       # trsů na buňku (nízká)
	"tuft_w_tall": 1.0,      # šířka trsu vůči výšce (1 = proporce modelu z prototypu)
	"tuft_w_short": 1.5,     # nízké trsy jsou přikrčené (širší než vysoké)
	"tuft_dry": 0.03,        # podíl suchých trsů
	"flowers_tall": 0.5,     # kvítků na buňku ve vysoké trávě
	# --- vítr -----------------------------------------------------------------
	"wind_dir_deg": 30.0,    # směr větru (stupně v rovině XZ)
	"wind_strength": 0.35,   # průměrný náklon ve větru (radiány)
	"wind_gust": 0.45,       # síla poryvů (radiány navíc)
	"wind_speed": 1.6,       # rychlost posunu poryvů (jednotky/s)
	"wind_scale": 0.22,      # velikost poryvů (1/jednotky)
	# --- rozhrnování ------------------------------------------------------------
	"trail_px": 12,          # rozlišení stopy (pixelů na jednotku)
	"trample_r": 0.42,       # poloměr rozhrnutí kolem postavičky (× hrana buňky)
	"trample_hold": 0.35,    # jak dlouho zůstane ohnutá po průchodu (s)
	"trample_recover": 1.6,  # návrat do původní polohy (s), s malým překmitem
	"trample_bend": 1.25,    # max. náklon při rozhrnutí (radiány)
	# --- procedurální zem louky (proc.tscn, shots 32_trava_procedural_*) ------------------------
	"pg_macro_scale": 0.16,  # velikost barevných fleků (1/buňky)
	"pg_macro": 0.20,        # světlejší/tmavší fleky (± jas)
	"pg_yellow": 0.45,       # posun do žlutozelena
	"pg_dry": 0.55,          # suchá místa: síla
	"pg_dry_cov": 0.16,      #   podíl plochy
	"pg_lush": 0.6,          # svěží tmavé skvrny (jetel): síla
	"pg_lush_cov": 0.12,     #   podíl plochy
	"pg_streak": 0.12,       # žíhání stébel po větru
	"pg_streak_w": 30.0,     #   pruhů na buňku napříč větrem
	"pg_streak_len": 7.0,    #   podél větru: 1/délka čárky v buňkách (3 = dlouhé, vypadalo jako déšť)
	"pg_grain": 0.07,        # zrno (22 na buňku, jako procedurální písek)
	"pg_clover": 0.7,        # lístky jetele ve svěžích skvrnách
	"pg_desat": 0.18,        # ubrání sytosti zeleně
	"pg_s1": 0.55,           # síla varianty 1 „jemná“
	"pg_s2": 1.0,            # síla varianty 2 „výrazná“
	"pg_s3": 0.8,            # síla varianty 3 „sladěná“
	"pg_match3": 0.8,        # varianta 3: kolik tónu louky převezmou trsy (0–1)
	# --- postavička --------------------------------------------------------------
	"walk_time": 9.0,        # průchod trasou (s)
	"char_h": 0.7,
	"char_r": 0.2,
}

static func parse_cli() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			if P.has(kv[0]):
				var old = P[kv[0]]
				P[kv[0]] = int(kv[1]) if typeof(old) == TYPE_INT else float(kv[1])

static func g(k: String) -> float:
	return float(P[k])
