# dvojice screenshotů vedle sebe s popisky: python3 objekty_srovnani.py a.png b.png out.png "popis a" "popis b"
import sys
from PIL import Image, ImageDraw, ImageFont
a, b, out, ta, tb = sys.argv[1:6]
box = (0, 60, 990, 680)
A = Image.open(a).crop(box); B = Image.open(b).crop(box)
w, h = A.size
o = Image.new("RGB", (w * 2 + 16, h + 56), (190, 220, 242))
o.paste(A, (0, 56)); o.paste(B, (w + 16, 56))
d = ImageDraw.Draw(o)
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
d.text((20, 12), ta, fill=(70, 50, 90), font=f); d.text((w + 36, 12), tb, fill=(70, 50, 90), font=f)
o.save(out)
