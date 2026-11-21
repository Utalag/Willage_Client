#!/usr/bin/env python3
"""Krok 2 (V1.0): obrázky a grafy testů funkce světa I z výstupů tools/svet_v1.gd.
Vstup: shots/krok02/svet_v1.json, det_beh1.json a binární mřížky float32 (výchozí /tmp/k2/data, mimo git).
Výstup: PNG do shots/krok02/. Konvence mřížek: index i * n + j, i podél x (východ), j podél y (sever)."""
import json, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource
from matplotlib.patches import Patch

D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/k2/data"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots", "krok02")
J = json.load(open(os.path.join(OUT, "svet_v1.json")))
SEED = J["seed"]
BIOMY = ["nížina", "mokřad", "pahorkatina", "hornatina", "sopečná oblast"]
BC = np.array([[0.66, 0.82, 0.55], [0.37, 0.66, 0.63], [0.79, 0.71, 0.35], [0.55, 0.48, 0.42], [0.63, 0.25, 0.23]])

def f32(name, n, k=1):
    a = np.fromfile(os.path.join(D, name), dtype=np.float32)
    return a.reshape(n, n, k) if k > 1 else a.reshape(n, n)

def img(a):            # [x, y(, c)] → obrázek se severem nahoře
    return np.flip(np.swapaxes(a, 0, 1), axis=0)

def save(fig, name):
    p = os.path.join(OUT, name); fig.savefig(p, dpi=110, bbox_inches="tight"); plt.close(fig); print(p)

def legenda_biomu(ax):
    ax.legend(handles=[Patch(color=BC[i], label=BIOMY[i]) for i in range(5)], loc="lower left", fontsize=7, framealpha=0.85)

def shade(h, krok, vert=1.0):
    ls = LightSource(azdeg=315, altdeg=40)
    return ls.shade(img(h), cmap=plt.cm.terrain, vert_exag=vert, dx=krok, dy=krok, blend_mode="soft", vmin=55, vmax=125)

# ---------------- mapy 4096 m: biomy, horniny, výšky se sopkami (dva seedy)
sop = {SEED: J["sopky"], SEED + 1: J["mapy"]["sopky_seed2"]}
for s in (SEED, SEED + 1):
    w = f32(f"biomy_s{s}_4096.f32", 512, 5); rgb = f32(f"horniny_rgb_s{s}_4096.f32", 512, 3); h = f32(f"vysky_s{s}_4096.f32", 512)
    fig, ax = plt.subplots(1, 3, figsize=(18, 6.3))
    ax[0].imshow(img(np.clip(w @ BC, 0, 1)), extent=[0, 4096, 0, 4096]); ax[0].set_title(f"Mapa biomů (seed {s}), mísení podle vah")
    legenda_biomu(ax[0])
    ax[1].imshow(img(np.clip(rgb, 0, 1)), extent=[0, 4096, 0, 4096]); ax[1].set_title(f"Mapa hornin (seed {s}), barva = směs zástupců")
    ax[2].imshow(shade(h, 8.0, 4.0), extent=[0, 4096, 0, 4096]); ax[2].set_title(f"Výška povrchu (seed {s}), sopky ×")
    for v in sop[s]:
        ax[2].plot(v["x"], v["y"], "x", color="red", ms=10, mew=2)
        ax[2].add_patch(plt.Circle((v["x"], v["y"]), v["R"], fill=False, color="red", lw=1))
    if s == SEED:
        st = J["mapy"]["start_m"]; st = [float(x) for x in st.strip("()").split(",")] if isinstance(st, str) else st
        for a in ax: a.add_patch(plt.Rectangle(st, 384, 384, fill=False, color="black", lw=1.5))
    for a in ax: a.set_xlabel("x (m)"); a.set_ylabel("y (m)")
    save(fig, f"mapy_4096_seed{s}.png")

# srovnání výchozí mapy biomů a varianty biom_velke_oblasti (přepínač, výchozí vyp)
velke_ok = all(os.path.exists(os.path.join(D, f"biomy_s{s}_4096_velke.f32")) for s in (SEED, SEED + 1))
if velke_ok:
    obl = J.get("mapy", {})
    fig, ax = plt.subplots(2, 2, figsize=(14, 14))
    for row, s in enumerate((SEED, SEED + 1)):
        wa = f32(f"biomy_s{s}_4096.f32", 512, 5)
        wv = f32(f"biomy_s{s}_4096_velke.f32", 512, 5)
        key_a = "oblasti_seed_a" if s == SEED else "oblasti_seed_b"
        key_v = "oblasti_velke_seed_a" if s == SEED else "oblasti_velke_seed_b"
        sa = obl.get(key_a, {})
        sv_ = obl.get(key_v, {})
        cap_a = ""
        cap_v = ""
        if sa:
            cap_a = f", {sa.get('ulomku', '?')} úlomků, medián √ {sa.get('median_prumer_m', 0):.0f} m"
        if sv_:
            cap_v = f", {sv_.get('ulomku', '?')} úlomků, medián √ {sv_.get('median_prumer_m', 0):.0f} m"
        ax[row, 0].imshow(img(np.clip(wa @ BC, 0, 1)), extent=[0, 4096, 0, 4096])
        ax[row, 0].set_title(f"Seed {s} výchozí (stanice 256 m){cap_a}")
        ax[row, 1].imshow(img(np.clip(wv @ BC, 0, 1)), extent=[0, 4096, 0, 4096])
        ax[row, 1].set_title(f"Seed {s} větší oblasti (měřítko {J.get('parametry', {}).get('biom_meritko_m', 768):.0f} m){cap_v}")
        for a in ax[row]:
            a.set_xlabel("x (m)"); a.set_ylabel("y (m)")
            if "start_m" in J.get("mapy", {}):
                st = J["mapy"]["start_m"]
                st = [float(x) for x in st.strip("()").split(",")] if isinstance(st, str) else st
                a.add_patch(plt.Rectangle(st, 384, 384, fill=False, color="black", lw=1.2))
            legenda_biomu(a)
    fig.suptitle("Srovnání mapy biomů 4096 m: výchozí měřítko (vlevo) a varianta větších oblastí za přepínačem (vpravo)")
    save(fig, "biomy_4096_srovnani.png")

def vec(s):

    return [float(x) for x in s.strip("()").split(",")] if isinstance(s, str) else s

# ---------------- výchozí svět 3 × 3: biomy, horniny, stínovaný reliéf (0,25 m)
st = vec(J["mapy"]["start_m"])
w = f32("biomy_start.f32", 384, 5); rgb = f32("horniny_rgb_start.f32", 384, 3)
h025 = f32("start_025.f32", 1536)
ext = [st[0], st[0] + 384, st[1], st[1] + 384]
fig, ax = plt.subplots(1, 3, figsize=(18, 6.3))
ax[0].imshow(img(np.clip(w @ BC, 0, 1)), extent=ext); ax[0].set_title("Biomy, výřez 3 × 3 bloky (1 m)"); legenda_biomu(ax[0])
ax[1].imshow(img(np.clip(rgb, 0, 1)), extent=ext); ax[1].set_title("Horniny, výřez 3 × 3 (1 m)")
ax[2].imshow(shade(h025, 0.25, 3.0), extent=ext); ax[2].set_title(f"Reliéf 0,25 m ({h025.min():.1f}–{h025.max():.1f} m), převýšení ×3")
for a in ax:
    for k in (1, 2):
        a.axvline(st[0] + 128 * k, color="k", lw=0.6, ls="--"); a.axhline(st[1] + 128 * k, color="k", lw=0.6, ls="--")
    a.set_xlabel("x (m)"); a.set_ylabel("y (m)")
save(fig, "vychozi_svet_3x3.png")

# vrstevnice výchozího světa
fig, ax = plt.subplots(figsize=(8, 8))
hh = img(h025)
cs = ax.contourf(hh[::-1][::2, ::2], levels=30, cmap="terrain", extent=ext, origin="lower")
ax.contour(hh[::-1][::2, ::2], levels=np.arange(50, 126, 1.0), colors="k", linewidths=0.3, extent=ext, origin="lower")
for k in (1, 2):
    ax.axvline(st[0] + 128 * k, color="r", lw=0.8, ls="--"); ax.axhline(st[1] + 128 * k, color="r", lw=0.8, ls="--")
fig.colorbar(cs, ax=ax, label="výška (m)"); ax.set_title("Výchozí svět 3 × 3: vrstevnice po 1 m, švy bloků červeně")
save(fig, "vychozi_svet_vrstevnice.png")

# ---------------- test 1: profil přes šev
pr = J["spojitost"]["profil"]
x = np.array(pr["x_m"]); z = np.array(pr["z_m"]); b = np.array(pr["blok"])
fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(x[b == 0], z[b == 0], ".-", ms=3, label="blok vlevo (vlastní dotaz)")
ax.plot(x[b == 1], z[b == 1], ".-", ms=3, label="blok vpravo (vlastní dotaz)")
ax.axvline(st[0] + 128, color="k", ls="--", lw=0.8, label="šev bloků")
sp = J["spojitost"]
ax.set_title(f"Test 1: řez přes šev, krok 0,25 m. Max rozdíl na švech bloků {sp['max_rozdil_bloky_m']} m, segmentů {sp['max_rozdil_segmenty_m']} m")
ax.set_xlabel("x (m)"); ax.set_ylabel("výška (m)"); ax.legend(); ax.grid(alpha=0.3)
save(fig, "test1_sev_profil.png")

# ---------------- test 2: histogramy sklonů (povrch s detailem; v titulku i překročení detailem a tvar)
sk = dict(J["sklony"])
svet_sk = json.load(open(os.path.join(OUT, "sklony_svet.json")))["sklony_svet"]
sk["celý svět 4096 m (4 m)"] = svet_sk
tvar_key = {"start": "start_tvar", "sopka": "sopka_tvar", "masiv": "masiv_tvar"}
fig, ax = plt.subplots(1, 4, figsize=(24, 5.0))
for a, k in zip(ax, ["start", "sopka", "masiv", "celý svět 4096 m (4 m)"]):
    r = sk[k]; hst = np.array(r["hist_0_5deg"], dtype=float)
    a.bar(np.arange(181) * 0.5 + 0.25, hst / hst.sum() * 100, width=0.5, color="#557")
    for q, c in (("p50_deg", "g"), ("p95_deg", "orange"), ("max_deg", "r")):
        a.axvline(r[q], color=c, ls="--", label=f"{q[:-4]} {r[q]:.1f}°")
    a.set_xlim(0, 55); a.set_xlabel("sklon (°)"); a.set_ylabel("% vzorků")
    tv = r.get("tvar") if k.startswith("celý") else sk.get(tvar_key.get(k, ""), {})
    tv_s = ""
    if tv:
        tv_s = f"\ntvar: max {tv['max_deg']:.1f}°, nad stropem {tv['max_nad_stropem_deg']:.2f}° ({tv['vzorku_nad_stropem']} vz.)"
    a.set_title(f"{k}: s detailem max {r['max_deg']:.1f}°, nad stropem {r['max_nad_stropem_deg']:.2f}° ({r['vzorku_nad_stropem']} vz.){tv_s}")
    a.legend(fontsize=8)
fig.suptitle("Test 2: sklony povrchu s detailem. Strop v přechodu = vážený průměr. Kritérium platí pro celkový tvar; drobný detail do 2 m smí strop překročit.")
save(fig, "test2_sklony_histogram.png")

# ---------------- test 3: sopky (mapa + řezy)
st3 = J["sopky_test"]
fig, ax = plt.subplots(1, 2, figsize=(16, 6.5))
hs = f32("vysky_sopka_1m.f32", 384); o = vec(J["mapy"]["okno_sopka"])
ax[0].imshow(shade(hs, 1.0, 2.0), extent=[o[0], o[0] + 384, o[1], o[1] + 384])
for v in J["sopky"]:
    ax[0].plot(v["x"], v["y"], "x", color="red", ms=8); ax[0].add_patch(plt.Circle((v["x"], v["y"]), v["R"], fill=False, color="red"))
    ax[0].add_patch(plt.Circle((v["x"], v["y"]), v["rc"], fill=False, color="yellow"))
ax[0].set_xlim(o[0], o[0] + 384); ax[0].set_ylim(o[1], o[1] + 384)
ax[0].set_title("Sopka 1: stínovaný reliéf 1 m (úpatí červeně, okraj kráteru žlutě)")
for i, e in enumerate(st3["sopky"]):
    ax[1].plot(e["rez"]["x_m"], e["rez"]["z_m"], label=f"sopka {i+1}: H {e['H_m']:.1f} m, Ø {e['prumer_upati_m']:.0f} m, kráter {e['krater_hloubka_m']:.1f} m")
ax[1].axhline(st3["sopky"][0]["strop_m"], color="r", ls="--", label="okraj sloupce − 5 m (123 m)")
ax[1].axhline(128, color="k", lw=0.8, label="okraj sloupce 128 m")
ax[1].set_aspect(2.0); ax[1].set_xlabel("vzdálenost od středu (m)"); ax[1].set_ylabel("výška (m)"); ax[1].legend(fontsize=8, loc="lower center")
ax[1].grid(alpha=0.3)
ax[1].set_title(f"Řezy sopkami (osa x přes střed), převýšení ×2, rozteč {', '.join(f'{d:.0f}' for d in st3['roztece_m'])} m")
ax[1].set_ylim(40, 132)
save(fig, "test3_sopky.png")

# ---------------- masiv: reliéf + řez
hm = f32("vysky_masiv_1m.f32", 384); mw = f32("masiv_vaha_masiv_1m.f32", 384); o = vec(J["mapy"]["okno_masiv"])
rz = J["mapy"]["rez_masiv"]
fig = plt.figure(figsize=(16, 7))
a0 = fig.add_subplot(1, 2, 1); a1 = fig.add_subplot(2, 2, 2); a3 = fig.add_subplot(2, 2, 4, sharex=a1)
E = [o[0], o[0] + 384, o[1], o[1] + 384]
a0.imshow(shade(hm, 1.0, 2.0), extent=E)
a0.contour(img(mw)[::-1], levels=[0.05, 0.5, 0.95], colors=["yellow", "orange", "red"], extent=E, origin="lower", linewidths=1)
a0.axhline(o[1] + 192, color="w", lw=0.8, ls=":")
a0.set_title("Masiv E87 v hornatině: reliéf 1 m;\nváha masivu 0,05 / 0,5 / 0,95 (žlutá / oranžová / červená), řez bíle")
a1.plot(rz["x_m"], rz["z_m"], color="saddlebrown"); a1.set_ylabel("výška (m)"); a1.grid(alpha=0.3)
a1.set_title("Řez masivem; podhůří = pás, kde váha masivu roste z 0 na 1")
a3.plot(rz["x_m"], rz["masiv"], color="r", label="váha masivu"); a3.plot(rz["x_m"], rz["hornatina"], color="gray", ls="--", label="váha hornatiny")
a3.set_ylim(0, 1.05); a3.set_xlabel("x od středu okna (m)"); a3.set_ylabel("váha"); a3.legend(); a3.grid(alpha=0.3)
save(fig, "masiv_rez.png")

# ---------------- test 6: čas
c = J["cas"]
fig, ax = plt.subplots(1, 2, figsize=(14, 4.5))
ax[0].bar(["výška", "sloupec", "bod"], [c["vyska_us"], c["sloupec_us"], c["bod_us"]], color="#468")
ax[0].set_ylabel("µs na dotaz"); ax[0].set_title("Dotaz na funkci světa (GDScript, box)")
k = ["blok128_1.0_ms", "blok128_0.5_ms", "blok128_0.25_ms", "blok128_sopka_0.5_ms", "mapa_3km_po_4m_ms", "e90_3km_ms"]
lab = ["blok 128 m\n1 m", "blok 128 m\n0,5 m", "blok 128 m\n0,25 m", "blok se sopkou\n0,5 m", "mapa 3 km\npo 4 m", "E90 3 km\n(stavba LOD)"]
ax[1].bar(lab, [c[x] / 1000 for x in k], color=["#468"] * 5 + ["#999"]); ax[1].set_ylabel("s"); ax[1].set_title("Výšky z funkce")
for i, x in enumerate(k): ax[1].text(i, c[x] / 1000, f"{c[x]/1000:.2f}", ha="center", va="bottom", fontsize=8)
save(fig, "test6_cas.png")
