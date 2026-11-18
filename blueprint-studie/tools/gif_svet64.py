#!/usr/bin/env python3
"""E50: GIF po fázích 50_svet64_faze.gif (bez textu, bez snímků jednotlivých vrstev). Vstup shots/svet64/ (tools/test_svet64.gd).
Fáze: hrubý terén → eroze → řeky a jezera → biomy → řez na dlaždice → detailní bloky přibývají (jemné buňky) → voda (koryta rostou, tůně, prameny)."""
import json, os, subprocess, tempfile, shutil, time
import numpy as np
from PIL import Image, ImageDraw
from matplotlib.colors import LightSource, to_rgb
from matplotlib import cm

t0 = time.time()
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
SD = os.path.join(D, "svet64")
J = json.load(open(os.path.join(SD, "meta.json")))
R, T, S, Wv = J["R"], J["T"], J["S"], J["Wv"]
OUT = int(os.environ.get("GIF_PX", 512))
PAL = np.array([to_rgb("#" + c) for c in J["pal"]])
BIO = np.array([to_rgb(c) for c in ["#3f7fd8", "#4f9bf0", "#a9d68a", "#6fb39a", "#c4e39a", "#4f8f4a", "#e2cf8c", "#9b8f88", "#f4f6fb"]])
TYP = {"louka": "#bfe39b", "kopec": "#9cbf5a", "svah": "#d8b878", "prohlubeň": "#5b8fe0", "hora_vyzdvizena": "#a0523c", "hora_zvrasnena": "#8a5aa8", "sopka": "#e0482c"}
ls = LightSource(azdeg=315, altdeg=40)
def g(a, n=R): return np.array(a, float).reshape(n, n).T          # index x*n+y → [y, x]
def rd(name, dt, n): return np.fromfile(os.path.join(SD, name), dtype=dt).reshape(n, -1)[:, :n].T if dt != np.uint8 or True else None
def resize(a, n=OUT):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return im.resize((n, n), Image.NEAREST if im.width < n else Image.LANCZOS)
def relief(h, base=None, lo=26, span=36, ve=1.5):
    sh = ls.hillshade(h, vert_exag=ve)
    if base is None: base = cm.terrain(np.clip((h - lo) / span, 0, 1))[..., :3]
    return np.clip(base * (0.45 + 0.7 * sh[..., None]), 0, 1)
water = np.array([0.2, 0.45, 0.92])
frames = []
raw, hm, river, lake, acc, bio = g(J["raw"]), g(J["hm"]), g(J["river"]), g(J["lake"]), g(J["acc"]), g(J["bio"]).astype(int)
ref = 40.0
for a in np.linspace(0.15, 1.0, 6): frames.append(resize(relief(ref + (raw - ref) * a)))   # 1 hrubý terén
frames += [frames[-1]] * 2
for e in J["ero"]: frames.append(resize(relief(g(e))))                                  # 2 eroze po dávkách
frames += [frames[-1]] * 2
lev = np.sort(acc[river > 0])[::-1] if river.any() else np.array([1.0])
for q in [0.1, 0.3, 0.6, 1.0]:                                                           # 3 řeky a jezera
    t = lev[min(int(q * (len(lev) - 1)), len(lev) - 1)]
    im = relief(hm).copy(); im[(river > 0) & (acc >= t)] = water; im[lake > 0] = water * 0.85
    frames.append(resize(im))
frames += [frames[-1]] * 2
riv = np.asarray(frames[-1]).astype(float) / 255
bimg = np.asarray(resize(relief(hm, BIO[bio]))).astype(float) / 255
for a in np.linspace(0.3, 1, 3): frames.append(resize(riv * (1 - a) + bimg * a))      # 4 biomy
frames += [frames[-1]] * 2
PX = R // T; tile = np.zeros((R, R, 3))
for e in J["tiles"]:
    x, y = e["slot"]; tile[y * PX:(y + 1) * PX, x * PX:(x + 1) * PX] = to_rgb(TYP[e["shape"]])
def grid(im):
    d = ImageDraw.Draw(im)
    for k in range(1, T):
        p = k * OUT // T; d.line([(p, 0), (p, OUT)], fill=(255, 255, 255), width=2); d.line([(0, p), (OUT, p)], fill=(255, 255, 255), width=2)
    return im
timg = np.asarray(resize(relief(hm, tile))).astype(float) / 255
for a in np.linspace(0.35, 1, 3): frames.append(grid(resize(bimg * (1 - a) + timg * a)))  # 5 dlaždice
frames += [frames[-1]] * 2
# 6 detailní bloky přibývají v pořadí generování (jemné buňky: vrch materiálu, stínování ze spojitého povrchu)
hf = np.fromfile(os.path.join(SD, "hf.f32"), np.float32).reshape(S, S).T
top = np.fromfile(os.path.join(SD, "top.u8"), np.uint8).reshape(S, S).T
order = np.fromfile(os.path.join(SD, "order.i32"), np.int32).reshape(T, T).T
n = S // T
det = np.clip(PAL[top] * (0.45 + 0.7 * ls.hillshade(hf, vert_exag=1.0)[..., None]), 0, 1)
canvas = np.asarray(resize(timg * 0.55 + 0.45 * 0.85, S)).astype(float) / 255
nb = int(order.max()) + 1; step = max(1, nb // 16)
for k in range(nb):
    ys, xs = np.where(order == k)
    for y, x in zip(ys, xs): canvas[y * n:(y + 1) * n, x * n:(x + 1) * n] = det[y * n:(y + 1) * n, x * n:(x + 1) * n]
    if k % step == step - 1 or k == nb - 1: frames.append(resize(canvas))
frames += [frames[-1]] * 3
# 7 voda na jemné mřížce: koryta rostou od pramenů (práh průtoku klesá), tůně, prameny, výtoky z podzemí
wat = np.fromfile(os.path.join(SD, "wat.u8"), np.uint8).reshape(Wv, Wv).T
eff = np.fromfile(os.path.join(SD, "eff.f32"), np.float32).reshape(Wv, Wv).T
post = np.fromfile(os.path.join(SD, "post.f32"), np.float32).reshape(Wv, Wv).T
k = S // Wv
def upk(a): return np.kron(a, np.ones((k, k))) if k > 1 else a
base = np.clip(PAL[top] * (0.45 + 0.7 * ls.hillshade(upk(post), vert_exag=1.0)[..., None]), 0, 1) if True else det
wet = wat > 0
ch = (wat == 1) | (wat == 4)   # koryta 1 buňku široká → pro čitelnost rozšířit o 1 sloupec
chd = ch.copy(); chd[1:] |= ch[:-1]; chd[:-1] |= ch[1:]; chd[:, 1:] |= ch[:, :-1]; chd[:, :-1] |= ch[:, 1:]
levs = np.sort(eff[wat == 1])[::-1] if (wat == 1).any() else np.array([1.0])
def dots(im, m, col, r):
    ys, xs = np.where(m)
    for y, x in zip(ys, xs):
        yy, xx = y * k, x * k
        im[max(yy - r, 0):yy + r + 1, max(xx - r, 0):xx + r + 1] = col
for q in [0.02, 0.08, 0.2, 0.4, 0.7, 1.0]:
    t = levs[min(int(q * (len(levs) - 1)), len(levs) - 1)]
    im = base.copy()
    on = ((wat == 1) & (eff >= t)) | (wat == 4)
    ond = on.copy(); ond[1:] |= on[:-1]; ond[:-1] |= on[1:]; ond[:, 1:] |= on[:, :-1]; ond[:, :-1] |= on[:, 1:]
    m = upk(ond & (wat != 2) | on) > 0
    im[m] = im[m] * 0.25 + water * 0.75
    if q >= 0.4:
        pm = upk(wat == 2) > 0; im[pm] = im[pm] * 0.2 + water * 0.8 * 0.9
    dots(im, wat == 3, (1.0, 1.0, 1.0), 3); dots(im, wat == 5, (0.1, 0.9, 0.9), 3)
    frames.append(resize(im))
frames += [frames[-1]] * 10
frames[-1].save(os.path.join(D, "50_svet64_voda.png"))
resize(canvas, S).save(os.path.join(D, "50_svet64_detail.png"))
tmp = tempfile.mkdtemp()
for i, f in enumerate(frames): f.save(os.path.join(tmp, "f%04d.png" % i))
out = os.path.join(D, "50_svet64_faze.gif"); pal = os.path.join(tmp, "p.png")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "5", "-i", os.path.join(tmp, "f%04d.png"), "-vf", "palettegen=max_colors=192:stats_mode=full", pal], check=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "5", "-i", os.path.join(tmp, "f%04d.png"), "-i", pal, "-lavfi", "paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle", "-loop", "0", out], check=True)
shutil.rmtree(tmp)
dt = time.time() - t0
open(os.path.join(D, "bench_svet64_render.txt"), "a").write("render GIF (Python): %d snímků, %.2f MB, %.1f s\n" % (len(frames), os.path.getsize(out) / 1e6, dt))
print(f"50_svet64_faze.gif: {len(frames)} snímků, {os.path.getsize(out) / 1e6:.2f} MB, {dt:.1f} s")
