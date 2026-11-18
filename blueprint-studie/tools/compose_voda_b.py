#!/usr/bin/env python3
"""E47b (voda z plochy, srovnání): 47b_mapa_plocha.png, 47b_hloubky_plocha.png z shots/voda_eroze_b.json (tools/test_voda_b.gd --b).
E47c (prameny): 47b_mapa.png z shots/voda_eroze_c.json; 47b_iso.png složený z uzlu ScenarioVodaB."""
import json, os
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import compose_voda as CV   # surf_img, water_img, seams, grid, col (načte i E47 json, jen kvůli funkcím)

D = CV.D
B = os.path.exists(os.path.join(D, "voda_eroze_b.json"))
d = json.load(open(os.path.join(D, "voda_eroze_b.json"))) if B else None
if B:
    CV.pal = np.array([CV.to_rgb("#" + c) if c else (0, 0, 0) for c in d["pal"]])
    G = 48
    b, a = d["before"], d["after"]
    sb, hb = CV.surf_img(b); sa, ha = CV.surf_img(a)
    ch = CV.grid(d["chan"]); sk = CV.grid(d["sink"]); dp = CV.grid(d["depth"]) * 0.5
    falls = [(t // G, t % G, f // G, f % G, m) for t, f, m in d["falls"]]

    fig, ax = plt.subplots(2, 3, figsize=(13.5, 9.4))
    ax[0, 0].imshow(sb); ax[0, 0].set_title("před: povrch (barva = hornina navrchu)")
    ax[0, 1].imshow(CV.water_img(b, sb)); ax[0, 1].set_title("před: kudy teče déšť (E47 bez strží)")
    m = np.ma.masked_where(dp <= 0.01, dp)
    ax[0, 2].imshow(sa * 0.6 + 0.4); im = ax[0, 2].imshow(m, cmap="magma_r", vmin=0, vmax=4)
    plt.colorbar(im, ax=ax[0, 2], fraction=0.046, label="zahloubení, m")
    ys, xs = np.where(sk == 1); ax[0, 2].scatter(xs, ys, s=22, c="#1a9850", edgecolors="k", lw=0.4, label="ponor: propustná hornina")
    ys, xs = np.where(sk == 2); ax[0, 2].scatter(xs, ys, s=30, c="#00e5ff", edgecolors="k", lw=0.4, label="ponor: kras (sůl/vápenec)")
    for tx, ty, fx, fy, mm in falls:
        ax[0, 2].scatter([tx], [ty], marker="^", s=70, c="#2166ac", edgecolors="w", lw=0.8)
    ax[0, 2].scatter([], [], marker="^", s=70, c="#2166ac", label="vodopád (spád ≥ 1,5 m)")
    ax[0, 2].legend(loc="lower left", fontsize=7, framealpha=0.85)
    ax[0, 2].set_title("strže: hloubka (cíl medián 2 m), ponory, vodopády")
    ax[1, 0].imshow(sa); ax[1, 0].set_title("po: v korytech odkrytá hornina pod 2 m")
    ax[1, 1].imshow(CV.water_img(a, sa)); ax[1, 1].set_title("po: tok se soustředí do strží,\nv ponorech mizí")
    for (x, y), n in {tuple(s[:2]): s[2] for s in d["slots"]}.items():
        ax[1, 2].text(x * 16 + 8, y * 16 + 8, n.replace("_", "\n"), ha="center", va="center", fontsize=9)
    ax[1, 2].imshow(np.ma.masked_invalid((ha - hb) * 0.5), cmap="RdBu", vmin=-4, vmax=4); ax[1, 2].set_title("změna povrchu, m (červeně odběr)")
    for x in ax.flat: CV.seams(x)
    fig.tight_layout(); fig.savefig(os.path.join(D, "47b_mapa_plocha.png"), dpi=85); plt.close(fig)

    # hloubky: histogram podle erodovatelnosti a tok před/po
    txt = open(os.path.join(D, "bench_voda_b.txt")).read().splitlines()
    dd = dp[ch == 1]
    fig, ax = plt.subplots(1, 2, figsize=(11, 4.2))
    ax[0].hist(dd, bins=np.arange(0, 4.26, 0.25), color="#b35806", edgecolor="w")
    ax[0].axvline(np.median(dd), color="k", ls="--"); ax[0].set_xlabel("hloubka strže, m"); ax[0].set_ylabel("sloupců koryta")
    ax[0].set_title(f"{len(dd)} sloupců koryta, medián {np.median(dd):.2f} m, strop 4 m")
    def share(w):
        f = np.sort(CV.col(w["flow"]).ravel())[::-1]; return np.cumsum(f) / f.sum()
    for w, lab, c in [(b, "před (bez strží)", "#999"), (a, "po E47b", "#2166ac")]:
        s = share(w); ax[1].plot(np.arange(1, len(s) + 1) / len(s) * 100, s * 100, label=lab, color=c)
    ax[1].set_xlim(0, 30); ax[1].axvline(5, color="k", lw=0.5, ls=":")
    ax[1].set_xlabel("% nejsilnějších sloupců"); ax[1].set_ylabel("% celkového toku"); ax[1].legend(); ax[1].set_title("soustředění toku do koryt")
    fig.tight_layout(); fig.savefig(os.path.join(D, "47b_hloubky_plocha.png"), dpi=85); plt.close(fig)

from PIL import Image
pa, pb = os.path.join(D, "47b_iso_pred.png"), os.path.join(D, "47b_iso_po.png")
if os.path.exists(pa) and os.path.exists(pb):
    A, B = Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")
    out = Image.new("RGB", (A.width + B.width, A.height), "white"); out.paste(A, (0, 0)); out.paste(B, (A.width, 0))
    out.resize((out.width * 3 // 4, out.height * 3 // 4), Image.LANCZOS).save(os.path.join(D, "47b_iso.png"))

# E47c mapa
c = json.load(open(os.path.join(D, "voda_eroze_c.json")))
CV.pal = np.array([CV.to_rgb("#" + x) if x else (0, 0, 0) for x in c["pal"]])
G = 48
sb, hb = CV.surf_img(c["before"]); sa, ha = CV.surf_img(c["after"])
eff = CV.grid(c["eff"]); sk = CV.grid(c["sink"]); dp = CV.grid(c["depth"]) * 0.5
pond = np.zeros((G, G), bool)
for comp in c["ponds"]:
    for i in comp: pond[i % G, i // G] = True
fig, ax = plt.subplots(1, 3, figsize=(15, 5.4))
ax[0].imshow(sb); ax[0].set_title("před: povrch (barva = hornina navrchu)")
img = sa * 0.8 + 0.2
img[pond] = img[pond] * 0.3 + np.array([0.1, 0.3, 0.85]) * 0.7
w = np.clip(eff / 4.0, 0, 1) ** 0.5
on = eff > 0
img[on] = img[on] * (1 - 0.85 * w[on, None]) + np.array([0.1, 0.4, 1.0]) * 0.85 * w[on, None]
ax[1].imshow(img)
for gi, druh, q in c["springs"]:
    ax[1].scatter([gi // G], [gi % G], marker="*", s=160, c={"snih": "w", "kontakt": "#ffd400", "kras": "#00e5ff"}[druh], edgecolors="k", lw=0.6)
for t, f, m in c["falls"]:
    ax[1].scatter([t // G], [t % G], marker="^", s=60, c="#2166ac", edgecolors="w", lw=0.8)
for gi, q in c["edge"]:
    ax[1].scatter([gi // G], [gi % G], marker="s", s=70, facecolors="none", edgecolors="#d7301f", lw=1.6)
ys, xs = np.where(sk > 0); ax[1].scatter(xs, ys, s=50, c="k", edgecolors="#00e5ff", lw=1.2)
for fr, ex, q in c.get("under", []):
    ax[1].annotate("", xy=(ex // G, ex % G), xytext=(fr // G, fr % G), arrowprops=dict(arrowstyle="->", color="#7b3294", lw=1.5, ls="--"))
ax[1].plot([], [], color="#7b3294", ls="--", label="podzemím z tůně k vyvěračce ve stěně")
for lab, mk, col in [("pramen: sníh / vrchol", "*", "w"), ("pramen: styk propustná/nepropustná", "*", "#ffd400")]:
    ax[1].scatter([], [], marker=mk, s=120, c=col, edgecolors="k", label=lab)
ax[1].scatter([], [], marker="^", c="#2166ac", label="vodopád ve strži ≥ 1,5 m"); ax[1].scatter([], [], marker="s", facecolors="none", edgecolors="#d7301f", label="přepad přes okraj ostrova")
ax[1].scatter([], [], c="k", edgecolors="#00e5ff", label="ponor (kras)"); ax[1].legend(loc="lower left", fontsize=7, framealpha=0.85)
ax[1].set_title("po: voda jen z pramenů, koryto (šířka ~ l/s),\ntůně do hladiny přelivu")
m = np.ma.masked_where(dp <= 0.01, dp)
ax[2].imshow(sa * 0.6 + 0.4); im = ax[2].imshow(m, cmap="magma_r", vmin=0, vmax=4)
plt.colorbar(im, ax=ax[2], fraction=0.046, label="zahloubení strže, m")
ax[2].set_title("strže z průtoku pramenů (cíl medián 2 m)")
for x in ax: CV.seams(x)
fig.tight_layout(); fig.savefig(os.path.join(D, "47b_mapa.png"), dpi=85); plt.close(fig)
print("ok b/c")
