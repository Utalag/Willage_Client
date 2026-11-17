# 14a_plochy.png (původní vzhled) a 07_domek.png (kawaii) vedle sebe -> shots/14_kawaii_pred_po.png
from PIL import Image, ImageDraw, ImageFont
import os
d = os.path.join(os.path.dirname(__file__), "..", "shots")
box = (0, 60, 990, 680)
a = Image.open(os.path.join(d, "14a_plochy.png")).crop(box)
b = Image.open(os.path.join(d, "07_domek.png")).crop(box)
w, h = a.size
out = Image.new("RGB", (w * 2 + 16, h + 56), (190, 220, 242))
out.paste(a, (0, 56)); out.paste(b, (w + 16, 56))
dr = ImageDraw.Draw(out)
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
dr.text((20, 12), "před: Lambert, bez obrysů", fill=(70, 50, 90), font=f)
dr.text((w + 36, 12), "po: kawaii toon + obrysy hran (T přepíná)", fill=(70, 50, 90), font=f)
out.save(os.path.join(d, "14_kawaii_pred_po.png"))
print("ok")
