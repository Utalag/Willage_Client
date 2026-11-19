#!/usr/bin/env python3
"""Řezy ostrova / bloku po vrstvách → animovaný GIF (data z tools/rez_data.gd, spouští tools/rez_gif.sh).
--pohled=izo (výchozí): izometrický voxelový obraz (Pillow, malířův algoritmus, 3 stínované stěny na viditelnou buňku, bez GPU)
všech buněk odspodu po řez z (roste po --krok), horní stěna = plocha řezu; --smer=dolu ukáže buňky od z nahoru po povrch.
--pohled=shora: plochý řez shora. Každý snímek = vodorovný řez ve výšce z (buňky po 0,5 m) shora: barva = materiál buňky (paleta sdílené tabulky),
černá = dutina pod povrchem, světlé pozadí = vzduch nad terénem, modře šrafované = pásmo podzemního tělesa
(tmavší = největší těleso). Vpravo legenda materiálů v řezu (česky) s počtem buněk."""
import argparse, base64, json, os
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("data"); ap.add_argument("out")
ap.add_argument("--oblast", default="vse", help="vse | x,y (slot bloku ostrova)")
ap.add_argument("--krok", type=int, default=2); ap.add_argument("--ms", type=int, default=750)
ap.add_argument("--px", type=int, default=0, help="pixelů na buňku (0 = automaticky)")
ap.add_argument("--podzemi", type=int, default=1); ap.add_argument("--od", type=int, default=0)
ap.add_argument("--pohled", default="izo", choices=["izo", "shora"]); ap.add_argument("--smer", default="nahoru", choices=["nahoru", "dolu"])
a = ap.parse_args()
d = json.load(open(a.data))
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
fn = ImageFont.truetype(F, 13); fb = ImageFont.truetype(F.replace("Sans.ttf", "Sans-Bold.ttf"), 16)
BS, NZ = 16, 64
blocks = {}
for b in d["bloky"]:
    if a.oblast != "vse" and tuple(b["slot"]) != tuple(int(v) for v in a.oblast.split(",")):
        continue
    blocks[tuple(b["slot"])] = (base64.b64decode(b["geo"]), b["hm"], b)
if not blocks:
    raise SystemExit("oblast %s: žádný blok" % a.oblast)
sx = [s[0] for s in blocks]; sy = [s[1] for s in blocks]
x0, y0 = min(sx) * BS, min(sy) * BS
W, H = (max(sx) - min(sx) + 1) * BS, (max(sy) - min(sy) + 1) * BS
px = a.px or (max(4, min(24, 640 // max(W, H))) if a.pohled == "shora" else max(4, min(14, 340 // max(W, H))))
col = {int(k): "#" + v[:6] for k, v in d["barvy"].items()}
names = {int(k): v for k, v in d["nazvy"].items()}
ug = d.get("podzemi", {}).get("sloupce", {}) if a.podzemi else {}
zmax = max(max(hm) for _, hm, _ in blocks.values())
LW = 300
title = "ostrov" if a.oblast == "vse" else "blok %s (%s %d)" % (a.oblast, list(blocks.values())[0][2]["typ"], list(blocks.values())[0][2]["seed"])

def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def izo_frames():
    import numpy as np
    NZv = zmax + 1
    S = np.zeros((W, H, NZv), dtype=np.int16) - 1          # -1 = mimo blok / vzduch nad terénem, 0 = dutina, jinak id
    B = np.zeros((W, H, NZv), dtype=np.uint8)              # 1 = pásmo největšího tělesa, 2 = jiné těleso
    for (s_, (geo, hm, _)) in blocks.items():
        g = np.frombuffer(geo, dtype=np.uint8).reshape(BS, BS, NZ)
        for lx in range(BS):
            for ly in range(BS):
                X = s_[0] * BS + lx - x0; Y = s_[1] * BS + ly - y0; h = hm[lx * BS + ly]
                S[X, Y, :min(h, NZv)] = g[lx, ly, :min(h, NZv)]
                if ug:
                    for lo, hi, big in ug.get("%d,%d" % (s_[0] * BS + lx, s_[1] * BS + ly), []):
                        z0 = max(int(lo / 0.5 + 1e-6), 0); z1 = min(int(np.ceil(hi / 0.5 - 1e-6)), NZv)
                        sl = B[X, Y, z0:z1]; B[X, Y, z0:z1] = np.where((sl == 0) | (sl > big), big, sl)
    pal = {m: np.array(hexrgb(c), dtype=float) for m, c in col.items()}
    ax_, by_ = px, px / 2.0; cz = px * 0.62                # 1 buňka = 1 × 1 × 0,5 m
    ox = H * ax_ + 10; oy = 50 + NZv * cz
    iw = int((W + H) * ax_ + 20); ih = int(oy + (W + H) * by_ + 20)
    P = lambda X, Y, Z: (ox + (X - Y) * ax_, oy + (X + Y) * by_ - Z * cz)
    cuts = list(range(a.od + a.krok, zmax + a.krok + 1, a.krok)) if a.smer == "nahoru" else list(range(a.od, zmax + 1, a.krok))
    out = []
    order = sorted(((x, y) for x in range(W) for y in range(H)), key=lambda e: (e[0] + e[1], e[0]))
    for zc in cuts:
        if a.smer == "nahoru":
            zlo, zhi = 0, min(zc, NZv)
        else:
            zlo, zhi = zc, NZv
        V = np.zeros((W + 1, H + 1, NZv + 1), dtype=bool)  # viditelná plná buňka (dutina na řezu = černá buňka)
        sub = S[:, :, zlo:zhi]
        solid = sub > 0
        if zhi > zlo:
            cavecut = (sub[:, :, -1] == 0) if a.smer == "nahoru" else (sub[:, :, 0] == 0)
            V[:W, :H, zlo:zhi] = solid
            if a.smer == "nahoru": V[:W, :H, zhi - 1] |= cavecut
            else: V[:W, :H, zlo] |= cavecut
        im = Image.new("RGB", (iw + LW, max(ih, 420)), (236, 240, 246))
        dr = ImageDraw.Draw(im)
        cnt = {}
        for (x, y) in order:
            col_ = V[x, y]
            zs = np.nonzero(col_[zlo:zhi])[0]
            for zi in zs:
                z = zlo + zi
                m = int(S[x, y, z])
                top = not V[x, y, z + 1]; fx = not V[x + 1, y, z]; fy = not V[x, y + 1, z]
                if not (top or fx or fy):
                    continue
                c = np.array((17, 17, 17), dtype=float) if m == 0 else pal.get(m, np.array((255, 0, 255), dtype=float))
                if ug and m != 0 and B[x, y, z]:
                    c = c * 0.55 + np.array((30, 90, 220)) * (0.45 if B[x, y, z] == 1 else 0.25)
                if (a.smer == "nahoru" and z == zhi - 1) or (a.smer == "dolu" and z == zlo):
                    cnt[m] = cnt.get(m, 0) + 1
                if fx:
                    dr.polygon([P(x + 1, y, z), P(x + 1, y + 1, z), P(x + 1, y + 1, z + 1), P(x + 1, y, z + 1)], fill=tuple(int(v) for v in c * 0.78))
                if fy:
                    dr.polygon([P(x, y + 1, z), P(x + 1, y + 1, z), P(x + 1, y + 1, z + 1), P(x, y + 1, z + 1)], fill=tuple(int(v) for v in c * 0.6))
                if top:
                    dr.polygon([P(x, y, z + 1), P(x + 1, y, z + 1), P(x + 1, y + 1, z + 1), P(x, y + 1, z + 1)], fill=tuple(int(v) for v in c))
        zz = zhi - 1 if a.smer == "nahoru" else zlo
        dr.text((8, 10), "Řez %s (izometrie): %s z = %d (výška %.1f m)%s" % (title, "buňky 0 až" if a.smer == "nahoru" else "buňky od", zz, (zz + 1) * 0.5 if a.smer == "nahoru" else zz * 0.5,
                "" if a.smer == "nahoru" else " nahoru"), font=fb, fill=(20, 20, 30))
        lx0 = iw + 8; ly = 46
        dr.text((lx0, ly), "Materiály na ploše řezu (buněk):", font=fn, fill=(20, 20, 30)); ly += 20
        for m, n in sorted(cnt.items(), key=lambda e: -e[1])[:16]:
            c = "#111111" if m == 0 else col.get(m, "#ff00ff")
            dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=c, outline=(80, 80, 80))
            dr.text((lx0 + 20, ly), "%s (%d) %d" % (names.get(m, "id %d" % m)[:28], m, n), font=fn, fill=(20, 20, 30)); ly += 18
        if ug:
            ly += 8
            dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=(90, 120, 200)); dr.text((lx0 + 20, ly), "modrý nádech = největší podz. těleso", font=fn, fill=(20, 20, 30)); ly += 18
            dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=(150, 165, 210)); dr.text((lx0 + 20, ly), "slabší nádech = jiné těleso", font=fn, fill=(20, 20, 30)); ly += 18
        dr.text((lx0, ly + 8), "černá = dutina na řezu (jinde prázdná)", font=fn, fill=(90, 90, 100))
        out.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
    return out

frames = []
if a.pohled == "izo":
    frames = izo_frames()
for z in (list(range(a.od, zmax + 1, a.krok)) if a.pohled == "shora" else []):
    im = Image.new("RGB", (W * px + LW, max(H * px, 360) + 40), (236, 240, 246))
    dr = ImageDraw.Draw(im)
    cnt = {}
    hat = Image.new("RGBA", im.size, (0, 0, 0, 0)); dh = ImageDraw.Draw(hat)
    zm = (z + 0.5) * 0.5
    for (s, (geo, hm, _)) in blocks.items():
        for lx in range(BS):
            for ly in range(BS):
                gx = s[0] * BS + lx; gy = s[1] * BS + ly
                X = (gx - x0) * px; Y = 40 + (gy - y0) * px
                ci = lx * BS + ly
                if z >= hm[ci]:
                    continue   # vzduch nad terénem
                m = geo[ci * NZ + z]
                c = "#111111" if m == 0 else col.get(m, "#ff00ff")
                dr.rectangle([X, Y, X + px - 1, Y + px - 1], fill=c)
                cnt[m] = cnt.get(m, 0) + 1
                for lo, hi, big in ug.get("%d,%d" % (gx, gy), []):
                    if lo <= zm < hi:
                        dh.rectangle([X, Y, X + px - 1, Y + px - 1], fill=(30, 90, 220, 110 if big == 1 else 60))
                        for k in range(-px, px, max(3, px // 3)):
                            dh.line([X + max(k, 0), Y + max(-k, 0), X + min(px - 1, px - 1 + k), Y + min(px - 1, px - 1 - k)], fill=(255, 255, 255, 90))
                        break
    im.paste(hat, (0, 0), hat)
    for k in range(0, W + 1, BS):
        dr.line([k * px, 40, k * px, 40 + H * px], fill=(60, 60, 60))
    for k in range(0, H + 1, BS):
        dr.line([0, 40 + k * px, W * px, 40 + k * px], fill=(60, 60, 60))
    dr.text((8, 10), "Řez %s: z = %d (výška %.1f–%.1f m), krok %d" % (title, z, z * 0.5, z * 0.5 + 0.5, a.krok), font=fb, fill=(20, 20, 30))
    lx0 = W * px + 12; ly = 46
    dr.text((lx0, ly), "Materiály v řezu (buněk):", font=fn, fill=(20, 20, 30)); ly += 20
    for m, n in sorted(cnt.items(), key=lambda e: -e[1])[:16]:
        c = "#111111" if m == 0 else col.get(m, "#ff00ff")
        dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=c, outline=(80, 80, 80))
        dr.text((lx0 + 20, ly), "%s (%d) %d" % (names.get(m, "id %d" % m)[:28], m, n), font=fn, fill=(20, 20, 30)); ly += 18
    if ug:
        ly += 8
        dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=(120, 150, 225)); dr.text((lx0 + 20, ly), "pásmo největšího podz. tělesa", font=fn, fill=(20, 20, 30)); ly += 18
        dr.rectangle([lx0, ly, lx0 + 14, ly + 14], fill=(185, 200, 235)); dr.text((lx0 + 20, ly), "jiné podzemní těleso", font=fn, fill=(20, 20, 30)); ly += 18
    dr.text((lx0, ly + 8), "černá = dutina, světlá = vzduch nad terénem", font=fn, fill=(90, 90, 100))
    frames.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
frames[0].save(a.out, save_all=True, append_images=frames[1:], duration=a.ms, loop=0, optimize=False)
print("uloženo %s (%d snímků, %s, z %d..%d po %d, %.1f MB)" % (a.out, len(frames), a.pohled, a.od, zmax, a.krok, os.path.getsize(a.out) / 1e6))
