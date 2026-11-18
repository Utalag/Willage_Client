#!/usr/bin/env python3
"""E48: 3D grafy funkcí vrstev jako GIF (vrstvy přibývají zdola nahoru, pak povrch, pomalá rotace). Bez textur a popisků.
Vstup shots/funkce.json (tools/dump_funkce.gd). Výstup shots/48_funkce_<typ>.gif (+ _still.png)."""
import json, os, sys, subprocess, tempfile, shutil
from multiprocessing import Pool
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from matplotlib.colors import to_rgb
from matplotlib import cm

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
J = json.load(open(os.path.join(D, "funkce.json")))
N = J["n"]; IDS = J["ids"]
PAL = [to_rgb("#" + c) for c in J["pal"]]
ZS = float(os.environ.get("FN_ZSCALE", "0.5"))     # svislé měřítko krychle (32 m × ZS)
LIGHT = np.array([0.4, -0.5, 0.75]); LIGHT /= np.linalg.norm(LIGHT)
EPS = 0.03

def prep(case):
    bl = J["cases"][case]
    x0 = min(b["slot"][0] for b in bl); y0 = min(b["slot"][1] for b in bl)
    out = []
    for b in bl:
        t = np.linspace(0, 8, N)
        X, Y = np.meshgrid(t + (b["slot"][0] - x0) * 8, t + (b["slot"][1] - y0) * 8, indexing="ij")
        S = np.array(b["surf"]).reshape(N, N)
        B = [np.array(v).reshape(N, N) for v in b["bs"]]
        out.append((X, Y, S, B))
    wx = (max(b["slot"][0] for b in bl) - x0 + 1) * 8; wy = (max(b["slot"][1] for b in bl) - y0 + 1) * 8
    return out, wx, wy

def quads(X, Y, Z, keep):
    """čtyřúhelníky sítě, kde aspoň jeden roh je viditelný"""
    q = []; idx = []
    for i in range(N - 1):
        for j in range(N - 1):
            if keep[i, j] or keep[i + 1, j] or keep[i, j + 1] or keep[i + 1, j + 1]:
                q.append([(X[i, j], Y[i, j], Z[i, j] * ZS), (X[i + 1, j], Y[i + 1, j], Z[i + 1, j] * ZS),
                          (X[i + 1, j + 1], Y[i + 1, j + 1], Z[i + 1, j + 1] * ZS), (X[i, j + 1], Y[i, j + 1], Z[i, j + 1] * ZS)])
    return q

def shade(q, base):
    q = np.array(q)
    if len(q) == 0: return []
    n = np.cross(q[:, 2] - q[:, 0], q[:, 3] - q[:, 1]); n /= np.linalg.norm(n, axis=1)[:, None] + 1e-12
    n[n[:, 2] < 0] *= -1
    l = np.clip(n @ LIGHT, 0, 1)
    return np.clip(np.array(base)[None, :] * (0.45 + 0.65 * l[:, None]), 0, 1)

def layer_polys(blocks, k, surf_on):
    P = []; C = []
    for X, Y, S, B in blocks:
        lo = B[k - 1] if k > 0 else np.zeros_like(S)
        Z = np.minimum(B[k], S)
        keep = (B[k] - lo > EPS) & (B[k] < S - EPS)
        q = quads(X, Y, Z, keep)
        P += q; C += list(shade(q, PAL[IDS[k]]))
    return P, C

def surf_polys(blocks):
    P = []; C = []
    for X, Y, S, B in blocks:
        q = quads(X, Y, S, np.ones_like(S, bool))
        zc = np.array([np.mean([v[2] for v in a]) / ZS for a in q])
        base = cm.terrain(np.clip((zc - 14) / 20, 0, 1))[:, :3]
        qa = np.array(q)
        n = np.cross(qa[:, 2] - qa[:, 0], qa[:, 3] - qa[:, 1]); n /= np.linalg.norm(n, axis=1)[:, None] + 1e-12
        n[n[:, 2] < 0] *= -1
        l = np.clip(n @ LIGHT, 0, 1)
        P += q; C += list(np.clip(base * (0.5 + 0.6 * l[:, None]), 0, 1))
    return P, C

def cube(ax, wx, wy):
    h = 32 * ZS
    for a, b in [((0, 0), (wx, 0)), ((wx, 0), (wx, wy)), ((wx, wy), (0, wy)), ((0, wy), (0, 0))]:
        for z in (0, h):
            ax.plot([a[0], b[0]], [a[1], b[1]], [z, z], color=(0.35, 0.35, 0.45), lw=0.7)
    for x, y in [(0, 0), (wx, 0), (wx, wy), (0, wy)]:
        ax.plot([x, x], [y, y], [0, h], color=(0.35, 0.35, 0.45), lw=0.7)

VIEW = {"klin": (12, -100, 0.7)}   # (elevace, počáteční azimut, ° na snímek); klín ze strany, aby byl vidět šev

def frame(args):
    case, fi, nlay, surf, azim, path = args
    blocks, wx, wy = prep(case)
    fig = plt.figure(figsize=(5.4, 6.4) if wx <= 8 else (6.6, 5.6), dpi=90)
    ax = fig.add_axes([0, 0, 1, 1], projection="3d")
    P = []; C = []
    for k in range(nlay):
        p, c = layer_polys(blocks, k, surf); P += p; C += c
    if surf:
        p, c = surf_polys(blocks); P += p; C += c
    if P:
        pc = Poly3DCollection(P, facecolors=C, edgecolors=[tuple(np.array(c) * 0.8) for c in C], linewidths=0.15)
        ax.add_collection3d(pc)
    cube(ax, wx, wy)
    ax.set_xlim(0, wx); ax.set_ylim(0, wy); ax.set_zlim(0, 32 * ZS)
    ax.set_box_aspect((wx, wy, 32 * ZS), zoom=1.0 if wx > 8 else 1.05)
    ax.view_init(elev=VIEW.get(case, (24,))[0], azim=azim)
    ax.set_axis_off()
    fig.savefig(path, facecolor=(0.96, 0.97, 1.0)); plt.close(fig)
    return path

def make(case, per_layer=2, hold_surf=8, spin=40, deg=1.6):
    nl = len(J["cases"][case][0]["bs"])
    plan = []
    for k in range(1, nl + 1): plan += [(k, False)] * per_layer
    plan += [(nl, True)] * hold_surf
    plan += [(nl, False)] * (spin // 2) + [(nl, True)] * (spin // 2)
    tmp = tempfile.mkdtemp()
    el, a0, dg = VIEW.get(case, (24, -60, deg))
    jobs = [(case, i, k, s, a0 + i * dg, os.path.join(tmp, "f%04d.png" % i)) for i, (k, s) in enumerate(plan)]
    with Pool(8) as pool: pool.map(frame, jobs)
    out = os.path.join(D, "48_funkce_%s.gif" % case)
    pal = os.path.join(tmp, "pal.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "8", "-i", os.path.join(tmp, "f%04d.png"),
                    "-vf", "scale=440:-1:flags=lanczos,palettegen=max_colors=128:stats_mode=diff", pal], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "8", "-i", os.path.join(tmp, "f%04d.png"), "-i", pal,
                    "-lavfi", "scale=440:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
                    "-loop", "0", out], check=True)
    shutil.copy(jobs[nl * per_layer + 2][5], os.path.join(D, "48_funkce_%s_still.png" % case))
    shutil.copy(jobs[nl * per_layer - 1][5], os.path.join(D, "48_funkce_%s_vrstvy.png" % case))
    shutil.rmtree(tmp)
    return out, len(plan), os.path.getsize(out)

if __name__ == "__main__":
    cases = sys.argv[1:] or list(J["cases"].keys())
    for c in cases:
        o, nf, sz = make(c)
        print(f"{os.path.basename(o)}: {nf} snímků, {sz / 1e6:.2f} MB")
