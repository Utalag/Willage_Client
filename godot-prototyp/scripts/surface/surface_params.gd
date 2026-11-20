@tool
class_name SurfaceParams
extends "res://scripts/tunable_params.gd"
## Parametry povrchu louka / písek / voda (schváleno Janem 17. 11. 2026, převzato ze studií napojeni-studie a trava-studie).
## Výchozí hodnoty = schválený stav: duální mřížka dual_shape 0 (bez kvádrů, bez posunu izočáry), měkkost 0,06,
## šedobéžový písek s procedurálním zrnem, pásy (mokrý písek 0,75, tráva v písku 1,1), travnatý břeh + bahno + pěna 0,3,
## procedurální louka varianta 3 „sladěná“ (síla 0,8, trsy převezmou 0,8 tónu).
## CLI: -- --surface.<klic>=hodnota. Barvy jsou sRGB (převod do lineárních v shaderu).

static var _inst

static func inst():
	if _inst == null:
		_inst = load("res://scripts/surface/surface_params.gd").new()
		_inst.apply_cli("surface")
	return _inst

@export_group("Skrytí podzemí")
@export var hide_undiscovered := true                 ## boky a řezy pod povrchem jednou neutrální texturou
@export var xray := false                             ## vývoj: ukaž skutečné materiály (vypne skrytí)
@export_range(0, 1, 1) var undiscovered_look := 0     ## 0 hlína, 1 skála (textura skryté stěny)
@export var col_undiscovered := Color(0.66, 0.50, 0.40) ## barva skryté stěny (výchozí hlína)
@export var side_plain := true                          ## E66b: boky ostrova (směr ven, bez souseda) jednou barvou bez textury
@export var col_side := Color(0.62, 0.52, 0.45)         ## E66b: barva boku ostrova
@export var fog_side := false                           ## E66b: vrstvy mlhy kolem ostrova (dělají na boku rozmazaný vzor); vypnuto = bok čistý
@export_range(0.0, 0.8, 0.05) var undiscovered_darken := 0.25  ## ztmavení / mlha s hloubkou
@export var wet_tint := true                          ## gen-v3: mokrá půda pod povrchem tmavší (jen viditelný materiál)
@export var data_water := true                        ## gen-v3: kreslit volnou vodu z vrstvy vody bloku (jeskyně, jezírka)

@export_group("Měřítko scény (E89, E94)")
## E94: scéna v metrech (1 jednotka = 1 m, buňka 0,5 × 0,5 × 0,5 m; stromy, stavby, kamera a mlha v metrech).
## Na větvi e94-metry výchozí zap (Jan 2026-11-20 11:04); vyp = dnešní buňka 1 × 1 × 0,5 (`--surface.p89_meritko=false`).
@export var p89_meritko := true
## E94b (Jan 2026-11-20 11:39): měřítko modelů rostlin ve scéně v metrech (× výšky VYSKA_M; 0,5 → listnáč 1,75 m,
## jehličnan 2 m, keř 0,5 m, kaktus 0,75 m). Hustota beze změny; bez p89_meritko se nepoužije.
@export_range(0.1, 2.0, 0.05) var p94_meritko_veg := 0.5

@export_group("Duální mřížka")
@export var dual_enabled := true                       ## duální mřížka pro povrch louky, písku a vody
@export_range(1, 8, 1) var dual_sub := 4               ## dělení dlaždice (svah mezi středy buněk)
@export_range(0.0, 1.0, 0.05) var dual_ease := 1.0     ## 0 lineární svah, 1 smoothstep (rovné středy)
@export_range(0.0, 0.5, 0.01) var dual_noise := 0.12   ## zvlnění hranice materiálu
@export_range(0.005, 0.4, 0.005) var dual_soft := 0.06 ## měkkost hranice materiálu
@export_range(0, 6, 1) var slope_max_layers := 2       ## rozdíl rohů dlaždice do N vrstev = svah, víc = stěna na buňkách
@export_range(1, 8, 1) var field_px := 4               ## texelů vzdálenostních polí na buňku
@export_range(3, 6, 1) var field_pad := 4              ## kolik buněk sousedů pole vidí (dosah pásů a pěny)

@export_group("Voda")
@export var water_enabled := true
@export_range(1, 63, 1) var water_lz := 30             ## sloupce louky/písku s výškou pod touto vrstvou jsou pod vodou (jen vzhled)
@export_range(-0.5, 0.0, 0.01) var water_offset := -0.15 ## hladina = water_lz × 0,5 m + posun (studie: 0,15 m pod souší)
@export var col_shallow := Color(0.52, 0.90, 0.90)
@export var col_deep := Color(0.24, 0.60, 0.90)
@export var col_foam := Color(0.97, 0.99, 1.0)
@export_range(0.0, 1.0, 0.01) var foam_w := 0.32
@export_range(0.0, 4.0, 0.05) var wave_reach := 1.3
@export_range(0.5, 6.0, 0.1) var wave_freq := 2.2
@export_range(0.0, 2.0, 0.05) var wave_speed := 0.35
@export_range(0.0, 1.0, 0.05) var foam_bank := 0.3     ## síla pěny u travnatého břehu (u pláže 1)
@export_range(0.0, 1.0, 0.05) var water_alpha := 0.55  ## průhlednost mělké vody
@export var extras := true                             ## pěna a vlny k břehu

@export_group("Písek")
@export_range(0, 1, 1) var sand_look := 1              ## 0 původní sytý, 1 šedobéžový
@export_range(0, 2, 1) var sand_detail := 2            ## 0 nic, 2 procedurální zrno + čeřiny (1 = textura, v prototypu nepoužito)
@export var col_sand := Color(0.98, 0.89, 0.62)
@export var col_sand2 := Color(0.84, 0.78, 0.67)
@export var col_bed := Color(0.86, 0.80, 0.60)
@export var col_bed2 := Color(0.78, 0.75, 0.65)
@export_range(0.0, 0.5, 0.01) var sand_grain := 0.16
@export_range(0.0, 0.3, 0.01) var sand_ripple := 0.09
@export_range(1.0, 20.0, 0.5) var sand_ripple_freq := 7.0
@export var bands := true                              ## přechodové pásy jako samostatný materiál
@export_range(0.0, 3.0, 0.05) var band_water := 0.75   ## pás uježděného mokrého písku u vody (× buňka)
@export_range(0.0, 3.0, 0.05) var band_grass := 1.1    ## pás písku prorostlého trávou před loukou (× buňka)
@export_range(0.0, 1.0, 0.01) var mix_tufts := 0.18    ## hustota řídkých trsů v pásu (podíl louky)
@export var col_packed := Color(0.72, 0.69, 0.62)
@export var col_mixgrass := Color(0.55, 0.72, 0.42)

@export_group("Břeh louky u vody")
@export var bank := true                               ## travnatý břeh + bahno místo písečného proužku
@export_range(0.0, 4.0, 0.05) var bank_reach := 2.2
@export_range(0.0, 1.0, 0.01) var mud_w := 0.16
@export var col_mud := Color(0.50, 0.46, 0.33)
@export var col_bank_soil := Color(0.58, 0.46, 0.34)

@export_group("Louka")
@export var col_grass := Color(0.56, 0.80, 0.47)
@export_range(0.0, 4.0, 0.05) var thin_w := 1.2       ## řídnutí trsů k okraji louky (× buňka)
@export_range(0.0, 1.0, 0.01) var thin_min := 0.15
@export var mat_line := true                           ## tenká čára na hranici materiálů

@export_group("Louka procedurální (varianta 3)")
@export var pg_enabled := true
@export_range(0.0, 2.0, 0.05) var pg_strength := 0.8
@export_range(0.0, 1.0, 0.05) var pg_match := 0.8      ## kolik tónu louky převezmou trsy
@export_range(0.02, 1.0, 0.01) var pg_macro_scale := 0.16
@export_range(0.0, 0.6, 0.01) var pg_macro := 0.20
@export_range(0.0, 1.0, 0.01) var pg_yellow := 0.45
@export_range(0.0, 1.0, 0.01) var pg_dry := 0.55
@export_range(0.0, 0.5, 0.01) var pg_dry_cov := 0.16
@export_range(0.0, 1.0, 0.01) var pg_lush := 0.6
@export_range(0.0, 0.5, 0.01) var pg_lush_cov := 0.12
@export_range(0.0, 0.5, 0.01) var pg_streak := 0.12
@export_range(5.0, 60.0, 1.0) var pg_streak_w := 30.0
@export_range(1.0, 20.0, 0.5) var pg_streak_len := 7.0
@export_range(0.0, 0.3, 0.01) var pg_grain := 0.07
@export_range(0.0, 1.0, 0.05) var pg_clover := 0.7

func rebuild_props() -> PackedStringArray:
	return PackedStringArray(["dual_enabled", "dual_sub", "dual_ease", "dual_noise", "dual_soft", "slope_max_layers",
		"field_px", "field_pad", "water_enabled", "water_lz", "water_offset", "band_grass", "mix_tufts", "thin_w", "thin_min"])

func water_y() -> float:
	return water_lz * 0.5 + water_offset

func labels() -> Dictionary:
	return {
		"hide_undiscovered": "Skrýt podzemí", "xray": "X-ray (skutečné materiály)",
		"undiscovered_look": "Textura skryté stěny (0 hlína, 1 skála)",
		"col_undiscovered": "Barva skryté stěny", "undiscovered_darken": "Ztmavení s hloubkou",
		"side_plain": "Bok ostrova bez textury", "col_side": "Barva boku ostrova", "fog_side": "Mlha před bokem ostrova",
		"wet_tint": "Mokrá půda (gen-v3)", "data_water": "Voda z dat bloku (gen-v3)",
		"dual_enabled": "Duální mřížka zapnuta", "dual_sub": "Dělení dlaždice", "dual_ease": "Vyhlazení svahu",
		"dual_noise": "Zvlnění hranice", "dual_soft": "Měkkost hranice", "slope_max_layers": "Max. svah (vrstev)",
		"field_px": "Rozlišení polí (px/buňka)", "field_pad": "Dosah polí (buněk)",
		"water_enabled": "Voda zapnuta", "water_lz": "Hladina: vrstva", "water_offset": "Hladina: posun (m)",
		"col_shallow": "Barva mělké vody", "col_deep": "Barva hluboké vody", "col_foam": "Barva pěny",
		"foam_w": "Šířka pěny", "wave_reach": "Dosah vln", "wave_freq": "Hustota vln", "wave_speed": "Rychlost vln",
		"foam_bank": "Pěna u trav. břehu", "water_alpha": "Průhlednost vody", "extras": "Pěna a vlny",
		"sand_look": "Vzhled písku (0/1)", "sand_detail": "Detail písku (0/2)", "col_sand": "Písek původní",
		"col_sand2": "Písek šedobéžový", "col_bed": "Dno původní", "col_bed2": "Dno šedobéžové",
		"sand_grain": "Zrno písku", "sand_ripple": "Čeřiny: síla", "sand_ripple_freq": "Čeřiny: hustota",
		"bands": "Přechodové pásy", "band_water": "Pás mokrého písku", "band_grass": "Pás trávy v písku",
		"mix_tufts": "Trsy v písku", "col_packed": "Mokrý písek", "col_mixgrass": "Tráva v písku",
		"bank": "Travnatý břeh", "bank_reach": "Dosah břehu", "mud_w": "Šířka bahna", "col_mud": "Bahno",
		"col_bank_soil": "Hlína břehu", "col_grass": "Barva louky", "thin_w": "Řídnutí k okraji",
		"thin_min": "Hustota na okraji", "mat_line": "Čára hranice",
		"pg_enabled": "Procedurální louka", "pg_strength": "Síla", "pg_match": "Sladění trsů",
		"pg_macro_scale": "Velikost fleků", "pg_macro": "Světlejší/tmavší", "pg_yellow": "Do žlutozelena",
		"pg_dry": "Suchá místa: síla", "pg_dry_cov": "Suchá místa: plocha", "pg_lush": "Jetel: síla",
		"pg_lush_cov": "Jetel: plocha", "pg_streak": "Žíhání stébel", "pg_streak_w": "Žíhání: pruhů/buňku",
		"pg_streak_len": "Žíhání: délka", "pg_grain": "Zrno louky", "pg_clover": "Lístky jetele",
	}
