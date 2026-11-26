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
        (0.765, 0.15, "#e8f1fb", "4 · Godot scény a uzly (C#, [Tool], viditelné v editoru)",
         ["EditorSveta.tscn\nMapaPlanety, PanelUdalosti,\nInspektor, PanelPrepoctu, Rez",
          "KonfiguratorKatalogu.tscn\nTabulky, ProfilVzhledu,\nNahledVzorku, Validace",
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
          "IKatalogy\nNacti / Validuj /\nNavrh verze / Diff",
          "IVizualniData\nGrafickeBloky(okno 0,5 m),\nOkraj, Vodopady"]),
        (0.12, 0.245, "#fbeaea", "1 · Knihovna cs/Willage.Gen (čistý C#, deterministická, bez Godotu) – už existuje",
         ["Jadro · Sum · Materialy\n(GeologyHash, Q16,\nFastNoiseLite, katalog)",
          "Svet · Geologie\n(SvetFn, maska pevniny,\nmoře, sopky, GeologieCs)",
          "Eroze · Klima\n(MapaEroze WGER,\npásma, srážky, oázy)",
          "Voda · Prusak\n(hladina, prameny,\nvodníci, pobřežní pás)",
          "NOVÉ: Pipeline · Planeta\nUdalosti · Vyrez · Bunky\nVizual (popis bloků)"]),
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
    fig, ax = canvas(17, 8, "2 · Tok dat generátoru světa (každý krok = uzel s klíčem keše; editor přepočítá jen kroky za změnou)")
    kroky = [("Parametry\nplanety + seed\n+ manifest katalogů", "#eeeeee"),
             ("Reliéf, moře,\nkontinenty, masiv,\nsopky (SvetFn)", "#e8f1fb"),
             ("Geologie\nvrstvy, útvary,\nnitro sopky", "#f3e6d8"),
             ("Eroze planety\nmapa 32 m WGER\n(pozůstatek minulosti)", "#e0efe0"),
             ("Klima a biomy\npásma, srážky,\npouště, oázy", "#fff3cc"),
             ("Voda\nhladina 7c, zvodnělá\nzóna 7d, prameny,\nvodníci, průsak", "#dcefff"),
             ("Vegetace a\npovrchové jevy\njako funkce", "#e6f5d8"),
             ("Hotová planeta\n(potvrzená,\nsoubor WPLN)", "#ffd9b3")]
    n = len(kroky); w = 0.105; g = (0.96 - n * w) / (n - 1)
    xs = []
    for i, (t, c) in enumerate(kroky):
        x = 0.02 + i * (w + g); xs.append(x)
        box(ax, x, 0.62, w, 0.17, t, fc=c, fs=7.9, bold=(i == n - 1))
        if i: arrow(ax, xs[i - 1] + w, 0.705, x, 0.705)
    ax.text(0.02, 0.925, "Funkce světa (jednou za planetu, předherní fáze, editor 7b)", fontsize=10.5, weight="bold")
    for i, k in enumerate(["K0", "K1", "K2", "K3", "K4", "K5", "K6", "K7"]):
        ax.text(xs[i] + w / 2, 0.60, f"klíč {k}", fontsize=7.5, ha="center", va="top", color="#666")
    # události editoru
    box(ax, 0.20, 0.825, 0.62, 0.06, "Události editoru s regiony přes více bloků (pořadí, parametry, seed, zap/vyp) → vstup kroků K1–K6",
        fc="#ffe3c2", fs=8.5)
    for i in (1, 3, 4, 5):
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

# ---------------------------------------------------------------- 3 propojení A/B/C
def obr3():
    fig, ax = canvas(13, 8.5, "3 · Jak se propojí generátor světa (A), konfigurátor katalogu (B) a vizuální generátor (C)")
    box(ax, 0.33, 0.40, 0.34, 0.28,
        "Sdílené katalogy (jedno MaterialId u8)\n\n• fyzika: materials-catalog-v1.json\n  (zrcadlo Willage_Dev, jen čtení)\n• generátor: poradi_hornin, sum_hornin,\n  hostitelé, klima_v1 (pásma), more, eroze,\n  voda, prusak, klima_presety\n• vzhled: vzhled_materialu_v1.json (A9)\n\nmanifest_katalogu_v1.json: soubor → SHA, schéma",
        fc="#fff6e0", fs=8.5)
    box(ax, 0.03, 0.66, 0.26, 0.2, "A · Generátor světa + editor 7b\npipeline K0–K7, události s regiony,\npotvrzená planeta WPLN", fc="#e8f1fb", fs=9, bold=False)
    box(ax, 0.71, 0.66, 0.26, 0.2, "B · Konfigurátor katalogu terénu\núpravy, validace, náhled vzorku,\nnávrh nové verze + diff", fc="#f5e1ff", fs=9)
    box(ax, 0.37, 0.08, 0.26, 0.2, "C · Vizuální generátor\ngrafické bloky 0,5 m, okraj,\nvodopády, průhlednost", fc="#eaf7ea", fs=9)
    arrow(ax, 0.29, 0.74, 0.33, 0.62, "čte fyziku +\ngenerátorové", c="#2b5d9b")
    arrow(ax, 0.71, 0.74, 0.67, 0.62, "píše jen návrh\nverze (ne Willage_Dev)", c="#7a3ea0")
    arrow(ax, 0.50, 0.40, 0.50, 0.28, "čte jen vzhled\n+ id materiálů", c="#2a7a2a")
    arrow(ax, 0.20, 0.66, 0.37, 0.20, None, c="#2a7a2a", rad=0.12)
    ax.text(0.255, 0.43, "data okna\n(DTO)", fontsize=8, color="#2a7a2a", ha="center", bbox=dict(fc="white", ec="none", pad=1))
    arrow(ax, 0.71, 0.70, 0.29, 0.80, "náhled vzorku\npřes fasádu A", c="#7a3ea0", rad=0.25)
    # klíče keše
    box(ax, 0.01, 0.08, 0.235, 0.27,
        "Klíč keše kroku Kn =\nH( gen_ver, verze algoritmu kroku,\n   kanonické parametry kroku,\n   SHA souborů z manifestu, které krok čte,\n   klíče vstupních kroků,\n   hash událostí, které krok ovlivňují )\n\nZměna vzhledu NEmění klíče světa.",
        fc="#f2f2f2", fs=7.4, ha="center")
    box(ax, 0.67, 0.08, 0.30, 0.27,
        "Uložení\n• planeta WPLN: hlavička + gen_ver + seed +\n  manifest (SHA) + parametry + události\n  + odvozené mapy (WGER, klima) jako keš\n• ostrov WTI1 (E88): vložení + překryv E78\n• katalog: verze vN + diff, potvrzená\n  planeta si pamatuje svoji verzi",
        fc="#f2f2f2", fs=8.2)
    fig.savefig(os.path.join(OUT, "03-propojeni-abc.png"), bbox_inches="tight"); plt.close(fig)

# ---------------------------------------------------------------- 4 drátěný model UI
def obr4():
    fig, axs = plt.subplots(1, 2, figsize=(17, 7.6), dpi=120, gridspec_kw=dict(width_ratios=[1.25, 1]))
    for ax in axs: ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
    fig.suptitle("4 · Drátěný model: editor světa (7b) a konfigurátor katalogu terénu", fontsize=14, weight="bold")
    ax = axs[0]
    ax.add_patch(Rectangle((0, 0), 1, 0.95, fc="#fafafa", ec="#333", lw=1.5))
    box(ax, 0.0, 0.89, 1, 0.06, "  Planeta: seed 49 ▾ | klima planety: mírné ▾ | gen_ver V1.0 | [Přepočítat]  [Zpět]  [Potvrdit planetu ✔]  [Uložit WPLN]",
        fc="#dde6f0", fs=8.3, ha="left", r=0.0)
    # levý panel události
    box(ax, 0.01, 0.17, 0.22, 0.70, "", fc="#ffffff", r=0.0)
    ax.text(0.02, 0.85, "Události (od nejstarší)", fontsize=9, weight="bold")
    ev = ["☑ 1 Pevnina: kontinent Z", "☑ 2 Pohoří S–J", "☑ 3 Pánev 1500 m", "☐ 4 Snížení (moře)", "☑ 5 Pásmo: chladné +10 %", "☑ 6 Řeka vynucená"]
    for i, e in enumerate(ev):
        fc = "#ffe3c2" if i == 1 else "#ffffff"
        box(ax, 0.02, 0.78 - i * 0.065, 0.20, 0.055, e, fc=fc, fs=7.8, ha="left", r=0.005)
    ax.text(0.02, 0.36, "[+ přidat ▾]  [▲] [▼]  [izolovat]", fontsize=7.8)
    ax.text(0.02, 0.31, "Vrstvy mapy:", fontsize=8.5, weight="bold")
    for i, v in enumerate(["☑ výška", "☐ moře", "☑ eroze", "☐ klima", "☑ biomy", "☐ voda/prameny"]):
        ax.text(0.03 + (i % 2) * 0.1, 0.27 - (i // 2) * 0.035, v, fontsize=7.8)
    # mapa
    ax.add_patch(Rectangle((0.25, 0.30), 0.48, 0.57, fc="#cfe3f2", ec="#333"))
    random.seed(3)
    land = Polygon([(0.30, 0.40), (0.36, 0.33), (0.50, 0.36), (0.62, 0.34), (0.70, 0.45), (0.66, 0.62), (0.70, 0.78), (0.55, 0.84), (0.40, 0.80), (0.31, 0.66), (0.28, 0.52)],
                   fc="#cfe6b5", ec="#6a8a4a")
    ax.add_patch(land)
    for k in range(8):  # pohoří
        ax.add_patch(Polygon([(0.47 + k * 0.004, 0.40 + k * 0.05), (0.49 + k * 0.004, 0.44 + k * 0.05), (0.51 + k * 0.004, 0.40 + k * 0.05)], fc="#a08a70", ec="none"))
    for gx in range(12):
        ax.plot([0.25 + gx * 0.04] * 2, [0.30, 0.87], color="#ffffff", lw=0.4)
    for gy in range(15):
        ax.plot([0.25, 0.73], [0.30 + gy * 0.04] * 2, color="#ffffff", lw=0.4)
    for (bx, by) in [(5, 3), (6, 3), (5, 4), (6, 4), (6, 5), (5, 5)]:
        ax.add_patch(Rectangle((0.25 + bx * 0.04, 0.30 + by * 0.04), 0.04, 0.04, fc=(1, 0.5, 0, 0.35), ec="#d06000", lw=1.2))
    ax.text(0.49, 0.315, "výběr 6 bloků 128 m (Shift = přidat), okraj s útlumem", fontsize=7.5, ha="center",
            bbox=dict(fc="white", ec="none", pad=1))
    ax.plot([0.30, 0.68], [0.56, 0.70], color="#c00000", lw=1.2, ls="--"); ax.text(0.66, 0.71, "řez", color="#c00000", fontsize=8)
    # inspektor
    box(ax, 0.75, 0.30, 0.24, 0.57, "", fc="#ffffff", r=0.0)
    ax.text(0.76, 0.85, "Inspektor: 2 Pohoří S–J", fontsize=9, weight="bold")
    for i, p in enumerate(["typ: pohoří", "region: 6 bloků, útlum 64 m", "převýšení: 420 m", "šířka: 900 m", "drsnost: 0,6", "seed: 7712", "verze algoritmu: 1", "ovlivní: K1→K7"]):
        ax.text(0.765, 0.80 - i * 0.055, p, fontsize=7.8)
        ax.add_patch(Rectangle((0.76, 0.785 - i * 0.055), 0.22, 0.04, fc="none", ec="#bbb", lw=0.6))
    # řez dole
    box(ax, 0.25, 0.04, 0.48, 0.24, "", fc="#ffffff", r=0.0)
    xs = [0.26 + i * 0.0115 for i in range(40)]
    ys = [0.12 + 0.07 * math.exp(-((i - 22) / 5) ** 2) + 0.01 * math.sin(i) for i in range(40)]
    ax.fill_between(xs, 0.06, ys, color="#d8c3a5"); ax.fill_between(xs, 0.06, [y - 0.03 for y in ys], color="#b59a7a")
    ax.plot(xs, [min(y - 0.01, 0.15) for y in ys], color="#1f6fd0", lw=1)
    ax.text(0.26, 0.255, "Řez (vrstvy, hladina, zvodnělá zóna šrafou)", fontsize=8, weight="bold")
    # přepočet
    box(ax, 0.75, 0.04, 0.24, 0.24, "", fc="#ffffff", r=0.0)
    ax.text(0.76, 0.255, "Přepočet kroků", fontsize=8.5, weight="bold")
    st = [("K1 reliéf", "✔ keš", "#2a7a2a"), ("K2 geologie", "✔ keš", "#2a7a2a"), ("K3 eroze", "⟳ 5,1 s", "#c06000"),
          ("K4 klima", "· čeká", "#888"), ("K5 voda", "· čeká", "#888"), ("K6 vegetace", "· čeká", "#888")]
    for i, (a, b, c) in enumerate(st):
        ax.text(0.765, 0.22 - i * 0.03, a, fontsize=7.8); ax.text(0.90, 0.22 - i * 0.03, b, fontsize=7.8, color=c)
    box(ax, 0.01, 0.04, 0.22, 0.12, "Diagnostika: podíl moře 35 %,\nřek 412, vodníků 84, oáz 0,\nčas 5,4 s, otisk 3fa1…", fc="#f2f2f2", fs=7.6, r=0.0)
    # --- konfigurátor
    ax = axs[1]
    ax.add_patch(Rectangle((0, 0), 1, 0.95, fc="#fafafa", ec="#333", lw=1.5))
    box(ax, 0.0, 0.89, 1, 0.06, "  Katalog: v3 (návrh v4*) | [Validovat] [Diff] [Uložit návrh] [Použít v editoru]", fc="#e9ddf3", fs=8.3, ha="left", r=0.0)
    tabs = ["Materiály", "Vzhled", "Pořadí hornin", "Pásma klimatu", "Biomy", "Voda/průsak"]
    for i, t in enumerate(tabs):
        box(ax, 0.01 + i * 0.163, 0.83, 0.155, 0.045, t, fc="#ffffff" if i != 1 else "#ffe3c2", fs=7.8, r=0.005)
    # tabulka
    box(ax, 0.01, 0.30, 0.55, 0.51, "", fc="#ffffff", r=0.0)
    hdr = ["id", "název", "barva", "hrany", "textura"]
    cols = [0.02, 0.07, 0.25, 0.34, 0.45]
    for c, hname in zip(cols, hdr): ax.text(c, 0.785, hname, fontsize=8, weight="bold")
    rows = [("1", "ornice", "#7aa64a", "měkké", "trava_a"), ("3", "písek", "#e8d39a", "měkké", "pisek_zrno"),
            ("5", "vápenec", "#d9d2c0", "lámavé", "vapenec_vrst"), ("6", "žula", "#b59a9a", "hranaté", "zula"),
            ("7", "čedič", "#5c6470", "sloupce", "cedic"), ("44", "dolomit", "#cfc8b0", "lámavé", "dolomit"),
            ("57", "jíl", "#c07a50", "oblé", "jil")]
    for i, r in enumerate(rows):
        y = 0.745 - i * 0.055
        for c, v in zip(cols, r):
            if v.startswith("#"):
                ax.add_patch(Rectangle((c, y - 0.012), 0.05, 0.03, fc=v, ec="#555"))
            else:
                ax.text(c, y, v, fontsize=7.8)
    ax.text(0.02, 0.32, "fyzika (K, pórovitost) jen čtení – zrcadlo Willage_Dev", fontsize=7.4, color="#a00")
    # náhled
    box(ax, 0.58, 0.30, 0.41, 0.51, "", fc="#ffffff", r=0.0)
    ax.text(0.59, 0.785, "Náhled vzorku 8 m (seed, místo ▾)", fontsize=8, weight="bold")
    for i in range(6):
        for j in range(4):
            cols2 = ["#7aa64a", "#c07a50", "#d9d2c0", "#d9d2c0", "#b59a9a", "#5c6470"]
            ax.add_patch(Rectangle((0.62 + j * 0.08, 0.36 + (5 - i) * 0.065), 0.08, 0.065, fc=cols2[i], ec="#666", lw=0.5))
    ax.text(0.79, 0.33, "řez / 3D mini", fontsize=7.6, ha="center")
    box(ax, 0.01, 0.04, 0.48, 0.23, "Validace\n✔ id unikátní 0–255\n✔ rozsahy, vzorec propustnosti\n⚠ pásma: součet podílů 0,98\n✖ vrstva < 0,25 m (pravidlo 1.7.1)", fc="#f2f2f2", fs=7.8, r=0.0)
    box(ax, 0.51, 0.04, 0.48, 0.23, "Diff v3 → v4*\n~ vápenec: hrany lámavé → hranaté\n+ pásmo „polární“ TDoC −22\n→ dotčené klíče: K4, K5 (svět)\n→ vzhled: jen keš sítí", fc="#f2f2f2", fs=7.8, r=0.0)
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
           "• hrany: převis trávy, útes,\n  okraj ostrova, šev bloku\n• profil vzhledu z katalogu (A9):\n  zaoblení, lámavost, textura\n• voda: hladina, vodopád\n\n→ stejné pro 3D sítě i 2D dlaždice")
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
