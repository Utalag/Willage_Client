#!/usr/bin/env python3
"""E74: souhrn běhů prototypu tools/gw_e74.gd (shots/e74/gw_<běh>.json)."""
import json, sys, os
d0 = sys.argv[1] if len(sys.argv) > 1 else "shots/e74"
for n in ["vychozi", "vychozi_obr", "vyzv", "vyzv_obr", "e67", "e67_obr", "e67_vyzv", "e67_vyzv_obr"]:
    f = os.path.join(d0, f"gw_{n}.json")
    if not os.path.exists(f): continue
    d = json.load(open(f)); m = d["pamet"]; o = d["objem"]; vy = d["vytoky"]; dg = d["vykopy"]
    kus = [e["kontakt"]["us"] for e in dg]; gms = [e["gw_ms"] for e in dg]; ms = [e["ms"] for e in dg]
    print(f"{n:13s} plný {d['voda_ms']['povrch + podzemí: plný výpočet']:6.0f} ms plocha {d['gw_ms']:5.1f} ms | paměť: pásma {m['pasma_B']} B, tělesa {m['telesa_vysledky_B']} B, plocha {m['plocha_B']} / řídká {m['plocha_ridka_B']} / kompakt {m['plocha_kompakt_B']} B "
          f"(sloupců s vodou {m['sloupcu_s_vodou']}, tvar {m['tvar_sloupcu']}, výjimek {m['vyjimek']}, film {m['film_sloupcu']}) | objem {o['resic']:.4f} vs {o['plocha']:.4f} m³ (Δ {o['rozdil']:.1e}) | "
          f"výtoky plochy {vy['vytoku_plochy']} {vy['typy']} výstupy řešiče {vy['vystupu_resice']} na výtoku {vy['na_vytoku']} vedle {vy['vedle']} mimo {vy['mimo']} | "
          f"výkop ⌀ {sum(ms)/len(ms):.0f} ms, plocha znovu ⌀ {sum(gms)/len(gms):.1f} ms, kontakt ⌀ {sum(kus)/len(kus):.0f} µs max {max(kus)} µs | vzorek vše {d['vzorek_vse']} | "
          f"neshod {d['neshod_celkem']} otisk≠plný {d['otisk_neshod']} plocha≠plná {d['plocha_neshod']} | otisk plochy {d['otisk_po']} hydro {d['hydro_otisk_po']} | chyba {d['hydro68_po']['bilance']['chyba_svet']:.1e} | vyver74 {d['vyver74']} obsazeno {d['obsazeno']}")
    print("   režimy:", {k: (v['objem_resic'], v['objem_plocha'], f"{v['rozdil']:.1e}", v['sloupcu'], v['tvar'], v['vyjimek'], v['kompakt_B'], v['otisk']) for k, v in d['rezimy'].items()})
