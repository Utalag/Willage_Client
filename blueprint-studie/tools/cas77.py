#!/usr/bin/env python3
"""E77 (Jan 2026-11-19 22:19: 1 herní den = 1 reálná hodina): přepočet sdílených tabulek na nový faktor času.
Faktor se čte z jednoho místa (scripts/voda/cas_hry.gd, FAKTOR). Mění jen popisná pole: cas_faktor, t_1m_realne_min
(reálné minuty průsaku 1 m, ∝ 1 / faktor) a rezim (okamzite < 10 min / udalost / nepropustne > 30 dní reálně, stejné prahy
jako E61). Kód hry tato pole nečte (simulace je v herních sekundách)."""
import json, os, re
D = os.path.dirname(__file__)
R = os.path.join(D, "..", "..", "sdilene")
F = float(re.search(r"const FAKTOR := ([0-9.]+)", open(os.path.join(D, "..", "scripts", "voda", "cas_hry.gd")).read()).group(1))
def rez(m, d):
    return "okamzite" if m < d.get("rezim_okamzite_min", 10.0) else ("udalost" if m < d.get("rezim_nepropustne_min", 43200.0) else "nepropustne")
for fn in ["materialy_voda.json", "horniny_voda.json"]:
    p = os.path.join(R, fn)
    d = json.load(open(p))
    old = float(d.get("cas_faktor", 144))
    if old == F:
        print(fn, "už má faktor", F); continue
    ch = 0
    for name, v in d["materials"].items():
        if v.get("t_1m_realne_min") is None: continue
        v["t_1m_realne_min"] = round(float(v["t_1m_realne_min"]) * old / F, 4)
        r = rez(v["t_1m_realne_min"], d)
        if r != v.get("rezim"): ch += 1
        v["rezim"] = r
    d["cas_faktor"] = int(F) if F == int(F) else F
    if "_e61" in d:
        d["_e61"] = d["_e61"].replace("při čase hry × 144 (1 herní den = 10 min)", "při čase hry × %g (1 herní den = %g min, E77)" % (F, 1440 / F))
    json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
    print(fn, "faktor", old, "→", F, ", změněný režim u", ch, "materiálů")
