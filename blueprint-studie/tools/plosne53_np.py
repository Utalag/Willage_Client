#!/usr/bin/env python3
"""E53: odhad paralelizace – stejné průchody celým polem vektorově (numpy = jedno jádro SIMD, náhrada za GPU/vlákna).
Měří ms na průchod rozlévání (tools/plosne53_roz.py, stejné pravidlo jako rozliv.gd) a na krok mělké vody (trubky)."""
import time, sys, json, numpy as np
sys.path.insert(0, "tools"); from plosne53_roz import run as roz
def pipe_step(b, d, f, src, dt=0.05, l=0.5, cf=2.0):
    Hs = b + d; P = np.pad(Hs, 1, constant_values=-1e9)
    W, H = b.shape
    nb = [P[2:, 1:-1], P[:-2, 1:-1], P[1:-1, 2:], P[1:-1, :-2]]
    for e in range(4):
        dh = np.where(nb[e] < -1e8, d, Hs - nb[e])
        f[e] = np.maximum(0, f[e] * (1 - cf * dt) + dt * 9.81 * l * dh)
    s = f.sum(0); k = np.where(s * dt > d * l * l, d * l * l / np.maximum(s * dt, 1e-30), 1.0); f *= k
    fin = np.zeros_like(d)
    fin[1:, :] += f[0][:-1, :]; fin[:-1, :] += f[1][1:, :]; fin[:, 1:] += f[2][:, :-1]; fin[:, :-1] += f[3][:, 1:]
    d += dt * (fin - f.sum(0) + src) / (l * l); np.maximum(d, 0, out=d)
out = {}
for N in (64, 256, 1024):
    x = np.arange(N)[:, None] * np.ones((1, N)); z = 10 - 0.3 * x + 0.5 * np.sin(np.arange(N) / 5.0)[None, :]
    k = np.full((N, N), 0.5); src = np.zeros((N, N)); src[2, N // 2] = 4.0; wall = np.zeros((N, N), int)
    t = time.perf_counter(); roz(z, k, src, wall, passes=10); tr = (time.perf_counter() - t) / 10 * 1000
    b = z * 0.5; d = np.zeros((N, N)); f = np.zeros((4, N, N)); s2 = src / 1000
    t = time.perf_counter()
    for _ in range(50): pipe_step(b, d, f, s2)
    tp = (time.perf_counter() - t) / 50 * 1000
    out[N] = {"rozliv_ms_pruchod": round(tr, 3), "mvoda_ms_krok": round(tp, 3)}
    print(N, out[N])
json.dump(out, open("shots/bench_plosne53_numpy.json", "w"), indent=1)
