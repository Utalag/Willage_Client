# G-4: Godot jádro WillageJadro – tok volání a náhledy vrstev z headless testu (02/03 uložil JadroTest přes uzly NahledVrstvy).
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
here = os.path.dirname(os.path.abspath(__file__))
fig = plt.figure(figsize=(16, 9))
ax = fig.add_axes([0, 0.36, 1, 0.64]); ax.set_xlim(0, 16); ax.set_ylim(0, 6); ax.axis("off")
def box(x, y, w, h, t, fc, z=False, fs=9):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05", fc=fc, ec="#c33" if z else "#333", lw=2 if z else 1, ls="--" if z else "-"))
    ax.text(x + w / 2, y + h / 2, t, ha="center", va="center", fontsize=fs)
def sip(x1, y1, x2, y2, t=""):
    ax.annotate("", (x2, y2), (x1, y1), arrowprops=dict(arrowstyle="->", color="#555"))
    if t: ax.text((x1 + x2) / 2 + 0.1, (y1 + y2) / 2, t, fontsize=8, color="#555")
ax.text(8, 5.7, "G-4: Godot jádro WillageJadro (autoload) – hlavní vlákno jen řadí a zobrazuje, fasáda běží na jednom vlákně fronty", ha="center", fontsize=13, weight="bold")
box(0.3, 3.9, 4.6, 1.3, "Uzly ve scéně (editor)\nNahledVrstvy (TextureRect) · StavJadra (Label)\nZastupnyPanel ×6 (7d, M8, M9, U-1, U-2, nápověda)", "#eef", False, 9)
box(5.6, 3.9, 4.6, 1.3, "WillageJadro (Node, autoload)\nGeneruj · Nastav · Mapa · Otisky · Moduly · Parametry\nUloz · Nacti · Potvrd · Zrus  → id úlohy < 1 ms", "#ffd", False, 9)
box(10.9, 3.9, 4.8, 1.3, "FrontaPrace (Willage.Gen.Api, bez Godotu)\njedno vlákno, pořadí, CancellationToken\nkonec / průběh → dispečer = CallDeferred", "#cde", False, 9)
box(10.9, 1.9, 4.8, 1.3, "GeneratorSveta (fasáda G-3)\npipeline M0–M7 + zástupné M6d, M8, M9\nprůběh po modulech, zrušení mezi moduly", "#cde", False, 9)
box(5.6, 1.9, 4.6, 1.3, "Adaptéry DTO → Godot\nTexturaMapy (Image/ImageTexture) · SitRezu (ArrayMesh)\nMultiMeshSloupce (MultiMesh) · DtoNaVariant", "#efe", False, 9)
box(0.3, 1.9, 4.6, 1.3, "Signály (hlavní vlákno)\nModulHotov · PlanetaHotova · OtiskyHotove · MapaHotova\nParametrZmenen · PlanetaInfo · PraceSelhala · PraceZrusena\nKatalogZmenen (zástupný)", "#fef", False, 8)
sip(4.9, 4.55, 5.6, 4.55, "příkaz"); sip(10.2, 4.55, 10.9, 4.55, "Zarad"); sip(13.3, 3.9, 13.3, 3.2, "vlákno fronty")
sip(10.9, 2.55, 10.2, 2.55, "DTO"); sip(5.6, 2.55, 4.9, 2.55, "Texture, Dictionary"); sip(2.6, 3.2, 2.6, 3.9, "")
ax.text(8, 0.9, "headless test JadroTest.tscn (Godot 4.7.2 mono): 12/0 · zahřáté volání 0,017 ms · 277 snímků během 1,9 s generace, nejdelší 23,6 ms · otisky = CLI", ha="center", fontsize=10, color="#363")
for i, (f, t) in enumerate([("02-nahled-vyska.png", "NahledVrstvy: výška (980×488 / 4)"), ("03-nahled-biom.png", "NahledVrstvy: biom (980×488 / 4)")]):
    a = fig.add_axes([0.05 + i * 0.48, 0.02, 0.42, 0.32]); a.imshow(plt.imread(os.path.join(here, f)), interpolation="nearest"); a.set_title(t, fontsize=10); a.axis("off")
plt.savefig(os.path.join(here, "01-jadro.png"), dpi=110, bbox_inches="tight"); print("ok")
