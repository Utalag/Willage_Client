#!/usr/bin/env python3
"""E75: souhrn měření krasu ze shots/e75/*.json (syntetický test tools/e75.gd a ostrov z prototypu tools/kras_e75.gd)."""
import json, glob, os
d = os.path.join(os.path.dirname(__file__), "..", "shots", "e75")
print("| test | režim | průtok l/s | pásem | m³/herní den | 1. dutina herní dny | reálně h | rychlosti ms | lokálně ms | plný ms | neshod přesně / >1e-12 | pořadí výkopů |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for f in sorted(glob.glob(os.path.join(d, "kras_*.json"))):
    j = json.load(open(f))
    for rz, v in j.items():
        a = v["bez_vykopu"]; ev = a["udalosti"]
        lok = sum(e["lokalne_ms"] for e in ev) / len(ev) if ev else 0
        pl = sum(e["plny_ms"] for e in ev) / len(ev) if ev else 0
        prv = a["prvni_dni"]
        print(f"| {os.path.basename(f)[5:-5]} | {rz} | {a['prutok_l_s']:.3f} | {a['pasem']} | {a['m3_za_den']:.3g} | {prv:.1f} | {prv*10/60:.1f} | {a['rates_ms']:.2f} | {lok:.0f} | {pl:.0f} | {a['neshod']} / {a['neshod_1e12']} | {'stejné' if v['poradi_stejny_otisk'] else 'JINÉ'} |" if prv != float('inf') else
              f"| {os.path.basename(f)[5:-5]} | {rz} | {a['prutok_l_s']:.3f} | {a['pasem']} | 0 | – | – | {a['rates_ms']:.2f} | – | – | {a['neshod']} / {a['neshod_1e12']} | {'stejné' if v['poradi_stejny_otisk'] else 'JINÉ'} |")
for f in sorted(glob.glob(os.path.join(d, "ostrov_*.json"))):
    j = json.load(open(f))
    print(os.path.basename(f), {k: j[k] for k in list(j)[:12] if not isinstance(j[k], (list, dict))})
