#!/usr/bin/env python3
"""E55 snímek: shots/55_prameny_prusak.png – dno těles (propustné / nepropustné), výstupy pramenů, průsak vs pramen při 16/32/64"""
import json, numpy as np
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
D = "shots/podzemi52/funkce_auto_s64_dut%d_pd0.05.json"
d = json.load(open(D % 64)); c = d["ctrl"]; W, H = c["W"], c["H"]
h = np.array(c["h"]).reshape(W, H)
fig, ax = plt.subplots(1, 2, figsize=(14, 6.3), gridspec_kw={"width_ratios": [1.25, 1]})
a = ax[0]
a.imshow(h.T, origin="lower", cmap="gray", extent=[0, W * c["side"], 0, H * c["side"]])
cls = np.zeros((W, H))
for b in d["bodies"]:
    for key, v in (("cols_nep", 1), ("cols_prop", 2)):
        for cc in b["dno"].get(key, []): cls[cc // H, cc % H] = max(cls[cc // H, cc % H], v)
from matplotlib.colors import ListedColormap
from matplotlib.patches import Patch
ov = np.ma.masked_where(cls == 0, cls)
a.imshow(ov.T, origin="lower", cmap=ListedColormap(["#c8742a", "#22cc99"]), vmin=1, vmax=2, alpha=0.75, extent=[0, W * c["side"], 0, H * c["side"]])
hand = [Patch(color="#c8742a", label="dno nepropustné (perm ≤ 0,05) → plnění, přeliv"), Patch(color="#22cc99", label="dno propustné → průsak")]
for b in d["bodies"]:
    if b["out_col"] >= 0 and b["out_q"] > 0:
        Ws, cm = d["surf"]["W"], d["surf"]["cm"]
        a.scatter([(b["out_col"] // Ws + 0.5) * cm], [(b["out_col"] % Ws + 0.5) * cm], s=180, marker="*", c="#18f", edgecolor="w", zorder=5,
                  label="výtok %s %.2f l/s" % ("ve stěně ostrova" if b["typ"] == "okraj" else "pramen", b["out_q"]))
a.set_title("E55 dno tělesa: %s; průsak %.2f l/s, výtok %.2f l/s" % (", ".join("%s %d" % (k, v) for k, v in
            {m: sum(1 for b in d["bodies"] if b["rezim_tel"] == m) for m in ("preliv", "smes", "nadrz")}.items()), d["leak"], d["out_q"]), fontsize=10)
hh, ll = a.get_legend_handles_labels(); a.legend(handles=hand + hh, loc="upper left", fontsize=8); a.set_xlabel("m"); a.set_ylabel("m")
a = ax[1]; res = [16, 32, 64]
lk = [json.load(open(D % r))["leak"] for r in res]; oq = [json.load(open(D % r))["out_q"] for r in res]
x = np.arange(3); a.bar(x - 0.2, lk, 0.4, label="průsak dnem", color="#2c9"); a.bar(x + 0.2, oq, 0.4, label="výtok (pramen / stěna)", color="#18f")
e52 = json.load(open("shots/podzemi52/funkce_nadrz_s64_dut64.json"))
a.axhline(e52["leak"], color="#c55", ls="--", lw=1); a.text(2.45, e52["leak"], "E52 nadrz: vše průsak %.2f" % e52["leak"], color="#c55", fontsize=8, ha="right", va="bottom")
for i in range(3): a.text(i - 0.2, lk[i] + 0.03, "%.3f" % lk[i], ha="center", fontsize=8); a.text(i + 0.2, oq[i] + 0.03, "%.3f" % oq[i], ha="center", fontsize=8)
a.set_xticks(x); a.set_xticklabels(["dutiny %d/blok" % r for r in res]); a.set_ylabel("l/s"); a.legend(fontsize=8)
a.set_title("nezávislé na rozlišení (povrch 64/blok)", fontsize=10)
fig.tight_layout(); fig.savefig("shots/55_prameny_prusak.png", dpi=90); print("shots/55_prameny_prusak.png")
