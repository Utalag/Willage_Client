#!/usr/bin/env python3
"""Spojí snímky 24_skala_<A–D><přípona>[_detail].png do mřížky 2 × 2 s českými popisky.
python3 tools/sheet.py [přípona] [výstupní jméno přehledu] [výstupní jméno detailu]"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots")
suf = sys.argv[1] if len(sys.argv) > 1 else ""
outs = [(sys.argv[2] if len(sys.argv) > 2 else "") or f"24_skala_srovnani{suf}.png",
        (sys.argv[3] if len(sys.argv) > 3 else "") or f"24_skala_detail{suf}.png"]
LABELS = {
    "A": "A – dnešní kostky + textura",
    "B": "B – kostky s rozbitím (zkosení, šum, vpadlé stěny)",
    "C": "C – souvislý povrch nad voxely (Surface Nets)",
    "D": "D – hybrid: kameny a balvany z Blenderu + skála C",
}
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
except OSError:
    font = small = ImageFont.load_default()
sub = sys.argv[4] if len(sys.argv) > 4 else ""
for detail, out in ((False, outs[0]), (True, outs[1])):
    ims = []
    for k in "ABCD":
        p = os.path.join(d, f"24_skala_{k}{suf}{'_detail' if detail else ''}.png")
        if os.path.exists(p):
            ims.append((k, Image.open(p).convert("RGB")))
    if not ims:
        continue
    w, h = ims[0][1].size
    g = 6
    sheet = Image.new("RGB", (2 * w + g, 2 * h + g), (70, 64, 90))
    dr = ImageDraw.Draw(sheet)
    for i, (k, im) in enumerate(ims):
        x, y = (i % 2) * (w + g), (i // 2) * (h + g)
        sheet.paste(im, (x, y))
        t = LABELS[k]
        dr.rectangle([x + 12, y + 12, x + 28 + dr.textlength(t, font=font), y + 56], fill=(255, 255, 255))
        dr.text((x + 20, y + 16), t, fill=(60, 40, 90), font=font)
    if sub:
        dr.rectangle([12, 2 * h + g - 50, 24 + dr.textlength(sub, font=small), 2 * h + g - 14], fill=(255, 255, 255))
        dr.text((18, 2 * h + g - 46), sub, fill=(60, 40, 90), font=small)
    sheet.save(os.path.join(d, out))
    print(out)
