# G-3: fasáda Willage.Gen.Api – rozhraní, zástupné části, WPLN a graf modulů se zástupnými.
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
here = os.path.dirname(os.path.abspath(__file__))
fig, ax = plt.subplots(figsize=(16, 9)); ax.set_xlim(0, 16); ax.set_ylim(0, 9); ax.axis("off")
def box(x, y, w, h, t, fc, z=False, fs=9):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05", fc=fc, ec="#c33" if z else "#333", lw=2 if z else 1, ls="--" if z else "-"))
    ax.text(x + w / 2, y + h / 2, t, ha="center", va="center", fontsize=fs)
ax.text(8, 8.65, "G-3: fasáda Willage.Gen.Api (bez Godotu) – čárkovaně červeně = zástupné", ha="center", fontsize=14, weight="bold")
box(0.3, 7.3, 15.4, 0.8, "Volající: Godot jádro WillageJadro (G-4) · okno Generátor světa (G-5) · CLI  Willage.Gen.Nastroje api · server Willage-backend (návrh k připomínkám)", "#eee")
box(5.5, 6.2, 5, 0.7, "GeneratorSveta  (jedna planeta v paměti, StavGeneratoru)", "#ffd")
api = [("IModuly\nSeznam · Parametry · Nastav\nVychozi · Prepocitej", "#cde", False), ("ISluzbaSveta\nGeneruj · Otisky\nUloz/Nacti WPLN · PotvrdPlanetu", "#cde", False),
       ("IDotazySveta\nSloupec · Bod · Rez · Mapa", "#cde", False), ("IKatalogy\nManifest · Kontrola\nDotceneModuly", "#cde", False),
       ("IVizualniData\n(okno 2, část C)", "#fee", True), ("IUpravyRegionu\n(U-1, fáze 3)", "#fee", True)]
for i, (t, c, z) in enumerate(api): box(0.3 + i * 2.6, 4.6, 2.4, 1.2, t, c, z, 8.5)
box(0.3, 3.9, 2.4, 0.5, "PrepocitejOblast (U-2)", "#fee", True, 8); box(0.3, 3.3, 2.4, 0.5, "Napoveda (texty)", "#fee", True, 8)
box(10.7, 3.9, 2.4, 0.5, "NavrhVerze", "#fee", True, 8)
box(3.0, 3.3, 4.9, 1.1, "WPLN v1 (Deflate): WPLN · verze · gen_ver · seed\nmanifest (SHA) · sada parametrů JSON · klíče modulů\npotvrzeno · úpravy (U-1, 0)", "#efe", False, 8.5)
box(8.2, 3.3, 2.3, 1.1, "SouradniceQ16\n2⁻¹⁶ m = Dev FxQ16\nhash = Dev golden", "#efe", False, 8.5)
ids = ["M0", "M1", "M2", "M3", "M4", "M5", "M6", "M6d\n7d", "M7", "M8", "M9"]
for i, m in enumerate(ids):
    z = m in ("M6d\n7d", "M8", "M9")
    box(0.3 + i * 1.42, 1.6, 1.2, 0.9, m, "#fee" if z else "#ddd", z, 10)
ax.text(8, 1.2, "Willage.Gen: pipeline G-1 + schéma G-2 (202 parametrů); zástupné moduly jsou průchozí, verze 0 – klíče M0–M7 a otisky beze změny", ha="center", fontsize=10)
ax.text(8, 0.6, "otisky přes fasádu: mapa 800d420bb00047de · klima cb11da8d141a2a5e · 86 vodníků · voda 14,14 377a8210f82c856a (vyp: 92, 8e239a68c6d01be0)", ha="center", fontsize=10, color="#363")
plt.savefig(os.path.join(here, "01-fasada-api.png"), dpi=110, bbox_inches="tight"); print("ok")
