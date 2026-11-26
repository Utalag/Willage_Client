#!/usr/bin/env python3
"""Obrázky kroku 3b z tools/geo_v1b_rezy.gd (data /tmp/k3b) a shots/krok03b/sum.json. PNG do shots/krok03b/."""
import json, os, sys, csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/k3b"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "shots", "krok03b")
os.makedirs(OUT, exist_ok=True)
META = json.load(open(os.path.join(D, "rezy_meta.json")))

col = {}
with open(os.path.join(HERE, "..", "data", "materialy_v1.csv"), newline="") as f:
    for r in csv.DictReader(f):
        try: i = int(r["id"])
        except Exception: continue
        hx = (r.get("barva_hex") or "").strip()
        col[i] = tuple(int(hx[k:k+2], 16) / 255 for k in (1, 3, 5)) if hx.startswith("#") and len(hx) == 7 else (0.6, 0.6, 0.6)
col[0] = (0.93, 0.96, 0.99)

kat = json.load(open(os.path.join(HERE, "..", "data", "teren", "poradi_hornin.json")))["rocks"]
klic = {r["key"]: r["id"] for r in kat if r["idx"] <= 40}
naz = {r["id"]: r["name"] for r in kat if r["idx"] <= 40}
tab = json.load(open(os.path.join(HERE, "..", "data", "v1", "utvary_hostitele.json")))
nikdy = {klic[k] for k in tab["nikdy"]}
host = {}
for t, e in tab["typy"].items():
    host[t] = {r["id"] for r in kat if r["idx"] <= 40 and r["kind"] in ("layer", "seam")} if e["hosts"] == "*" else {klic[k] for k in e["hosts"]}
    host[t] -= nikdy
host["zila"] = host["zila"]
TYP = {38: "zila", 8: "zila", 9: "zila", 47: "dome", 21: "pipe", 42: "skarn"}
TELO_BARVA = {"zila": (1.0, 0.55, 0.0), "dome": (0.1, 0.4, 1.0), "pipe": (0.7, 0.0, 0.8), "skarn": (0.0, 0.7, 0.3), "kras": (0.0, 0.0, 0.0)}

def f32(name, shape): return np.fromfile(os.path.join(D, name), dtype=np.float32).reshape(shape)

def nacti(sek, kl):
    m = META[sek]; n, nz = m["n"], m["nz"]
    return f32(f"{sek}_{kl}_id.f32", (n, nz)), f32(f"{sek}_{kl}_vrstva.f32", (n, nz)), f32(f"{sek}_{kl}_povrch.f32", (n,))

def rgb_vrstvy(lay, fade=0.0):
    n, nz = lay.shape
    img = np.ones((nz, n, 3))
    for i in range(n):
        for k in range(nz):
            c = np.array(col.get(int(lay[i, k]), (0.5, 0.5, 0.5)))
            img[k, i] = c * (1 - fade) + fade
    return img

def hranice(img, lay):
    n, nz = lay.shape
    for i in range(n):
        for k in range(nz - 1):
            if lay[i, k] != lay[i, k + 1] and lay[i, k + 1] != 0:
                img[k, i] = img[k, i] * 0.35

def rez_a10():
    m = META["a10"]; ext = [m["x0"], m["x1"], 0, m["nz"] * m["krok_z"]]
    fig, ax = plt.subplots(2, 1, figsize=(13, 8), sharex=True)
    for a, kl, t in zip(ax, ("pred", "po"), ("PŘED (jedno měřítko 180 m, 1 oktáva pro všechny)", "PO (měřítko / amplituda / oktávy podle horniny)")):
        idm, lay, zp = nacti("a10", kl)
        img = rgb_vrstvy(lay); hranice(img, lay)
        a.imshow(img, origin="lower", extent=ext, aspect="auto", interpolation="nearest")
        a.set_title(t); a.set_ylabel("z (m)")
        a.set_ylim(0, float(zp.max()) + 2)
    ax[1].set_xlabel("x (m), řez západ–východ, y = %.0f m" % m["y0"])
    fig.suptitle("A10: mocnosti vrstev před a po (čáry = rozhraní vrstev)")
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "a10_rez_pred_po.png"), dpi=110); plt.close()

def teloMaska(idm, lay):
    return (idm != lay) & (lay != 0)

def rez_a1(sek, nazev):
    m = META[sek]; ext = [0, m["x1"] - m["x0"], 0, m["nz"] * m["krok_z"]]
    fig, ax = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    stat = {}
    for a, kl, t in zip(ax, ("pred", "po"), ("PŘED (host_ok = true)", "PO (útvary jen v hostiteli)")):
        idm, lay, zp = nacti(sek, kl)
        img = rgb_vrstvy(lay, fade=0.55)
        n, nz = lay.shape
        zle = 0; telo = 0
        for i in range(n):
            for k in range(nz):
                f = int(idm[i, k]); l = int(lay[i, k])
                if l == 0: continue
                typ = TYP.get(f) if f != l else None
                if typ is None and f == 0 and l != 0: typ = "kras"
                if typ is None: continue
                telo += 1
                if l in nikdy or l not in host[typ]:
                    img[k, i] = (1, 0, 0); zle += 1
                else:
                    img[k, i] = TELO_BARVA[typ]
        a.imshow(img, origin="lower", extent=ext, aspect="auto", interpolation="nearest")
        a.set_title(f"{t}: buňky útvarů {telo}, z toho v nehostiteli (červeně) {zle}")
        a.set_ylabel("z (m)"); a.set_ylim(0, float(zp.max()) + 2)
        stat[kl] = {"telo": telo, "v_nehostiteli": zle}
    ax[1].set_xlabel("x od začátku řezu (m); oranžová žíla, modrá dóm, fialová komín, zelená skarn, černá kras; bledě = vrstvy")
    fig.suptitle(nazev); fig.tight_layout(); fig.savefig(os.path.join(OUT, f"a1_rez_{sek}_pred_po.png"), dpi=110); plt.close()
    return stat

def krivky():
    S = json.load(open(os.path.join(OUT, "sum.json")))["krivky"]
    fig, ax = plt.subplots(6, 1, figsize=(12, 10), sharex=True)
    R = json.load(open(os.path.join(OUT, "sum.json")))["radky"]
    for a, k in zip(ax, ("shale", "granite", "quartzite", "cave_limestone", "quartz_sandstone", "conglomerate")):
        x = np.arange(375) * 4.0
        a.plot(x, S[k + "_legacy"], color="0.6", lw=1, label="před (180 m, 1 oktáva)")
        a.plot(x, S[k], color="C3", lw=1.4, label="po")
        r = R[k]
        a.set_ylabel(k, fontsize=8); a.set_ylim(0, 1)
        a.text(0.995, 0.08, f"{r['meritko_m']:.0f} m, amp {r['amplituda']}, {r['oktavy']} okt.", transform=a.transAxes, ha="right", fontsize=8)
    ax[0].legend(loc="upper left", fontsize=8)
    ax[-1].set_xlabel("vzdálenost (m)")
    fig.suptitle("A10: pole mocnosti 0–1 podle horniny (0,5 = střed rozsahu thick0…thick1)")
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "a10_krivky_horniny.png"), dpi=110); plt.close()

def rez_dom(sek, nazev, fname):
    m = META[sek]; ext = [m["x0"], m["x1"], 0, m["nz"] * m["krok_z"]]
    fig, ax = plt.subplots(2, 1, figsize=(13, 8), sharex=True)
    stat = {}
    for a, kl, t in zip(ax, ("pred", "po"), ("PŘED (střed dómu 0,55–0,75 výšky, v krystaliniku)", "PO (střed dómu v pásmu sedimentů, Jan 26. 11.)")):
        idm, lay, zp = nacti(sek, kl)
        img = rgb_vrstvy(lay, fade=0.35)
        n, nz = lay.shape
        telo = 0
        for i in range(n):
            for k in range(nz):
                f = int(idm[i, k]); l = int(lay[i, k])
                if l == 0: continue
                typ = TYP.get(f) if f != l else None
                if typ is None and f == 0 and l != 0: typ = "kras"
                if typ is None: continue
                telo += 1
                img[k, i] = TELO_BARVA[typ]
        xs = np.linspace(m["x0"], m["x1"], len(zp), endpoint=False) + 0.5 * (m["x1"] - m["x0"]) / len(zp)
        a.imshow(img, origin="lower", extent=ext, aspect="auto", interpolation="nearest")
        a.plot(xs, zp * 0.67, color="k", ls="--", lw=0.7, alpha=0.6)
        a.plot(xs, zp * 0.92, color="k", ls="--", lw=0.7, alpha=0.6)
        a.set_title(f"{t}: buněk útvarů {telo}")
        a.set_ylabel("z (m)")
        a.set_ylim(0, float(zp.max()) + 2)
        stat[kl] = telo
    ax[1].set_xlabel("x (m), y = %.0f m; čárkovaně pásmo sedimentů (0,67–0,92 výšky povrchu sloupce); modrá = dóm (sůl), zelená skarn, oranžová žíla" % m["y0"])
    fig.suptitle(nazev)
    fig.tight_layout(); fig.savefig(os.path.join(OUT, fname), dpi=110); plt.close()
    return stat

if "a10" in META:
    rez_a10()
if "a1" in META:
    st = {"a1": rez_a1("a1", "A1: svislý řez blokem 14,14 (y = 1825 m)"), "a1b": rez_a1("a1b", "A1: svislý řez blokem 14,15 (y = 1921 m)")}
    json.dump(st, open(os.path.join(OUT, "a1_rezy_stat.json"), "w"), indent=1)
    print(st)
if os.path.isfile(os.path.join(OUT, "sum.json")) and "a10" in META:
    krivky()
dst = {}
if "dom" in META:
    dst["dom"] = rez_dom("dom", "Dóm (sůl): svislý řez y = 1917 m, střed (2069, 1917)", "a1_rez_dom_pred_po.png")
if "dom2" in META:
    dst["dom2"] = rez_dom("dom2", "Dóm (sůl): svislý řez y = 1943 m, střed (1889, 1943)", "a1_rez_dom2_pred_po.png")
if dst:
    json.dump(dst, open(os.path.join(OUT, "dom_rezy_stat.json"), "w"), indent=1)
    print(dst)
