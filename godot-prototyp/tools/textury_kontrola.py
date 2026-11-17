# Kontrola dlaždicovatelnosti: posun o polovinu (švy doprostřed) + metrika švu.
# seam = průměrný rozdíl přes okraj (poslední vs první řádek/sloupec) / průměrný rozdíl sousedních řádků uvnitř.
import glob, os, sys
import numpy as np
from PIL import Image, ImageDraw
src = sorted(glob.glob(sys.argv[1] + "/textury-v2-*.jpeg"))
out = sys.argv[2]
sheet = Image.new("RGB", (5 * 260, 2 * 280), (240, 240, 240))
for i, f in enumerate(src):
    a = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
    inner = (np.abs(np.diff(a, axis=0)).mean() + np.abs(np.diff(a, axis=1)).mean()) / 2
    edge = (np.abs(a[0] - a[-1]).mean() + np.abs(a[:, 0] - a[:, -1]).mean()) / 2
    r = np.roll(np.roll(a, a.shape[0] // 2, 0), a.shape[1] // 2, 1).astype(np.uint8)
    t = Image.fromarray(r).resize((256, 256))
    x, y = (i % 5) * 260 + 2, (i // 5) * 280 + 2
    sheet.paste(t, (x, y))
    name = os.path.basename(f)[12:-5]
    ImageDraw.Draw(sheet).text((x, y + 260), "%s seam %.2f" % (name, edge / inner), fill=(0, 0, 0))
    print("%-10s šev/uvnitř = %.2f" % (name, edge / inner))
sheet.save(out)
