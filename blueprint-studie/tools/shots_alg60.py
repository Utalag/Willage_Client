#!/usr/bin/env python3
"""E60 grafy: povrch lokální přepočet (tok.update vs tok60) po fázích a podle mapy; graf pánví vs PF bez ε."""
import json, os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
D = os.path.join(os.path.dirname(__file__), "..", "shots")
def J(n): return json.load(open(os.path.join(D, "alg60", n)))
fig, ax = plt.subplots(1, 3, figsize=(15, 4.6))
# 1) fáze 512²
pr = J("tok_prof_s64_m0_ff.json") if os.path.exists(os.path.join(D, "alg60", "tok_prof_s64_m0_ff.json")) else J("tok_prof_s64.json")
fa = J("tok_fast_s64_m0_ff.json")
ks = ["flood", "d8_okno", "po_proudu", "odtoky"]; lab = ["okno + flood", "D8 + průtok v okně", "po proudu", "odtoky tůní + tůně"]
x = range(len(ks))
ax[0].bar([i - 0.2 for i in x], [pr["phases"].get(k, 0) for k in ks], 0.4, label="tok.update (E58 C+A)", color="#c0504d")
ax[0].bar([i + 0.2 for i in x], [fa["phases"].get(k, 0) for k in ks], 0.4, label="tok60 (E60)", color="#4f81bd")
ax[0].set_xticks(list(x)); ax[0].set_xticklabels(lab, rotation=15, fontsize=8); ax[0].set_ylabel("ms na výkop (průměr)")
ax[0].set_title("512²: kde se tráví čas"); ax[0].legend(fontsize=8)
# 2) podle mapy
W = []; r = []; n = []; rm = []; nm = []
for s in (16, 32, 64):
    d = J(f"tok_fast_s{s}_m0_ff.json"); W.append(f"{d['W']}²"); r.append(d["ref_avg"]); n.append(d["new_avg"]); rm.append(d["ref_max"]); nm.append(d["new_max"])
x = range(3)
ax[1].bar([i - 0.2 for i in x], r, 0.4, color="#c0504d", label="tok.update průměr")
ax[1].bar([i + 0.2 for i in x], n, 0.4, color="#4f81bd", label="tok60 průměr")
ax[1].plot([i - 0.2 for i in x], rm, "v", color="#7f2020", label="max"); ax[1].plot([i + 0.2 for i in x], nm, "v", color="#1f3f7f")
for i in x: ax[1].text(i + 0.2, n[i], f"{n[i]:.1f}", ha="center", va="bottom", fontsize=8); ax[1].text(i - 0.2, r[i], f"{r[i]:.1f}", ha="center", va="bottom", fontsize=8)
ax[1].set_xticks(list(x)); ax[1].set_xticklabels(W); ax[1].set_ylabel("ms na výkop"); ax[1].set_title("Lokální přepočet po výkopu (bit po bitu stejné)"); ax[1].legend(fontsize=8)
# 3) B vs PF
lab = []; a = []; b = []; c = []
for s in (16, 32, 64):
    d = J(f"b_s{s}.json"); lab.append(f"{d['W']}²"); a.append(d["lake_pf0"]); b.append(d["lake_B"]); c.append(d["lake_eps"])
x = range(3)
ax[2].bar([i - 0.27 for i in x], a, 0.27, label="PF bez ε", color="#9bbb59")
ax[2].bar([i for i in x], b, 0.27, label="graf pánví B", color="#4f81bd")
ax[2].bar([i + 0.27 for i in x], c, 0.27, label="tok.gd (ε = 1e-3)", color="#c0504d")
ax[2].set_yscale("log"); ax[2].set_xticks(list(x)); ax[2].set_xticklabels(lab); ax[2].set_ylabel("buněk tůní (fill > hm + 0,01)")
ax[2].set_title("B = PF bez ε přesně (0 rozdílných buněk)"); ax[2].legend(fontsize=8)
plt.tight_layout(); plt.savefig(os.path.join(D, "60_povrch.png"), dpi=110)
print("ok")
