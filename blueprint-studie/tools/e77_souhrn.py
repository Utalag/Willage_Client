#!/usr/bin/env python3
"""E77: souhrn před (p71_cas 144) / po (24) ze shots/e77: ostrov (voda_e66, výchozí a E67), stav a události (cas_e77),
test smyčky E68, referenční testy E69."""
import json, os, re
D = os.path.join(os.path.dirname(__file__), "..", "shots", "e77")
J = lambda f: json.load(open(os.path.join(D, f)))
for sfx, nm in [("", "výchozí (E58)"), ("_e67", "E67")]:
    print(f"## ostrov {nm}")
    for k in ["pred", "po"]:
        o = J(f"{k}_ostrov{sfx}.json"); u = J(f"{k}_udalosti{sfx}.json")
        v = o["vykopy"]; dig = sum(e["ms"] for e in v) / len(v)
        b0 = o["hydro68_pred"]; b1 = o["hydro68_po"]
        print(f"{k}: p71_cas {u['p71_cas']:.0f} | prameny {u['prameny']} výstupy {u['vystupy']} ({u['vystupy_lps']:.5f} l/s) mokrá pásma {u['mokra_pasma']} objem {u['objem_m3']:.4f} m³ "
              f"přítok těles {u['pritok_teles_lps']:.5f} okraj {u['okraj_lps']:.5f} chyba {u['chyba_bilance']} | plný {o['voda_ms']['celkem']:.0f} ms, výkop ⌀ {dig:.0f} ms, "
              f"neshod {o['neshod_celkem']} | otisk {b0['otisk']} → po výkopech {b1['otisk']} (okraj {b1['bilance']['okraj']:.5f}, chyba {b1['bilance']['chyba_svet']}) | "
              f"první tůň {u['prvni_tun_s']:.1f} s = {u['prvni_tun_dni']:.4f} dne = {u['prvni_tun_realne_min']*60:.1f} s reálně; první eroze E51 {u['prvni_eroze_s']:.0f} s = "
              f"{u['prvni_eroze_dni']:.2f} dne = {u['prvni_eroze_realne_min']:.1f} min reálně")
print("## test smyčky E68")
for k in ["pred", "po"]:
    e = J(f"{k}_e68.json")
    print(k, {r: (e[r]["ustaleni"]["otisk"], e[r]["ustaleni"]["kola"], e[r]["ustaleni"]["bilance"]["chyba_svet"]) for r in e})
print("## E69 (řádky, které se liší)")
a = [l for l in open(os.path.join(D, "pred_e69.log")) if "bilance" in l]; b = [l for l in open(os.path.join(D, "po_e69.log")) if "bilance" in l]
for x, y in zip(a, b):
    if x != y:
        print("před:", re.sub(r"\s+", " ", x.strip())); print("po:  ", re.sub(r"\s+", " ", y.strip()))
print("stejných řádků", sum(1 for x, y in zip(a, b) if x == y), "z", len(a))
