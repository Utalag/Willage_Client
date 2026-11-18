#!/usr/bin/env python3
"""E47: snímky 47_voda_eroze_* z shots/voda_eroze.json (tools/test_voda.gd)."""
import json, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource, to_rgb

D = os.path.join(os.path.dirname(__file__), "..", "shots")
d = json.load(open(os.path.join(D, "voda_eroze.json")))
pal = np.array([to_rgb("#" + c) if c else (0, 0, 0) for c in d["pal"]])
GW = GH = 48

def grid(a):  # index gx*GH+gy → [gy, gx]
    g = np.array([np.nan if v is None else v for v in a], float).reshape(GW, GH).T
    return g

def col(a):  # index gx + gy*GW → [gy, gx]
    return np.array(a, float).reshape(GH, GW)

def surf_img(w):
    h = grid(w["hm_f"]); top = grid(w["top"])
    rgb = np.ones((GH, GW, 3)) * 0.8
    ok = ~np.isnan(top)
    rgb[ok] = pal[top[ok].astype(int)]
    ls = LightSource(azdeg=315, altdeg=40)
    hh = np.nan_to_num(h, nan=np.nanmin(h))
    shade = ls.hillshade(hh, vert_exag=2.0)
    return np.clip(rgb * (0.45 + 0.75 * shade[..., None]), 0, 1), h

def water_img(w, base):
    dep = col(w["depth"]); fl = col(w["flow"])
    img = base * 0.75 + 0.25
    lo, hi = np.percentile(fl, 75), np.percentile(fl, 99)
    f = np.clip((fl - lo) / max(hi - lo, 1e-9), 0, 1) ** 0.6
    blue = np.array([0.15, 0.45, 0.95])
    a = f[..., None] * 0.85
    img = img * (1 - a) + blue * a
    pond = np.clip(dep / 0.15, 0, 1)[..., None]
    img = img * (1 - pond) + np.array([0.05, 0.2, 0.7]) * pond
    return img

def seams(ax):
    for k in range(1, 3):
        ax.axhline(k * 16 - 0.5, color="w", lw=0.6, alpha=0.6); ax.axvline(k * 16 - 0.5, color="w", lw=0.6, alpha=0.6)
    ax.set_xticks([]); ax.set_yticks([])

b = d["before"]; a = d["modes"]["okraj"]
sb, hb = surf_img(b); sa, ha = surf_img(a)
fig, ax = plt.subplots(2, 3, figsize=(13.5, 9.4))
ax[0, 0].imshow(sb); ax[0, 0].set_title("před erozí: povrch (barva = hornina navrchu)")
ax[0, 1].imshow(water_img(b, sb)); ax[0, 1].set_title("před: kudy teče déšť (modře = 25 % sloupců\ns nejsilnějším tokem), jezírko tmavě")
diff = ha - hb
ax[0, 2].imshow(diff * 0.5, cmap="RdBu", vmin=-3, vmax=3); ax[0, 2].set_title("eroze (okraj připnutý): změna povrchu, m\nčerveně odběr, modře nános")
ax[1, 0].imshow(sa); ax[1, 0].set_title("po erozi: v korytech odkrytá hornina,\nnános štěrku/písku je pod drnem (viz řezy)")
ax[1, 1].imshow(water_img(a, sa)); ax[1, 1].set_title("po: kudy teče déšť po erozi")
sl = {tuple(s[:2]): s[2] for s in d["slots"]}
for (x, y), n in sl.items():
    ax[1, 2].text(x * 16 + 8, y * 16 + 8, n.replace("_", "\n"), ha="center", va="center", fontsize=9)
ax[1, 2].imshow(np.where(np.isnan(hb), np.nan, hb * 0.5), cmap="terrain"); ax[1, 2].set_title("bloky (výška před, m)")
for x in ax.flat: seams(x)
fig.tight_layout(); fig.savefig(os.path.join(D, "47_voda_eroze_mapa.png"), dpi=85); plt.close(fig)

# režimy eroze a šev
fig, ax = plt.subplots(1, 3, figsize=(13.5, 4.9))
for i, (m, t) in enumerate([("blok", "A každý blok sám: šev se roztrhne"), ("okraj", "B okraj připnutý: šev spojitý"), ("svet", "C celý svět naráz: šev spojitý")]):
    h = grid(d["modes"][m]["hm_f"])
    ls = LightSource(azdeg=315, altdeg=35)
    sh = ls.hillshade(np.nan_to_num(h, nan=np.nanmin(h)), vert_exag=3.0)
    ax[i].imshow(sh, cmap="gray"); ax[i].imshow(np.ma.masked_invalid((h - hb) * 0.5), cmap="RdBu", vmin=-3, vmax=3, alpha=0.45)
    ax[i].set_title(t); seams(ax[i])
fig.tight_layout(); fig.savefig(os.path.join(D, "47_voda_eroze_svy.png"), dpi=85); plt.close(fig)

# řezy před / po
names = [("nizina", "louka (2,1)"), ("hora_vyzdvizena", "hora vyzdvižená (0,0)"), ("hora_zvrasnena", "hora zvrásněná (1,2)"), ("sopka", "sopka (2,0)"), ("prohlubne", "prohlubeň (1,0)")]
fig, ax = plt.subplots(2, 5, figsize=(15, 7.6))
for j, (k, t) in enumerate(names):
    for i, (w, lab) in enumerate([(b, "před"), (a, "po")]):
        c = np.array(w["sections"][k]["cells"])  # [x][z]
        img = pal[c.T[::-1]]
        img[c.T[::-1] == 0] = (0.86, 0.92, 0.98)
        x = ax[i, j]; x.imshow(img, aspect=0.5, interpolation="nearest")
        if i == 1:
            hb0 = np.array([max([z + 1 for z in range(64) if cc[z] != 0] or [0]) for cc in b["sections"][k]["cells"]])
            x.step(np.arange(16), 64 - hb0, where="mid", color="k", lw=0.8, ls="--")
        x.set_title(f"{t}, {lab}, y = {w['sections'][k]['y']}", fontsize=9); x.set_xticks([]); x.set_yticks([])
        lo = min(np.argmax(np.array(w["sections"][k]["cells"]) == 0, axis=1).min(), 64)
        x.set_ylim(64 - 4, 64 - 64)
        x.set_ylim(64 - max(lo - 24, 0) - 0.5, -0.5)
fig.suptitle("řezy: čárkovaně povrch před erozí; vrstvy (hranice bs) se nemění, koryto je prořízne, nános = štěrk/písek", fontsize=10)
fig.tight_layout(); fig.savefig(os.path.join(D, "47_voda_eroze_rezy.png"), dpi=85); plt.close(fig)
print("ok")

# 3D před / po vedle sebe (z uzlu ScenarioVoda, ./run.sh voda)
from PIL import Image
for a_, b_, o_ in [("iso_pred", "iso_po", "iso"), ("iso_rez_pred", "iso_rez_po", "iso_rez")]:
    pa, pb = os.path.join(D, f"47_voda_eroze_{a_}.png"), os.path.join(D, f"47_voda_eroze_{b_}.png")
    if os.path.exists(pa) and os.path.exists(pb):
        A, B = Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")
        out = Image.new("RGB", (A.width + B.width, A.height), "white"); out.paste(A, (0, 0)); out.paste(B, (A.width, 0))
        out.resize((out.width * 3 // 4, out.height * 3 // 4), Image.LANCZOS).save(os.path.join(D, f"47_voda_eroze_{o_}.png"))
