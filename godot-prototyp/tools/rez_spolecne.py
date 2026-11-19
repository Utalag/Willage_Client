"""Společný kód řezů (tools/rez_gif.py, tools/rez_profil.py): načtení dat z tools/rez_data.gd, výběr oblasti,
paleta a české názvy, podzemní tělesa, voda, mřížka buněk (numpy) a legenda."""
import base64, json
import numpy as np
from PIL import ImageFont

BS, NZ = 16, 64
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

def fonts(size=13, bold=16):
    return ImageFont.truetype(FONT, size), ImageFont.truetype(FONT.replace("Sans.ttf", "Sans-Bold.ttf"), bold)

def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

class Data:
    """oblast = "vse" nebo "x,y" (slot bloku ostrova); souřadnice buněk jsou souřadnice ostrova (slot × 16 + sloupec)"""
    def __init__(self, path, oblast="vse", podzemi=True):
        d = json.load(open(path))
        self.oblast = oblast
        self.blocks = {}
        for b in d["bloky"]:
            if oblast != "vse" and tuple(b["slot"]) != tuple(int(v) for v in oblast.split(",")):
                continue
            self.blocks[tuple(b["slot"])] = (base64.b64decode(b["geo"]), b["hm"], b)
        if not self.blocks:
            raise SystemExit("oblast %s: žádný blok" % oblast)
        sx = [s[0] for s in self.blocks]; sy = [s[1] for s in self.blocks]
        self.x0, self.y0 = min(sx) * BS, min(sy) * BS
        self.W, self.H = (max(sx) - min(sx) + 1) * BS, (max(sy) - min(sy) + 1) * BS
        self.col = {int(k): "#" + v[:6] for k, v in d["barvy"].items()}
        self.names = {int(k): v for k, v in d["nazvy"].items()}
        self.ug = d.get("podzemi", {}).get("sloupce", {}) if podzemi else {}
        self.voda = d.get("voda", {})
        self.gw = d.get("podzemni_voda", {}) if podzemi else {}   # výplň podzemní vodou po sloupcích [[spodek m, hladina m, těleso]] ze stavu řešiče
        self.tv = d.get("telesa_voda", []) if podzemi else []    # tělesa s vodou: hladina, výstup [x, y, z], typ povrch|okraj, režim
        self.zmax = max(max(hm) for _, hm, _ in self.blocks.values())
        b0 = list(self.blocks.values())[0][2]
        self.title = "ostrov" if oblast == "vse" else "blok %s (%s %d)" % (oblast, b0["typ"], b0["seed"])

    def color(self, m):
        return (17, 17, 17) if m == 0 else hexrgb(self.col.get(m, "#ff00ff"))

    def grid(self, nz=None):
        """S[x, y, z]: -1 = mimo blok / vzduch nad terénem, 0 = dutina, jinak plné id; B: 1 = největší podzemní těleso, 2 = jiné"""
        NZv = nz or self.zmax + 1
        S = np.zeros((self.W, self.H, NZv), dtype=np.int16) - 1
        B = np.zeros((self.W, self.H, NZv), dtype=np.uint8)
        for (s_, (geo, hm, _)) in self.blocks.items():
            g = np.frombuffer(geo, dtype=np.uint8).reshape(BS, BS, NZ)
            for lx in range(BS):
                for ly in range(BS):
                    X = s_[0] * BS + lx - self.x0; Y = s_[1] * BS + ly - self.y0; h = hm[lx * BS + ly]
                    S[X, Y, :min(h, NZv)] = g[lx, ly, :min(h, NZv)]
                    for lo, hi, big in self.ug.get("%d,%d" % (s_[0] * BS + lx, s_[1] * BS + ly), []):
                        z0 = max(int(lo / 0.5 + 1e-6), 0); z1 = min(int(np.ceil(hi / 0.5 - 1e-6)), NZv)
                        sl = B[X, Y, z0:z1]; B[X, Y, z0:z1] = np.where((sl == 0) | (sl > big), big, sl)
        return S, B

    def tint(self, c, b):
        """modrý nádech podzemního tělesa (b = 1 největší, 2 jiné)"""
        if not b: return c
        c = np.array(c, dtype=float) * 0.55 + np.array((30, 90, 220)) * (0.45 if b == 1 else 0.25)
        return tuple(int(v) for v in c)

    def legend(self, dr, x, y, cnt, fn, extra=()):
        """legenda: materiály (id, název, počet) + doplňkové položky [(barva, text)]"""
        for m, n in sorted(cnt.items(), key=lambda e: -e[1])[:16]:
            dr.rectangle([x, y, x + 14, y + 14], fill=self.color(m), outline=(80, 80, 80))
            dr.text((x + 20, y), "%s (%d) %d" % (self.names.get(m, "id %d" % m)[:28], m, n), font=fn, fill=(20, 20, 30)); y += 18
        if extra: y += 6
        for c, t in extra:
            dr.rectangle([x, y, x + 14, y + 14], fill=c, outline=(80, 80, 80)); dr.text((x + 20, y), t, font=fn, fill=(20, 20, 30)); y += 18
        return y
