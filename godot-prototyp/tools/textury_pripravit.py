# Příprava textur materiálů z gemini/textury-v2-*.jpeg -> godot-prototyp/assets/tex/NN.png (512 px)
# 1) ořez 8 px okraje (JPEG/rámeček), 2) prolnutí okrajů: out = w·A + (1−w)·roll(A, ½),
#    w = 0 na okraji -> 1 ve vzdálenosti 18 % strany (smoothstep); švy A i posunuté kopie tak zmizí.
import glob, os, sys
import numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
N = 512
x = np.arange(N) + 0.5
d = np.minimum(x, N - x) / (N * 0.18)
d = np.clip(d, 0, 1); d = d * d * (3 - 2 * d)
w = np.minimum.outer(d, d)[..., None]
for f in sorted(glob.glob(src + "/textury-v2-*.jpeg")):
    im = Image.open(f).convert("RGB")
    im = im.crop((8, 8, im.width - 8, im.height - 8)).resize((N, N), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32)
    r = np.roll(np.roll(a, N // 2, 0), N // 2, 1)
    o = w * a + (1 - w) * r
    inner = (np.abs(np.diff(o, axis=0)).mean() + np.abs(np.diff(o, axis=1)).mean()) / 2
    edge = (np.abs(o[0] - o[-1]).mean() + np.abs(o[:, 0] - o[:, -1]).mean()) / 2
    nn = os.path.basename(f)[11:13]
    Image.fromarray(np.clip(o, 0, 255).astype(np.uint8)).save(f"{dst}/{nn}.png")
    print(nn, "šev/uvnitř = %.2f" % (edge / inner))
