#!/usr/bin/env python3
"""E49: GIF po fázích 49_svet_8x8_faze.gif + snímky fází (bez textu). Vstup shots/svet8.json (tools/test_svet8.gd).
Fáze: hrubý terén (narůstá) → srážky → eroze → řeky a jezera → biomy → řez na dlaždice a typy → detailní dlaždice od první."""
import json, os, subprocess, tempfile, shutil
import numpy as np
from PIL import Image, ImageDraw
from matplotlib.colors import LightSource, to_rgb
from matplotlib import cm

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
J = json.load(open(os.path.join(D, "svet8.json")))
R, T = J["R"], J["T"]; S = 512; SC = S // R
PAL = np.array([to_rgb("#" + c) for c in J["pal"]])
BIO = np.array([to_rgb(c) for c in ["#3f7fd8", "#4f9bf0", "#a9d68a", "#6fb39a", "#c4e39a", "#4f8f4a", "#e2cf8c", "#9b8f88", "#f4f6fb"]])
TYP = {"louka": "#bfe39b", "kopec": "#9cbf5a", "svah": "#d8b878", "prohlubeň": "#5b8fe0", "hora_vyzdvizena": "#a0523c", "hora_zvrasnena": "#8a5aa8", "sopka": "#e0482c"}
ls = LightSource(azdeg=315, altdeg=40)

def g(a): return np.array(a, float).reshape(R, R).T   # index x*R+y → [y, x]
def up(img, k=SC): return np.kron(img, np.ones((k, k, 1))) if img.ndim == 3 else np.kron(img, np.ones((k, k)))

def relief(h, base=None):
    sh = ls.hillshade(h, vert_exag=1.5)
    if base is None: base = cm.terrain(np.clip((h - 26) / 36, 0, 1))[..., :3]
    return np.clip(base * (0.45 + 0.7 * sh[..., None]), 0, 1)

def to_im(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
def big(a): return to_im(up(a))

raw = g(J["raw"]); hm = g(J["hm"]); rain = g(J["rain"]); river = g(J["river"]); lake = g(J["lake"]); acc = g(J["acc"]); bio = g(J["bio"]).astype(int)
fill = g(J["fill"])
frames = []; stills = {}
ref = 40.0
# 1 hrubý terén narůstá z roviny
for a in np.linspace(0.15, 1.0, 6): frames.append(big(relief(ref + (raw - ref) * a)))
frames += [frames[-1]] * 2; stills["hrube"] = frames[-1]
# 2 srážky (modrý nádech podle srážek)
base1 = relief(raw)
for a in np.linspace(0.25, 1.0, 3):
    frames.append(big(base1 * (1 - 0.6 * a * rain[..., None]) + np.array([0.2, 0.45, 0.95]) * 0.6 * a * rain[..., None]))
frames += [frames[-1]] * 2; stills["srazky"] = frames[-1]
# 3 eroze po dávkách
for e in J["ero"]: frames.append(big(relief(g(e))))
# 4 řeky rostou (práh klesá), jezera
water = np.array([0.2, 0.45, 0.92])
thr = np.percentile(acc[river > 0], 100) if river.any() else 1
lev = np.sort(acc[river > 0])[::-1] if river.any() else np.array([1.0])
for q in [0.05, 0.15, 0.3, 0.5, 0.75, 1.0]:
    t = lev[min(int(q * (len(lev) - 1)), len(lev) - 1)]
    im = relief(hm).copy()
    m = (river > 0) & (acc >= t)
    im[m] = water
    lm = lake > 0
    im[lm] = water * 0.85
    frames.append(big(im))
frames += [frames[-1]] * 2; stills["eroze_reky"] = frames[-1]
rivimg = frames[-1]
# 5 biomy (prolnutí)
bimg = relief(hm, BIO[bio])
A = np.asarray(rivimg).astype(float) / 255; B = up(bimg)
for a in np.linspace(0.25, 1, 4): frames.append(to_im(A * (1 - a) + B * a))
frames += [frames[-1]] * 3; stills["biomy"] = frames[-1]
# 6 řez na dlaždice a typy
tile = np.zeros((R, R, 3))
PX = R // T
for e in J["tiles"]:
    x, y = e["slot"]; tile[y * PX:(y + 1) * PX, x * PX:(x + 1) * PX] = to_rgb(TYP[e["shape"]])
def grid_lines(im):
    d = ImageDraw.Draw(im)
    for k in range(1, T):
        d.line([(k * S // T, 0), (k * S // T, S)], fill=(255, 255, 255), width=2); d.line([(0, k * S // T), (S, k * S // T)], fill=(255, 255, 255), width=2)
    return im
B2 = up(relief(hm, tile))
for a in np.linspace(0.3, 1, 4): frames.append(grid_lines(to_im(B * (1 - a) + B2 * a)))
frames += [frames[-1]] * 3; stills["dlazdice"] = frames[-1]
# 7 detailní dlaždice od první (vrch materiálu + stínování z funkce povrchu, voda z hrubé fáze)
cur = np.asarray(frames[-1]).astype(float) / 255 * 0.55 + 0.45 * 0.85
canvas = cur.copy()
DT = S // T; k4 = DT // 16
hf = np.zeros((T * 16, T * 16))
for d in J["detail"]:
    x, y = d["slot"]; hf[y * 16:(y + 1) * 16, x * 16:(x + 1) * 16] = np.array(d["hm_f"]).reshape(16, 16).T
shf = ls.hillshade(hf, vert_exag=1.5)
wat = np.kron((river > 0) | (lake > 0), np.ones((2, 2)))   # 1 bod hrubé mřížky = 2 řídicí body
for d in J["detail"]:
    x, y = d["slot"]
    top = np.array(d["top"]).reshape(16, 16).T
    col = PAL[top]
    col[top == 0] = (0.8, 0.8, 0.8)
    s = shf[y * 16:(y + 1) * 16, x * 16:(x + 1) * 16]
    img = np.clip(col * (0.45 + 0.7 * s[..., None]), 0, 1)
    w = wat[y * 16:(y + 1) * 16, x * 16:(x + 1) * 16]
    img[w > 0] = img[w > 0] * 0.35 + water * 0.65
    canvas[y * DT:(y + 1) * DT, x * DT:(x + 1) * DT] = np.kron(img, np.ones((k4, k4, 1)))
    frames.append(to_im(canvas))
frames += [frames[-1]] * 10; stills["detail"] = frames[-1]
for k, im in stills.items(): im.save(os.path.join(D, f"49_svet_8x8_{k}.png"))
tmp = tempfile.mkdtemp()
for i, f in enumerate(frames): f.resize((448, 448), Image.LANCZOS).save(os.path.join(tmp, "f%04d.png" % i))
out = os.path.join(D, "49_svet_8x8_faze.gif"); pal = os.path.join(tmp, "p.png")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "6", "-i", os.path.join(tmp, "f%04d.png"), "-vf", "palettegen=max_colors=160:stats_mode=full", pal], check=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "6", "-i", os.path.join(tmp, "f%04d.png"), "-i", pal, "-lavfi", "paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle", "-loop", "0", out], check=True)
shutil.rmtree(tmp)
print(f"49_svet_8x8_faze.gif: {len(frames)} snímků, {os.path.getsize(out) / 1e6:.2f} MB")
