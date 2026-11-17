extends RefCounted
## VŠECHNY parametry studie na jednom místě. Každý jde přepsat z příkazové řádky: -- --klic=hodnota
## (např. -- --sample_n=20 --cell_xy=0.5 --cell_z=0.25 --splat_px=8)

static var P := {
	# --- rozlišení a měřítko (fyzické jednotky = metry) --------------------------------
	"sample_n": 10,          # vzorek (zmenšený „blok“) má sample_n × sample_n buněk
	"cell_xy": 1.0,          # vodorovná hrana buňky (prototyp 1,0)
	"cell_z": 0.5,           # výška buňky (vrstvy) – prototyp 0,5; vzorek má 4 vrstvy = 2 m
	"layers": 4,             # výška vzorku ve vrstvách (10 × 10 × 4)
	"seed": 4242,
	"layout": 0,             # 0 = louka / píščina / voda / pobřeží, 1 = louka přímo u vody (33_*)
	# --- výšky (metry) -----------------------------------------------------------------
	"water_level": 0.85,     # hladina; souš musí mít povrch nad ní, dno vody pod ní
	"meadow_h": 1.75, "meadow_var": 0.30,
	"sand_h": 1.15, "sand_var": 0.25,
	"bed_h": 0.5,
	# --- dorovnání stran mezi vzorky (stejné jako block_gen.gd: 0 = auto, 1–4 = blend N buněk, 5 = ponechat)
	"side_mode": 0,
	"blend_max": 6,          # auto: rozdíl do 6 vrstev se dorovná, větší = útes
	"auto_cells": 3,
	# --- přístup 1: klasická mřížka, přechody na hranách buněk -----------------------
	"edge_band": 0.30,       # jak daleko (× buňka) zasáhne „silnější“ materiál do sousední buňky
	"edge_noise": 0.45,      # nepravidelnost okraje (podíl šířky pásu)
	"edge_soft": 0.05,
	# --- přístup 2: duální mřížka (rohy dlaždic = středy buněk) -----------------------
	"dual_sub": 4,           # dělení dlaždice na 4 × 4 čtverce (výšky mezi středy buněk)
	"dual_ease": 1.0,        # 0 = lineární svah mezi středy, 1 = smoothstep (rovné středy, svah u hran)
	"dual_noise": 0.12,      # zvlnění hranice materiálu
	"dual_soft": 0.06,
	# --- samostatné buňky v duální mřížce (Jan 14:20: „méně agresivní přechody“) -----------
	"dual_shape": 0,         # 0 současná, 1 posun izočáry, 2 plošina + zkosení, 3 hybrid
	"iso_bias": 0.5,         # 1: náskok silnějšího materiálu (tráva +bias, písek +bias/2)
	"bevel": 0.3,            # 2: šířka zkosení na hraně buňky (× buňka); 1 = jako současná
	"hyb_small": 2,          # 3: skupina do 2 buněk stejného materiálu = samostatný prvek → kvádr
	"hyb_step": 2,           # 3: schod ≥ 2 vrstvy → svislá stěna na hraně buňky (jako skála)
	"hyb_bevel": 1.0,        # 3: ostatní přechody jako současná duální mřížka
	# --- textura materiálů (splat) ---------------------------------------------------
	"splat_px": 16,          # texelů na buňku
	# --- doplňky (vrstva navíc nad oběma přístupy) -------------------------------------
	"wet_w": 0.9,            # mokrý písek: do vzdálenosti 0,9 buňky od vody …
	"wet_h": 0.35,           # … a do výšky 0,35 m nad hladinou
	"wet_dark": 0.72,
	"foam_w": 0.32,          # pevný pás pěny u břehu (× buňka)
	"wave_reach": 1.3,       # dosah vln k břehu (× buňka)
	"wave_freq": 2.2,
	"wave_speed": 0.35,
	"thin_w": 1.2,           # řídnutí trávy: v pásu 1,2 buňky od okraje louky
	"thin_min": 0.15,        # hustota přímo na okraji
	# --- vzhled písku a přechodových pásů (Janova zpětná vazba 14:14) -------------------
	"sand_look": 1,          # 0 = původní sytý plochý písek, 1 = přirozenější šedobéžový
	"sand_detail": 2,        # 0 = bez detailu, 1 = textura Gemini z prototypu (assets/tex/03.png), 2 = procedurální zrno + čeřiny
	"sand_tex_contrast": 4.0,
	"sand_tex_scale": 0.6,     # opakování textury písku na metr
	"bands": 1,              # 1 = přechodové pásy jako samostatný materiál
	"band_water": 0.75,      # pás uježděného mokrého písku u vody (× buňka)
	"band_grass": 1.1,       # pás „tráva v písku“ před loukou (× buňka)
	"mix_tufts": 0.18,       # hustota řídkých trsů v pásu tráva v písku (podíl hustoty louky)
	# --- louka přímo u vody (33_*) ---------------------------------------------------------
	"bank": -1,              # -1 = automaticky (zapnuto jen pro layout 1); travnatý břeh: tráva až k vodě (žádný písečný proužek) + pás bahna
	"bank_reach": 2.2,       # do jaké vzdálenosti od louky (× buňka) je dno nad vodou travnaté
	"mud_w": 0.16,           # šířka tmavého bahnitého pásu u vody (× buňka)
	"reeds": -1,             # -1 = automaticky (layout 1); rákos na čáře vody u louky
	"reed_density": 8.0,     # stébel rákosu na buňku délky břehu (v trsech)
	"reed_h": 0.8,           # × hrana buňky
	"foam_bank": 0.3,        # síla pěny u travnatého břehu (u pláže 1)
	# --- tráva (varianta C z trava-studie) ---------------------------------------------
	"tufts": 24,             # trsů na buňku
	"tuft_h": 0.30,          # × hrana buňky
	"tuft_dry": 0.03,
	"flowers": 0.5,
	"wind_dir_deg": 30.0, "wind_strength": 0.35, "wind_gust": 0.45, "wind_speed": 1.6, "wind_scale": 0.22,
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

static func i(k: String) -> int:
	return int(P[k])
