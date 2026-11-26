#!/usr/bin/env python3
"""Obrázky kroku 4 z výstupu tools/voda_v1.gd (C# běžec). Použití: voda_v1_grafy.py /tmp/k4/vse → shots/krok04/."""
import csv, json, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/k4/vse"
TU = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(TU, "..", "shots", "krok04")
os.makedirs(OUT, exist_ok=True)
J = json.load(open(os.path.join(D, "krok04_vse.json")))

barvy = {}
with open(os.path.join(TU, "..", "data", "materialy_v1.csv"), newline="") as f:
    for r in csv.DictReader(f):
        try: i = int(r["id"])
        except Exception: continue
        hx = (r.get("barva_hex") or "").strip()
        barvy[i] = tuple(int(hx[k:k+2], 16) / 255 for k in (1, 3, 5)) if hx.startswith("#") and len(hx) == 7 else (0.5, 0.5, 0.5)
barvy[0] = (0.93, 0.96, 1.0); barvy[75] = (0.15, 0.05, 0.05)
lut = np.array([barvy.get(i, (0.5, 0.5, 0.5)) for i in range(256)])
ZNACKY = {"Kras": ("o", "#1f4fff"), "Kontakt": ("s", "#00a0a0"), "Snih": ("*", "#ffffff"), "Vyver": ("^", "#00c000")}

# 1) mapa hloubky hladiny pod povrchem 3 × 3
m = J["mapa"]; N = m["n"]; k = m["krok_m"]
L = np.fromfile(os.path.join(D, "mapa_L.f32"), np.float32).reshape(N, N)
P = np.fromfile(os.path.join(D, "mapa_P.f32"), np.float32).reshape(N, N)
x0 = 14 * 128; y0 = 14 * 128
fig, ax = plt.subplots(1, 2, figsize=(15, 7))
ext = [x0, x0 + N * k, y0, y0 + N * k]
im = ax[0].imshow(P - L, origin="lower", extent=ext, cmap="viridis_r", vmin=0, vmax=np.percentile(P - L, 99))
plt.colorbar(im, ax=ax[0], label="hloubka hladiny pod povrchem (m)")
ax[0].contour(P - L, levels=[1e-3], origin="lower", extent=ext, colors="red", linewidths=0.6)
ax[0].set_title(f"Krok 4: hloubka hladiny, 3 × 3 bloky (2 m); červeně zóna vývěru ({100*m['vyver_podil']:.1f} %)")
im2 = ax[1].imshow(L, origin="lower", extent=ext, cmap="terrain")
plt.colorbar(im2, ax=ax[1], label="hladina L (m)")
ax[1].contour(L, levels=20, origin="lower", extent=ext, colors="k", linewidths=0.3)
ax[1].set_title("hladina podzemní vody L (vrstevnice) a prameny")
for a in ax:
    for s in (x0 + 128, x0 + 256): a.axvline(s, color="w", lw=0.6, ls="--"); a.axhline(s - x0 + y0, color="w", lw=0.6, ls="--")
for s in J["prameny"]["seznam"]:
    mk, c = ZNACKY.get(s["druh"], ("x", "k"))
    for a in ax: a.scatter(s["x"], s["y"], marker=mk, c=c, edgecolors="k", s=60, zorder=5)
for d, (mk, c) in ZNACKY.items(): ax[1].scatter([], [], marker=mk, c=c, edgecolors="k", label=d)
ax[1].legend(loc="upper right", fontsize=8)
plt.tight_layout(); plt.savefig(os.path.join(OUT, "mapa_hladiny_3x3.png"), dpi=110); plt.close()

# 2) svislé řezy s hladinou, nasycenou, zavěšenou a sevřenou vodou
for r in J["rezy"]:
    sl = r["sloupce"]; n = len(sl); kr = r["krok_m"]
    mat = np.fromfile(os.path.join(D, r["mat"]), np.uint8).reshape(n, 512)
    zmax = max(c[0] for c in sl) + 4; zmin = max(0, min(c[1] for c in sl) - 25)
    img = lut[mat.T]
    fig, ax = plt.subplots(figsize=(18, 6))
    ax.imshow(img, origin="lower", extent=[r["x0"], r["x0"] + n * kr, 0, 128], aspect="auto", interpolation="nearest")
    xs = r["x0"] + (np.arange(n) + 0.5) * kr
    ax.plot(xs, [c[1] for c in sl], color="#0040ff", lw=1.3, label="hladina L")
    for i, c in enumerate(sl):
        x = xs[i]
        if c[2]: ax.plot([x, x], c[2], color="#3080ff", alpha=0.35, lw=1.2)
        for z in c[3]: ax.plot([x, x], z, color="#00d0ff", lw=1.5)
        for s in c[4]: ax.plot([x, x], s[:2], color="#ff00ff", alpha=0.5, lw=1.2)
    ax.plot([], [], color="#3080ff", label="nasyceno (volná hladina)"); ax.plot([], [], color="#00d0ff", label="zavěšená voda")
    ax.plot([], [], color="#ff00ff", label="sevřená vrstva")
    for s in (r["x0"] + 128, r["x0"] + 256): ax.axvline(s, color="k", lw=0.6, ls="--")
    ax.set_ylim(zmin, zmax); ax.set_xlabel("x (m)"); ax.set_ylabel("z (m)")
    ax.set_title(f"Krok 4: řez y = {r['y']:.2f} m (0,5 m), hladina a voda ze sloupce; švy čárkovaně")
    ax.legend(loc="lower right", fontsize=8)
    plt.tight_layout(); plt.savefig(os.path.join(OUT, f"rez_y{r['y']:.0f}.png"), dpi=100); plt.close()
print("hotovo", OUT)
