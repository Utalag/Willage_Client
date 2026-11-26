"""T-2b: srovnávací arch v0 / v1 / Dev náhled / pokus s opravami (PIL). Vstupy: snímky testu EditorMaterialuTest (Xvfb),
Docs/images/vpmg-v1 z pinu Dev, volitelně výstup VpmgPreview --samples-v1 z lokální opravené kopie pinu (jen pokus, Dev se nemění).
Použití: python3 t2b_srovnani.py <v0_slozka> <v1_slozka> <dev_nahledy> <pokus_slozka> <vystup.png>"""
import sys
from PIL import Image, ImageDraw, ImageFont
V0, V1, DEV, FIX, OUT = sys.argv[1:6]
mats = [(1, 'grass', 'Tráva'), (2, 'topsoil', 'Ornice / hlína'), (3, 'gravel_sand', 'Štěrk / písek'), (5, 'cave_limestone', 'Vápenec'), (6, 'granite', 'Žula')]
def font(sz): return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', sz)
F, FS, FB = font(18), font(13), font(21)
T, pad, lab, top = 256, 16, 190, 120
colw = T + pad
cols = ['v0 – Dev 3476488\nbase_fill + hash_grain\n(seed 49, snímek T-2)', 'v1 – Dev 12c3e6b v okně klienta\nreceptura v1, seed 0xC0FFEE00\n(= golden Dev)', 'Dev náhled\nDocs/images/vpmg-v1\n(kontrola shody bajtů)', 'POKUS (není v Dev): v1 +\nSmoothStep /1024² a strata\nmix (n − 512)']
W = lab + colw * len(cols) + pad; H = top + len(mats) * (T + pad + 20) + 60
im = Image.new('RGB', (W, H), (30, 30, 36)); d = ImageDraw.Draw(im)
d.text((pad, 12), 'Editor materiálů T-2b – vzorek 5 materiálů: VPMG v0 vs v1 (dlaždice 2×2 z 64 px, zvětšeno nejbližším sousedem)', font=FB, fill=(235, 235, 235))
for i, c in enumerate(cols): d.multiline_text((lab + i * colw, 52), c, font=FS, fill=(180, 200, 255) if i < 3 else (255, 190, 120))
def tile(img):
    t = Image.new('RGB', (128, 128))
    for x in (0, 64):
        for y in (0, 64): t.paste(img, (x, y))
    return t.resize((T, T), Image.NEAREST)
for r, (mid, key, naz) in enumerate(mats):
    y = top + r * (T + pad + 20)
    d.multiline_text((pad, y + T // 2 - 20), f'{mid} {key}\n{naz}', font=F, fill=(230, 230, 230))
    v0 = Image.open(f'{V0}/textura-{mid}-{key}.png').convert('RGB').resize((T, T), Image.NEAREST)
    v1 = Image.open(f'{V1}/textura-v1-{mid}-{key}.png').convert('RGB')
    dev = Image.open(f'{DEV}/material-{mid:03d}-{key}.png').convert('RGB')
    same = v1.crop((0, 0, v1.size[0] // 2, v1.size[1] // 2)).resize((64, 64), Image.NEAREST).tobytes() == dev.tobytes()
    fix = Image.open(f'{FIX}/material-{mid:03d}-{key}.png').convert('RGB')
    for i, t in enumerate([v0, v1.resize((T, T), Image.NEAREST), tile(dev), tile(fix)]): im.paste(t, (lab + i * colw, y))
    d.text((lab + 2 * colw, y + T + 2), 'bajty = okno klienta ✓' if same else 'ROZDÍL od okna', font=FS, fill=(140, 230, 140) if same else (255, 120, 120))
    print(key, 'shoda s Dev náhledem' if same else 'ROZDÍL')
d.text((pad, H - 50), 'Žluté / modré pruhy a binární šum ve v1 jsou i v náhledech Dev (goldeny je obsahují): SmoothStep ve VpmgIntNoise dělí jen /1024 (přestřelí až ~1000×), strata přičítá necentrovaný šum.', font=FS, fill=(255, 200, 140))
d.text((pad, H - 28), 'Poslední sloupec = jen lokální pokus nad kopií pinu v /tmp (Dev nezměněn) – návrh opravy pro Willage-backend; goldeny by se přepočítaly.', font=FS, fill=(255, 200, 140))
im.save(OUT); print(OUT)
