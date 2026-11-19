#!/usr/bin/env python3
"""E68: souhrn běhů prototypu voda_e66 (shots/e68/prototyp_*.json)."""
import json, sys, os
d0 = sys.argv[1] if len(sys.argv) > 1 else "shots/e68"
for n in ["vyp", "vyp_obr", "zap", "zap_obr", "e67_vyp", "e67_vyp_obr", "e67_zap", "e67_zap_obr"]:
    f = os.path.join(d0, f"prototyp_{n}.json")
    if not os.path.exists(f): continue
    d = json.load(open(f))
    h0 = d["hydro68_pred"]; h = d["hydro68_po"]; b0 = h0["bilance"]; b = h["bilance"]; s = d["souhrn_po"]
    ms = [e["ms"] for e in d["vykopy"]]; kol = [e["kola68"].get("kola") for e in d["vykopy"]]; cy = [e["kola68"].get("cyklus", 0) for e in d["vykopy"]]
    print(f"{n:12s} plný {d['voda_ms']['povrch + podzemí: plný výpočet']:7.0f} ms | kola {h0['kolo']} | chyba svět {b0['chyba_svet']:+.5f} → po výkopech {b['chyba_svet']:+.5f} | "
          f"okraj {b0['okraj']:.4f} ponory {b0['ponory']:.4f} odtok tůní {b0['odtok_tuni']:.4f} prameny {b0['prameny_z_podzemi']:.4f} stěna {b0['podzemi_stena']:.4f} | "
          f"otisk {h0['otisk']} → {h['otisk']} | neshod {d['neshod_celkem']} | výkop ⌀ {sum(ms)/len(ms):.1f} max {max(ms):.1f} ms | kola {kol} cyklus {cy} | "
          f"prameny {s['prameny']} vodopády {s['vodopady']}+{s['vodopady_okraj']} okraj {s['okraj_lps']} tůně {s['tun_sloupcu']} koryto {s['koryto_sloupcu']} volání {s['volani_podzemi']} | ug {d['podzemi_vystupy']}")
