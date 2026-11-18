"""Složí srovnávací snímky 46_* (PIL + matplotlib): klín se skicou, rozlišení 16 vs 32, rezervoár + jeskyně."""
import os, re
from PIL import Image, ImageDraw, ImageFont
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
D = os.path.dirname(os.path.abspath(__file__)) + "/.."
S = D + "/shots/"
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
def label(img, txt, xy=(8, 6)):
    d = ImageDraw.Draw(img); d.rectangle([xy[0]-4, xy[1]-2, xy[0]+12*len(txt)+8, xy[1]+28], fill="white"); d.text(xy, txt, fill="black", font=F)

# 1) klín: profil mocností z bench_horniny.txt (funkce bs, řez y = 8)
txt = open(S + "bench_horniny.txt").read()
rows = re.findall(r"^vrstva (\d) (.+?): ([\d. ]+) \| ([\d. ]+)$", txt, re.M)
if rows:
    th = [[float(v) for v in (r[2] + " " + r[3]).split()] for r in rows]
    n = len(th[0]); xs = [(i + 0.5) * 0.5 for i in range(n)]
    fig, ax = plt.subplots(figsize=(8, 4.2), dpi=100)
    cols = ["#8c6e5a", "#c0603a", "#f0a060", "#d8b890", "#7a5528", "#a09878", "#d8b030"]
    base = [0.0] * n
    for k, t in enumerate(th):
        top = [b + v * 0.5 for b, v in zip(base, t)]
        ax.fill_between(xs, base, top, color=cols[k], step="mid", lw=0)
        mid = max(range(n), key=lambda i: t[i])
        ax.text(xs[mid], (base[mid] + top[mid]) / 2, str(k + 1), ha="center", va="center", fontsize=12, weight="bold")
        ax.plot(xs, top, color="k", lw=0.8, drawstyle="steps-mid")
        base = top
    ax.axvline(8.0, color="k", ls="--"); ax.set_xlim(0, 16)
    ax.set_xlabel("x (m): levý blok 1,2,4,5,6,7 | pravý (nový) 1,3,5,6,7"); ax.set_ylabel("výška nad bází sedimentů (m)")
    ax.set_title("Klín z funkcí mocností (řez y = 8): 2 a 4 se vyklíní, 3 naroste od švu")
    fig.tight_layout(); fig.savefig(S + "_klin_profil.png"); plt.close(fig)
    sk0 = Image.open(D + "/inspirace/skica-klin.jpg").convert("RGB")
    sk = sk0.crop((0, int(sk0.height * 0.235), sk0.width, int(sk0.height * 0.78)))
    cut = Image.open(S + "_klin_rez.png").convert("RGB")
    pr = Image.open(S + "_klin_profil.png").convert("RGB")
    H = 560
    sk = sk.resize((int(sk.width * H / sk.height), H)); pr = pr.resize((int(pr.width * H / pr.height), H)); cut = cut.resize((int(cut.width * H / cut.height), H))
    W = sk.width + pr.width
    out = Image.new("RGB", (W, H * 2), "white")
    out.paste(sk, (0, 0)); out.paste(pr, (sk.width, 0)); out.paste(cut, ((W - cut.width) // 2, H))
    label(out, "Janova skica klínu [16]", (8, 6)); label(out, "řez 3D (buňky 0,5 m)", ((W - cut.width) // 2 + 8, H + 130))
    out.save(S + "46_horniny_klin.png")

# 2) rozlišení 16 vs 32
if os.path.exists(S + "_rozl16.png"):
    a, b, c = [Image.open(S + f).convert("RGB") for f in ("_rozl16.png", "_rozl32.png", "_rozl_rozdil.png")]
    m = re.search(r"^celkem: (.+)$", txt, re.M)
    out = Image.new("RGB", (a.width * 3 + 40, a.height + 80), "white")
    for i, im in enumerate((a, b, c)): out.paste(im, (i * (a.width + 20), 70))
    d = ImageDraw.Draw(out)
    d.text((8, 6), "Řez y = 4 m přes (0,0) hora vyzdvižená | (1,0) prohlubeň | (2,0) sopka", fill="black", font=F)
    d.text((8, 36), "16×16×64 (0,5 m)   |   32×32×128 (0,25 m)   |   neshoda po zmenšení (červeně)   " + (m.group(1) if m else ""), fill="black", font=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 17))
    out.save(S + "46_horniny_rozliseni.png")

# 3) rezervoár + jeskyně
if os.path.exists(S + "_rezervoar.png") and os.path.exists(S + "_jeskyne.png"):
    a = Image.open(S + "_rezervoar.png").convert("RGB"); b = Image.open(S + "_jeskyne.png").convert("RGB")
    out = Image.new("RGB", (a.width + b.width, a.height), "white"); out.paste(a, (0, 0)); out.paste(b, (a.width, 0))
    out.save(S + "46_horniny_rezervoar_jeskyne.png")
# dílčí snímky _*.png zůstávají (vstup pro opakované složení)
print("ok")
