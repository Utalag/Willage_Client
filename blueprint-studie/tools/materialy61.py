#!/usr/bin/env python3
"""E61 (Jan 04:39): převzetí návrhu E59 (sdilene/materialy_voda_navrh.json) do sdílených tabulek. Zálohy v shots/e61/.
Mění perm, por, ret, ero_v, sed_v (+ nová pole K_ms, Sy, skupina, t_1m_realne_min, rezim); res, load, cantilever, ero_vol
beze změny. Vzduch, sníh a minerály (id ≥ 100) beze změny. Měkké horniny (spraš, kopcový písek, suť) dostanou ero_vol jako
hlína / písek, ostatní horniny ero_vol nemají (zůstanou pro erozi tvrdé)."""
import json, os
R = os.path.join(os.path.dirname(__file__), "..", "..", "sdilene")
N = json.load(open(f"{R}/materialy_voda_navrh.json"))["materials"]
T_OK, T_HOR = 10.0, 30 * 24 * 60.0   # reálné minuty
def rez(m): return "okamzite" if m < T_OK else ("udalost" if m < T_HOR else "nepropustne")
HDR = {"_e61": "Od v4 (Jan 04:39, blueprint-studie E61): vodní pole podle reálných hodnot (výzkum E59, ZDROJE [32], [38]–[41]). "
       "perm = (log10 K + 9) / 6 v [0, 1] (K ≤ 1e-9 m/s → 0, K ≥ 1e-3 → 1); por = pórovitost n; ret = n − Sy (zadržená voda); "
       "K_ms = typická hydraulická vodivost m/s; Sy = specifická vydatnost; t_1m_realne_min = průsak 1 m při spádu 1 v reálných "
       "minutách při čase hry × 144 (1 herní den = 10 min); rezim = okamzite (< 10 min reálně: ustálený stav) / udalost (halda E51) / "
       "nepropustne (> 30 dní reálně). ero_v, sed_v odečteny z Hjulströmova diagramu (řádově). Dřívější hodnoty byly zkušební "
       "(záloha blueprint-studie/shots/e61/).",
       "perm_mapovani": "(log10 K_ms + 9) / 6", "cas_faktor": 144, "rezim_okamzite_min": T_OK, "rezim_nepropustne_min": T_HOR}
SOFT = {"loess": "dirt", "hill_sand": "sand", "subalpine_scree": "sand"}
ch = []
for fn, ver in [("materialy_voda.json", 4), ("horniny_voda.json", 2)]:
    d = json.load(open(f"{R}/{fn}"))
    main = json.load(open(f"{R}/materialy_voda.json"))["materials"] if fn != "materialy_voda.json" else d["materials"]
    for name, v in d["materials"].items():
        e = N.get(name)
        if e is None: continue
        old = {k: v.get(k) for k in ("perm", "por", "ret", "ero_v", "sed_v")}
        v["perm"] = e["perm_navrh"]; v["por"] = e["por_navrh"]; v["ret"] = e["ret_navrh"]
        v["ero_v"] = e["ero_v_navrh"]; v["sed_v"] = e["sed_v_navrh"]
        if name in SOFT and "ero_vol" not in v: v["ero_vol"] = main[SOFT[name]]["ero_vol"]
        v["K_ms"] = e["K_ms"]; v["Sy"] = e["Sy"]; v["skupina"] = e["skupina"]
        v["t_1m_realne_min"] = round(e["t_1m_realne_min"], 4); v["rezim"] = rez(e["t_1m_realne_min"])
        ch.append((fn, name, old, {k: v[k] for k in old}, v["rezim"]))
    d["version"] = ver
    for k, x in HDR.items(): d[k] = x
    if fn == "materialy_voda.json":
        d["_popis"] = d["_popis"].replace(", vápenec nepropustný", "; vápenec od v4 podle reálné K, Jan 04:39")
    else:
        d["_popis"] = d["_popis"].replace("krystalinikum, karbonáty jako vápenec podle Jana nepropustné", "od v2 podle reálných K (E61, Jan 04:39)")
    json.dump(d, open(f"{R}/{fn}", "w"), ensure_ascii=False, indent=1)
L = ["| tabulka | materiál | perm | por | ret | ero_v | sed_v | režim |", "|---|---|---|---|---|---|---|---|"]
for fn, n, o, nw, r in ch:
    f = lambda k: f"{o[k]} → {nw[k]}" if o[k] != nw[k] else f"{nw[k]}"
    L.append(f"| {fn.split('_')[0]} | {n} | {f('perm')} | {f('por')} | {f('ret')} | {f('ero_v')} | {f('sed_v')} | {r} |")
open(os.path.join(os.path.dirname(__file__), "..", "shots", "e61", "zmeny_tabulek.md"), "w").write("\n".join(L) + "\n")
print(len(ch), "materiálů změněno")
