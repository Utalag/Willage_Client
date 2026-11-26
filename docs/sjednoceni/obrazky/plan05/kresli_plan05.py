#!/usr/bin/env python3
"""Ilustrační obrázky k plánu 05 (generátor světa, konfigurátor katalogu, vizuální generátor).
Spuštění: python3 kresli_plan05.py  → PNG do stejné složky. Jen ilustrace, ne měření."""
import os, math, random
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, Polygon, Circle, Ellipse, FancyArrowPatch

OUT = os.path.dirname(os.path.abspath(__file__))
plt.rcParams["font.family"] = "DejaVu Sans"

def box(ax, x, y, w, h, text, fc="#ffffff", ec="#333333", fs=9, bold=False, r=0.02, ha="center", lw=1.2, tc="#111"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0,rounding_size={r}", fc=fc, ec=ec, lw=lw))
    tx = x + w / 2 if ha == "center" else x + 0.01
    ax.text(tx, y + h / 2, text, ha=ha, va="center", fontsize=fs, weight="bold" if bold else "normal", color=tc, wrap=True)

def arrow(ax, x1, y1, x2, y2, text=None, c="#444", fs=8, style="-|>", ls="-", lw=1.3, rad=0.0):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, mutation_scale=12, color=c, lw=lw, ls=ls,
                                 connectionstyle=f"arc3,rad={rad}"))
    if text:
        ax.text((x1 + x2) / 2, (y1 + y2) / 2, text, fontsize=fs, ha="center", va="center", color=c,
                bbox=dict(fc="white", ec="none", pad=1))

def canvas(w, h, title):
    fig, ax = plt.subplots(figsize=(w, h), dpi=130)
    ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
    ax.text(0.5, 0.975, title, ha="center", va="top", fontsize=14, weight="bold")
    return fig, ax

# ---------------------------------------------------------------- 1 vrstvy architektury
def obr1():
    fig, ax = canvas(13, 9.5, "1 · Vrstvy architektury: C# jádro → fasáda/adaptéry → Godot jádro → scény a skripty")
    L = [  # y, výška, barva, nadpis, položky
        (0.765, 0.15, "#e8f1fb", "4 · Godot scény a uzly (C#, [Tool]) – dvě samostatná okna + hra",
         ["Okno 1: GeneratorSveta.tscn\nseznam modulů M1–M6,\nkonfigurátor modulu, náhled",
          "Okno 2: EditorMaterialu.tscn\nmateriály, vzhled,\nvarianty modelů",
          "Ostrov.tscn (hra)\nOknoTerenu, OkrajOstrova,\nVodopady, Pruhlednost",
          "Nástroje / dema\n(demo.tscn, headless\nsnímky a měření)"]),
        (0.585, 0.14, "#eaf7ea", "3 · Godot jádro – adaptéry (godot-prototyp/scripts/cs/Jadro, autoload WillageJadro)",
         ["WillageJadro (Node, autoload)\njediná instance služby,\nsignály KrokHotov / PlanetaHotova",
          "Prevodniky DTO → Godot\nImage/ImageTexture,\nArrayMesh, MultiMesh",
          "Vlakna a fronta\nTask + CallDeferred,\nzrušení, průběh",
          "Most pro GDScript\n[GlobalClass] (VodaV1 …)\njen dočasně"]),
        (0.405, 0.14, "#fff6e0", "2 · Fasáda API (nový projekt cs/Willage.Gen.Api, bez Godotu, jen DTO)",
         ["ISluzbaSveta\nGeneruj / Nacti / Uloz /\nPotvrdPlanetu",
          "Dotazy\nSloupec, Bod, Rez,\nVzorekOkna(obdélník)",
          "IModuly · IKatalogy\nschéma parametrů, náhled,\npřepočet · verze, diff",
          "IVizualniData\nGrafickeBloky(okno 0,5 m),\nOkraj, Vodopady"]),
        (0.12, 0.245, "#fbeaea", "1 · Knihovna cs/Willage.Gen (čistý C#, deterministická, bez Godotu) – už existuje",
         ["Jadro · Sum · Materialy\n(GeologyHash, Q16,\nFastNoiseLite, katalog)",
          "Svet · Geologie\n(SvetFn, maska pevniny,\nmoře, sopky, GeologieCs)",
          "Eroze · Klima\n(MapaEroze WGER,\npásma, srážky, oázy)",
          "Voda · Prusak\n(hladina, prameny,\nvodníci, pobřežní pás)",
          "NOVÉ: Pipeline (moduly)\nPlaneta · Vizual (popis\nbloků); později Udalosti"]),
    ]
    for y, h, c, t, items in L:
        box(ax, 0.03, y, 0.94, h, "", fc=c, ec="#888", r=0.01)
        ax.text(0.045, y + h - 0.02, t, fontsize=10.5, weight="bold", va="top")
        n = len(items); w = (0.90 - 0.015 * (n - 1)) / n
        for i, it in enumerate(items):
            fc = "#ffffff" if not it.startswith("NOVÉ") else "#ffe3c2"
            box(ax, 0.05 + i * (w + 0.015), y + 0.012, w, h - 0.06, it, fc=fc, fs=8.3)
    for y in (0.585 + 0.14, 0.405 + 0.14, 0.12 + 0.245):
        arrow(ax, 0.5, y + 0.035, 0.5, y + 0.002, c="#555")
    ax.text(0.53, 0.745, "volá jen jádro (nikdy přímo knihovnu)", fontsize=8, color="#555")
    ax.text(0.53, 0.565, "volá fasádu, převádí DTO", fontsize=8, color="#555")
    ax.text(0.53, 0.385, "skládá kroky knihovny", fontsize=8, color="#555")
    box(ax, 0.03, 0.02, 0.45, 0.075, "Data a katalogy (godot-prototyp/data, manifest s hashi)\nmaterials-catalog-v1.json = zrcadlo Willage_Dev, jen čtení",
        fc="#f2f2f2", fs=8.5)
    box(ax, 0.52, 0.02, 0.45, 0.075, "Willage-backend (server, C#) může později použít\nstejnou fasádu 2 + knihovnu 1 (bez Godotu)",
        fc="#f2f2f2", fs=8.5)
    arrow(ax, 0.25, 0.095, 0.25, 0.12, c="#777")
    arrow(ax, 0.75, 0.095, 0.75, 0.405, c="#777", ls="--")
    fig.savefig(os.path.join(OUT, "01-vrstvy-architektury.png"), bbox_inches="tight"); plt.close(fig)

# ---------------------------------------------------------------- 2 tok dat pipeline
def obr2():
    fig, ax = canvas(17, 8, "2 · Tok dat generátoru světa (každý stávající krok = modul s klíčem keše a vlastním konfigurátorem)")
    kroky = [("M0 Planeta\nseed, gen_ver,\npřepínače,\nmanifest katalogů", "#eeeeee"),
             ("M1 Funkce světa\nbiomy, reliéf,\nmasiv, sopky", "#e8f1fb"),
             ("M2 Moře a\nkontinenty\nmaska, pánve", "#e8f1fb"),
             ("M3 Geologie\nvrstvy, útvary,\nnitro sopky", "#f3e6d8"),
             ("M4 Eroze planety\nmapa 32 m WGER\n(pozůstatek)", "#e0efe0"),
             ("M5 Klima a biomy\npásma, srážky,\npouště, oázy", "#fff3cc"),
             ("M6 Voda a průsak\nhladina, prameny,\nvodníci, pobř. pás", "#dcefff"),
             ("M7 Výstup\nhotová planeta\n(WPLN)", "#ffd9b3")]
    n = len(kroky); w = 0.105; g = (0.96 - n * w) / (n - 1)
    xs = []
    for i, (t, c) in enumerate(kroky):
        x = 0.02 + i * (w + g); xs.append(x)
        box(ax, x, 0.62, w, 0.17, t, fc=c, fs=7.9, bold=(i == n - 1))
        if i: arrow(ax, xs[i - 1] + w, 0.705, x, 0.705)
    ax.text(0.02, 0.915, "Funkce světa = moduly okna Generátor světa (každý krok má svůj konfigurátor)", fontsize=10.5, weight="bold")
    for i in range(8):
        ax.text(xs[i] + w / 2, 0.60, f"klíč M{i} + konfigurátor", fontsize=7.5, ha="center", va="top", color="#666")
    # události editoru
    box(ax, 0.20, 0.83, 0.62, 0.045, "Fáze 3 (až po obalení stávajícího): 7d zvodnělá zóna, M8 povrchové jevy, M9 vegetace, úpravy s regiony → vstup modulů",
        fc="#ffe3c2", fs=8.5)
    for i in (1, 2, 5, 6):
        arrow(ax, xs[i] + w / 2, 0.825, xs[i] + w / 2, 0.79, c="#c06000")
    # spodní řada – výřezy a ostrov
    ax.text(0.02, 0.475, "Ostrov (až z hotového světa, kroky 8–12 plánu 04)", fontsize=10.5, weight="bold")
    dol = [("Blueprint\nblok 128 m\n(Source)", "#ffd9b3"), ("Výřez:\nTransform\n(otočení, zrcadlo,\nposun výšky)", "#f5e1ff"),
           ("Placement\nnapojení švů\nAuto / Blend / Keep", "#f5e1ff"), ("Slupka buněk 0,25 m\nv okně + okraj,\npřekryv změn E78", "#e8f1fb"),
           ("Voda na ostrově\nsimulace, eroze jako\nvrstva posunu", "#dcefff"), ("Ostrov\nWTI1: seed + verze +\nvložení + rozdíl", "#ffd9b3")]
    m = len(dol); w2 = 0.14; g2 = (0.96 - m * w2) / (m - 1); xd = []
    for i, (t, c) in enumerate(dol):
        x = 0.02 + i * (w2 + g2); xd.append(x)
        box(ax, x, 0.25, w2, 0.17, t, fc=c, fs=8.2)
        if i: arrow(ax, xd[i - 1] + w2, 0.335, x, 0.335)
    xk = xs[-1] + w / 2; xb = xd[0] + w2 / 2
    ax.plot([xk, xk, xb, xb], [0.62, 0.52, 0.52, 0.44], color="#c06000", lw=1.4)
    arrow(ax, xb, 0.445, xb, 0.42, c="#c06000")
    ax.text((xk + xb) / 2, 0.535, "řez hotové planety na blueprinty (bloky 128 m)", fontsize=8, color="#c06000", ha="center")
    box(ax, 0.30, 0.05, 0.40, 0.11, "Vizuální generátor jen ČTE: okno 64 dlaždic (16 m) z slupky → grafické bloky 0,5 m → sítě Godotu",
        fc="#eaf7ea", fs=8.8)
    arrow(ax, xd[3] + w2 / 2, 0.25, 0.55, 0.16, c="#2a7a2a")
    arrow(ax, xd[4] + w2 / 2, 0.25, 0.62, 0.16, c="#2a7a2a")
    fig.savefig(os.path.join(OUT, "02-tok-dat-generatoru.png"), bbox_inches="tight"); plt.close(fig)

# ---------------------------------------------------------------- 3 propojení: dvě samostatná okna
def obr3():
    fig, ax = canvas(14, 9, "3 · Dvě samostatná okna nad jedním C# jádrem: generátor světa (moduly) a editor materiálů")
    # okno A
    box(ax, 0.02, 0.50, 0.45, 0.41, "", fc="#e8f1fb", ec="#2b5d9b", r=0.01, lw=1.8)
    ax.text(0.035, 0.89, "Okno 1 · Generátor světa (GeneratorSveta.tscn, vlastní proces)", fontsize=10, weight="bold", va="top")
    mods = ["M0 Planeta: seed, přepínače", "M1 Funkce světa: reliéf, sopky", "M2 Moře a kontinenty", "M3 Geologie: vrstvy, útvary", "M4 Eroze planety 32 m", "M5 Klima a biomy", "M6 Voda a průsak", "M7 Výstup planety WPLN"]
    for i, m in enumerate(mods):
        box(ax, 0.035, 0.835 - i * 0.04, 0.17, 0.032, m, fc="#ffffff" if i != 5 else "#ffe3c2", fs=6.9, r=0.004)
    box(ax, 0.22, 0.56, 0.235, 0.29, "Konfigurátor vybraného modulu\n(vlastní panel na každý krok,\njako funkční vrstvy v GeoLabu)\n\n• parametry modulu (JSON)\n• náhled: mapa / řez / diagnostika\n• přepočítat modul + závislé\n• izolovat vrstvu, výchozí hodnoty",
        fc="#ffffff", fs=7.8)
    ax.text(0.035, 0.515, "fáze 3: + 7d zvodnělá zóna, M8 povrchové jevy, M9 vegetace, úpravy s regiony", fontsize=7.4, color="#2b5d9b")
    # okno B
    box(ax, 0.53, 0.50, 0.45, 0.41, "", fc="#f5e1ff", ec="#7a3ea0", r=0.01, lw=1.8)
    ax.text(0.545, 0.89, "Okno 2 · Editor materiálů a textur (EditorMaterialu.tscn)", fontsize=10, weight="bold", va="top")
    box(ax, 0.545, 0.56, 0.15, 0.29, "Materiály (id u8)\n\nkatalog Willage_Dev\n(jen čtení):\ngeology + visualProfiles\n\nreceptura VPMG v0:\nbase_fill, hash_grain", fc="#ffffff", fs=7.6)
    vars_ = ["plochý blok", "okraj ostrova", "svah / schody", "vykopaná jáma", "přechod", "pod vodou"]
    for i, v in enumerate(vars_):
        x = 0.71 + (i % 3) * 0.088; y = 0.70 - (i // 3) * 0.14
        box(ax, x, y, 0.08, 0.12, v, fc="#ffffff", fs=7.2, r=0.005)
    ax.text(0.71, 0.855, "Varianty modelů (vykreslovač jako ve hře)", fontsize=7.6, weight="bold")
    # sdílené
    box(ax, 0.02, 0.24, 0.96, 0.17,
        "Sdílené C# jádro: cs/Willage.Gen (moduly kroků, popis grafických bloků) + cs/Willage.Gen.Api (fasáda, DTO) + Godot autoload WillageJadro\n"
        "Okna spolu nemluví přímo: sdílejí jen soubory a verze katalogů (manifest SHA). Uložení vzhledu → generátor dostane signál KatalogZmenen.",
        fc="#fff6e0", fs=8.6)
    arrow(ax, 0.25, 0.50, 0.25, 0.41, c="#2b5d9b"); arrow(ax, 0.75, 0.50, 0.75, 0.41, c="#7a3ea0")
    box(ax, 0.02, 0.03, 0.30, 0.16, "Data generátoru (data/v1): parametry modulů\nmění jen okno 1; klíč modulu =\nH(gen_ver, verze, parametry, SHA vstupů)", fc="#f2f2f2", fs=7.8)
    box(ax, 0.35, 0.03, 0.30, 0.16, "Vzhled: visualProfiles katalogu Willage_Dev (jen čtení)\n+ receptury VPMG (okno 2 ukládá jen u nás);\nklíče světa se tím NEmění, jen keš sítí", fc="#f2f2f2", fs=7.8)
    box(ax, 0.68, 0.03, 0.30, 0.16, "Uložení: planeta WPLN (seed, gen_ver, manifest,\nparametry modulů) · ostrov WTI1 + překryv E78\n· commit katalogu Dev + receptury VPMG", fc="#f2f2f2", fs=7.8)
    for x in (0.17, 0.50, 0.83): arrow(ax, x, 0.24, x, 0.19, c="#777")
    fig.savefig(os.path.join(OUT, "03-propojeni-abc.png"), bbox_inches="tight"); plt.close(fig)

# ---------------------------------------------------------------- 4 drátěné modely dvou oken
def obr4():
    fig, axs = plt.subplots(1, 2, figsize=(18, 8), dpi=120, gridspec_kw=dict(width_ratios=[1.2, 1]))
    for ax in axs: ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
    fig.suptitle("4 · Drátěné modely: okno Generátor světa (konfigurátor na každý modul) a samostatné okno Editor materiálů", fontsize=13.5, weight="bold")
    # --- okno 1
    ax = axs[0]
    ax.add_patch(Rectangle((0, 0), 1, 0.95, fc="#fafafa", ec="#2b5d9b", lw=2))
    box(ax, 0, 0.89, 1, 0.06, "  Generátor světa · planeta: seed 49 ▾ | gen_ver V1.0 | [Přepočítat vše] [Potvrdit planetu ✔] [Uložit WPLN]", fc="#dde6f0", fs=8.3, ha="left", r=0)
    ax.text(0.015, 0.855, "Moduly (vrstvy)", fontsize=9, weight="bold")
    mods = [("M0 Planeta", "✔"), ("M1 Funkce světa", "✔"), ("M2 Moře a kontinenty", "✔"), ("M3 Geologie", "✔"), ("M4 Eroze", "✔"), ("M5 Klima a biomy", "✎"), ("M6 Voda a průsak", "·"), ("M7 Výstup planety", "·")]
    for i, (m, st) in enumerate(mods):
        box(ax, 0.01, 0.79 - i * 0.055, 0.19, 0.047, f"{m}   {st}", fc="#ffe3c2" if i == 5 else "#ffffff", fs=7.4, ha="left", r=0.005)
    ax.text(0.015, 0.315, "✔ z keše  ✎ upraveno  · čeká", fontsize=6.8, color="#555")
    ax.text(0.015, 0.20, "fáze 3: M8 povrchové\njevy, M9 vegetace,\núpravy s regiony", fontsize=7.0, color="#2b5d9b")
    # konfigurátor modulu
    box(ax, 0.22, 0.17, 0.33, 0.70, "", fc="#ffffff", r=0)
    ax.text(0.23, 0.85, "Konfigurátor: M5 Klima a biomy", fontsize=9, weight="bold")
    ax.text(0.23, 0.81, "planeta: mírné ▾  srážky 800 mm", fontsize=7.6)
    ax.text(0.23, 0.77, "Pásma (předdefinovaná, jde vypnout):", fontsize=7.8, weight="bold")
    hdr = ["", "pásmo", "podíl", "T od", "T do"]; cx = [0.23, 0.25, 0.36, 0.43, 0.49]
    for c, h in zip(cx, hdr): ax.text(c, 0.735, h, fontsize=7.4, weight="bold")
    rows = [("☐", "tropy", "0,15", "26", "21"), ("☑", "subtropy", "0,15", "21", "15"), ("☑", "mírné", "0,60", "15", "5"), ("☑", "chladné", "0,25", "5", "−5"), ("☐", "polární", "0,10", "−5", "−22")]
    for i, r in enumerate(rows):
        for c, v in zip(cx, r): ax.text(c, 0.70 - i * 0.035, v, fontsize=7.4)
    for i, p in enumerate(["výškový gradient 0,05 °C/m", "orografické zesílení 60", "vyhlazení srážek 128 m", "práh pouště 0,5"]):
        ax.text(0.23, 0.50 - i * 0.04, p, fontsize=7.4); ax.add_patch(Rectangle((0.228, 0.49 - i * 0.04), 0.31, 0.033, fc="none", ec="#bbb", lw=0.5))
    box(ax, 0.23, 0.24, 0.31, 0.06, "[Přepočítat M5 + závislé (M6, M7)]", fc="#e0efe0", fs=7.8, r=0.005)
    ax.text(0.23, 0.20, "[Izolovat vrstvu] [Výchozí hodnoty] [Uložit sadu]", fontsize=7.3)
    # náhled
    ax.add_patch(Rectangle((0.57, 0.40), 0.42, 0.47, fc="#cfe3f2", ec="#333"))
    ax.text(0.58, 0.85, "Náhled modulu: mapa biomů", fontsize=8.3, weight="bold")
    bands = ["#e8e8f0", "#9fb88a", "#7fae5a", "#a8c96a", "#d8c890"]
    for i, c in enumerate(bands):
        ax.add_patch(Rectangle((0.60, 0.44 + i * 0.075), 0.36, 0.075, fc=c, ec="none", alpha=0.85))
    ax.add_patch(Polygon([(0.63, 0.46), (0.72, 0.44), (0.90, 0.50), (0.94, 0.66), (0.88, 0.80), (0.70, 0.79), (0.62, 0.64)], fc="none", ec="#333", lw=1))
    ax.text(0.97, 0.47, "pól", fontsize=7, ha="right"); ax.text(0.97, 0.78, "rovník", fontsize=7, ha="right")
    box(ax, 0.57, 0.17, 0.42, 0.21, "", fc="#ffffff", r=0)
    ax.text(0.58, 0.36, "Řez / diagnostika modulu", fontsize=8.3, weight="bold")
    for i, t in enumerate(["mírný les 89 %, tajga 7 %, step 4 %", "srážky návětří 1,25×, závětří 0,6×", "start: mírné pásmo, 15,8 °C, 1049 mm", "čas modulu 30 ms · otisk 7b2c…"]):
        ax.text(0.585, 0.32 - i * 0.035, t, fontsize=7.4)
    box(ax, 0.01, 0.03, 0.98, 0.1, "Řetěz: M0 ✔ → M1 ✔ → M2 ✔ → M3 ✔ → M4 ✔ (5,1 s, keš) → M5 ✎ → M6 · → M7 ·\nzměna v M5 nezneplatní M0–M4 (klíče modulů)", fc="#f2f2f2", fs=7.8, r=0)
    # --- okno 2
    ax = axs[1]
    ax.add_patch(Rectangle((0, 0), 1, 0.95, fc="#fafafa", ec="#7a3ea0", lw=2))
    box(ax, 0, 0.89, 1, 0.06, "  Editor materiálů · katalog Dev 3476488 + VPMG v0 | [Validovat] [Diff] [Uložit recepturu] [Návrh pro backend]", fc="#e9ddf3", fs=8.3, ha="left", r=0)
    box(ax, 0.01, 0.17, 0.25, 0.70, "", fc="#ffffff", r=0)
    ax.text(0.02, 0.85, "Materiály", fontsize=9, weight="bold")
    mats = [("1 ornice", "#7aa64a"), ("3 písek", "#e8d39a"), ("5 vápenec", "#d9d2c0"), ("6 žula", "#b59a9a"), ("7 čedič", "#5c6470"), ("57 jíl", "#c07a50")]
    for i, (n, c) in enumerate(mats):
        y = 0.80 - i * 0.055
        if i == 2: ax.add_patch(Rectangle((0.015, y - 0.02), 0.24, 0.045, fc="#ffe3c2", ec="none"))
        ax.add_patch(Rectangle((0.02, y - 0.012), 0.03, 0.028, fc=c, ec="#555")); ax.text(0.06, y, n, fontsize=7.8, va="center")
    ax.text(0.02, 0.44, "Receptura VPMG: 5", fontsize=8.3, weight="bold")
    for i, p in enumerate(["profil default (Dev, čtení)", "s1 base_fill ☑ albedo", "s2 hash_grain ☑", "seed 49 · 64 px", "+ operace = návrh backendu"]):
        ax.text(0.02, 0.40 - i * 0.035, p, fontsize=7.4)
    ax.text(0.02, 0.185, "katalog i fyzika: jen čtení (Dev)", fontsize=6.8, color="#a00")
    ax.text(0.28, 0.855, "Varianty modelů (čtou stejný popis bloků jako hra)", fontsize=8.6, weight="bold")
    col = "#d9d2c0"; grass = "#8cbc5a"
    titles = ["plochý blok", "okraj ostrova", "svah / schody", "vykopaná jáma", "přechod s pískem", "pod vodou / mokrý"]
    for k, t in enumerate(titles):
        x0 = 0.28 + (k % 3) * 0.24; y0 = 0.52 - (k // 3) * 0.33
        ax.add_patch(Rectangle((x0, y0), 0.23, 0.31, fc="#ffffff", ec="#888"))
        ax.text(x0 + 0.115, y0 + 0.285, t, fontsize=7.8, ha="center", weight="bold")
        sub = fig.add_axes([0, 0, 0.01, 0.01]); sub.axis("off"); sub.set_aspect("equal")
        bb = ax.get_position(); W = bb.width; H = bb.height
        sub.set_position([bb.x0 + (x0 + 0.01) * W, bb.y0 + (y0 + 0.01) * H, 0.21 * W, 0.26 * H])
        cells = []
        if k == 0: cells = [(i, j, 0, col) for i in range(3) for j in range(3)]
        elif k == 1:
            cells = [(i, j, z, ("#a8a090" if z == 0 else col)) for i in range(3) for j in range(3) for z in range(2)]
        elif k == 2: cells = [(i, j, z, col) for i in range(3) for j in range(3) for z in range(3 - i)]
        elif k == 3: cells = [(i, j, z, col) for i in range(3) for j in range(3) for z in range(2) if not (i == 1 and j == 1 and z == 1) and not (i == 0 and j == 1 and z == 1)]
        elif k == 4: cells = [(i, j, 0, col if i + j < 3 else "#e8d39a") for i in range(3) for j in range(3)]
        else: cells = [(i, j, 0, col) for i in range(3) for j in range(3)]
        for (i, j, z, c) in sorted(cells, key=lambda t: (t[2], -(t[0] + t[1]))):
            cube(sub, i, j, z, 1, c, 1, 0, 0, lw=0.5)
        if k == 1:
            sub.add_patch(Polygon([iso(0, 0, 2), iso(3, 0, 2), iso(3, 3, 2), iso(0, 3, 2)], fc="#9cc96a", ec="#5a7a3a", lw=0.6))
            for i in range(12):
                a = iso(i * 0.25, 0, 2.0); b = iso(i * 0.25 + 0.12, 0, 1.6); c2 = iso(i * 0.25 + 0.25, 0, 2.0)
                sub.add_patch(Polygon([a, b, c2], fc="#6f9e45", ec="none"))
            for (rx, ry) in [(0.4, -0.6), (1.6, 0.0)]:
                sub.add_patch(Polygon([(rx, ry), (rx + 0.4, ry + 0.05), (rx + 0.25, ry - 0.35)], fc="#7a7478", ec="#333", lw=0.5))
        if k == 5:
            sub.add_patch(Polygon([iso(0, 0, 1.4), iso(3, 0, 1.4), iso(3, 3, 1.4), iso(0, 3, 1.4)], fc=(0.45, 0.75, 0.95, 0.45), ec="#3a8ac0"))
        sub.set_xlim(-3.2, 3.2); sub.set_ylim(-1.3, 4.2)
    box(ax, 0.28, 0.025, 0.71, 0.12, "Varianty = malé syntetické vzorky buněk 0,25 m (deterministické),\nvykreslené vizuálním generátorem (grafické bloky 0,5 m).\nNová varianta = nový vzorek, editor se nemění.", fc="#f2f2f2", fs=7.4, r=0)
    box(ax, 0.01, 0.025, 0.25, 0.12, "samostatné okno;\nuložení → signál\npro generátor", fc="#f2f2f2", fs=7.2, r=0)
    fig.savefig(os.path.join(OUT, "04-dratovy-model-editoru.png"), bbox_inches="tight"); plt.close(fig)
# ---------------------------------------------------------------- 5 vizuální generátor
ISO_X = (math.cos(math.radians(30)), math.sin(math.radians(30)))
def iso(x, y, z, s=1.0, ox=0.0, oy=0.0):
    return (ox + (x - y) * ISO_X[0] * s, oy + (x + y) * ISO_X[1] * s + z * s)

def cube(ax, x, y, z, d, col, s, ox, oy, ec="#333", lw=0.6, alpha=1.0):
    def p(a, b, c): return iso(a, b, c, s, ox, oy)
    top = [p(x, y, z + d), p(x + d, y, z + d), p(x + d, y + d, z + d), p(x, y + d, z + d)]
    left = [p(x, y, z), p(x + d, y, z), p(x + d, y, z + d), p(x, y, z + d)]
    right = [p(x, y, z), p(x, y + d, z), p(x, y + d, z + d), p(x, y, z + d)]
    def shade(c, k):
        c = matplotlib.colors.to_rgb(c); return tuple(min(1, v * k) for v in c)
    for poly, k in ((left, 0.78), (right, 0.62), (top, 1.08)):
        ax.add_patch(Polygon(poly, fc=shade(col, k), ec=ec, lw=lw, alpha=alpha))

def obr5():
    fig = plt.figure(figsize=(17, 9.5), dpi=120)
    fig.suptitle("5 · Vizuální generátor: buňky dat 0,25 m → grafické bloky 0,5 m → izometrický ostrov", fontsize=14, weight="bold")
    # panel a: 2x2x2 buňky
    ax = fig.add_axes([0.01, 0.52, 0.22, 0.40]); ax.axis("off"); ax.set_aspect("equal")
    for (x, y, z) in sorted([(i, j, k) for i in range(2) for j in range(2) for k in range(2)], key=lambda t: (t[2], -(t[0] + t[1]))):
        col = "#7aa64a" if z == 1 else "#a07850"
        if (x, y, z) == (1, 1, 1): continue
        cube(ax, x, y, z, 1, col, 1, 0, 0)
    ax.set_xlim(-2.2, 2.2); ax.set_ylim(-0.3, 3.4)
    ax.set_title("a) 8 datových buněk 0,25 m\n(jedna chybí = vykopaná)", fontsize=9.5)
    # panel b: grafický blok
    ax = fig.add_axes([0.24, 0.52, 0.22, 0.40]); ax.axis("off"); ax.set_aspect("equal")
    cube(ax, 0, 0, 0, 2, "#a07850", 1, 0, 0, lw=1.2)
    t = [iso(0, 0, 2), iso(2, 0, 2), iso(2, 2, 2), iso(0, 2, 2)]
    ax.add_patch(Polygon(t, fc="#8cbc5a", ec="#333", lw=1.2))
    # převis trávy (třásně na přední hraně)
    for i in range(9):
        a = iso(i * 0.22, 0, 2); b = iso(i * 0.22 + 0.11, 0, 1.75); c = iso(i * 0.22 + 0.22, 0, 2)
        ax.add_patch(Polygon([a, b, c], fc="#6f9e45", ec="none"))
    # vykopaný roh
    for t_ in (1.0,):
        ax.plot(*zip(iso(t_, 0, 0), iso(t_, 0, 2)), color="#5a4030", lw=0.6, ls=":")
        ax.plot(*zip(iso(0, t_, 0), iso(0, t_, 2)), color="#5a4030", lw=0.6, ls=":")
        ax.plot(*zip(iso(0, 0, t_), iso(2, 0, t_)), color="#5a4030", lw=0.6, ls=":")
        ax.plot(*zip(iso(0, 0, t_), iso(0, 2, t_)), color="#5a4030", lw=0.6, ls=":")
        ax.plot(*zip(iso(t_, 0, 2), iso(t_, 2, 2)), color="#4a7a2a", lw=0.6, ls=":")
        ax.plot(*zip(iso(0, t_, 2), iso(2, t_, 2)), color="#4a7a2a", lw=0.6, ls=":")
    ax.set_xlim(-2.2, 2.2); ax.set_ylim(-0.3, 3.4)
    ax.set_title("b) jeden grafický blok 0,5 m: síť + textura,\ntečkovaně hranice podbuněk 0,25 m", fontsize=9.5)
    # panel c: typy bloků
    ax = fig.add_axes([0.47, 0.52, 0.18, 0.40]); ax.axis("off")
    ax.set_xlim(0, 1); ax.set_ylim(0, 1)
    ax.set_title("c) popis bloku (C#, bez Godotu)", fontsize=9.5)
    txt = ("PopisBloku 0,5 m:\n• hlavní materiál (id u8) + podíl\n• maska 8 podbuněk (bitová)\n• horní plocha: tráva / písek / voda\n"
           "• hrany: převis trávy, útes,\n  okraj ostrova, šev bloku\n• profil vzhledu: visualProfiles\n  katalogu Dev + textura VPMG\n• voda: hladina, vodopád\n\n→ stejné pro 3D sítě i 2D dlaždice")
    ax.text(0.02, 0.95, txt, fontsize=8.6, va="top", bbox=dict(fc="#fff6e0", ec="#999"))
    # panel d: ostrov
    ax = fig.add_axes([0.02, 0.0, 0.96, 0.52]); ax.axis("off"); ax.set_aspect("equal")
    ax.set_title("d) izometrický ostrov (pevný zoom 64 dlaždic ≈ 16 m na šířku): převis trávy, vrstvená skalní hrana, visící kameny, vodopád do mlhy, průhlednost u postavy", fontsize=9.5)
    s = 1.0; N = 12
    # mlha / oblaka dole
    CLOUDS = []
    for i in range(9):
        CLOUDS.append(iso(i * 1.5, 0, -7.4 - 0.3 * (i % 2))); CLOUDS.append(iso(0, i * 1.5, -7.4 - 0.3 * ((i + 1) % 2)))
    # skalní okraj: vrstvy pod přední hranou
    bands = ["#8a6a4a", "#b6a58c", "#8f8a84", "#6f6a70"]
    for side in ("L", "R"):
        for bi, col in enumerate(bands):
            z0, z1 = -bi * 1.2, -(bi + 1) * 1.2
            if side == "L":
                poly = [iso(0, 0, z0), iso(N, 0, z0), iso(N, 0, z1 + (0.3 if bi == 3 else 0)), iso(0, 0, z1)]
            else:
                poly = [iso(0, 0, z0), iso(0, N, z0), iso(0, N, z1), iso(0, 0, z1 - (0.3 if bi == 2 else 0))]
            ax.add_patch(Polygon(poly, fc=col, ec="#4a3a2a", lw=0.8))

    # visící kameny + kořeny
    for (x, y, z, r) in [(3, 0, -5.9, 0.55), (8.5, 0, -6.1, 0.45), (0, 4, -6.0, 0.5), (0, 8.5, -5.8, 0.4)]:
        cx, cy = iso(x, y, z)
        ax.add_patch(Polygon([(cx - r, cy + r * 0.3), (cx + r, cy + r * 0.4), (cx + r * 0.6, cy - r), (cx - r * 0.5, cy - r * 0.8)], fc="#7a7478", ec="#333"))
        ax.plot([cx, cx + 0.1, cx - 0.05], [cy + r * 0.35, cy + 0.8, cy + 1.3], color="#6b4e2e", lw=0.8)
    # horní plocha
    ax.add_patch(Polygon([iso(0, 0, 0), iso(N, 0, 0), iso(N, N, 0), iso(0, N, 0)], fc="#9cc96a", ec="#5a7a3a"))
    # převis trávy přes hranu (třásně)
    for i in range(48):
        a = iso(i * N / 48, 0, 0.05); b = iso(i * N / 48 + 0.12, 0, -0.45 - 0.2 * (i % 3)); c = iso((i + 1) * N / 48, 0, 0.05)
        ax.add_patch(Polygon([a, b, c], fc="#7fb050", ec="none"))
        a = iso(0, i * N / 48, 0.05); b = iso(0, i * N / 48 + 0.12, -0.45 - 0.2 * ((i + 1) % 3)); c = iso(0, (i + 1) * N / 48, 0.05)
        ax.add_patch(Polygon([a, b, c], fc="#6f9e45", ec="none"))
    # řeka + vodopád
    river = [iso(5.2, N, 0.02), iso(6.2, N, 0.02), iso(6.0, 0, 0.02), iso(5.0, 0, 0.02)]
    ax.add_patch(Polygon(river, fc="#7cc4f0", ec="#3a8ac0"))
    w0, w1 = iso(5.0, 0, 0), iso(6.0, 0, 0)
    ax.add_patch(Polygon([w0, w1, (w1[0] + 0.3, w1[1] - 7.6), (w0[0] - 0.3, w0[1] - 7.6)], fc=(0.55, 0.8, 0.97, 0.75), ec="#3a8ac0"))
    for k in range(6):
        ax.plot([w0[0] + 0.15 * k + 0.05, w0[0] + 0.15 * k], [w0[1] - 0.2, w0[1] - 6.6], color="white", lw=0.6, alpha=0.8)
    for (cx, cy) in CLOUDS:
        ax.add_patch(Ellipse((cx, cy), 3.2, 1.3, fc=(1, 1, 1, 0.92), ec=(0.82, 0.86, 0.95, 1)))
    ax.add_patch(Ellipse((w0[0] + 0.5, w0[1] - 7.8), 3.5, 1.3, fc=(1, 1, 1, 0.97), ec="none"))
    ax.annotate("vodopád z okraje do oblak\n(dál se nesimuluje)", xy=(w1[0] + 0.2, w1[1] - 4), xytext=(12.5, -8.6), fontsize=8, arrowprops=dict(arrowstyle="-", color="#333"))
    # stromy, domek
    for (x, y) in [(2, 8), (3, 10), (9, 9), (10, 4), (8, 11)]:
        cx, cy = iso(x, y, 0)
        ax.plot([cx, cx], [cy, cy + 0.8], color="#6b4e2e", lw=2)
        ax.add_patch(Circle((cx, cy + 1.2), 0.6, fc="#5f9a48", ec="#2f5a28"))
    # kopec s převisem (blok 0,5 m výš)
    for (x, y) in [(8, 6), (9, 6), (8, 7), (9, 7), (10, 6), (10, 7)]:
        cube(ax, x, y, 0, 1, "#a07850", 1, 0, 0, lw=0.4)
        ax.add_patch(Polygon([iso(x, y, 1), iso(x + 1, y, 1), iso(x + 1, y + 1, 1), iso(x, y + 1, 1)], fc="#9cc96a", ec="#5a7a3a", lw=0.4))
    # postava a průhlednost
    px, py = iso(4, 4, 0)
    ax.add_patch(Ellipse((px, py + 1.0), 3.4, 4.0, fc=(1, 1, 1, 0.0), ec="#c00000", ls="--", lw=1.2))
    for i in range(10):
        for j in range(12):
            if (i + j) % 2 == 0:
                ax.add_patch(Rectangle((px - 1.3 + i * 0.26, py - 0.8 + j * 0.3), 0.08, 0.08, fc="#c00000", alpha=0.35, ec="none"))
    ax.plot([px, px], [py, py + 1.0], color="#ff7aa0", lw=4); ax.add_patch(Circle((px, py + 1.25), 0.25, fc="#ffd0b0", ec="#333"))
    ax.annotate("průhlednost: válec od postavy ke kameře\n(dither), řez v podzemí – přepínače,\nvýchozí vypnuto (7.3)", xy=(px - 1.6, py + 1.0), xytext=(-13.5, py + 3.5), fontsize=8, color="#a00000", arrowprops=dict(arrowstyle="-", color="#a00000"))
    ax.annotate("vrstvy hornin na hraně podle geologie okraje\n(bok = prezentace, ne data; 5 m pod nejnižší buňkou)", xy=iso(N - 1, 0, -2.0), xytext=(11.5, -2.8), fontsize=8, arrowprops=dict(arrowstyle="-", color="#333"))
    ax.annotate("visící kameny s kořínky (MultiMesh)", xy=iso(0, 4, -6.0), xytext=(-13.5, -6.5), fontsize=8, arrowprops=dict(arrowstyle="-", color="#333"))
    ax.annotate("převis trávy přes hranu (pás nad okrajem)", xy=iso(N - 2, 0, -0.3), xytext=(9.5, 2.0), fontsize=8, arrowprops=dict(arrowstyle="-", color="#333"))
    ax.annotate("kopec o 1 grafický blok (0,5 m) výš", xy=iso(10, 7, 1), xytext=(9.5, 9.5), fontsize=8, arrowprops=dict(arrowstyle="-", color="#333"))
    ax.set_xlim(-14, 19); ax.set_ylim(-10, 12.5)
    fig.savefig(os.path.join(OUT, "05-vizualni-generator.png"), bbox_inches="tight"); plt.close(fig)

if __name__ == "__main__":
    obr1(); obr2(); obr3(); obr4(); obr5()
    print("hotovo:", sorted(f for f in os.listdir(OUT) if f.endswith(".png")))
