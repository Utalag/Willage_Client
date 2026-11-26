# G-1: graf modulů M0–M7 (skutečné závislosti v kódu) – ilustrační obrázek
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
fig, ax = plt.subplots(figsize=(15, 7.2), dpi=110); ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
ax.text(0.5, 0.965, "G-1 · Graf modulů generátoru světa (dependsOn podle kódu) a klíč modulu", ha="center", fontsize=14, weight="bold")
W, H = 0.135, 0.12
uzly = {
 "M0": (0.005, 0.50, "M0 Planeta\nseed, rozměry, start,\nklima planety, přepínače", "#eeeeee", "—"),
 "M1": (0.16, 0.50, "M1 Funkce světa\nSvetFn bez moře\n(reliéf, biomy, sopky)", "#e8f1fb", "klima_presety.csv"),
 "M2": (0.315, 0.50, "M2 Moře a kontinenty\nSvetFn startu\n(maska, sklon, pánve)", "#e8f1fb", "v1/more_v1.json"),
 "M3": (0.49, 0.70, "M3 Geologie\nGeologieCs: vrstvy,\nútvary, mince, sopky", "#f3e6d8", "poradi_hornin, materialy_v1,\nutvary_hostitele, sum_hornin,\nmineraly_hostitele"),
 "M4": (0.49, 0.30, "M4 Eroze planety\nWGER 32 m (dnešní klíč)\n+ vodníci kroku 6", "#e0efe0", "v1/eroze_v1.json"),
 "M5": (0.67, 0.30, "M5 Klima a biomy\nMapaKlimatu, hydrologie,\noázy", "#fff3cc", "v1/klima_v1.json"),
 "M6": (0.67, 0.70, "M6 Voda a průsak\nParametryVody, průsak,\nkatalog (voda líně)", "#dcefff", "voda_v1, prusak_v1,\nmaterials-catalog-v1"),
 "M7": (0.855, 0.50, "M7 Výstup planety\nSvetKrok06 + souhrn\n(napojí erozi)", "#ffd9b3", "souhrn manifestu"),
}
for k, (x, y, t, c, f) in uzly.items():
    w = W
    ax.add_patch(FancyBboxPatch((x, y), w, H, boxstyle="round,pad=0.006,rounding_size=0.012", fc=c, ec="#444", lw=1.2))
    ax.text(x + w / 2, y + H / 2, t, ha="center", va="center", fontsize=8.6)
    if k in ("M3", "M6"): ax.text(x + w / 2, y + H + 0.012, f, ha="center", va="bottom", fontsize=7.2, color="#555", style="italic")
    else: ax.text(x + w / 2, y - 0.012, f, ha="center", va="top", fontsize=7.2, color="#555", style="italic")
def stred(k, strana):
    x, y = uzly[k][0], uzly[k][1]; w = W
    return {"r": (x + w, y + H / 2), "l": (x, y + H / 2), "t": (x + w / 2, y + H), "b": (x + w / 2, y)}[strana]
hrany = [("M0","r","M1","l"),("M1","r","M2","l"),("M2","r","M3","l"),("M2","r","M4","l"),("M4","r","M5","l"),("M3","r","M6","l"),("M5","t","M6","b"),
         ("M3","b","M7","l"),("M4","t","M7","l"),("M5","r","M7","b"),("M6","r","M7","t")]
for a, sa, b, sb in hrany:
    p1, p2 = stred(a, sa), stred(b, sb)
    rad = 0.0
    if (a, b) == ("M3", "M7"): rad = 0.25
    if (a, b) == ("M4", "M7"): rad = -0.25
    if (a, b) == ("M6", "M7"): rad = -0.3
    if (a, b) == ("M5", "M7"): rad = 0.3
    ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle="-|>", mutation_scale=13, lw=1.3, color="#333", connectionstyle=f"arc3,rad={rad}"))
ax.add_patch(FancyBboxPatch((0.02, 0.03), 0.96, 0.17, boxstyle="round,pad=0.006,rounding_size=0.01", fc="#f7f7f7", ec="#999"))
ax.text(0.035, 0.175, "Klíč modulu = SHA-256( gen_ver V1.0 | id | verze algoritmu | kanonické parametry modulu | SHA jeho souborů z manifestu | klíče vstupních modulů )", fontsize=9.2, va="top", weight="bold")
ax.text(0.035, 0.13, "• změna modulu N změní klíč N a jeho závislých, klíče před ním ne (test pro každý modul i každý z 15 datových souborů)\n"
        "• manifest_katalogu_v1.json: SHA všech souborů v godot-prototyp/data (CRLF → LF); soubory, které C# nečte, mění jen klíč M7\n"
        "• geologie (M3) a eroze (M4) jsou souběžné větve: změna geologie nepřepočítá erozi ani klima; změna klimatu přepočítá jen M5–M7",
        fontsize=8.6, va="top")
plt.savefig("01-graf-modulu.png", bbox_inches="tight"); print("ok")
