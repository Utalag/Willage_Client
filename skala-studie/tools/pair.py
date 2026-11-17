#!/usr/bin/env python3
"""Spojí dva snímky vedle sebe s českými popisky: pair.py vlevo.png "popisek" vpravo.png "popisek" výstup.png"""
import sys
from PIL import Image, ImageDraw, ImageFont
a, la, b, lb, out = sys.argv[1:6]
A, B = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
im = Image.new("RGB", (A.width + B.width + 6, A.height), (70, 64, 90))
im.paste(A, (0, 0)); im.paste(B, (A.width + 6, 0))
dr = ImageDraw.Draw(im)
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
for x, t in ((12, la), (A.width + 18, lb)):
    dr.rectangle([x, 12, x + 16 + dr.textlength(t, font=f), 56], fill=(255, 255, 255))
    dr.text((x + 8, 16), t, fill=(60, 40, 90), font=f)
im.save(out); print(out)
