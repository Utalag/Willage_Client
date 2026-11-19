#!/usr/bin/env python3
"""E56: shots/56_profil.png (řez vrcholem před / po, postava 2 m), shots/56_mapa.png (stínování, červeně > 45°).
Vstup shots/svah56.json (max_slope 1.0) a volitelně shots/svah56_s06.json (max_slope 0.6)."""
import json, os, numpy as np, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
D = os.path.join(os.path.dirname(__file__), "..", "shots")
runs = [("před", json.load(open(f"{D}/svah56.json")), "pred_hf", "pred")]
runs.append(("po, sklon ≤ 1,0 (45°)", runs[0][1], "po_hf", "po"))
if os.path.exists(f"{D}/svah56_s06.json"):
    s = json.load(open(f"{D}/svah56_s06.json")); runs.append(("po, sklon ≤ 0,6 (31°)", s, "po_hf", "po"))
N = runs[0][1]["N"]
def H(r, k): return np.array(r[k]).reshape(N, N) * 0.5  # metry
tx, ty = runs[0][1]["pred"]["vrchol"]
fig, ax = plt.subplots(figsize=(11, 4.5))
x = np.arange(N) * 0.5
for (lab, r, k, m), c in zip(runs, ["#444", "#c33", "#36c"]):
    ax.plot(x, H(r, k)[tx, :], color=c, lw=1.6, label=f"{lab}: p95 {r[m]['p95']:.0f}°, max {r[m]['max']:.0f}°, pata {r[m]['pata_m']:.0f} m")
# postava 2 m na úpatí
h0 = H(runs[0][1], "pred_hf")[tx, :]; fx = x[max(0, ty - 30)]; fz = h0[max(0, ty - 30)]
ax.plot([fx, fx], [fz, fz + 1.4], color="k", lw=3); ax.plot([fx], [fz + 1.75], "ko", ms=7)
ax.plot([fx - .3, fx, fx + .3], [fz, fz + .9, fz], color="k", lw=2)
ax.annotate("člověk 2 m", (fx, fz + 2.1), ha="center", fontsize=9)
ax.set_aspect("equal"); ax.set_xlabel("m (řez řádkem s nejvyšším vrcholem)"); ax.set_ylabel("výška m")
ax.legend(fontsize=8, loc="lower right"); ax.set_title("E56 řez vrcholem: před / po omezovači sklonu (měřítko 1:1)")
fig.tight_layout(); fig.savefig(f"{D}/56_profil.png", dpi=130)
fig, axs = plt.subplots(1, len(runs), figsize=(5 * len(runs), 5.2))
for a, (lab, r, k, m) in zip(axs, runs):
    h = H(r, k); gx, gy = np.gradient(h, 0.5)
    sl = np.degrees(np.arctan(np.hypot(gx, gy)))
    shade = np.clip(0.5 + 0.5 * (-gx - gy) / np.sqrt(2 + gx**2 + gy**2) * 1.4, 0, 1)
    rgb = np.dstack([shade] * 3); rgb[sl > 45] = [0.85, 0.1, 0.1]
    a.imshow(rgb.transpose(1, 0, 2), origin="lower"); a.set_xticks([]); a.set_yticks([])
    a.set_title(f"{lab}\n> 45°: {r[m]['nad45_pct']:.1f} % | schod max {int(r[m]['schod_max'])} b.", fontsize=9)
fig.suptitle("E56 stínování povrchu 64 × 64 m, červeně sklon > 45°"); fig.tight_layout(); fig.savefig(f"{D}/56_mapa.png", dpi=110)
print("ok")
