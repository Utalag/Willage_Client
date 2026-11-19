#!/usr/bin/env python3
"""E59 návrh kalibrovaných vodních vlastností (Jan 03:47). NEPŘEPISUJE sdílené tabulky; píše
../sdilene/materialy_voda_navrh.json a shots/materialy59.md (tabulka do PROP).
K = typická hydraulická vodivost [m/s] (střed rozsahu v log, Freeze & Cherry 1979 tab. 2.2; půdy Rawls 1982),
n = pórovitost (F&C tab. 2.4), Sy = specifická vydatnost (Johnson 1967 tab. 29), ret = n − Sy (zadržená voda),
ero_v / sed_v = odečet z Hjulströmova diagramu (řádový odhad), skály = herní odhad.
Průsak 1 m při spádu 1: v = K / Sy (pórová rychlost), t = 1 m / v. Čas hry: 1 herní den = 10 min reálně (× 144)."""
import json, math, os
R = os.path.join(os.path.dirname(__file__), "..", "..", "sdilene")
G = {  # skupina: (K typ, K min, K max, n, Sy, ero_v, sed_v, popis)
 "pisek":      (1e-4, 1e-6, 1e-2, 0.35, 0.26, 0.25, 0.03, "čistý písek"),
 "sterk":      (1e-2, 1e-3, 1.0, 0.30, 0.22, 1.2, 0.4, "štěrk, suť"),
 "hlina":      (3.7e-6, 1e-7, 1e-5, 0.43, 0.15, 0.4, 0.003, "hlinitá půda (loam, Rawls 1982)"),
 "drn":        (1e-5, 1e-6, 1e-4, 0.45, 0.15, 1.5, 0.003, "půda s drnem a kořeny"),
 "spras":      (1e-7, 1e-9, 1e-5, 0.45, 0.08, 0.3, 0.002, "spraš, prach"),
 "jil":        (1e-10, 1e-12, 1e-9, 0.50, 0.02, 1.2, 0.0005, "jíl"),
 "piskovec":   (1e-7, 1e-10, 1e-6, 0.20, 0.10, 2.0, 0.0, "pískovec"),
 "slepenec":   (1e-6, 1e-8, 1e-4, 0.20, 0.10, 2.0, 0.0, "slepenec"),
 "prachovec":  (1e-9, 1e-11, 1e-7, 0.15, 0.03, 1.5, 0.0, "prachovec, flyš"),
 "bridlice":   (1e-11, 1e-13, 1e-9, 0.05, 0.01, 2.0, 0.0, "jílová břidlice, fylit, svor"),
 "vapenec":    (3e-8, 1e-9, 1e-6, 0.05, 0.02, 4.0, 0.0, "vápenec, dolomit (nekrasový)"),
 "kras":       (1e-4, 1e-6, 1e-2, 0.10, 0.05, 4.0, 0.0, "krasový vápenec"),
 "evaporit":   (1e-13, 1e-14, 1e-12, 0.01, 0.005, 1.0, 0.0, "sůl, sádrovec (rozpouští se zvlášť)"),
 "uhli":       (1e-7, 1e-9, 1e-5, 0.08, 0.03, 1.5, 0.0, "uhlí (puklinová propustnost)"),
 "krystal":    (1e-12, 1e-14, 1e-10, 0.01, 0.005, 6.0, 0.0, "nerozpukané krystalinikum a vyvřeliny"),
 "krystal_pukl": (1e-6, 1e-8, 1e-4, 0.05, 0.02, 3.0, 0.0, "rozpukané / zvětralé krystalinikum"),
 "cedic":      (1e-9, 1e-11, 1e-7, 0.05, 0.02, 6.0, 0.0, "hutný čedič"),
 "vulk_zvetr": (1e-5, 1e-7, 1e-2, 0.25, 0.10, 2.0, 0.0, "propustný / zvětralý vulkanit"),
}
MAP = {  # materiál → skupina
 "grass": "drn", "dirt": "hlina", "sand": "pisek", "clay": "jil", "clay_deposit": "jil", "limestone": "vapenec",
 "granite": "krystal", "basalt": "cedic", "copper": "krystal", "iron": "krystal",
 "siltstone": "prachovec", "conglomerate": "slepenec", "rock_salt": "evaporit", "gypsum": "evaporit", "dolomite": "vapenec",
 "black_coal": "uhli", "lignite": "uhli", "shale": "bridlice", "quartz_sandstone": "piskovec", "loess": "spras", "hill_sand": "pisek",
 "limestone_outcrop": "vapenec", "deep_limestone": "vapenec", "weathered_volcanic": "vulk_zvetr", "flysch": "prachovec",
 "sandstone_towers": "piskovec", "weathered_granite": "krystal_pukl", "subalpine_scree": "sterk", "slope_schist": "bridlice",
 "mica_schist": "bridlice", "phyllite": "bridlice", "cave_limestone": "kras",
}
def perm_log(K):   # návrh: log škála 1e-9 → 0, 1e-3 → 1 (lineárně v log10 K)
    return max(0.0, min(1.0, (math.log10(K) + 9.0) / 6.0))
def t1m(K, sy):    # s na 1 m při spádu 1
    return 1.0 / (K / max(sy, 1e-4))
def fmt_t(s):
    d = s / 86400.0; rm = s / 144.0 / 60.0
    return d, rm
tabs = []
for fn in ["materialy_voda.json", "horniny_voda.json"]:
    d = json.load(open(f"{R}/{fn}")); tabs.append((fn, d["materials"]))
out = {"_popis": "E59 NÁVRH (Jan 03:47), nepřijato – Jan rozhodne. Nepřepisuje materialy_voda.json ani horniny_voda.json. "
       "K_ms = typická hydraulická vodivost m/s (Freeze & Cherry 1979 tab. 2.2, půdy Rawls 1982), n = pórovitost (F&C tab. 2.4), "
       "Sy = specifická vydatnost (Johnson 1967), ret_navrh = n − Sy omezené ≤ por, perm_navrh = (log10 K + 9) / 6 v [0, 1], "
       "ero_v / sed_v z Hjulströmova diagramu (řádově), skály herní odhad. t_1m = čas průsaku 1 m při spádu 1 (s herního času); "
       "1 herní den = 10 min reálně (× 144).", "zdroje": ["ZDROJE [32]", "ZDROJE [38]", "ZDROJE [39]", "ZDROJE [40]", "ZDROJE [41]"],
       "cas_hry_faktor": 144, "materials": {}}
rows = []
for fn, mats in tabs:
    for name, v in mats.items():
        g = MAP.get(name)
        if g is None:
            if name in ("air", "snow") or int(v.get("id", 0)) >= 100: continue
            g = "krystal"
        K, kmin, kmax, n, sy, ev, sv, pop = G[g]
        ret = round(min(n - sy, max(float(v.get("por", n)), n - sy)), 3)
        t = t1m(K, sy); dd, rm = fmt_t(t)
        e = {"zdroj_tabulky": fn, "skupina": g, "popis_skupiny": pop, "K_ms": K, "K_rozsah_ms": [kmin, kmax], "n": n, "Sy": sy,
             "por_navrh": n, "ret_navrh": round(n - sy, 3), "perm_navrh": round(perm_log(K), 3), "ero_v_navrh": ev, "sed_v_navrh": sv,
             "t_1m_s": t, "t_1m_herni_dny": dd, "t_1m_realne_min": rm,
             "soucasne": {k: v.get(k) for k in ("perm", "por", "ret", "ero_v", "sed_v")}}
        out["materials"][name] = e
        rows.append((name, g, K, n, sy, e["perm_navrh"], v.get("perm"), ev, v.get("ero_v"), sv, v.get("sed_v"), dd, rm))
json.dump(out, open(f"{R}/materialy_voda_navrh.json", "w"), ensure_ascii=False, indent=1)
def ft(x):
    if x is None: return "—"
    return f"{x:.3g}"
def tt(dd, rm):
    if rm < 1: return f"{rm*60:.0f} s"
    if rm < 120: return f"{rm:.0f} min"
    if rm < 60 * 48: return f"{rm/60:.0f} h"
    if rm < 60 * 24 * 730: return f"{rm/1440:.0f} dní"
    return f"{rm/525600:.0f} let"
L = ["| materiál | skupina | K m/s | n | Sy | perm návrh (nyní) | ero_v návrh (nyní) | sed_v návrh (nyní) | 1 m: herní dny | 1 m: reálně |", "|---|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    name, g, K, n, sy, pn, pc, ev, ec, sv, sc, dd, rm = r
    L.append(f"| {name} | {g} | {K:.0e} | {n} | {sy} | {pn} ({ft(pc)}) | {ev} ({ft(ec)}) | {sv} ({ft(sc)}) | {dd:.3g} | {tt(dd, rm)} |")
open(os.path.join(os.path.dirname(__file__), "..", "shots", "materialy59.md"), "w").write("\n".join(L) + "\n")
print(len(rows), "materiálů")
for r in rows[:12]: print(r[0], r[1], f"{r[11]:.3g} dní", tt(r[11], r[12]))
