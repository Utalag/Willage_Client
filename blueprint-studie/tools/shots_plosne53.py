#!/usr/bin/env python3
"""E53 snímky: 53_rozliv.png (pravidlo rozlévání, numpy kopie tools/plosne53_roz.py = stejné pravidlo jako rozliv.gd),
53_srovnani.png (čas na průchod GDScript vs numpy, tok.gd) z shots/bench_plosne53_n64.json a bench_plosne53_numpy.json"""
import json, sys, numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
sys.path.insert(0, "tools"); from plosne53_roz import run
W, H = 50, 41
x = np.arange(W)[:, None] * np.ones((1, H)); z = 10 - 0.3 * x
k = np.where(x < 25, 0.5, 0.25); src = np.zeros((W, H)); src[2, 20] = 4.0; wall = np.zeros((W, H), int)
q1, _, it1 = run(z, k, src, wall)
z2 = z.copy(); z2[25:, :14] += 1; z2[25:, 26:] += 1
q2, l2, it2 = run(z2, k, src, wall, passes=3000)
fig, ax = plt.subplots(1, 2, figsize=(12, 5))
for a, q, t in ((ax[0], q1, "přítok 4: písek k 0,5 → 8 buněk, od x=25 k 0,25 → 16 (%d průchodů)" % it1),
                (ax[1], q2, "od x=25 koryto 12 buněk mezi břehy +1: hromadění, přeliv přes břehy")):
    im = a.imshow(q.T, origin="lower", cmap="Blues", vmin=0, vmax=1.0); a.axvline(24.5, color="#c60", lw=1); a.set_title(t, fontsize=9); a.set_xlabel("x (po spádu)")
    for xx in (15, 40): a.text(xx, 1, "%d buněk" % int((q[xx] > 1e-9).sum()), color="#a30", fontsize=9, ha="center")
fig.colorbar(im, ax=ax, label="průtok buňkou (jednotky přítoku)", shrink=0.8)
fig.suptitle("E53 pravidlo rozlévání: šířka = ceil(Q / propustnost), celé buňky"); fig.savefig("shots/53_rozliv.png", dpi=90)
b = json.load(open("shots/bench_plosne53_n64.json")); npj = json.load(open("shots/bench_plosne53_numpy.json"))
fig, ax = plt.subplots(figsize=(9, 4.5))
lab = ["tok.gd celý route", "tok.gd lokální změna", "rozlévání 1 průchod GDScript", "rozlévání 1 průchod numpy", "mělká voda 1 krok GDScript", "mělká voda 1 krok numpy"]
val = [b["tok_ms"], b["loc"]["tok_ms"], b["rz_warm"]["ms_pass"], npj["64"]["rozliv_ms_pruchod"], b["sw_warm"]["ms_step"], npj["64"]["mvoda_ms_krok"]]
ax.barh(lab, val, color=["#888", "#888", "#58b", "#8bd", "#5a5", "#9d9"]); ax.set_xscale("log"); ax.invert_yaxis(); ax.set_xlabel("ms (log), mapa 64²")
for i, v in enumerate(val): ax.text(v * 1.1, i, "%.2f ms" % v, va="center", fontsize=8)
ax.set_title("E53: jeden průchod je levný, ale do ustálení jich je tisíce (tok.gd 1 průchod frontou)", fontsize=10)
fig.tight_layout(); fig.savefig("shots/53_srovnani.png", dpi=90)
print("shots/53_rozliv.png shots/53_srovnani.png")
