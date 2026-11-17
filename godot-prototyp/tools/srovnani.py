# Složí 10_ (v2.1) a 11_ (v2.2) vedle sebe -> shots/12_srovnani_v21_v22.png
from PIL import Image, ImageDraw, ImageFont
import os
d = os.path.join(os.path.dirname(__file__), "..", "shots")
a = Image.open(os.path.join(d, "10_hory_kopce_seedy.png")).crop((180, 60, 1100, 760))
b = Image.open(os.path.join(d, "11_terasy_seedy.png")).crop((180, 60, 1100, 760))
w, h = a.size
out = Image.new("RGB", (w * 2 + 20, h + 60), (190, 220, 242))
out.paste(a, (0, 60)); out.paste(b, (w + 20, 60))
dr = ImageDraw.Draw(out)
try:
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
except Exception:
    f = ImageFont.load_default()
dr.text((20, 14), "proto-v2.1: eliptické vrcholy", fill=(70, 50, 90), font=f)
dr.text((w + 40, 14), "proto-v2.2: profil nad makro-šumem (terasy, útesy)", fill=(70, 50, 90), font=f)
out.save(os.path.join(d, "12_srovnani_v21_v22.png"))
print("ok")
