#!/usr/bin/env python3
"""E58 grafy: shots/58_podzemi.png (varianty a kombinace), 58_povrch.png (route / A / B, výkop C / C+A), 58_server.png (zátěž serveru E57 znovu)."""
import json, os, matplotlib
matplotlib.use("Agg"); import matplotlib.pyplot as plt
D = os.path.join(os.path.dirname(__file__), "..", "shots"); A = f"{D}/alg58"
V = ["base", "A", "B", "C", "A+B", "A+C", "B+C", "A+B+C"]
u = {v: json.load(open(f"{A}/ug_{v.replace('+', 'p')}_s64_u16.json")) for v in V if os.path.exists(f"{A}/ug_{v.replace('+', 'p')}_s64_u16.json")}
f, ax = plt.subplots(1, 3, figsize=(14, 4.4))
vs = [v for v in V if v in u]
cols = ["#888" if v == "base" else ("#2a7" if v in ("B+C", "A+B+C") else "#59c") for v in vs]
ax[0].bar(vs, [u[v]["full_ms"] for v in vs], color=cols); ax[0].set_title("plné řešení všech volání (ms)", fontsize=10)
ax[1].bar(vs, [u[v]["edit_avg"] for v in vs], color=cols); ax[1].set_yscale("log"); ax[1].set_title("výkop 1 m: průměr (ms, log)", fontsize=10)
for i, v in enumerate(vs): ax[1].text(i, u[v]["edit_avg"] * 1.15, f"{u[v]['edit_avg']:.1f}", ha="center", fontsize=8)
ax[2].bar(vs, [u[v]["extra_mb"] for v in vs], color=cols); ax[2].set_title("paměť struktur navíc (MB)", fontsize=10)
for a in ax: a.tick_params(axis="x", rotation=45, labelsize=8)
f.suptitle("E58 podzemí (svět E52, povrch 64 / blok, 312 tis. pásem, 20 výkopů) — všechny varianty 0 neshod s plným řešením", fontsize=10)
f.tight_layout(); f.savefig(f"{D}/58_podzemi.png", dpi=110)
t = {nv: json.load(open(f"{A}/tok_s{nv}.json")) for nv in (16, 32, 64) if os.path.exists(f"{A}/tok_s{nv}.json")}
if t:
    f, ax = plt.subplots(1, 2, figsize=(12, 4.2))
    xs = [f"{t[k]['W']}²" for k in t]; import numpy as np; x = np.arange(len(xs)); w = 0.25
    ax[0].bar(x - w, [t[k]["route_ms"] for k in t], w, label="route (halda)", color="#888")
    ax[0].bar(x, [t[k]["route_A_ms"] for k in t], w, label="route A (kbelíky)", color="#59c")
    ax[0].bar(x + w, [t[k]["B_ms"] for k in t], w, label="B graf pánví (jen fill, nepřesné)", color="#c95")
    ax[0].set_xticks(x, xs); ax[0].set_yscale("log"); ax[0].legend(fontsize=8); ax[0].set_title("plný výpočet povrchu (ms, log)", fontsize=10)
    ax[1].bar(x - w, [t[k]["route_after_ms"] for k in t], w, label="bez C: plný route", color="#888")
    ax[1].bar(x, [t[k]["edit_C"]["avg"] for k in t], w, label="C: update (E51b)", color="#2a7")
    ax[1].bar(x + w, [t[k]["edit_CA"]["avg"] for k in t], w, label="C + A", color="#59c")
    ax[1].set_xticks(x, xs); ax[1].set_yscale("log"); ax[1].legend(fontsize=8); ax[1].set_title("výkop u vody (ms, log)", fontsize=10)
    f.suptitle("E58 povrch (svet64 při 16 / 32 / 64 na blok)", fontsize=10); f.tight_layout(); f.savefig(f"{D}/58_povrch.png", dpi=110)
# server: 50 hráčů, úpravy/min, 5 % do podzemí
f, ax = plt.subplots(figsize=(7.5, 4.2))
rates = [4, 20]; surf = {k: t[k]["edit_CA"]["avg"] for k in t}
s512 = surf.get(64, 2.6)
for v, c in [("base", "#888"), ("A+B+C", "#2a7")]:
    if v not in u: continue
    ug_ms = u[v]["edit_avg"]
    ys = [50 * r * (0.95 * s512 + 0.05 * (ug_ms + s512)) / 60000 * 100 for r in rates]
    ax.plot(rates, ys, "o-", color=c, label=f"{v}: podzemí {ug_ms:.1f} ms / výkop")
ax.axhline(100, color="r", ls="--", lw=1); ax.text(4.2, 103, "1 jádro", color="r", fontsize=8)
ax.set_xlabel("úprav za minutu na hráče (50 hráčů)"); ax.set_ylabel("% jednoho jádra"); ax.set_yscale("log")
ax.set_title(f"E58 zátěž serveru: povrch 512² ({s512:.0f} ms / výkop) + 5 % výkopů do podzemí", fontsize=9); ax.legend(fontsize=8)
f.tight_layout(); f.savefig(f"{D}/58_server.png", dpi=110)
print("ok")
