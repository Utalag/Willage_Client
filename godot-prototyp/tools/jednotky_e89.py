#!/usr/bin/env python3
"""E89: audit jednotek v kódu prototypu (scripts/**/*.gd bez nových souborů E89: jednotky.gd, meritko_demo.gd).
Počítá: opakované konstanty geometrie, konvence indexu buňky, klíče parametrů s jednotkou v názvu,
stejný klíč s různou výchozí hodnotou v p.get(...), převody 0,001 / 1000 (l ↔ m³) a místa měřítka scény.
Výstup: JSON na stdout, --md = tabulka markdown."""
import json, re, sys, pathlib
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
files = sorted(p for p in (ROOT / "scripts").rglob("*.gd") if p.name not in ("jednotky.gd", "meritko_demo.gd"))

re_const = re.compile(r'^\s*const\s+(BS|BH|CELL_H|U|BW|BHT|CELL|CELL_M|SURF_Y)\s*:?=\s*([^#\n]+)')
re_idx_game = re.compile(r'\(\s*\w+\s*\*\s*(BS|16)\s*\+\s*\w*z\w*\s*\)\s*\*\s*(BH|64)')
re_idx_geo = re.compile(r'\(\s*\w+\s*\*\s*(16|n|N|BS)\s*\+\s*\w*y\w*\s*\)\s*\*\s*(64|nz|NZ|BH)')
re_get = re.compile(r'p\w*\.get\(\s*"(\w+)"\s*,\s*([^)]+?)\)')
re_key = re.compile(r'"(\w+)"\s*:')
re_div = re.compile(r'/\s*1000(\.0)?\b')                      # l → m³ dělením
re_mul = re.compile(r'(\*\s*0\.001\b|0\.001\s*\*|q_to_m3)')     # l → m³ násobením 0,001 (jiný poslední bit než dělení)
re_skip = re.compile(r"get_ticks_|usec|msec|range_i|snapped")
re_cell_h = re.compile(r'\*\s*(CELL_H|0\.5)\b')

UNIT_SUFFIX = ("_m", "_m2", "_m3", "_s", "_lps", "_q", "_l", "_ms", "_dni", "_hj")

out = {"souboru": len(files), "konstanty": defaultdict(list), "index_hra_y_nahoru": 0, "index_geo_z_nahoru": 0,
       "souboru_s_indexem": {"hra": [], "geo": []}, "get_vychozi": defaultdict(set), "l_m3_deleni": 0, "l_m3_nasobeni": 0,
       "nasobeni_0_5": 0, "klice_s_jednotkou": set(), "klice_bez_jednotky_s_fyzikou": set()}
params_keys = set()
for f in files:
    rel = str(f.relative_to(ROOT))
    t = f.read_text(encoding="utf-8")
    for line in t.splitlines():
        code = line.split("#", 1)[0]
        m = re_const.match(code)
        if m: out["konstanty"][m.group(1)].append([rel, m.group(2).strip()])
        if re_idx_game.search(code): out["index_hra_y_nahoru"] += 1; out["souboru_s_indexem"]["hra"].append(rel)
        if re_idx_geo.search(code): out["index_geo_z_nahoru"] += 1; out["souboru_s_indexem"]["geo"].append(rel)
        for k, d in re_get.findall(code): out["get_vychozi"][k].add(d.strip())
        if "/voda/" in "/" + rel and not re_skip.search(code):
            if re_div.search(code): out["l_m3_deleni"] += 1
            if re_mul.search(code): out["l_m3_nasobeni"] += 1
        out["nasobeni_0_5"] += len(re_cell_h.findall(code))
    if rel.endswith("teren/params.gd"):
        params_keys = set(re_key.findall(t))
for k in params_keys:
    if k.endswith(UNIT_SUFFIX): out["klice_s_jednotkou"].add(k)
konflikt = {k: sorted(v) for k, v in out["get_vychozi"].items() if len(v) > 1}
def num(s):
    try: return float(s)
    except ValueError: return None
konflikt_cisla = {k: v for k, v in konflikt.items() if len({num(x) for x in v if num(x) is not None}) > 1}
res = {
    "souboru": out["souboru"],
    "konstanty_geometrie": {k: v for k, v in out["konstanty"].items()},
    "konstanty_pocet_mist": {k: len(v) for k, v in out["konstanty"].items()},
    "index_hra_y_nahoru_mist": out["index_hra_y_nahoru"], "index_hra_souboru": len(set(out["souboru_s_indexem"]["hra"])),
    "index_geo_z_nahoru_mist": out["index_geo_z_nahoru"], "index_geo_souboru": len(set(out["souboru_s_indexem"]["geo"])),
    "p_get_klicu": len(out["get_vychozi"]), "p_get_ruzne_vychozi": len(konflikt), "p_get_ruzne_vychozi_cisla": konflikt_cisla,
    "v_params_klicu": len(params_keys), "v_params_s_jednotkou_v_nazvu": len(out["klice_s_jednotkou"]),
    "voda_l_m3_deleni_1000_mist": out["l_m3_deleni"], "voda_l_m3_nasobeni_0_001_mist": out["l_m3_nasobeni"], "nasobeni_0_5_nebo_CELL_H_mist": out["nasobeni_0_5"],
}
if "--md" in sys.argv:
    print("| konstanta | míst | hodnoty |\n|---|---|---|")
    for k, v in res["konstanty_geometrie"].items():
        print(f"| {k} | {len(v)} | {', '.join(sorted({x[1] for x in v}))} |")
    for k in ["index_hra_y_nahoru_mist", "index_hra_souboru", "index_geo_z_nahoru_mist", "index_geo_souboru", "p_get_klicu",
              "p_get_ruzne_vychozi", "v_params_klicu", "v_params_s_jednotkou_v_nazvu", "voda_l_m3_deleni_1000_mist", "voda_l_m3_nasobeni_0_001_mist", "nasobeni_0_5_nebo_CELL_H_mist"]:
        print(f"- {k}: {res[k]}")
    print("- číselně různé výchozí hodnoty p.get:")
    for k, v in sorted(konflikt_cisla.items()): print(f"  - {k}: {v}")
else:
    print(json.dumps(res, ensure_ascii=False, indent=1))
