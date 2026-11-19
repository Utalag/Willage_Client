#!/usr/bin/env python3
"""E51: snímky z shots/eroze51.json (tools/test_eroze51.gd).
51_koryto.png  podélný profil osy koryta v čase (měkký vs. tvrdý pruh) + mapa zahloubení
51_tun.png     zanášení tůně: objem v čase + příčný řez dnem a hladinou v čase
51_hraz.png    protržení hráze: koruna, objem tůně, průtok po proudu a odtok do podzemí v čase + mapa toku před / po"""
import json, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
J = json.load(open(os.path.join(D, "eroze51.json")))
C = 0.5
plt.rcParams.update({"font.size": 10})

k = J["koryto"]; W, H = k["W"], k["H"]
fig, ax = plt.subplots(1, 3, figsize=(15, 4.6), gridspec_kw={"width_ratios": [1.3, 1.3, 1]})
cm = plt.cm.viridis
P = k["prof"]; x = np.arange(W) * C
for side, key, title in [(0, "soft", "měkký pruh: hlína 2 buňky na písku"), (1, "hard", "tvrdý pruh: hlína 1 buňka na žule")]:
    a = ax[side]
    for j, t in enumerate(P["t"]):
        a.step(x, np.array(P[key][j]) * C, where="mid", color=cm(j / max(len(P["t"]) - 1, 1)), label=f"{t:.0f} d")
    a.set_title(title); a.set_xlabel("vzdálenost po proudu (m)"); a.set_ylabel("dno koryta (m)"); a.grid(alpha=0.3)
    a.set_ylim(0, 11)
ax[0].legend(title="čas", fontsize=8)
d = (np.array(k["hm0"]) - np.array(k["hm"])).reshape(W, H).T * C
wall = np.array(k["wall"]).reshape(W, H).T
d = np.ma.masked_where(wall > 0, d)
im = ax[2].imshow(d, origin="lower", cmap="magma_r", aspect="equal", extent=[0, W * C, 0, H * C])
ax[2].set_title("zahloubení po %.0f dnech (m)" % P["t"][-1]); ax[2].set_xlabel("x (m)"); ax[2].set_ylabel("y (m)")
plt.colorbar(im, ax=ax[2], fraction=0.035)
fig.suptitle("E51 koryto: odpočet objemu vody při v ≥ ero_v (pramen 5 l/s v každém pruhu)")
fig.tight_layout(); fig.savefig(os.path.join(D, "51_koryto.png"), dpi=110); plt.close(fig)

t = J["tun"]; cu = t["curve"]; W, H = t["W"], t["H"]
fig, ax = plt.subplots(1, 2, figsize=(13, 4.6))
ax[0].plot(cu["t"], cu["vol"], "o-", color="#3060c0", label="objem vody (m³)")
a2 = ax[0].twinx(); a2.plot(cu["t"], np.array(cu["dmax"]), "s--", color="#c06030", label="max. hloubka (m)")
ax[0].set_xlabel("čas (dny)"); ax[0].set_ylabel("objem tůně (m³)"); a2.set_ylabel("max. hloubka (m)")
ax[0].set_title("tůň se zanáší (přítok 2 l/s, plaveniny + nános z eroze)"); ax[0].grid(alpha=0.3)
xs = np.arange(W) * C
sel = [j for j in range(len(cu["t"])) if cu["t"][j] in (0, 15, 30, 45, 60, 90)] or list(range(min(5, len(cu["t"]))))
for n, j in enumerate(sel):
    sec = np.array(cu["sec"][j]); col = cm(n / max(len(sel) - 1, 1))
    ax[1].step(xs, sec[:, 0] * C, where="mid", color=col, label=f"dno {cu['t'][j]:.0f} d")
    wet = sec[:, 1] > sec[:, 0] + 0.01
    ax[1].fill_between(xs, sec[:, 0] * C, np.where(wet, sec[:, 1], sec[:, 0]) * C, step="mid", color=col, alpha=0.25)
ax[1].set_xlim(0, 14); ax[1].set_xlabel("x (m), řez středem tůně"); ax[1].set_ylabel("výška (m)"); ax[1].set_title("dno (čára) a voda (výplň) v čase"); ax[1].legend(fontsize=8); ax[1].grid(alpha=0.3)
fig.tight_layout(); fig.savefig(os.path.join(D, "51_tun.png"), dpi=110); plt.close(fig)

h = J["hraz"]; hi = h["hist"]; W, H = h["W"], h["H"]
fig = plt.figure(figsize=(14, 5))
g = fig.add_gridspec(2, 3, width_ratios=[1.4, 1, 1])
a = fig.add_subplot(g[:, 0])
a.plot(hi["t"], np.array(hi["crest"]) * C, "-", color="#b08040", label="koruna hráze (m)")
a.plot(hi["t"], hi["pond"], "-", color="#3060c0", label="objem tůně (m³)")
a.plot(hi["t"], hi["q_down"], "-", color="#20a060", lw=2, label="průtok po proudu (l/s)")
a.plot(hi["t"], hi["drain"], "--", color="#806080", label="odtok tůně do podzemí (l/s)")
a.set_xlabel("čas (dny)"); a.set_title("protržení pískové hráze mění tok po proudu"); a.legend(fontsize=8); a.grid(alpha=0.3)
b = fig.add_subplot(g[:, 1:])
xs = np.arange(W) * C
for n, (lg, tt) in enumerate(zip(hi["long"], hi["long_t"])):
    L = np.array(lg); col = cm(n / max(len(hi["long"]) - 1, 1))
    b.step(xs, L[:, 0] * C, where="mid", color=col, label=f"dno {tt:.0f} d")
    wet = L[:, 1] > L[:, 0] + 0.01
    b.fill_between(xs, L[:, 0] * C, np.where(wet, L[:, 1], L[:, 0]) * C, step="mid", color=col, alpha=0.3)
b.axvspan(h["crest"] // H * C - 0.25, h["crest"] // H * C + 0.75, color="#d0b070", alpha=0.25, label="písková hráz")
b.set_xlabel("vzdálenost po údolí (m)"); b.set_ylabel("výška (m)"); b.set_title("podélný řez osou údolí: tůň za hrází (výplň) a koruna v čase")
b.legend(fontsize=8); b.grid(alpha=0.3)
fig.savefig(os.path.join(D, "51_hraz.png"), dpi=110, bbox_inches="tight"); plt.close(fig)
print("51_koryto.png, 51_tun.png, 51_hraz.png")
