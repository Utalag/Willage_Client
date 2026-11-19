#!/usr/bin/env python3
"""E63 graf: podzemí, výkop průměr / max podle varianty a mapy (log), zátěž serveru za podzemí."""
import json, os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
D = os.path.join(os.path.dirname(__file__), "..", "shots")
V = [("base", "base"), ("ApBpC", "A+B+C"), ("ApBpCpD", "+D (E62)"), ("ApBpCpDpE", "+E sestup bez volání"), ("ApBpCpDpEpI", "+E+I lokální oprava")]
C = ["#7f7f7f", "#c0504d", "#f79646", "#9bbb59", "#4f81bd"]
fig, ax = plt.subplots(1, 2, figsize=(13, 4.6))
rows = []
for k, (f, lab) in enumerate(V):
    av = []; mx = []
    for s in (16, 32, 64):
        d = json.load(open(os.path.join(D, "alg58", f"ug_{f}_s{s}_u16_e61.json")))
        av.append(d["edit_avg"]); mx.append(d["edit_max"]); assert d["mismatch"] == 0
    rows.append((lab, av, mx))
    x = [i + (k - 2) * 0.16 for i in range(3)]
    ax[0].bar(x, av, 0.16, color=C[k], label=lab)
    ax[0].plot(x, mx, "v", color=C[k])
    for xi, a in zip(x, av): ax[0].text(xi, a, f"{a:.0f}", ha="center", va="bottom", fontsize=7)
ax[0].set_yscale("log"); ax[0].set_xticks(range(3)); ax[0].set_xticklabels(["s16", "s32", "s64"])
ax[0].set_ylabel("ms na výkop (sloupec průměr, ▼ max)"); ax[0].set_title("Podzemí po výkopu, 20 výkopů, 0 neshod"); ax[0].set_ylim(50, 60000); ax[0].legend(fontsize=7, loc="upper right", ncol=2)
L = [("50 × 20/min", 1000), ("50 × 4/min", 200), ("10 × 4/min", 40)]
for k, (lab, av, mx) in enumerate(rows):
    x = [i + (k - 2) * 0.16 for i in range(3)]
    y = [n * 0.05 * av[2] / 60000 * 100 for _, n in L]
    ax[1].bar(x, y, 0.16, color=C[k], label=lab)
    for xi, a in zip(x, y): ax[1].text(xi, a, f"{a:.1f}", ha="center", va="bottom", fontsize=7)
ax[1].axhline(100, color="k", lw=0.8, ls="--"); ax[1].set_yscale("log")
ax[1].set_xticks(range(3)); ax[1].set_xticklabels([l for l, _ in L]); ax[1].set_ylabel("% jednoho jádra (s64, 5 % výkopů do podzemí)")
ax[1].set_title("Zátěž serveru jen za podzemí"); ax[1].set_ylim(0.1, 5000); ax[1].legend(fontsize=7, loc="upper right", ncol=2)
plt.tight_layout(); plt.savefig(os.path.join(D, "63_podzemi.png"), dpi=110)
for lab, av, mx in rows: print(lab, [f"{a:.0f}/{m:.0f}" for a, m in zip(av, mx)], [f"{n*0.05*av[2]/600:.1f}%" for _, n in L])
