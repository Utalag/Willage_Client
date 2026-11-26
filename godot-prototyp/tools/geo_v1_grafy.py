#!/usr/bin/env python3
"""Obrázky kroku 3 z výstupů tools/geo_v1.gd. Data: /tmp/k3/data, JSON a PNG: shots/krok03/."""
import json, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import csv

D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/k3/data"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots", "krok03")
os.makedirs(OUT, exist_ok=True)
J = json.load(open(os.path.join(OUT, "geo_v1.json")))

def f32(name, shape):
    a = np.fromfile(os.path.join(D, name), dtype=np.float32)
    return a.reshape(shape)

# barvy materiálů
cmap_ids = {}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "materialy_v1.csv")
with open(path, newline="") as f:
    for r in csv.DictReader(f):
        try:
            i = int(r["id"])
        except Exception:
            continue
        hx = (r.get("barva_hex") or "").strip()
        if hx.startswith("#") and len(hx) == 7:
            cmap_ids[i] = tuple(int(hx[k:k+2], 16)/255 for k in (1, 3, 5))
        else:
            cmap_ids[i] = (0.85, 0.85, 0.9) if i == 0 else (0.5, 0.5, 0.5)
cmap_ids[0] = (0.92, 0.95, 0.98)
cmap_ids[75] = (0.15, 0.05, 0.05)
cmap_ids[250] = (0.2, 0.4, 0.8)

def rez_img(name, meta, title, fname, highlight_x=None):
    n, nz, krok = int(meta["n"]), int(meta["nz"]), float(meta["krok_m"])
    ids = f32(f"rez_{name}_id.f32", (n, nz))
    # ids index i * nz + iz, i along profile, iz along z — stored i*nz+iz, reshape (n, nz)
    rgb = np.zeros((nz, n, 3))
    for iz in range(nz):
        for i in range(n):
            rgb[iz, i] = cmap_ids.get(int(ids[i, iz]), (0.4, 0.4, 0.4))
    fig, ax = plt.subplots(figsize=(12, 5.2))
    ext = [0, meta["delka_m"], 0, nz * krok]
    ax.imshow(rgb, origin="lower", extent=ext, aspect="auto", interpolation="nearest")
    if os.path.exists(os.path.join(D, f"rez_{name}_povrch.f32")):
        zp = f32(f"rez_{name}_povrch.f32", (n,))
        xs = np.linspace(0, meta["delka_m"], n)
        ax.plot(xs, zp, color="k", lw=0.7, label="povrch")
    if highlight_x is not None:
        ax.axvline(highlight_x, color="w", ls="--", lw=0.8, label="šev")
    ax.set_xlabel("vzdálenost po řezu (m)")
    ax.set_ylabel("z (m)")
    ax.set_title(title)
    ax.legend(loc="upper right", fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, fname), dpi=120)
    plt.close()
    print("uloženo", fname)

# šev: start 3×3 začíná na start_blok*128, šev +128 je 128 m od začátku řezu
rez_img("sev", J["rez_sev"], "Svislý řez přes šev bloků (výchozí 3 × 3, západ–východ)", "rez_sev.png", highlight_x=128.0)
rez_img("masiv", J["rez_masiv"], "Svislý řez přes masiv", "rez_masiv.png")
if "rez_sopka" in J:
    rez_img("sopka", J["rez_sopka"], "Svislý řez sopkou (průduch id 75 k z = 0, slupky lávy/popela)", "rez_sopka.png")

# mince
nb = int(J.get("mapy", {}).get("mince_n", 16))
m = f32("mince_16x16.f32", (nb, nb))
fig, ax = plt.subplots(figsize=(6, 5.5))
ax.imshow(m.T, origin="lower", extent=[0, nb * 128, 0, nb * 128], cmap="coolwarm", vmin=0, vmax=1, interpolation="nearest")
ax.set_title("Mince E82: bloky „ano“ (červeně) / „ne“ (modře), 128 m")
ax.set_xlabel("x (m)"); ax.set_ylabel("y (m)")
# výřez 3×3
st = J.get("parametry", {}).get("start_blok", [14, 14])
from matplotlib.patches import Rectangle
ax.add_patch(Rectangle((st[0]*128, st[1]*128), 384, 384, fill=False, ec="k", lw=1, ls="--"))
fig.tight_layout()
fig.savefig(os.path.join(OUT, "mince_mapa.png"), dpi=120)
plt.close()
print("uloženo mince_mapa.png")

# útvary řez
n = int(J.get("mapy", {}).get("utvary_n", 384))
u = f32("utvary_rez_20m.f32", (n, n))
rgb = np.zeros((n, n, 3))
for i in range(n):
    for j in range(n):
        rgb[j, i] = cmap_ids.get(int(u[i, j]), (0.4, 0.4, 0.4))
fig, ax = plt.subplots(figsize=(7, 6.5))
o = st
ext = [o[0]*128, o[0]*128+384, o[1]*128, o[1]*128+384]
ax.imshow(rgb, origin="lower", extent=ext, interpolation="nearest")
ax.set_title("Vodorovný řez 20 m pod povrchem, výřez 3 × 3 (útvary a vrstvy)")
ax.set_xlabel("x (m)"); ax.set_ylabel("y (m)")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "utvary_rez_20m.png"), dpi=120)
plt.close()
print("uloženo utvary_rez_20m.png")

# čas
c = J["cas"]
fig, ax = plt.subplots(figsize=(7, 4.2))
labs = ["segment 8 m\n0,25 m / 128 m", "srovnání E84\n0,5 m / 32 m", "E84 R1\n(měřeno tehdy)", "hranice\n32×32"]
vals = [c["segment_8m_025_ms"], c["segment_8m_05_32m_ms"], c["e84_r1_ms"], c["hranice_8m_025_ms"]]
ax.bar(labs, vals, color=["#468", "#46a", "#999", "#8a6"])
ax.set_ylabel("ms")
ax.set_title("Čas na segment 8 m")
for i, v in enumerate(vals):
    ax.text(i, v, f"{v:.0f}", ha="center", va="bottom", fontsize=8)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "cas_segment.png"), dpi=120)
plt.close()
print("uloženo cas_segment.png")
