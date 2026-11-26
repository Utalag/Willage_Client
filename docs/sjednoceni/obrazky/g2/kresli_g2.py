# G-2: přehled schématu parametrů (moduly → skupiny → počty). Vstup: docs/sjednoceni/reporty/g2/schema_parametru_v1.json
import json, os, collections
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
here = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(here, "../../reporty/g2/schema_parametru_v1.json"), encoding="utf-8"))
P = d["parametry"]
nazvy = {"M0":"Planeta","M1":"Funkce světa","M2":"Moře a kontinenty","M3":"Geologie","M4":"Eroze","M5":"Klima a biomy","M6":"Voda a průsak","M7":"Výstup"}
barvy = {"ParametrySveta":"#4c78a8","ParametryEroze":"#f58518","ParametryKlimatu":"#54a24b","ParametryVody":"#b279a2","prusak_v1.json":"#9d755d"}
fig, ax = plt.subplots(figsize=(18, 10)); ax.set_xlim(0, 8); ax.set_ylim(0, 1); ax.axis("off")
for i, m in enumerate(nazvy):
    pm = [p for p in P if p["Modul"] == m]
    x = i + 0.04
    ax.add_patch(FancyBboxPatch((x, 0.86), 0.92, 0.1, boxstyle="round,pad=0.01", fc="#333", ec="none"))
    ax.text(x + 0.46, 0.925, f"{m} {nazvy[m]}", ha="center", va="center", color="w", fontsize=10, weight="bold")
    ax.text(x + 0.46, 0.885, f"{len(pm)} parametrů", ha="center", va="center", color="#ddd", fontsize=9)
    sk = collections.OrderedDict()
    for p in pm: sk.setdefault((p["Zdroj"], p["Skupina"]), []).append(p)
    y = 0.84; h = 0.78 / max(1, sum(len(v) for v in sk.values()) + 2 * len(sk))
    for (zdroj, s), ps in sk.items():
        hh = h * (len(ps) + 1.6)
        ax.add_patch(FancyBboxPatch((x, y - hh), 0.92, hh - h * 0.3, boxstyle="round,pad=0.004", fc=barvy[zdroj], ec="none", alpha=0.85))
        jc = sum(p["JenCteni"] for p in ps); od = sum(p["RozsahZdroj"] == "odhad" for p in ps)
        ax.text(x + 0.03, y - hh / 2 - h * 0.15, f"{s}\n{len(ps)}×" + (f", {jc} jen čtení" if jc else "") + (f", {od} odhad" if od else ""),
                va="center", fontsize=7.5, color="w")
        y -= hh
    if not pm: ax.text(x + 0.46, 0.6, "bez parametrů\n(skládá výstup)", ha="center", fontsize=9, color="#555")
for j, (z, b) in enumerate(barvy.items()):
    ax.add_patch(plt.Rectangle((0.05 + j * 1.6, 0.01), 0.12, 0.025, fc=b)); ax.text(0.2 + j * 1.6, 0.022, z, va="center", fontsize=9)
typy = collections.Counter(p["Typ"] for p in P)
ax.set_title(f"G-2 schéma parametrů M0–M7: {len(P)} parametrů (" + ", ".join(f"{k} {v}" for k, v in typy.items()) + "); nápověda = prázdný slot", fontsize=13)
plt.savefig(os.path.join(here, "01-schema-parametru.png"), dpi=110, bbox_inches="tight")
print("ok")
