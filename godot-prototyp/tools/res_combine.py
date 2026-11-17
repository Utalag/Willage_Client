#!/usr/bin/env python3
"""Spojí dvojice shots/23_rozliseni_*_L.png + _R.png (z režimu --res-test) do jednoho obrázku s popisky."""
import glob, os, re, sys
from PIL import Image, ImageDraw, ImageFont
d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
except OSError:
    font = ImageFont.load_default()
def label(tag):
    m = re.match(r"(\d+)(?:x(\d+)_c([\d.]+)x([\d.]+))?", tag)
    n = int(m.group(1))
    if m.group(2):
        return f"{n}×{n}×{m.group(2)}, buňka {m.group(3)}×{m.group(3)}×{m.group(4)}"
    c = 16 / n
    return f"{n}×{n}×64, buňka {c:g}×{c:g}×0,5"
for L in sorted(glob.glob(os.path.join(d, "23_rozliseni_*_L.png"))):
    R = L[:-6] + "_R.png"
    out = L[:-6] + ".png"
    m = re.search(r"23_rozliseni_(.+?)_vs_(.+?)_(hora|kopec|louka|piscina)", os.path.basename(L))
    a, b = Image.open(L).convert("RGB"), Image.open(R).convert("RGB")
    im = Image.new("RGB", (a.width + b.width + 8, a.height), (60, 60, 80))
    im.paste(a, (0, 0)); im.paste(b, (a.width + 8, 0))
    dr = ImageDraw.Draw(im)
    for x, t in ((20, label(m.group(1))), (a.width + 28, label(m.group(2)))):
        dr.rectangle([x - 8, 14, x + dr.textlength(t, font=font) + 8, 56], fill=(255, 255, 255))
        dr.text((x, 18), t, fill=(60, 40, 90), font=font)
    im.save(out)
    os.remove(L); os.remove(R)
    print(os.path.basename(out))
