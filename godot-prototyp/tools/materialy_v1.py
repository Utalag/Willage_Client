#!/usr/bin/env python3
"""Krok 1 (V1.0): kontrola jedné tabulky materiálů data/materialy_v1.csv (docs/sjednoceni 1.6).
Kontroly: unikátní id 0–255, skupiny, rozsahy (propustnost 0–1, pórovitost 0–1, hustota > 0), vzorec
propustnosti (log10 K + 9) / 6, X [l/s] = K * 0,25 m2 * 1000 (1.8.1, buňka 0,5 m), shoda se sdilene/*_voda.json v4.
Konflikty se jen vypisují (opraví se v kroku 3). Výstup: JSON + graf PNG. Použití: python3 tools/materialy_v1.py [--out=dir]
"""
import csv, json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "shots", "krok01")
for a in sys.argv[1:]:
    if a.startswith("--out="): OUT = a.split("=", 1)[1]
os.makedirs(OUT, exist_ok=True)

def num(s):
    t = (s or "").replace("[~]", "").replace("~", "").strip().split(" ")[0]
    try: return float(t)
    except ValueError: return None

rows = list(csv.DictReader(open(os.path.join(ROOT, "data", "materialy_v1.csv"), encoding="utf-8")))
chyby, konflikty, info = [], [], {}
ids = {}
for r in rows:
    i = int(r["id"])
    if i in ids: chyby.append(f"duplicitní id {i}")
    ids[i] = r
    if not 0 <= i <= 255: chyby.append(f"id {i} mimo u8")
    if r["skupina"] not in ("soil", "rock", "ore", "water", "other"): chyby.append(f"id {i}: neznámá skupina {r['skupina']}")
    p, por, hus, K, X = (num(r[k]) for k in ("propustnost_0_1", "porovitost", "hustota_kg_m3", "K_m_s", "propustnost_l_s_herni"))
    if p is not None and not 0 <= p <= 1: chyby.append(f"id {i}: propustnost {p} mimo 0–1")
    if por is not None and not 0 <= por <= 1: chyby.append(f"id {i}: pórovitost {por} mimo 0–1")
    if hus is not None and hus <= 0: chyby.append(f"id {i}: hustota {hus}")
    if K is not None and p is not None:
        pv = min(1, max(0, (math.log10(K) + 9) / 6))
        if abs(pv - p) > 0.01: chyby.append(f"id {i}: propustnost {p} ≠ vzorec {pv:.3f}")
    if K is not None and X is not None:
        xv = K * 0.25 * 1000
        if abs(xv - X) > 0.02 * xv: chyby.append(f"id {i}: X {X} ≠ K·0,25 m²·1000 = {xv:.3g}")
    if hus is None and r["skupina"] not in ("other",): konflikty.append(f"id {i} ({r['nazev_cs']}): chybí hustota")

# shoda se staršími vodními tabulkami v4 (stejné id → stejný K a perm?)
stare = {}
for f in ("materialy_voda.json", "horniny_voda.json"):
    d = json.load(open(os.path.join(ROOT, "..", "sdilene", f), encoding="utf-8"))
    for k, m in d["materials"].items(): stare[m["id"]] = (k, m, f)
shoda = {"stejne": 0, "jinak": [], "chybi_v_csv": [], "chybi_ve_vode": []}
for i, (k, m, f) in sorted(stare.items()):
    if i not in ids: shoda["chybi_v_csv"].append(f"{i} {k}"); continue
    p = num(ids[i]["propustnost_0_1"])
    if p is None or abs(p - m["perm"]) > 0.01: shoda["jinak"].append(f"{i} {k}: voda {m['perm']} / csv {p}")
    else: shoda["stejne"] += 1
for i in ids:
    if i not in stare and ids[i]["skupina"] != "other": shoda["chybi_ve_vode"].append(f"{i} {ids[i]['nazev_cs']}")
for r in rows:
    if "konflikt" in r["poznamka"].lower() or "dva klíče" in r["poznamka"]: konflikty.append(f"id {r['id']} ({r['nazev_cs']}): {r['poznamka']}")
pasma = [i for i in ids if 57 <= i <= 74]

vysl = {"pocet": len(rows), "chyby": chyby, "konflikty_k_reseni_v_kroku_3": konflikty,
        "pasma_krajiny_57_74": len(pasma), "shoda_s_vodou_v4": shoda}
json.dump(vysl, open(os.path.join(OUT, "materialy_v1.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
data = sorted([(num(r["K_m_s"]), r) for r in rows if num(r["K_m_s"])], key=lambda x: x[0])
fig, ax = plt.subplots(figsize=(10, 14))
y = range(len(data))
ax.barh(list(y), [math.log10(k) + 14 for k, _ in data], left=-14, color=[r["barva_hex"] if r["barva_hex"].startswith("#") else "#999" for _, r in data], edgecolor="#333", linewidth=0.3)
ax.set_yticks(list(y)); ax.set_yticklabels([f"{r['id']} {r['nazev_cs'][:28]}" for _, r in data], fontsize=7)
ax.set_xlabel("log10 K [m/s]  (propustnost 0–1 = (log10 K + 9) / 6)")
ax.set_title(f"Krok 1 V1.0: tabulka materiálů, {len(data)} z {len(rows)} id s K (barva = barva_hex)")
ax2 = ax.twiny(); ax2.set_xlim(ax.get_xlim()); t = [-13, -11, -9, -7, -5, -3]
ax2.set_xticks(t); ax2.set_xticklabels([f"X={10**k*250:.2g} l/s" for k in t], fontsize=7)
plt.tight_layout(); plt.savefig(os.path.join(OUT, "materialy_propustnost.png"), dpi=110)
print(f"materialy_v1: {len(rows)} materiálů, chyb {len(chyby)}, konfliktů {len(konflikty)}, shoda s vodou v4 {shoda['stejne']}, jinak {len(shoda['jinak'])}, chybí v csv {len(shoda['chybi_v_csv'])}")
sys.exit(1 if chyby else 0)
