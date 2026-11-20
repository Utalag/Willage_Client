extends RefCounted
## KOPIE z blueprint-studie/scripts/voda/litry.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E94: jediný převod litrů na m³ ve vodě (Jan 2026-11-20 11:04 „sjednocení“). Tvar = dělení 1000: IEEE dělení je
## správně zaokrouhlené, násobení 0,001 zaokrouhluje dvakrát (0,001 není v binárním tvaru přesně) a u 13 % průtoků dalo
## jiný poslední bit (E89). Port (C#, telefon) musí použít stejný tvar.
## Ve vnitřních smyčkách se nevolá funkce (3–4× dražší, E89), ale stejný výraz `x / LI.L_NA_M3` s konstantou.
## Parametr `ug_q_to_m3` (0,001, v testech 1) zůstává; kontext z něj má `l_na_m3` = 1 / ug_q_to_m3 (1000 přesně, testy 1).

const L_NA_M3 := 1000.0

## litry (l, l/s) → m³ (m³, m³/s)
static func m3(v_l: float, l_na_m3 := L_NA_M3) -> float:
	return v_l / l_na_m3

## m³ → litry
static func l(v_m3: float, l_na_m3 := L_NA_M3) -> float:
	return v_m3 * l_na_m3

## počet litrů na m³ z parametru ug_q_to_m3 (m³ na litr; výchozí 0,001 → 1000.0 přesně, testy s jednotkou 1 → 1)
static func z_parametru(p: Dictionary) -> float:
	return 1.0 / float(p.get("ug_q_to_m3", 1.0 / L_NA_M3))
