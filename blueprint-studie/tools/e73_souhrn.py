#!/usr/bin/env python3
"""E73: souhrn běhů prototypu voda_e66 (shots/e73/prototyp_<režim>_<přepínač>[_obr].json)."""
import json, sys, os
d0 = sys.argv[1] if len(sys.argv) > 1 else "shots/e73"
for m in ["vychozi", "e67"]:
    for s in ["vyp", "vyver", "pritok", "zrychleni", "prusak", "vse"]:
        f = os.path.join(d0, f"prototyp_{m}_{s}.json"); fo = os.path.join(d0, f"prototyp_{m}_{s}_obr.json")
        if not os.path.exists(f): continue
        d = json.load(open(f)); do = json.load(open(fo)) if os.path.exists(fo) else None
        h0 = d["hydro68_pred"]; h = d["hydro68_po"]; b0 = h0["bilance"]; b = h["bilance"]; su = d["souhrn_po"]
        ms = [e["ms"] for e in d["vykopy"]]; kol = [e["kola68"].get("kola") for e in d["vykopy"]]
        cy = sum(1 for e in d["vykopy"] if e["kola68"].get("cyklus", 0))
        ho = do["hydro68_po"]["otisk"] if do else "-"
        print(f"{m:7s} {s:9s} plný {d['voda_ms']['povrch + podzemí: plný výpočet']:6.0f} ms | kola {h0['kolo'].get('kola')} cyk {h0['kolo'].get('cyklus',0)} skoky {h0['kolo'].get('skoky',0)} | "
              f"chyba {b0['chyba_svet']:+.5f} → {b['chyba_svet']:+.5f} | okraj {b0['okraj']:.4f} prameny {b0['prameny_z_podzemi']:.4f} odtok {b0['odtok_tuni']:.4f} | "
              f"výkop ⌀ {sum(ms)/len(ms):.0f} max {max(ms):.0f} ms kola max {max(kol)} cyklů {cy} | neshod {d['neshod_celkem']}+{do['neshod_celkem'] if do else '-'} | "
              f"pr {su['prameny']} vod {su['vodopady']}+{su['vodopady_okraj']} okraj {su['okraj_lps']} tůně {su['tun_sloupcu']} kor {su['koryto_sloupcu']} | "
              f"otisk {h['otisk']} {'=' if ho == h['otisk'] else '≠'} {ho} | ug {d['podzemi_vystupy']}")
