#!/usr/bin/env python3
"""Svislé řezy (profily) bloku nebo ostrova (data z tools/rez_data.gd, spouští tools/rez_profil.sh; společný kód
tools/rez_spolecne.py jako rez_gif.py). 6 obrázků: 3 řezy kolmo na osu X (v 1/4, 1/2, 3/4 šířky) a 3 kolmo na osu Y,
všechny ve stejném měřítku (vodorovně metry podél řezu, svisle výška v m, buňka 1 × 0,5 m bez převýšení), a přehled 2 × 3.
Barvy plných id ze sdílené tabulky, česká legenda, černá = dutina. Tři různé věci, ať se nepletou:
  šrafa = rozsah podzemního tělesa (propustná hornina / krasové pásmo, kudy voda MŮŽE téct; samo o sobě suché),
  sytá modrá (poloprůhledná) = skutečná podzemní voda ze stavu řešiče podzemí (ostrov_voda.gd), do hladiny tělesa,
  tyrkysová = povrchová voda (tůň / koryto). Vzduch prázdný."""
import argparse, os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rez_spolecne as RS

ap = argparse.ArgumentParser()
ap.add_argument("data"); ap.add_argument("out", help="adresář výstupu")
ap.add_argument("--oblast", default="vse"); ap.add_argument("--podzemi", type=int, default=1)
ap.add_argument("--px", type=int, default=0, help="pixelů na 1 m vodorovně (0 = automaticky; svisle 0,5 m = px/2)")
ap.add_argument("--prehled_sirka", type=int, default=1500, help="šířka přehledu 2 × 3 v px")
a = ap.parse_args()
D = RS.Data(a.data, a.oblast, bool(a.podzemi))
fn, fb = RS.fonts(); fs, _ = RS.fonts(11)
S, B = D.grid()
W, H, NZv = D.W, D.H, D.zmax + 1
L = max(W, H)
px = a.px or max(8, min(40, 640 // L))
pv = px / 2.0                       # buňka 0,5 m vysoká → bez převýšení
SKY = (236, 240, 246); WATER = (40, 190, 215)          # povrchová voda: tyrkysová
GW = (20, 50, 190, 150)                                 # stojatá podzemní voda: sytá modrá, poloprůhledná
FLOW = (110, 190, 255, 170)                             # protékající podzemní voda (E67 pretok): světle modrá
RED = (230, 40, 40)
def onm(typ): return "pramen" if typ == "povrch" else "vodopád na okraji"
HATCH = {1: (255, 255, 255, 150), 2: (255, 255, 255, 90)}   # šrafa tělesa (největší / jiné)
ML, MT, MB, LW = 56, 64, 40, 370    # okraje: vlevo osa z, nahoře titulek, dole osa polohy, vpravo legenda
pw, ph = int(L * px), int(NZv * pv)

def hatch(d, x, y, w, h, c, step=6):
    """diagonální šrafa (/) v obdélníku, fáze podle absolutní polohy → navazuje přes buňky"""
    x, y, w, h = int(x), int(y), int(round(w)), int(round(h))
    for k in range(-((x + y) % step), w + h, step):
        x1, y1 = x + max(0, k - h + 1), y + h - 1 - max(0, h - 1 - k) if k < h else y
        pts = []
        for t in range(max(0, k - h + 1), min(w, k + 1)):
            pts.append((x + t, y + h - 1 - (k - t)))
        if pts: d.line([pts[0], pts[-1]], fill=c, width=1)
os.makedirs(a.out, exist_ok=True)
frac = [(1, 4, "1/4"), (1, 2, "1/2"), (3, 4, "3/4")]
paths = []
def render(osa, k, lab, fname, popis=None):
    """jeden svislý řez: osa X = pevné x = k (profil podél Y), osa Y = pevné y = k; vrací cestu k PNG"""
    m_along = H if osa == "X" else W
    im = Image.new("RGB", (ML + pw + 20 + LW, MT + ph + MB), (250, 250, 252))
    dr = ImageDraw.Draw(im)
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); do = ImageDraw.Draw(ov)
    dr.rectangle([ML, MT, ML + pw, MT + ph], fill=SKY)
    has_gw = False; gw_lv = []; has_fl = [False]
    cnt = {}; has_w = False; has_c = False; has_b = False
    for t in range(m_along):
        x, y = (k, t) if osa == "X" else (t, k)
        col = S[x, y]
        top = -1
        gwc = D.gw.get("%d,%d" % (D.x0 + x, D.y0 + y))
        bodies_col = {}
        for z in range(NZv):
            v = int(col[z])
            if v < 0: continue
            top = z
            c = D.color(v)
            if v == 0: has_c = True
            X0 = ML + t * px; Y1 = MT + ph - z * pv
            dr.rectangle([X0, Y1 - pv, X0 + px - 1, Y1 - 1], fill=c)
            b = int(B[x, y, z])
            if b:
                has_b = True
                hatch(do, X0, Y1 - pv, px, pv, HATCH[b])
            cnt[v] = cnt.get(v, 0) + 1
        zt = (top + 1) * 0.5
        for lo, hi in D.film.get("%d,%d" % (D.x0 + x, D.y0 + y), []):   # protékající voda: film u dna mokrého pásma
            hi = min(hi, zt)
            if hi - lo <= 1e-3: continue
            ya, yb = MT + ph - hi * 2 * pv, MT + ph - lo * 2 * pv - 1
            do.rectangle([ML + t * px, ya, ML + t * px + px - 1, max(ya, yb)], fill=FLOW); has_fl[0] = True
        # stojatá podzemní voda: pásma od spodku po hladinu (stav řešiče), oříznuté terénem
        for lo, hi, bi in (gwc or []):
            hi = min(hi, zt)
            if hi - lo <= 1e-3: continue
            ya, yb = MT + ph - hi * 2 * pv, MT + ph - lo * 2 * pv - 1
            do.rectangle([ML + t * px, ya, ML + t * px + px - 1, max(ya, yb)], fill=GW); has_gw = True
            gw_lv.append((bi, t))
        w = D.voda.get("%d,%d" % (D.x0 + x, D.y0 + y))
        if w and top >= 0:
            lv, pond = w
            y_top = MT + ph - (top + 1) * pv
            y_w = MT + ph - lv * pv
            if y_top - y_w < 3: y_w = y_top - 3           # koryto: tenká vrstva, aspoň 3 px
            dr.rectangle([ML + t * px, y_w, ML + t * px + px - 1, y_top - 1], fill=WATER); has_w = True
    im.paste(Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")); dr = ImageDraw.Draw(im)
    # hladina každé stojaté vody (čárkovaně přes sloupce, kde v řezu drží vodu) a výstupy (pramen / vodopád na okraji)
    notes = []
    per = {}
    for (bi, t) in gw_lv: per.setdefault(bi, set()).add(t)
    for n_, (bi, ts) in enumerate(sorted(per.items(), key=lambda e: -len(e[1]))):
        hl = D.hl[bi]; yl_ = MT + ph - hl["hladina"] * 2 * pv
        for t in sorted(ts):
            for xx in range(ML + t * px, ML + t * px + px, 8):
                dr.line([xx, yl_, min(xx + 4, ML + t * px + px - 1), yl_], fill=(0, 20, 120), width=2)
        if n_ < 3:
            dr.text((ML + min(ts) * px + 3, yl_ - 15), "%.2f m (%s)" % (hl["hladina"], hl["typ"]), font=fs, fill=(0, 20, 120))
    off = 0
    for (ox, oy, oz, typ, oq) in D.vy:
        on = (ox == D.x0 + k) if osa == "X" else (oy == D.y0 + k)
        tt = (oy - D.y0) if osa == "X" else (ox - D.x0)
        if on and 0 <= tt < m_along:
            cx = ML + tt * px + px / 2; cy = MT + ph - oz * 2 * pv
            dr.polygon([(cx, cy - 2), (cx - 7, cy - 14), (cx + 7, cy - 14)], fill=RED, outline=(90, 0, 0))
            if len(notes) < 3: notes.append("▼ %s (%d, %d) ve %.2f m, %.3f l/s" % (onm(typ), ox, oy, oz, oq))
        else: off += 1
    if off and D.vy: notes.append("dalších %d výstupů mimo řez (%s)" % (off, "pretok, E67" if D.rezim == "pretok" else "staré podzemí"))
    for i, nt in enumerate(notes[:4]):
        dr.text((ML + 4, MT + 4 + i * 15), nt, font=fs, fill=(150, 0, 0) if nt.startswith("▼") else (0, 20, 120))
    # švy bloků, osy
    for s in range(0, m_along + 1, RS.BS):
        dr.line([ML + s * px, MT, ML + s * px, MT + ph], fill=(120, 120, 130))
    dr.rectangle([ML, MT, ML + pw, MT + ph], outline=(60, 60, 70))
    for zm in range(0, int(NZv * 0.5) + 1, 2):
        yy = MT + ph - zm * 2 * pv
        dr.line([ML - 5, yy, ML, yy], fill=(40, 40, 50)); dr.text((ML - 8, yy - 7), "%d" % zm, font=fs, fill=(40, 40, 50), anchor="ra")
    dr.text((6, MT - 16), "výška (m)", font=fs, fill=(40, 40, 50))
    st = 4 if m_along <= 16 else 8
    a0 = D.y0 if osa == "X" else D.x0
    for t in range(0, m_along + 1, st):
        xx = ML + t * px
        dr.line([xx, MT + ph, xx, MT + ph + 5], fill=(40, 40, 50)); dr.text((xx, MT + ph + 7), "%d" % (a0 + t), font=fs, fill=(40, 40, 50), anchor="ma")
    dr.text((ML + pw // 2, MT + ph + 22), "%s (souřadnice ostrova, m)" % ("y" if osa == "X" else "x"), font=fs, fill=(40, 40, 50), anchor="ma")
    kc = (D.x0 if osa == "X" else D.y0) + k
    kde = ("v %s %s" % (lab, "bloku" if a.oblast != "vse" else "ostrova")) if lab else "přes výstup podzemní vody"
    dr.text((8, 8), "Řez %s kolmo na osu %s %s: %s = %d, profil podél %s" % (D.title, osa, kde, osa.lower(), kc, "Y" if osa == "X" else "X"),
            font=fb, fill=(20, 20, 30))
    dr.text((8, 30), "stejné měřítko všech 6 řezů: 1 m = %d px vodorovně i svisle (buňka 1 × 0,5 m), bez převýšení" % px, font=fs, fill=(90, 90, 100))
    dr.text((ML + pw + 20, MT), "Materiály v řezu (buněk):", font=fn, fill=(20, 20, 30))
    yl = D.legend(dr, ML + pw + 20, MT + 20, cnt, fn) + 8
    xl = ML + pw + 20
    def sw(y, kind, text, sub=None):
        sim = Image.new("RGBA", (15, 15), (150, 150, 150, 255)); sd = ImageDraw.Draw(sim)
        if kind == "h1": hatch(sd, 0, 0, 15, 15, HATCH[1])
        elif kind == "h2": hatch(sd, 0, 0, 15, 15, HATCH[2])
        elif kind == "gw": hatch(sd, 0, 0, 15, 15, HATCH[1]); sd.rectangle([0, 0, 14, 14], fill=GW)
        else: sd.rectangle([0, 0, 14, 14], fill=kind)
        im.paste(Image.alpha_composite(Image.new("RGBA", (15, 15), (150, 150, 150, 255)), sim).convert("RGB"), (xl, y))
        dr.rectangle([xl, y, xl + 14, y + 14], outline=(80, 80, 80))
        dr.text((xl + 20, y), text, font=fn, fill=(20, 20, 30)); y += 17
        if sub: dr.text((xl + 20, y), sub, font=fs, fill=(90, 90, 100)); y += 15
        return y + 2
    dr.text((xl, yl), "Voda vs. propustná hornina:", font=fn, fill=(20, 20, 30)); yl += 20
    if has_b:
        yl = sw(yl, "h1", "šrafa = podzemní těleso (největší)", "propustná hornina / kras, kudy voda může téct – NE voda")
        yl = sw(yl, "h2", "slabší šrafa = jiné podzemní těleso")
    if D.gw or D.film or D.vy:
        yl = sw(yl, "gw", "sytá modrá = stojatá podzemní voda",
                ("vana jen v uzavřené misce, po práh / do výstupu" if D.rezim == "pretok" else "výplň tělesa po hladinu (staré podzemí)") if has_gw else "v tomto řezu žádná (stav řešiče podzemí)")
        if D.rezim == "pretok":
            yl = sw(yl, FLOW, "světle modrá = protékající podzemní voda", "jen pásma, kudy voda opravdu teče (film u dna)" if has_fl[0] else "v tomto řezu žádná")
        yl = sw(yl, (0, 20, 120), "čárkovaně = hladina stojaté vody")
        yl = sw(yl, RED, "▼ výstup: pramen / vodopád na okraji", "vodopád = vývěr ve stěně ostrova do mlhy")
    else:
        yl = sw(yl, (200, 200, 200), "podzemní voda: stav řešiče není k dispozici", "(spusť s --voda=1 a --podzemi=1)")
    if has_w or D.voda: yl = sw(yl, WATER, "tyrkysová = povrchová voda (tůň / koryto)", None if has_w else "v tomto řezu žádná")
    yl = sw(yl, (17, 17, 17), "černá = dutina (jeskyně), suchá")
    yl = sw(yl, SKY, "vzduch")
    fp = os.path.join(a.out, fname)
    im.save(fp)
    return fp

for osa in ("X", "Y"):
    n = W if osa == "X" else H
    for (p, q, lab) in frac:
        paths.append(render(osa, min(n * p // q, n - 1), lab, "rez_%s_%s.png" % (osa.lower(), lab.replace("/", ""))))
# výstupy těles (pramen / vodopád na okraji), které neleží na žádném z 6 řezů → navíc řez kolmo na X přes výstup
extra_paths = []
cutx = [min(W * p // q, W - 1) for (p, q, _) in frac]; cuty = [min(H * p // q, H - 1) for (p, q, _) in frac]
done_x = set()
for (ox, oy, oz, typ, oq) in D.vy:          # nejsilnější výstupy (nejvýš 2), které neleží na žádném z 6 řezů
    if len(extra_paths) >= 2: break
    ox -= D.x0; oy -= D.y0
    if not (0 <= ox < W and 0 <= oy < H) or ox in cutx or oy in cuty or ox in done_x: continue
    done_x.add(ox)
    extra_paths.append(render("X", ox, None, "rez_vystup_%d.png" % (len(extra_paths) + 1)))
# přehled 2 × 3 (řádek X, řádek Y) + třetí řádek: půdorys (řezy, výstupy těles) a řezy přes výstupy
def pudorys(size):
    c = max(2, (size - 64) // max(W, H))
    im = Image.new("RGB", (size, size), (250, 250, 252)); d = ImageDraw.Draw(im)
    X0, Y0 = 46, 30
    for x in range(W):
        for y in range(H):
            col = S[x, y]; zz = [z for z in range(NZv) if col[z] > 0]
            if not zz: continue
            cc = D.color(int(col[zz[-1]]))
            w = D.voda.get("%d,%d" % (D.x0 + x, D.y0 + y))
            if w: cc = WATER
            d.rectangle([X0 + x * c, Y0 + y * c, X0 + x * c + c - 1, Y0 + y * c + c - 1], fill=cc)
    for (p, q, lab) in frac:
        kx = min(W * p // q, W - 1); ky = min(H * p // q, H - 1)
        d.line([X0 + kx * c + c // 2, Y0, X0 + kx * c + c // 2, Y0 + H * c], fill=(200, 0, 120), width=2)
        d.text((X0 + kx * c + c // 2, Y0 - 14), "X " + lab, font=fs, fill=(200, 0, 120), anchor="ma")
        d.line([X0, Y0 + ky * c + c // 2, X0 + W * c, Y0 + ky * c + c // 2], fill=(120, 0, 200), width=2)
        d.text((X0 - 4, Y0 + ky * c + c // 2), "Y " + lab, font=fs, fill=(120, 0, 200), anchor="rm")
    for n_, (ox, oy, oz, typ, oq) in enumerate(D.vy):
        ox -= D.x0; oy -= D.y0
        if not (0 <= ox < W and 0 <= oy < H): continue
        cx, cy = X0 + ox * c + c / 2, Y0 + oy * c + c / 2; r_ = 7 if n_ < 3 else 4
        d.polygon([(cx, cy + 3), (cx - r_, cy - 2 * r_), (cx + r_, cy - 2 * r_)], fill=RED if typ == "povrch" else (255, 150, 0), outline=(90, 0, 0))
    d.text((X0, size - 16), "půdorys (x →, y ↓): čáry = řezy, ▼ červená = pramen, oranžová = vodopád na okraji", font=fs, fill=(40, 40, 50))
    return im
ims = [Image.open(p) for p in paths]
cw = a.prehled_sirka // 3
sc = cw / ims[0].width
chh = int(ims[0].height * sc)
row3 = [pudorys(min(cw, max(chh, 300)))] + [Image.open(p_) for p_ in extra_paths[:2]]
r3h = max(chh, row3[0].height)
ov = Image.new("RGB", (cw * 3, chh * 2 + 36 + r3h), (250, 250, 252))
dov = ImageDraw.Draw(ov)
npr = sum(1 for v in D.vy if v[3] == "povrch"); nok = len(D.vy) - npr
qpr = sum(v[4] for v in D.vy if v[3] == "povrch"); qok = sum(v[4] for v in D.vy if v[3] != "povrch")
vany = [h_ for h_ in D.hl if h_["objem_m3"] > 0]
gwi = ("[ukázkové zdroje: 0,02 l/s v každém místním minimu povrchu] " if D.zdroje == "minima" else "") + "%s: %d stojatých vod (největší %s), výstupy: %d pramenů %.2f l/s, %d vodopádů na okraji %.2f l/s" % (
    "přetoky ve 3D (E67)" if D.rezim == "pretok" else "staré podzemí (vana tělesa)", len(vany),
    ", ".join("%.2f m %s %.1f m³" % (h_["hladina"], h_["typ"], h_["objem_m3"]) for h_ in sorted(vany, key=lambda e: -e["objem_m3"])[:2]) or "–",
    npr, qpr, nok, qok) + (" (+%d slabších < 1 ml/s)" % D.vy_slabe if D.vy_slabe else "")
dov.text((8, 4), "Svislé řezy – %s: nahoře kolmo na X (1/4, 1/2, 3/4), uprostřed kolmo na Y, dole půdorys%s" % (D.title, " a řez přes výstup" if extra_paths else ""), font=fb, fill=(20, 20, 30))
dov.text((8, 22), "podzemní voda (stav řešiče): " + (gwi or "žádné těleso s vodou"), font=fs, fill=(0, 20, 120))
for i, im in enumerate(ims):
    ov.paste(im.resize((cw, chh), Image.LANCZOS), ((i % 3) * cw, 36 + (i // 3) * chh))
for j, im in enumerate(row3):
    if j > 0: im = im.resize((cw, chh), Image.LANCZOS)
    ov.paste(im, (j * cw, 36 + 2 * chh))
pp = os.path.join(a.out, "prehled.png"); ov.save(pp)
print("uloženo %d řezů%s + přehled do %s (1 m = %d px)" % (len(paths), (" + %d přes výstup" % len(extra_paths)) if extra_paths else "", a.out, px))
