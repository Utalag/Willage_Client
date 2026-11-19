#!/usr/bin/env python3
"""E52: shots/podzemi52/*.json → shots/podzemi52/tabulka.md + snímky shots/52_*.png"""
import json, glob, os
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
D = "shots/podzemi52"
R = {os.path.basename(f)[:-5]: json.load(open(f)) for f in sorted(glob.glob(D + "/*.json"))}
ug = {k: v for k, v in R.items() if v.get("var") != "povrch"}
base = ug.get("slovnik_s64_u64")
order = sorted(ug, key=lambda k: (["slovnik", "pole", "darcy3d", "funkce"].index(ug[k]["var"]) if ug[k]["var"] in ["slovnik", "pole", "darcy3d", "funkce"] else 9, k))
L = ["| varianta | peak MB | podzemí ms (sestavení + řešení, řešení ×) | přítok l/s | průsak | výtok | okraj | lokální změna ms (podzemí) | CG it |",
     "|---|---|---|---|---|---|---|---|---|"]
for k in order:
    v = ug[k]
    cg = v.get("cg", {}); it = cg.get("it", [])
    L.append("| %s | %.0f | %.0f + %.0f (%d×) | %.2f | %.2f | %.2f | %.2f | %.0f (%.0f) | %s |" % (k, v["peak_mb"], v["build_ms"], v["solve_ms"], v["solves"], v["q_in"], v["leak"], v["out_q"], v["edge_q"],
             v.get("local_update_ms", 0) + v.get("local_drains_ms", 0), v.get("local_ug_ms", 0), ("%d–%d" % (min(it), max(it))) if it else "—"))
L.append("")
L.append("| povrch (vodopády) | rozlišení | vodopádů | okraj l/s |"); L.append("|---|---|---|---|")
for k in sorted(R):
    v = R[k]
    if v.get("var") == "povrch": L.append("| %s | %d | %d | %.2f |" % (k, v["nv"], v["falls"], v["edge_q"]))
# Darcy detaily
for k in order:
    v = ug[k]
    for b in v["bodies"]:
        for key in ("darcy", "darcy3d"):
            if b.get(key): L.append("\n%s %s: %s" % (k, key, json.dumps({a: c for a, c in b[key].items() if a not in ("outs",)}, ensure_ascii=False)[:600])); break
open(D + "/tabulka.md", "w").write("\n".join(L) + "\n"); open("shots/bench_podzemi52.txt", "w").write("\n".join(L) + "\n"); print("\n".join(L))
# snímky
names = order
fig, ax = plt.subplots(1, 2, figsize=(13, 5))
ax[0].barh(names, [ug[k]["peak_mb"] for k in names], color="#5b8"); ax[0].set_xlabel("peak paměti MB"); ax[0].invert_yaxis()
ax[1].barh(names, [(ug[k]["build_ms"] + ug[k]["solve_ms"]) / 1000 for k in names], color="#58b"); ax[1].set_xlabel("podzemí s (sestavení + řešení)"); ax[1].invert_yaxis(); ax[1].set_yticklabels([])
fig.suptitle("E52 podzemní voda: paměť a čas (svět 8×8, povrch 64/blok)"); fig.tight_layout(); fig.savefig("shots/52_pamet_cas.png", dpi=90)
fig, ax = plt.subplots(figsize=(11, 5))
lk = [ug[k]["leak"] for k in names]; oq = [ug[k]["out_q"] for k in names]; eq = [ug[k]["edge_q"] for k in names]
ax.barh(names, lk, label="průsak", color="#c96"); ax.barh(names, oq, left=lk, label="výtok podzemím", color="#69c")
ax.invert_yaxis(); ax.set_xlabel("l/s (přítok do podzemí)"); ax.legend()
for i, k in enumerate(names): ax.text(lk[i] + oq[i] + 0.02, i, "okraj %.1f" % eq[i], va="center", fontsize=8)
fig.suptitle("E52 kam teče voda z tůní do podzemí"); fig.tight_layout(); fig.savefig("shots/52_vystupy.png", dpi=90)
pv = sorted([v for v in R.values() if v.get("var") == "povrch"], key=lambda v: v["nv"])
fig, ax = plt.subplots(figsize=(7, 4))
for dx, c in ((0.0, "#c55"), (0.5, "#5a5")):
    s = [v for v in pv if ("dx%s" % dx) in v["name"]]
    ax.plot([v["nv"] for v in s], [v["falls"] for v in s], "o-", color=c, label="vodopad_dx_m=%s%s" % (dx, " (staré: na buňku)" if dx == 0 else ""))
ax.set_xlabel("buněk na blok"); ax.set_ylabel("počet vodopádů"); ax.legend(); ax.set_xticks([16, 32, 64])
fig.suptitle("E52 pravidlo vodopádu: metry na vodorovné vzdálenosti"); fig.tight_layout(); fig.savefig("shots/52_vodopady.png", dpi=90)
print("snímky: shots/52_pamet_cas.png shots/52_vystupy.png shots/52_vodopady.png")
