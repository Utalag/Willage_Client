"""T-2b/T-2c: srovnávací arch textur vzorku 5 materiálů (PIL, jen offline příprava obrázků do reportu).
Každý sloupec = složka s texturami textura-[v1-]<id>-<key>.png ze snímků EditorMaterialuTest (dlaždice 2×2 z 64 px, 4× zvětšeno);
arch je převzorkuje na 2×2 dlaždice, 8× nejbližší soused (1024 px). Volitelně --dev <Docs/images/vpmg-v1> = kontrola bajtů posledního sloupce.
Použití: python3 srovnani_textur.py vystup.png [--dev slozka] "popisek=slozka:predpona" ..."""
import sys
from PIL import Image, ImageDraw, ImageFont
a = sys.argv[1:]; out = a.pop(0); dev = None
if a and a[0] == '--dev': dev = a[1]; a = a[2:]
cols = [(x.split('=', 1)[0].replace('\\n', '\n'), *x.split('=', 1)[1].rsplit(':', 1)) for x in a]
mats = [(1, 'grass', 'Tráva'), (2, 'topsoil', 'Ornice / hlína'), (3, 'gravel_sand', 'Štěrk / písek'), (5, 'cave_limestone', 'Vápenec'), (6, 'granite', 'Žula')]
def font(sz): return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', sz)
T, pad, lab, top = 1024, 32, 360, 230
W = lab + (T + pad) * len(cols) + pad; H = top + len(mats) * (T + pad + 50) + 40
im = Image.new('RGB', (W, H), (30, 30, 36)); d = ImageDraw.Draw(im)
d.text((pad, 24), 'Editor materiálů – vzorek 5 materiálů: textury VPMG (dlaždice 2×2 z 64 px, 8× nejbližší soused), seed v popisku sloupce', font=font(40), fill=(235, 235, 235))
for i, (c, _, _) in enumerate(cols): d.multiline_text((lab + i * (T + pad), 100), c, font=font(30), fill=(180, 200, 255))
for r, (mid, key, naz) in enumerate(mats):
    y = top + r * (T + pad + 50)
    d.multiline_text((pad, y + T // 2 - 40), f'{mid} {key}\n{naz}', font=font(36), fill=(230, 230, 230))
    for i, (_, slozka, pred) in enumerate(cols):
        t = Image.open(f'{slozka}/textura-{pred}{mid}-{key}.png').convert('RGB')
        tile = t.crop((0, 0, t.size[0] // 2, t.size[1] // 2)).resize((64, 64), Image.NEAREST)  # jedna dlaždice 64 px
        two = Image.new('RGB', (128, 128))
        for x in (0, 64):
            for yy in (0, 64): two.paste(tile, (x, yy))
        im.paste(two.resize((T, T), Image.NEAREST), (lab + i * (T + pad), y))
        if dev and i == len(cols) - 1:
            same = tile.tobytes() == Image.open(f'{dev}/material-{mid:03d}-{key}.png').convert('RGB').tobytes()
            d.text((lab + i * (T + pad), y + T + 6), 'bajty = náhled Dev ✓' if same else 'ROZDÍL od náhledu Dev', font=font(28), fill=(140, 230, 140) if same else (255, 120, 120))
            print(key, 'shoda s náhledem Dev' if same else 'ROZDÍL')
im.save(out, optimize=True); print(out, im.size)
