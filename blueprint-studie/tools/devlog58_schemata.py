#!/usr/bin/env python3
"""Schémata pro devlog (voda-algoritmy.md): kreslené matplotlibem, bez měření. → ../devlog/img/va_*.png"""
import os, numpy as np, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyArrowPatch, Circle
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "devlog", "img")
os.makedirs(OUT, exist_ok=True)
MC = {"tráva": "#6a3", "hlína": "#a7764a", "písek": "#e3c770", "jíl": "#9a8c7a", "vápenec": "#cfcab8", "žula": "#8b8b93", "dutina": "#ffffff"}

def save(f, n): f.tight_layout(); f.savefig(f"{OUT}/{n}", dpi=110); plt.close(f)

# 1) data: řídicí mřížka a pásma sloupce
f, ax = plt.subplots(1, 2, figsize=(11, 4.6))
a = ax[0]
for x in range(8):
    for y in range(8): a.add_patch(Rectangle((x, y), 1, 1, fc="#eef", ec="#99a"))
a.add_patch(Rectangle((3, 4), 1, 1, fc="#fc8", ec="k", lw=2))
a.set_xlim(0, 8); a.set_ylim(0, 8); a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
a.set_title("řídicí mřížka 0,5 m: 16 × 16 bodů na blok 8 m\n(hm_f = povrch, bs[k] = hranice vrstev)", fontsize=9)
a = ax[1]
cols = [[(0, 2, "žula"), (2, 3.5, "jíl"), (3.5, 6, "písek"), (6, 6.6, "hlína"), (6.6, 7, "tráva")],
        [(0, 2.2, "žula"), (2.2, 3.4, "jíl"), (3.4, 4.0, "písek"), (4.0, 4.6, "dutina"), (4.6, 6.2, "písek"), (6.2, 6.8, "hlína"), (6.8, 7.1, "tráva")],
        [(0, 2.5, "žula"), (2.5, 3.2, "vápenec"), (3.2, 5.7, "písek"), (5.7, 6.4, "hlína"), (6.4, 6.7, "tráva")]]
for i, c in enumerate(cols):
    for lo, hi, m in c:
        a.add_patch(Rectangle((i * 1.3, lo), 1, hi - lo, fc=MC[m], ec="k", lw=0.6))
        if hi - lo > 0.5: a.text(i * 1.3 + 0.5, (lo + hi) / 2, m, ha="center", va="center", fontsize=7)
a.annotate("pásmo [lo, hi) + materiál\n(propustné → těleso)", (1.8, 5.2), (4.2, 6.5), fontsize=8, arrowprops=dict(arrowstyle="->"))
a.annotate("překryv v z → hrana\nmezi sousedními sloupci", (1.25, 4.8), (4.2, 3.6), fontsize=8, arrowprops=dict(arrowstyle="->"))
a.set_xlim(-0.2, 6.5); a.set_ylim(0, 7.5); a.set_xticks([]); a.set_ylabel("z (m)")
a.set_title("sloupec = zásobník pásem (CSR: cs[sloupec] → pásma)", fontsize=9)
save(f, "va_data.png")

# 2) režimy nadrz / preliv / auto
f, ax = plt.subplots(1, 3, figsize=(12, 3.8))
x = np.linspace(0, 10, 200)
top = 6 + 0.6 * np.sin(x / 1.6); bot = 2 + 0.8 * np.cos(x / 2.0) - 0.05 * x
for a, t, mode in zip(ax, ["nadrz: celé těleso = jedna nádrž", "preliv: hladina od nejnižšího místa\npo nejnižší výchoz → pramen", "auto: podle dna (E55)"], [0, 1, 2]):
    a.fill_between(x, 0, bot, color=MC["jíl"] if mode != 0 else MC["vápenec"]); a.fill_between(x, bot, top, color=MC["písek"]); a.fill_between(x, top, top + 0.5, color=MC["tráva"])
    if mode == 0:
        a.fill_between(x, bot, np.minimum(top, 4.2), color="#39f", alpha=.6)
        for xx in [2, 5, 8]: a.annotate("", (xx, 0.3), (xx, 1.6), arrowprops=dict(arrowstyle="->", color="b"))
        a.text(5, 0.6, "průsak dnem i boky", ha="center", fontsize=8, color="b")
    elif mode == 1:
        L = 3.0; a.fill_between(x, bot, np.minimum(top, L), where=bot < L, color="#39f", alpha=.6)
        a.annotate("pramen", (10, L), (7.5, 5.5), fontsize=8, arrowprops=dict(arrowstyle="->"))
    else:
        a.fill_between(x[:100], 0, bot[:100], color=MC["písek"]); L = 3.2
        a.fill_between(x, bot, np.minimum(top, L), where=bot < L, color="#39f", alpha=.6)
        a.text(2.5, 0.6, "propustné dno\n→ průsak", ha="center", fontsize=8); a.text(7.5, 0.6, "jíl → zbytek\nvýstupem", ha="center", fontsize=8)
    a.set_title(t, fontsize=9); a.set_xticks([]); a.set_yticks([]); a.set_ylim(0, 7)
save(f, "va_rezimy.png")

# 3) halda vs kbelíky
f, ax = plt.subplots(1, 2, figsize=(11, 3.8))
a = ax[0]
pos = {0: (4, 3), 1: (2, 2), 2: (6, 2), 3: (1, 1), 4: (3, 1), 5: (5, 1), 6: (7, 1)}
vals = [1.0, 1.25, 1.5, 2.0, 1.75, 3.0, 2.5]
for k, (px, py) in pos.items():
    if k: pa = (k - 1) // 2; a.plot([px, pos[pa][0]], [py, pos[pa][1]], "k-", lw=.8)
for k, (px, py) in pos.items():
    a.add_patch(Circle((px, py), .38, fc="#fd8", ec="k")); a.text(px, py, f"{vals[k]:.2f}", ha="center", va="center", fontsize=8)
a.set_xlim(0, 8); a.set_ylim(0.3, 3.7); a.set_aspect("equal"); a.axis("off")
a.set_title("halda: každé vložení / výběr O(log N)", fontsize=9)
a = ax[1]
for b in range(6):
    a.add_patch(Rectangle((b * 1.2, 0), 1, 3, fc="#eef" if b != 1 else "#fd8", ec="k"))
    a.text(b * 1.2 + .5, -0.3, f"[{b * .0625:.3f}, {(b + 1) * .0625:.3f})", ha="center", fontsize=6)
    for j in range([2, 4, 1, 0, 3, 2][b]): a.add_patch(Rectangle((b * 1.2 + .15, .2 + j * .55), .7, .4, fc="#9cf", ec="k", lw=.5))
a.text(1.7, 3.3, "aktuální kbelík = malá halda", ha="center", fontsize=8)
a.set_xlim(-0.3, 7.3); a.set_ylim(-0.6, 3.7); a.axis("off")
a.set_title("kbelíky po hladinách dz: vložení O(1), halda jen uvnitř kbelíku", fontsize=9)
save(f, "va_kbeliky.png")

# 4) graf těles (B) a stopa (C)
f, ax = plt.subplots(1, 2, figsize=(11, 4.2))
a = ax[0]
rng = np.random.default_rng(3)
nodes = {"T1": (2, 3, 300), "T2": (5, 4, 60), "T3": (6.5, 1.5, 40)}
for k, (px, py, s) in nodes.items():
    a.add_patch(Circle((px, py), .25 + s / 400, fc="#9cf", ec="k")); a.text(px, py, k, ha="center", va="center", fontsize=9)
for (u, v) in [("T1", "pramen A"), ("T2", "okraj"), ("T3", "pramen B")]:
    pass
outs = {"pramen A": (3.8, 0.6), "okraj": (7.6, 4.2), "pramen B": (7.8, 0.4)}
for k, (px, py) in outs.items(): a.add_patch(Rectangle((px - .45, py - .2), .9, .4, fc="#cfc", ec="k")); a.text(px, py, k, ha="center", va="center", fontsize=7)
for u, v in [("T1", "pramen A"), ("T2", "okraj"), ("T3", "pramen B")]:
    a.add_patch(FancyArrowPatch(nodes[u][:2], outs[v], arrowstyle="->", mutation_scale=12))
a.text(0.2, 4.8, "uzel = těleso: Σ průsak, kandidáti výstupu (z, sloupec),\nplocha dna podle materiálu, objem po hladině", fontsize=8)
a.set_xlim(0, 8.5); a.set_ylim(0, 5.5); a.set_aspect("equal"); a.axis("off"); a.set_title("B: graf těles (stovky uzlů místo 312 tis. pásem)", fontsize=9)
a = ax[1]
g = np.zeros((16, 16)); g[3:12, 2:10] = 1; g[2:13, 1:11] = np.maximum(g[2:13, 1:11], 0.5)
a.imshow(g.T, origin="lower", cmap="Blues", vmin=0, vmax=1.3)
a.plot([13], [12], "r*", ms=14); a.plot([6], [6], "k*", ms=14)
a.text(13, 13.3, "výkop mimo stopu\n→ beze změny", ha="center", fontsize=8, color="r")
a.text(6, 7.2, "výkop ve stopě\n→ delta souhrnů", ha="center", fontsize=8)
a.set_xticks([]); a.set_yticks([]); a.set_title("C: stopa volání = sloupce navštívených pásem + sousedé", fontsize=9)
save(f, "va_graf_stopa.png")

# 5) povrch: D8 + priority-flood
f, ax = plt.subplots(1, 2, figsize=(11, 3.8))
x = np.linspace(0, 10, 60); h = 3 + np.sin(x) * 1.2 + 0.15 * x
x = np.linspace(0, 10, 200); h = 3 + np.sin(x * 1.3) * 1.2 + 0.25 * x - 0.03 * x * x
fl = np.array([max(h[i], min(h[:i + 1].max(), h[i:].max())) for i in range(len(h))])
a = ax[0]; a.fill_between(x, 0, h, color=MC["hlína"]); a.fill_between(x, h, fl, color="#39f", alpha=.6)
a.annotate("odtok přes okraj ostrova", (10, h[-1]), (7, 1.2), fontsize=8, arrowprops=dict(arrowstyle="->"))
a.set_title("priority-flood: fill = nejnižší přeliv k okraji (+ ε spád)\nmodře tůně v prohlubních", fontsize=9); a.set_xticks([]); a.set_yticks([])
a = ax[1]
for i in range(5):
    for j in range(5): a.add_patch(Rectangle((i, j), 1, 1, fc="#eef", ec="#99a"))
a.add_patch(Rectangle((2, 2), 1, 1, fc="#fc8", ec="k"))
for d, (dx, dy) in enumerate([(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]):
    a.annotate("", (2.5 + dx * .9, 2.5 + dy * .9), (2.5, 2.5), arrowprops=dict(arrowstyle="->", color="r" if d == 4 else "#777", lw=2 if d == 4 else .8))
a.text(2.5, -.5, "D8: tok do souseda s největším spádem (fill_i − fill_j) / vzdálenost", ha="center", fontsize=8)
a.set_xlim(0, 5); a.set_ylim(-1, 5); a.set_aspect("equal"); a.axis("off"); a.set_title("D8 směr toku", fontsize=9)
save(f, "va_povrch.png")
print("ok")
