#!/usr/bin/env python3
"""E64 graf a tabulka: podzemí po výkopu, varianty K / I / R / V / P proti E63 (+E+I). Čte shots/e64/*.json, píše shots/64_podzemi.png."""
import json, os, sys
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
B = os.path.join(os.path.dirname(__file__), "..", "shots")
def e63(s):
    d = json.load(open(os.path.join(B, "alg58", f"ug_ApBpCpDpEpI_s{s}_u16_e61.json")))
    a = sorted(d["edit_ms"]); return {"edit_avg": d["edit_avg"], "edit_p95": a[-2], "edit_max": d["edit_max"], "step": d["edit_max"], "steps": 1, "vis": None, "mm": d["mismatch"], "mb": d["extra_mb"], "ms13": d["edit_ms"][12]}
def e64(f, s, tag=""):
    d = json.load(open(os.path.join(B, "e64", f"ug_{f}_s{s}{tag}.json")))
    return {"edit_avg": d["edit_avg"], "edit_p95": d["edit_p95"], "edit_max": d["edit_max"], "step": max(d["step_max_ms"]), "steps": max(d["steps"]),
            "vis": sum(d["visited"]) / len(d["visited"]), "mm": d["mismatch"], "mmo": d["mismatch_old"], "mb": d["state_mb"], "ms13": d["edit_ms"][12], "full": d["full_ms"]}
V = [("E63 +E+I", None), ("K (plný sestup)", "ApBpCpDpK"), ("K+I", "ApBpCpDpKpI"), ("K+I+V", "ApBpCpDpKpIpV"), ("K+I+R", "ApBpCpDpKpIpR"),
     ("K+I+R+V", "ApBpCpDpKpIpRpV"), ("K+I+P", "ApBpCpDpKpIpP"), ("K+I+P+R", "ApBpCpDpKpIpPpR"), ("K+I+P+R+V", "ApBpCpDpKpIpPpRpV")]
rows = {}
for lab, f in V:
    rows[lab] = {s: (e63(s) if f is None else e64(f, s)) for s in (16, 32, 64)}
bud = {}
for b in (2000, 5000, 10000):
    for s in (16, 32, 64):
        tag = "" if b == 5000 else f"_b{b}"
        p = os.path.join(B, "e64", f"ug_ApBpCpDpKpIpPpR_s{s}{tag}.json")
        if os.path.exists(p): bud[(b, s)] = e64("ApBpCpDpKpIpPpR", s, tag)
# tabulka (markdown) na stdout
print("| varianta | s16 prům / p95 / max | s32 | s64 | max krok s64 | kroků max s64 | navštíveno s64 | neshod | stav MB s64 |")
print("|---|---|---|---|---|---|---|---|---|")
f1 = lambda x: f"{x:.0f}" if x >= 10 else f"{x:.1f}"
for lab in rows:
    r = rows[lab]
    cell = lambda s: f"{f1(r[s]['edit_avg'])} / {f1(r[s]['edit_p95'])} / {f1(r[s]['edit_max'])}"
    vis = "–" if r[64]["vis"] is None else f"{r[64]['vis']:.0f}"
    mm = sum(r[s]["mm"] for s in (16, 32, 64))
    print(f"| {lab} | {cell(16)} | {cell(32)} | {cell(64)} | {f1(r[64]['step'])} | {r[64]['steps']} | {vis} | {mm} | {r[64]['mb']:.1f} |")
print()
print("| rozpočet R (K+I+P+R) | mapa | max krok ms | kroků max | průměr ms | max výkop ms (součet kroků) |")
print("|---|---|---|---|---|---|")
for (b, s), r in sorted(bud.items()):
    print(f"| {b} | s{s} | {f1(r['step'])} | {r['steps']} | {f1(r['edit_avg'])} | {f1(r['edit_max'])} |")
print()
print("E63 nejhorší výkop (s32 #13):", {lab: round(rows[lab][32]["ms13"], 1) for lab in rows})
L = [("50 × 20/min", 1000), ("50 × 4/min", 200), ("10 × 4/min", 40)]
print("server (s64, 5 % výkopů do podzemí, % jádra):")
for lab in rows:
    print(lab, [round(n * 0.05 * rows[lab][64]["edit_avg"] / 60000 * 100, 2) for _, n in L])
# graf
sel = ["E63 +E+I", "K+I", "K+I+V", "K+I+R", "K+I+P", "K+I+P+R"]
C = ["#7f7f7f", "#4f81bd", "#8064a2", "#f79646", "#9bbb59", "#c0504d"]
fig, ax = plt.subplots(1, 3, figsize=(17, 4.8))
w = 0.13
for k, lab in enumerate(sel):
    x = [i + (k - 2.5) * w for i in range(3)]
    av = [rows[lab][s]["edit_avg"] for s in (16, 32, 64)]; mx = [rows[lab][s]["edit_max"] for s in (16, 32, 64)]
    st = [rows[lab][s]["step"] for s in (16, 32, 64)]
    ax[0].bar(x, av, w, color=C[k], label=lab); ax[0].plot(x, mx, "v", color=C[k])
    if "R" in lab: ax[0].plot(x, st, "_", color="k", ms=10, mew=2)
    for xi, a in zip(x, av): ax[0].text(xi, a, f"{a:.0f}", ha="center", va="bottom", fontsize=7)
ax[0].set_yscale("log"); ax[0].set_xticks(range(3)); ax[0].set_xticklabels(["s16", "s32", "s64"]); ax[0].set_ylim(5, 2000)
ax[0].set_ylabel("ms na výkop (sloupec průměr, ▼ max, — max krok R)"); ax[0].set_title("E64 podzemí po výkopu, 3 × 20 výkopů, 0 neshod")
ax[0].legend(fontsize=7, ncol=2, loc="upper left")
bs = [2000, 5000, 10000]
for s, col in ((16, "#4f81bd"), (64, "#c0504d")):
    ax[1].plot(bs, [bud[(b, s)]["step"] for b in bs], "o-", color=col, label=f"max krok s{s}")
    ax[1].plot(bs, [bud[(b, s)]["steps"] for b in bs], "s--", color=col, alpha=0.6, label=f"kroků nejhoršího výkopu s{s}")
ax[1].set_xscale("log"); ax[1].set_yscale("log"); ax[1].set_xticks(bs); ax[1].set_xticklabels(["2k", "5k", "10k"])
ax[1].set_xlabel("rozpočet R (operací na krok)"); ax[1].set_title("R: rozložení nejhoršího výkopu (K+I+P+R)"); ax[1].legend(fontsize=7)
for k, lab in enumerate(sel):
    x = [i + (k - 2.5) * w for i in range(3)]
    y = [n * 0.05 * rows[lab][64]["edit_avg"] / 60000 * 100 for _, n in L]
    ax[2].bar(x, y, w, color=C[k], label=lab)
    for xi, a in zip(x, y): ax[2].text(xi, a, f"{a:.2f}" if a < 1 else f"{a:.1f}", ha="center", va="bottom", fontsize=6)
ax[2].set_yscale("log"); ax[2].set_xticks(range(3)); ax[2].set_xticklabels([l for l, _ in L]); ax[2].set_ylabel("% jednoho jádra (s64, 5 % výkopů do podzemí)")
ax[2].set_title("Zátěž serveru jen za podzemí")
from matplotlib.ticker import FuncFormatter
for a in ax: a.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}".replace(".", ",")))
ax[1].yaxis.set_minor_formatter(FuncFormatter(lambda v, _: ""))
ax[2].yaxis.set_minor_formatter(FuncFormatter(lambda v, _: ""))
plt.tight_layout(); plt.savefig(os.path.join(B, "64_podzemi.png"), dpi=110)
print("→ shots/64_podzemi.png")
