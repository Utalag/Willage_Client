#!/usr/bin/env python3
"""Příprava dlaždic textur (OFFLINE příprava assetů – výjimka z pravidla „jen C#“, Jan 23:14; do hry ani pipeline světa nejde). Pillow + numpy (celá čísla).

PNG/JPEG → bezešvá neprůhledná dlaždice 128×128 RGBA8:
  1. střed čtverce (nejdelší centrovaný čtverec; --roztahnout = bez ořezu),
  2. zmenšení / zvětšení plošným průměrem (box filtr) v celých číslech (bez mezizaokrouhlení, deterministické),
  3. bezešvost posunem o půl dlaždice a lineárním prolnutím po osách (nejdřív X, pak Y): váha posunutého obrazu
     w = d·256/63 (d = vzdálenost sloupce / řádku od středu 0…63) → na okraji jen posunutý obraz (spojitý přes okraj),
     ve středu jen původní (šev posunutého obrazu tam má váhu 0),
  4. alfa 255 (RGB se ponechá, průhlednost vstupu se zahodí),
  5. výstup PNG + SHA-256 souboru PNG a SHA-256 surových RGBA8 bajtů (nezávislé na kodéru PNG – pro porovnání s budoucí implementací v C# / Dev).

Použití: python3 tools/priprava_dlazdic.py vstup.png[=jméno] […] -o slozka [--velikost 128] [--roztahnout] [--manifest m.json]
Výstup: <slozka>/<jméno>.png (bez „=jméno“: <stem>-dlazdice128.png), řádek „jméno  sha256_png  sha256_rgba“
(i do <slozka>/dlazdice.sha256.txt) a volitelně manifest JSON (zdroj + jeho SHA-256, rozměry, sha256 RGBA8, pngSha256).
"""
import argparse, hashlib, json, os, sys
import numpy as np
from PIL import Image


def ctverec(im, roztahnout):
    w, h = im.size
    if roztahnout or w == h:
        return im
    s = min(w, h)
    x0, y0 = (w - s) // 2, (h - s) // 2
    return im.crop((x0, y0, x0 + s, y0 + s))


def vahy(src, dst):
    """Matice vah dst×src: výstupní pixel x pokrývá [x·src, (x+1)·src), zdrojový i [i·dst, (i+1)·dst) – překryv v celých číslech."""
    m = np.zeros((dst, src), dtype=np.int64)
    for x in range(dst):
        a, b = x * src, (x + 1) * src
        for i in range(a // dst, min(src, (b + dst - 1) // dst)):
            ov = min(b, (i + 1) * dst) - max(a, i * dst)
            if ov > 0:
                m[x, i] = ov
    return m


def plosny_prumer(rgb, n):
    """Box filtr (plošný průměr) v celých číslech: součet Wy·P·Wxᵀ bez mezizaokrouhlení, pak (součet + tot/2) // tot."""
    h, w, _ = rgb.shape
    wx, wy = vahy(w, n), vahy(h, n)
    tot = w * h
    out = np.empty((n, n, 3), dtype=np.int64)
    for c in range(3):
        out[:, :, c] = wy @ rgb[:, :, c].astype(np.int64) @ wx.T
    return (out + tot // 2) // tot


def prolni_osu(px, osa):
    """Prolnutí s obrazem posunutým o n/2 po ose (1 = X / sloupce, 0 = Y / řádky); váha posunutého w = d·256 // (n/2 − 1)."""
    n = px.shape[0]; h = n // 2
    t = np.arange(n)
    d = np.where(t < h, h - 1 - t, t - h)
    w = (d * 256) // (h - 1)
    w = w[None, :, None] if osa == 1 else w[:, None, None]
    b = np.roll(px, -h, axis=osa)  # b[x] = px[(x + h) % n]
    return (px * (256 - w) + b * w + 128) >> 8


def priprav(cesta, n=128, roztahnout=False):
    im = ctverec(Image.open(cesta).convert('RGB'), roztahnout)
    px = plosny_prumer(np.asarray(im, dtype=np.uint8), n)
    px = prolni_osu(prolni_osu(px, 1), 0)  # nejdřív X, pak Y
    rgba = np.empty((n, n, 4), dtype=np.uint8)
    rgba[:, :, :3] = px; rgba[:, :, 3] = 255
    return rgba.tobytes()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('vstupy', nargs='+'); ap.add_argument('-o', '--vystup', required=True)
    ap.add_argument('--velikost', type=int, default=128); ap.add_argument('--roztahnout', action='store_true')
    ap.add_argument('--manifest')
    a = ap.parse_args()
    if a.velikost % 2 or a.velikost < 4: sys.exit('velikost musí být sudá ≥ 4')
    os.makedirs(a.vystup, exist_ok=True)
    ap_m = a.manifest
    radky, polozky = [], []
    for spec in a.vstupy:
        v, _, jm = spec.partition('=')
        jm = jm or os.path.splitext(os.path.basename(v))[0] + f'-dlazdice{a.velikost}'
        rgba = priprav(v, a.velikost, a.roztahnout)
        out = os.path.join(a.vystup, f'{jm}.png')
        Image.frombytes('RGBA', (a.velikost, a.velikost), rgba).save(out, optimize=False)
        sp, sr = hashlib.sha256(open(out, 'rb').read()).hexdigest(), hashlib.sha256(rgba).hexdigest()
        radek = f'{jm}  png {sp}  rgba {sr}'
        print(radek); radky.append(radek)
        polozky.append({'soubor': os.path.basename(out), 'format': 'rgba8', 'widthPx': a.velikost, 'heightPx': a.velikost,
                        'sha256': sr, 'pngSha256': sp,
                        'zdroj': {'soubor': os.path.basename(v), 'sha256': hashlib.sha256(open(v, 'rb').read()).hexdigest()}})
    with open(os.path.join(a.vystup, 'dlazdice.sha256.txt'), 'w') as f:
        f.write('\n'.join(radky) + '\n')
    if ap_m:
        with open(ap_m, 'w', encoding='utf-8') as f:
            json.dump({'nastroj': 'tools/priprava_dlazdic.py', 'postup': f'střed čtverce, box filtr na {a.velikost}, prolnutí posunem o půl (X pak Y), alfa 255',
                       'dlazdice': polozky}, f, ensure_ascii=False, indent=2); f.write('\n')

if __name__ == '__main__':
    main()
