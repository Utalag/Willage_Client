#!/usr/bin/env python3
"""E66b: obrázek podzemního tělesa ostrova z shots/66_parita/teleso_e66.json (tools/teleso_e66.gd)
→ ../blueprint-studie/shots/66b_teleso.png: mapa (které sloupce patří do největšího tělesa), řez přes ostrov
(pásma podle materiálu, propustná pásma tělesa šrafovaná) a podíl jednotlivých vrstev."""
import json, os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

D = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(D, "../shots/66_parita/teleso_e66.json")))
ox, oy = d["off"]
names = {m["id"]: m["jmeno"] for m in d["materialy"]}
perm = {m["id"]: m["perm"] for m in d["materialy"]}
mapa = np.array(d["mapa"], dtype=float)
# jen oblast ostrova (sloty -2..3 → s rezervou) – ořez na sloupce, kde je pevnina
land = np.argwhere(mapa >= 0)
x0, y0 = land.min(0); x1, y1 = land.max(0)
sub = mapa[x0:x1 + 1, y0:y1 + 1]

fig = plt.figure(figsize=(15, 10))
ax1 = fig.add_axes([0.04, 0.42, 0.26, 0.42])
cm = matplotlib.colors.ListedColormap(["#e8e8e8", "#9ec5e8", "#1f5fa8"])
img = np.ma.masked_less(sub, 0)
ax1.imshow(img.T, origin="lower", cmap=cm, vmin=0, vmax=2, extent=[x0 - ox, x1 + 1 - ox, y0 - oy, y1 + 1 - oy])
for k in range(0, 33, 16):
    ax1.axvline(k, color="k", lw=0.8); ax1.axhline(k, color="k", lw=0.8)
for yl in d["rezy"]:
    ax1.axhline(int(yl) - oy + 0.5, color="#ffb000", lw=2, ls="--")
ax1.set_title("Mapa: sloupce s pásmem největšího tělesa\n(tmavě modrá = jedno těleso, %d z %d sloupců)" % (d["bodies"][0]["sloupcu"], d["land"]), fontsize=10)
ax1.set_xlabel("x (sloupec ostrova)"); ax1.set_ylabel("y (sloupec ostrova)")
for (tx, ty, t) in [(1, 1, "louka 101"), (17, 1, "hora 202"), (1, 17, "kopec 303"), (17, 17, "louka 404")]:
    ax1.text(tx, ty, t, fontsize=9, color="white", weight="bold")

# barvy materiálů řezu
rng = np.random.default_rng(3)
cols = {}
def col(m):
    if m not in cols:
        cols[m] = rng.uniform(0.25, 0.95, 3)
    return cols[m]
fixed = {1: (0.45, 0.75, 0.3), 2: (0.55, 0.4, 0.25), 52: (0.93, 0.83, 0.55), 5: (0.75, 0.78, 0.85), 44: (0.6, 0.65, 0.75),
         3: (0.85, 0.7, 0.45), 49: (0.8, 0.8, 0.7), 54: (0.9, 0.8, 0.6), 6: (0.6, 0.55, 0.6), 4: (0.6, 0.5, 0.45), 51: (0.4, 0.4, 0.45)}
cols.update({k: np.array(v) for k, v in fixed.items()})

axes = [fig.add_axes([0.36, 0.50, 0.62, 0.34]), fig.add_axes([0.36, 0.07, 0.62, 0.34])]
used = {}
for ax, (yl, rez) in zip(axes, d["rezy"].items()):
    for gx, c in enumerate(rez):
        if c["wall"]:
            continue
        x = gx - ox
        for lo, hi, m, body, big in c["b"]:
            ax.add_patch(Rectangle((x, lo), 1, hi - lo, facecolor=col(m), edgecolor="none"))
            if big:
                ax.add_patch(Rectangle((x, lo), 1, hi - lo, facecolor="none", edgecolor="#1f5fa8", hatch="////", lw=0))
            used[m] = used.get(m, 0) + (hi - lo)
    for k in range(0, 33, 16):
        ax.axvline(k, color="k", lw=0.8)
    ax.set_xlim(-0.5, 32.5); ax.set_ylim(0, 33)
    ax.set_ylabel("výška (m)")
    ax.set_title("Řez y = %d (šrafováno = pásma největšího tělesa; svislé čáry = švy bloků)" % (int(yl) - oy), fontsize=10)
axes[1].set_xlabel("x (sloupec ostrova)")

ax3 = fig.add_axes([0.03, 0.04, 0.28, 0.32]); ax3.axis("off")
top = sorted(used.items(), key=lambda e: -e[1])[:14]
y = 1.0
ax3.text(0, y, "Materiály v řezech (id, jméno, perm; těleso = perm ≥ 0,30 nebo kras)", fontsize=9, weight="bold"); y -= 0.08
for m, _ in top:
    ax3.add_patch(Rectangle((0, y - 0.03), 0.05, 0.05, facecolor=col(m), transform=ax3.transAxes))
    p = perm.get(m, 0.0)
    ax3.text(0.07, y - 0.02, "%d %s  perm %.2f%s" % (m, names.get(m, "?"), p, "  → těleso" if (p >= 0.3 or m in (5, 44, 49, 48, 56)) else ""), fontsize=8)
    y -= 0.065
fig.suptitle("Proč je pod ostrovem jedno velké podzemní těleso: souvislé propustné vrstvy (křemenný pískovec 52, jeskynní vápenec 5, hlubinný vápenec 44)\n"
             "procházejí všemi 4 bloky (navázání mocností přes švy) a půda + tráva je spojí shora – stejně jako ve studii svet64 (1 těleso přes 16358 z 16384 sloupců)", fontsize=12, y=0.985)
out = os.path.join(D, "../../blueprint-studie/shots/66b_teleso.png")
fig.savefig(out, dpi=90)
print("uloženo", os.path.normpath(out))
