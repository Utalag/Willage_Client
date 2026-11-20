#!/usr/bin/env python3
# T01 (dříve E65): návrh vlastností a těžby hornin (tezba-studie; jen tabulka + graf).
# Nepřepisuje sdilene/materialy_voda.json ani horniny_voda.json.
# Čas hry z jednoho místa: blueprint-studie/scripts/voda/cas_hry.gd (E77, 1 herní den = 1 h reálně, faktor 24).
# Buňka 0,5 m = 0,125 m³; výnos a čas ~ objemu.

from __future__ import annotations
import json
import re
from pathlib import Path

STUDY = Path(__file__).resolve().parent.parent
OUT_JSON = STUDY / "data" / "horniny_tezba_navrh.json"
OUT_PNG = STUDY / "shots" / "65_horniny_tezba.png"

CAS_HRY = STUDY.parent / "blueprint-studie" / "scripts" / "voda" / "cas_hry.gd"
CAS_FAKTOR = float(re.search(r"const FAKTOR := ([0-9.]+)", CAS_HRY.read_text(encoding="utf-8")).group(1))  # herních dní za reálný den
BUNKA_M = 0.5
OBJEM = BUNKA_M ** 3  # 0.125 m³

# produktivita m³/h s minimálním dostatečným nástrojem (řádově, ZDROJE [10][11][12])
PROD_M3H = {
    "ruka": 0.80,
    "kamen": 0.25,
    "bronz": 0.12,
    "zelezo": 0.05,
    "ocel": 0.03,
    "trhaviny": 1.20,
}

# hratelný návrh (sekundy reálného času na buňku 0,5 m), Jan rozhodne
NAVRH_S = {
    "ruka": 1.0,
    "kamen": 3.0,
    "bronz": 6.0,
    "zelezo": 12.0,
    "ocel": 18.0,
    "trhaviny": 2.0,
}

NASTROJE = [
    {"id": "ruka", "idx": 0, "nazev": "ruka / dřevo", "popis": "sypké zeminy a sníh"},
    {"id": "kamen", "idx": 1, "nazev": "kamenné nástroje", "popis": "měkké horniny (sádrovec, sůl, uhlí, břidlice)"},
    {"id": "bronz", "idx": 2, "nazev": "bronz / měď", "popis": "středně pevné sedimenty (vápenec, pískovec)"},
    {"id": "zelezo", "idx": 3, "nazev": "železo", "popis": "tvrdé krystalinikum (žula, čedič, rula, gabro)"},
    {"id": "ocel", "idx": 4, "nazev": "ocel", "popis": "velmi tvrdé a abrazivní (kvarcit, eklogit)"},
    {"id": "trhaviny", "idx": 5, "nazev": "trhaviny", "popis": "volitelně plocha, rychleji, víc suti a prachu; není nutná brána"},
]

TRIDY = [
    {"id": "sypka", "nastroj_min": "ruka", "ucs_mpa": [0, 1], "popis": "sypké nebo velmi slabé (písek, suť, ornice, sníh)"},
    {"id": "mekka", "nastroj_min": "kamen", "ucs_mpa": [1, 25], "popis": "měkká hornina (sádrovec, sůl, uhlí, jílovec, zvětraliny)"},
    {"id": "stredni", "nastroj_min": "bronz", "ucs_mpa": [25, 80], "popis": "střední (vápenec, pískovec, dolomit, fylit)"},
    {"id": "tvrda", "nastroj_min": "zelezo", "ucs_mpa": [80, 200], "popis": "tvrdá (žula, čedič, rula, gabro)"},
    {"id": "velmi_tvrda", "nastroj_min": "ocel", "ucs_mpa": [200, 400], "popis": "velmi tvrdá / vysoce abrazivní (kvarcit, eklogit, amfibolit)"},
]

SUROVINY = {
    "blok_horniny": {"id": 200, "nazev": "stavební kámen / kvádr", "popis": "znovu položitelný jako stejné MaterialId", "placeable": "host", "score": 3, "kusovy": False},
    "sterk": {"id": 201, "nazev": "štěrk / drcený kámen", "placeable": "gravel_or_fill", "score": 1, "kusovy": False},
    "pisek": {"id": 202, "nazev": "písek", "placeable": "sand", "score": 1.5, "kusovy": False},
    "jil": {"id": 203, "nazev": "jíl", "placeable": "clay", "score": 2, "kusovy": False},
    "hlina": {"id": 204, "nazev": "hlína", "placeable": "dirt", "score": 1, "kusovy": False},
    "vapno": {"id": 205, "nazev": "vápno / vápencová surovina", "placeable": None, "score": 4, "kusovy": False},
    "sul": {"id": 206, "nazev": "sůl", "placeable": None, "score": 5, "kusovy": False},
    "sadrovec": {"id": 207, "nazev": "sádrovec", "placeable": None, "score": 3, "kusovy": False},
    "uhli": {"id": 208, "nazev": "černé uhlí", "placeable": "coal", "score": 12, "kusovy": False},
    "lignit": {"id": 209, "nazev": "hnědé uhlí", "placeable": "lignite", "score": 6, "kusovy": False},
    "ruda_med": {"id": 210, "nazev": "měděná ruda", "placeable": None, "score": 40, "kusovy": False},
    "ruda_zelezo": {"id": 211, "nazev": "železná ruda", "placeable": None, "score": 25, "kusovy": False},
    "ruda_fe_ti": {"id": 212, "nazev": "titanomagnetit (Fe-Ti)", "placeable": None, "score": 30, "kusovy": False},
    "ruda_zlato": {"id": 213, "nazev": "zlatá ruda", "placeable": None, "score": 250, "kusovy": False},
    "ruda_vzacne": {"id": 214, "nazev": "vzácné kovy (Li, Sn, Ta)", "placeable": None, "score": 90, "kusovy": False},
    "drahokamy": {"id": 215, "nazev": "drahokamy", "placeable": None, "score": 150, "kusovy": True},
    "diamanty": {"id": 216, "nazev": "diamanty", "placeable": None, "score": 400, "kusovy": True},
    "granaty": {"id": 217, "nazev": "granáty", "placeable": None, "score": 60, "kusovy": True},
    "kremenny_pisek": {"id": 218, "nazev": "křemenný písek", "placeable": "sand", "score": 2, "kusovy": False},
    "snih": {"id": 219, "nazev": "sníh / led", "placeable": "snow", "score": 8, "kusovy": False},
    "prach": {"id": 220, "nazev": "prach / jemná suť (část nepoužitelná)", "placeable": None, "score": 0, "kusovy": False},
    "jalovina": {"id": 221, "nazev": "jalovina", "placeable": None, "score": 0.5, "kusovy": False},
}

# typické hodnoty skupin: mohs, mohs_r, ucs, ucs_r, rho, cai, trida, chovani, vzacnost, zdroje
G = {
    "vzduch": dict(mohs=0, mohs_r=(0, 0), ucs=0, ucs_r=(0, 0), rho=1, cai=0, trida="sypka", nastroj="ruka", chovani="netezitelne", vzacnost="—", z=[1]),
    "snih": dict(mohs=1.5, mohs_r=(1, 2), ucs=0.5, ucs_r=(0.1, 2), rho=850, cai=0.2, trida="sypka", nastroj="ruka", chovani="sypka", vzacnost="běžná", z=[7]),
    "puda": dict(mohs=2.0, mohs_r=(1, 2.5), ucs=0.3, ucs_r=(0.05, 1), rho=1700, cai=0.4, trida="sypka", nastroj="ruka", chovani="soudrzna_zemina", vzacnost="běžná", z=[1, 2, 4]),
    "pisek": dict(mohs=6.0, mohs_r=(5, 7), ucs=0.0, ucs_r=(0, 0.2), rho=1800, cai=1.5, trida="sypka", nastroj="ruka", chovani="sypka", vzacnost="běžná", z=[4, 5, 7]),
    "jil": dict(mohs=2.0, mohs_r=(1, 2.5), ucs=0.4, ucs_r=(0.05, 1), rho=1800, cai=0.4, trida="sypka", nastroj="ruka", chovani="soudrzna_zemina", vzacnost="běžná", z=[2, 4, 5]),
    "spras": dict(mohs=2.0, mohs_r=(1, 2.5), ucs=0.2, ucs_r=(0.05, 0.8), rho=1550, cai=0.5, trida="sypka", nastroj="ruka", chovani="sypka", vzacnost="běžná", z=[2, 4]),
    "sterk": dict(mohs=5.0, mohs_r=(3, 7), ucs=0.0, ucs_r=(0, 0.2), rho=1900, cai=1.5, trida="sypka", nastroj="ruka", chovani="sypka", vzacnost="běžná", z=[4, 5]),
    "evap_sad": dict(mohs=2.0, mohs_r=(2, 2), ucs=12, ucs_r=(7, 35), rho=2300, cai=0.3, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 7]),
    "evap_sul": dict(mohs=2.3, mohs_r=(2, 2.5), ucs=27, ucs_r=(15, 35), rho=2160, cai=0.3, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 4, 7]),
    "uhli": dict(mohs=2.3, mohs_r=(2, 3), ucs=30, ucs_r=(8, 50), rho=1400, cai=0.6, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 4, 5]),
    "lignit": dict(mohs=2.0, mohs_r=(1.5, 2.5), ucs=15, ucs_r=(5, 30), rho=1200, cai=0.5, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="běžná", z=[3, 4]),
    "bridlice": dict(mohs=3.0, mohs_r=(2, 4), ucs=30, ucs_r=(5, 100), rho=2500, cai=0.7, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="běžná", z=[1, 3, 5, 7]),
    "prachovec": dict(mohs=3.5, mohs_r=(3, 5), ucs=50, ucs_r=(20, 90), rho=2400, cai=1.0, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[3, 4]),
    "vapenec": dict(mohs=3.2, mohs_r=(3, 4), ucs=107, ucs_r=(30, 250), rho=2640, cai=1.5, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[1, 3, 4, 5, 7]),
    "dolomit": dict(mohs=3.7, mohs_r=(3.5, 4), ucs=86, ucs_r=(15, 120), rho=2850, cai=1.5, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 4, 7]),
    "piskovec": dict(mohs=6.5, mohs_r=(6, 7), ucs=80, ucs_r=(20, 170), rho=2400, cai=2.5, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[1, 3, 4, 5, 7]),
    "slepenec": dict(mohs=5.0, mohs_r=(3, 7), ucs=80, ucs_r=(40, 130), rho=2500, cai=2.0, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[3, 4]),
    "flys": dict(mohs=4.0, mohs_r=(3, 6), ucs=40, ucs_r=(15, 80), rho=2450, cai=1.5, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[1, 3]),
    "fylit": dict(mohs=3.5, mohs_r=(3, 5), ucs=39, ucs_r=(20, 70), rho=2600, cai=0.8, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="běžná", z=[3, 5]),
    "svor": dict(mohs=5.0, mohs_r=(4, 7), ucs=104, ucs_r=(60, 200), rho=2700, cai=1.8, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="běžná", z=[3, 5, 7]),
    "hadec": dict(mohs=4.0, mohs_r=(3, 5), ucs=60, ucs_r=(30, 120), rho=2600, cai=1.0, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 7]),
    "kimberlit": dict(mohs=4.5, mohs_r=(4, 6), ucs=40, ucs_r=(20, 80), rho=2600, cai=1.5, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="vzácná", z=[3, 9]),
    "zvetr": dict(mohs=4.0, mohs_r=(2, 6), ucs=20, ucs_r=(5, 40), rho=2300, cai=1.2, trida="mekka", nastroj="kamen", chovani="soudrzna", vzacnost="běžná", z=[1, 4]),
    "zula": dict(mohs=6.5, mohs_r=(6, 7), ucs=154, ucs_r=(100, 250), rho=2720, cai=5.0, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="běžná", z=[1, 3, 4, 5, 7]),
    "cedic": dict(mohs=6.5, mohs_r=(6, 8), ucs=145, ucs_r=(100, 300), rho=3000, cai=3.0, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="běžná", z=[1, 3, 4, 5]),
    "gabro": dict(mohs=6.5, mohs_r=(6, 7), ucs=228, ucs_r=(100, 300), rho=3000, cai=3.0, trida="velmi_tvrda", nastroj="ocel", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 4, 5]),
    "rula": dict(mohs=6.5, mohs_r=(6, 7), ucs=130, ucs_r=(80, 240), rho=2750, cai=4.5, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="běžná", z=[3, 4, 5, 7]),
    "amfibolit": dict(mohs=6.0, mohs_r=(5, 7), ucs=212, ucs_r=(100, 280), rho=3000, cai=5.0, trida="velmi_tvrda", nastroj="ocel", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 5]),
    "kvarcit": dict(mohs=7.0, mohs_r=(7, 7), ucs=209, ucs_r=(150, 300), rho=2650, cai=5.5, trida="velmi_tvrda", nastroj="ocel", chovani="soudrzna", vzacnost="neobvyklá", z=[1, 3, 4, 5, 7]),
    "eklogit": dict(mohs=7.0, mohs_r=(6.5, 7.5), ucs=250, ucs_r=(180, 350), rho=3400, cai=5.0, trida="velmi_tvrda", nastroj="ocel", chovani="soudrzna", vzacnost="vzácná", z=[3, 4, 7]),
    "peridotit": dict(mohs=6.7, mohs_r=(6.5, 7), ucs=197, ucs_r=(100, 280), rho=3200, cai=4.0, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="neobvyklá", z=[3, 4, 7]),
    "ruda_med": dict(mohs=4.0, mohs_r=(3, 5), ucs=80, ucs_r=(40, 150), rho=3200, cai=2.0, trida="stredni", nastroj="bronz", chovani="soudrzna", vzacnost="vzácná", z=[4, 8]),
    "ruda_fe": dict(mohs=6.0, mohs_r=(5.5, 6.5), ucs=150, ucs_r=(80, 250), rho=4500, cai=3.0, trida="tvrda", nastroj="zelezo", chovani="soudrzna", vzacnost="neobvyklá", z=[4, 23]),
    "drahokam": dict(mohs=8.0, mohs_r=(6.5, 10), ucs=200, ucs_r=(100, 400), rho=3500, cai=5.0, trida="velmi_tvrda", nastroj="ocel", chovani="soudrzna", vzacnost="vzácná", z=[7, 9]),
}

def y(*pairs):
    """('surovina', permille) ... must sum 1000."""
    items = [{"surovina": k, "promile": int(v)} for k, v in pairs]
    s = sum(i["promile"] for i in items)
    if s != 1000:
        raise SystemExit(f"promile sum {s} != 1000: {pairs}")
    return items

# výchozí výnosy skupin (objemová promile)
Y = {
    "vzduch": y(("prach", 1000)),
    "snih": y(("snih", 1000)),
    "puda": y(("hlina", 800), ("jil", 150), ("pisek", 50)),
    "pisek": y(("pisek", 900), ("sterk", 100)),
    "jil": y(("jil", 900), ("hlina", 100)),
    "spras": y(("hlina", 500), ("pisek", 400), ("jil", 100)),
    "sterk": y(("sterk", 800), ("pisek", 200)),
    "evap_sad": y(("sadrovec", 850), ("sterk", 150)),
    "evap_sul": y(("sul", 900), ("sterk", 100)),
    "uhli": y(("uhli", 850), ("jalovina", 150)),
    "lignit": y(("lignit", 800), ("jil", 200)),
    "bridlice": y(("jil", 500), ("sterk", 400), ("prach", 100)),
    "prachovec": y(("sterk", 600), ("jil", 300), ("pisek", 100)),
    "vapenec": y(("blok_horniny", 600), ("vapno", 250), ("sterk", 150)),
    "dolomit": y(("blok_horniny", 500), ("vapno", 300), ("sterk", 200)),
    "piskovec": y(("blok_horniny", 500), ("kremenny_pisek", 300), ("sterk", 200)),
    "slepenec": y(("blok_horniny", 400), ("sterk", 500), ("pisek", 100)),
    "flys": y(("sterk", 400), ("jil", 300), ("pisek", 300)),
    "fylit": y(("sterk", 700), ("blok_horniny", 200), ("jil", 100)),
    "svor": y(("blok_horniny", 300), ("sterk", 700)),
    "hadec": y(("blok_horniny", 600), ("sterk", 400)),
    "kimberlit": y(("sterk", 850), ("blok_horniny", 150)),
    "zvetr": y(("sterk", 500), ("pisek", 300), ("jil", 200)),
    "zula": y(("blok_horniny", 700), ("sterk", 250), ("kremenny_pisek", 50)),
    "cedic": y(("blok_horniny", 700), ("sterk", 300)),
    "gabro": y(("blok_horniny", 650), ("sterk", 350)),
    "rula": y(("blok_horniny", 650), ("sterk", 350)),
    "amfibolit": y(("blok_horniny", 600), ("sterk", 400)),
    "kvarcit": y(("blok_horniny", 600), ("kremenny_pisek", 200), ("sterk", 200)),
    "eklogit": y(("blok_horniny", 700), ("sterk", 300)),
    "peridotit": y(("blok_horniny", 700), ("sterk", 300)),
    "ruda_med": y(("ruda_med", 400), ("jalovina", 600)),
    "ruda_fe": y(("ruda_zelezo", 700), ("jalovina", 300)),
    "drahokam": y(("jalovina", 900), ("sterk", 100)),
}

# kusový výnos (na 1 buňku 0,5 m), mimo objemová promile
KUS = {
    "diamant": [{"surovina": "diamanty", "kusu_na_bunku_05": 1}],
    "drahokam": [{"surovina": "drahokamy", "kusu_na_bunku_05": 1}],
    "granat": [{"surovina": "granaty", "kusu_na_bunku_05": 1}],
}

# (key, id, name, skupina, idx_or_none, zone, kind, extra)
# extra může přepsat vytezek, kusovy, ucs, ...
ROCKS = [
    ("air", 0, "vzduch", "vzduch", None, "vzduch", "air", {"netezitelne": True}),
    ("cloud_line", 0, "Hranice mraků (vzduch)", "vzduch", 62, "vzduch", "air", {"netezitelne": True, "alias_id": 0}),
    ("map_ceiling", 0, "Strop mapy, vzduch", "vzduch", 63, "vzduch", "air", {"netezitelne": True, "alias_id": 0}),
    ("grass", 1, "tráva / drn", "puda", None, "povrch", "soil", {"vytezek": y(("hlina", 700), ("jil", 150), ("pisek", 150))}),
    ("dirt", 2, "hlína", "puda", None, "povrch", "soil", {}),
    ("topsoil", 2, "Ornice, humus", "puda", 40, "povrch", "soil", {"alias_id": 2}),
    ("sand", 3, "písek", "pisek", None, "sedimenty", "layer", {}),
    ("gravel_sand", 3, "Štěrk, hlinitopísčité sedimenty", "sterk", 38, "sedimenty", "layer", {"vytezek": y(("sterk", 500), ("pisek", 500)), "alias_id": 3}),
    ("clay", 4, "jíl", "jil", None, "sedimenty", "layer", {}),
    ("weathered_clay", 4, "Zvětralá břidlice a jíly", "jil", 37, "sedimenty", "layer", {"alias_id": 4}),
    ("limestone", 5, "vápenec", "vapenec", None, "sedimenty", "layer", {}),
    ("cave_limestone", 5, "Masivní jeskynní vápenec", "vapenec", 32, "sedimenty", "layer", {"alias_id": 5}),
    ("granite", 6, "žula", "zula", 18, "krystalinikum", "layer", {}),
    ("basalt", 7, "čedič", "cedic", None, "plast", "layer", {}),
    ("diabase", 7, "Diabaz (= čedič gen-v3)", "cedic", 9, "plast", "layer", {"ucs": 229, "ucs_r": (150, 350), "rho": 2800, "alias_id": 7, "z": [3, 4]}),
    ("copper", 8, "měděná ruda", "ruda_med", None, "rudy", "vein", {"poznamka": "Buňka už je obohacená žíla, ne porfyrový průměr 0,44 % Cu [49]. Herní podíl 400 ‰ je abstrakce."}),
    ("iron", 9, "železná ruda", "ruda_fe", None, "rudy", "pocket", {"poznamka": "Buňka je už ložisková čočka; podíl 700 ‰ odpovídá spíš DSO/magnetitu (~50–60 % Fe) [55] než chudé hornině."}),
    ("snow", 10, "sníh", "snih", None, "hory", "snow", {}),
    ("eternal_snow", 10, "Věčný sníh a led", "snih", 57, "hory", "snow", {"alias_id": 10}),
    ("clay_deposit", 12, "ložiskový jíl", "jil", None, "sedimenty", "layer", {"vytezek": y(("jil", 1000)), "vzacnost": "neobvyklá"}),
    ("peridotite", 20, "Peridotit / dunit", "peridotit", 0, "plast", "layer", {}),
    ("kimberlite", 21, "Kimberlit (komíny)", "kimberlit", 1, "plast", "pipe", {"poznamka": "Diamanty nejsou objemový podíl (reálně 0,02–10 ct/t, medián 0,25 [50]). Jsou v buňkách diamond + šance na nález."}),
    ("lherzolite", 22, "Lherzolit, olivín", "peridotit", 2, "plast", "layer", {}),
    ("eclogite", 23, "Eklogit", "eklogit", 3, "plast", "layer", {}),
    ("pyroxenite", 24, "Pyroxenit", "gabro", 4, "plast", "layer", {"ucs": 200, "rho": 3200}),
    ("serpentinite", 25, "Serpentinit (hadec)", "hadec", 5, "plast", "layer", {}),
    ("gabbro", 26, "Gabro", "gabro", 6, "plast", "layer", {}),
    ("norite", 27, "Norit / anortozit", "gabro", 7, "plast", "layer", {"ucs": 229}),
    ("fe_ti_zone", 28, "Fe-Ti rudní zóna (magnetit)", "gabro", 8, "plast", "layer", {"poznamka": "Hornina zóny je jako gabro; ruda je v buňkách fe_ti, ne jako objemový podíl hostitele."}),
    ("granulite", 29, "Granulit", "rula", 10, "plast", "layer", {"ucs": 90, "ucs_r": (60, 200), "z": [3]}),
    ("amphibolite", 30, "Amfibolit", "amfibolit", 11, "plast", "layer", {}),
    ("lower_gneiss", 31, "Spodní přechodová břidlice / rula", "rula", 12, "plast", "layer", {}),
    ("migmatite", 32, "Migmatit", "rula", 13, "krystalinikum", "layer", {}),
    ("orthogneiss", 33, "Ortorula", "rula", 14, "krystalinikum", "layer", {}),
    ("biotite_gneiss", 34, "Biotitická rula", "rula", 15, "krystalinikum", "layer", {}),
    ("two_mica_gneiss", 35, "Dvojslídná rula", "rula", 16, "krystalinikum", "layer", {}),
    ("granodiorite", 36, "Granodiorit", "zula", 17, "krystalinikum", "layer", {"ucs": 160, "z": [3]}),
    ("leucogranite", 37, "Světlá granitoidní žula", "zula", 19, "krystalinikum", "layer", {}),
    ("pegmatite", 38, "Pegmatitové žíly", "zula", 20, "krystalinikum", "vein", {"ucs": 120, "ucs_r": (60, 200), "trida": "tvrda", "nastroj": "zelezo", "poznamka": "Drahokamy a vzácné kovy jsou samostatné buňky (gem, rare_metal, gold), ne objemový podíl žíly."}),
    ("quartzite", 39, "Krystalický kvarcit", "kvarcit", 21, "krystalinikum", "layer", {}),
    ("mica_schist", 40, "Svor (granáty, slídy)", "svor", 22, "krystalinikum", "layer", {}),
    ("phyllite", 41, "Fylit", "fylit", 23, "krystalinikum", "layer", {}),
    ("skarn", 42, "Skarn (kontakt)", "vapenec", 24, "krystalinikum", "contact", {"ucs": 100, "mohs": 5.0, "mohs_r": (4, 7), "trida": "tvrda", "nastroj": "zelezo", "cai": 2.5, "vytezek": y(("blok_horniny", 500), ("vapno", 200), ("sterk", 300)), "poznamka": "Cu, Fe a granáty jsou samostatné buňky v hostiteli."}),
    ("crystalline_transition", 43, "Přechodová zóna krystalinika", "rula", 25, "krystalinikum", "layer", {}),
    ("deep_limestone", 44, "Hlubinný vápenec / křída", "vapenec", 26, "sedimenty", "layer", {"poznamka": "V tabulce pořadí je i křída, ale load 100/5 odpovídá spíš kompetentnímu vápenci než křídě (UCS ~1 MPa [44]). Hodnoty jako vápenec."}),
    ("siltstone", 45, "Prachovec", "prachovec", 27, "sedimenty", "layer", {}),
    ("conglomerate", 46, "Slepenec", "slepenec", 28, "sedimenty", "layer", {}),
    ("rock_salt", 47, "Kamenná sůl (dómy)", "evap_sul", 29, "sedimenty", "dome", {}),
    ("gypsum", 48, "Sádrovec, anhydrit", "evap_sad", 30, "sedimenty", "layer", {}),
    ("dolomite", 49, "Dolomit", "dolomit", 31, "sedimenty", "layer", {}),
    ("black_coal", 50, "Černé uhlí (sloj)", "uhli", 33, "sedimenty", "seam", {}),
    ("shale", 51, "Jílová břidlice", "bridlice", 34, "sedimenty", "layer", {}),
    ("quartz_sandstone", 52, "Křemenný pískovec", "piskovec", 35, "sedimenty", "layer", {}),
    ("lignite", 53, "Hnědé uhlí / lignit", "lignit", 36, "sedimenty", "seam", {}),
    ("loess", 54, "Spraš a zvětraliny", "spras", 39, "sedimenty", "layer", {}),
    ("hill_sand", 55, "Písčité podloží pahorků", "pisek", 41, "hory", "mountain", {}),
    ("limestone_outcrop", 56, "Vápencové výchozy", "vapenec", 42, "hory", "mountain", {}),
    ("weathered_volcanic", 57, "Zvětralé vyvřeliny", "zvetr", 43, "hory", "mountain", {}),
    ("flysch", 58, "Lesní půdy, flyš", "flys", 44, "hory", "mountain", {}),
    ("sandstone_towers", 59, "Pískovcové věže a stěny", "piskovec", 45, "hory", "mountain", {}),
    ("weathered_granite", 60, "Zvětralá žula vysočin", "zvetr", 46, "hory", "mountain", {"vytezek": y(("sterk", 500), ("pisek", 300), ("jil", 200)), "poznamka": "Grus: zvětralá žula se rozpadá na štěrk, písek a jíl."}),
    ("mountain_ridge", 61, "Horské hřebeny (Šumava/Krkonoše)", "rula", 47, "hory", "mountain", {}),
    ("slope_schist", 62, "Krystalické břidlice svahů", "svor", 48, "hory", "mountain", {}),
    ("granite_massif", 63, "Žulové masivy hřbetů", "zula", 49, "hory", "mountain", {}),
    ("rock_wall", 64, "Strmé skalní stěny", "zula", 50, "hory", "mountain", {}),
    ("alpine_crystalline", 65, "Vysokohorské krystalinikum", "rula", 51, "hory", "mountain", {}),
    ("subalpine_scree", 66, "Subalpínské pásmo (skály, sutě)", "sterk", 52, "hory", "mountain", {}),
    ("alpine_belt", 67, "Alpínský stupeň", "rula", 53, "hory", "mountain", {}),
    ("alpine_granite", 68, "Vysokohorský granit", "zula", 54, "hory", "mountain", {}),
    ("alpine_quartzite", 69, "Vysokohorské kvarcity a břidlice", "kvarcit", 55, "hory", "mountain", {}),
    ("extreme_ridge", 70, "Extrémní hřebeny", "zula", 56, "hory", "mountain", {}),
    ("high_massif", 71, "Velehorský masiv", "zula", 58, "hory", "mountain", {}),
    ("rock_spire", 72, "Skalní věže", "zula", 59, "hory", "mountain", {}),
    ("summit_pyramid", 73, "Vrcholové pyramidy", "zula", 60, "hory", "mountain", {}),
    ("highest_point", 74, "Nejvyšší bod (skála, led)", "zula", 61, "hory", "mountain", {"poznamka": "Název mísí skálu a led; hodnoty jako žula. Sníh je samostatná buňka eternal_snow."}),
    ("volcanic_conduit", 75, "Sopouch (vulkanický kanál)", "cedic", 64, "telesa", "vent", {"ucs": 100, "trida": "tvrda", "nastroj": "zelezo"}),
    ("diamond", 100, "diamanty", "drahokam", None, "rudy", "pocket", {"mohs": 10, "mohs_r": (10, 10), "kusovy": KUS["diamant"], "poznamka": "Kusový výnos 1 kámen / buňku 0,5 m (hra, ne reálný objem). Zbytek objemu je jalovina. Reálná teoretická jakost kimberlitu je ct/t [50]."}),
    ("gem", 101, "drahokamy", "drahokam", None, "rudy", "pocket", {"mohs": 7.5, "mohs_r": (7, 9), "kusovy": KUS["drahokam"]}),
    ("rare_metal", 102, "vzácné kovy (Li, Sn, Ta)", "ruda_med", None, "rudy", "vein", {"vytezek": y(("ruda_vzacne", 300), ("jalovina", 700)), "poznamka": "Buňka je už žíla; 300 ‰ je herní abstrakce (reálné cín/Li ložisko bývá < 1 % [49-typově])."}),
    ("fe_ti", 103, "titanomagnetit (Fe-Ti)", "ruda_fe", None, "rudy", "pocket", {"vytezek": y(("ruda_fe_ti", 600), ("jalovina", 400))}),
    ("coal", 104, "černé uhlí (minerál)", "uhli", None, "rudy", "layer", {}),
    ("lignite", 105, "hnědé uhlí (minerál)", "lignit", None, "rudy", "layer", {}),
    # lignite id 105 vs rock 53 — different keys, ok. Wait rock lignite is id 53 and mineral lignite is 105.
    ("garnet", 106, "granáty", "drahokam", None, "rudy", "pocket", {"mohs": 7.0, "mohs_r": (6.5, 7.5), "kusovy": KUS["granat"]}),
    ("gold", 107, "zlato", "ruda_med", None, "rudy", "vein", {"vytezek": y(("ruda_zlato", 80), ("kremenny_pisek", 620), ("jalovina", 300)), "poznamka": "Reálně g/t (žilné zlato často jednotky g/t). Buňka je už bohatá žíla; 80 ‰ je herní abstrakce, ne hmotnostní jakost."}),
]


def times(nastroj: str) -> dict:
    prod = PROD_M3H[nastroj]
    t_real_min = (OBJEM / prod) * 60.0
    t_herni_s = t_real_min * 60.0 / CAS_FAKTOR
    return {
        "prod_m3_h": prod,
        "t_real_min_bunka_05": round(t_real_min, 2),
        "t_herni_s_bunka_05": round(t_herni_s, 2),
        "t_navrh_s_bunka_05": NAVRH_S[nastroj],
    }


def build_materials() -> dict:
    out = {}
    for key, mid, name, grp, idx, zone, kind, extra in ROCKS:
        g = dict(G[grp])
        src = list(g.pop("z"))
        if "z" in extra:
            src = list(extra["z"])
        nastroj = extra.get("nastroj", g["nastroj"])
        trida = extra.get("trida", g["trida"])
        mohs = extra.get("mohs", g["mohs"])
        mohs_r = extra.get("mohs_r", g["mohs_r"])
        ucs = extra.get("ucs", g["ucs"])
        ucs_r = extra.get("ucs_r", g["ucs_r"])
        rho = extra.get("rho", g["rho"])
        cai = extra.get("cai", g["cai"])
        rec = {
            "id": mid,
            "nazev": name,
            "idx": idx,
            "zona": zone,
            "kind": kind,
            "skupina_tezba": grp,
            "mohs": mohs,
            "mohs_rozsah": list(mohs_r),
            "ucs_mpa": ucs,
            "ucs_rozsah_mpa": list(ucs_r),
            "hustota_kg_m3": rho,
            "cai": cai,
            "trida_tvrdosti": trida,
            "nastroj_min": nastroj,
            "chovani": extra.get("chovani", g["chovani"]),
            "vzacnost_horniny": extra.get("vzacnost", g["vzacnost"]),
            "vytezek_vychozi_promile": extra.get("vytezek", Y[grp]),
            "cas": times(nastroj) if not extra.get("netezitelne") else None,
            "netezitelne": bool(extra.get("netezitelne", False)),
            "zdroje": src,
        }
        if extra.get("kusovy"):
            rec["vytezek_kusovy"] = extra["kusovy"]
        if extra.get("poznamka"):
            rec["poznamka"] = extra["poznamka"]
        if extra.get("alias_id") is not None:
            rec["alias_material_id"] = extra["alias_id"]
        # opotřebení: CAI / 6 na buňku 0,5 m při minimálním nástroji (1.0 = celý nástroj)
        rec["opotrebeni_na_bunku_05"] = round((cai / 6.0), 3) if not rec["netezitelne"] else 0.0
        out[key] = rec
    return out


def document_meta(materials: dict) -> dict:
    return {
        "_popis": (
            "T01 NÁVRH (dříve E65, 2026-11-19): vlastnosti a těžba hornin. Nepřepisuje materialy_voda.json "
            "ani horniny_voda.json. Typické hodnoty (střed rozsahu) z rešerše, rozsahy jsou široké. "
            "Jan 13:23 (rozhodnutí): každá hornina má seznam získatelných surovin; blueprint vrstvy "
            "může přepsat jen podíly (součet 1000 ‰, jen povolené suroviny). "
            "Jan 13:27 (hypotéza, ne rozhodnutí): zpracování rozloží horninu v poměrech bloku; "
            "dovednost Mineralogie odemyká poznávání. "
            "Jan 13:31 (rozhodnutí): po identifikaci zůstanou obě jména (vlastní i skutečné); "
            "vlastní jméno může hráč sám smazat. "
            "Čas a výnos jsou úměrné objemu (buňka 0,5 m = 0,125 m³; při 0,125 m vše × 1/64)."
        ),
        "version": 1,
        "status": "navrh, ceka na Jana",
        "datum": "2026-11-19",
        "zdroje": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 23],
        "cas_hry_faktor": CAS_FAKTOR,
        "bunka_m": BUNKA_M,
        "objem_bunky_m3": OBJEM,
        "nastroje": NASTROJE,
        "tridy_tvrdosti": TRIDY,
        "suroviny": SUROVINY,
        "rozhodnuti": {
            "2026-11-17_17:53": "Výnos kopání: vždy 1 blok materiálu + šance na nález. Platí dál pro krok kopání v doporučené dvoukrokové variantě.",
            "2026-11-19_13:23": "Každá hornina má seznam získatelných surovin (i více druhů). Při definici vrstev blueprintu může blok přepsat procenta výnosu. Podíly sečtou 100 %, jen suroviny povolené u té horniny.",
            "2026-11-19_13:31": "Po identifikaci zůstanou obě jména (vlastní název hráče i skutečný název). Vlastní název může hráč sám smazat.",
        },
        "hypotezy": {
            "2026-11-19_13:27": "Zpracování rozloží horninu na suroviny v poměrech bloku. Postava s Mineralogií pozná, které minerály to jsou. Zlepšení dovednosti buď odemkne další vrstvu/třídu hornin, nebo dá body na poznání konkrétního materiálu. Neznámé suroviny stejně padají (jako „neznámý minerál“ se znaky barva/tvrdost/hustota) a jdou zkoušet.",
            "2026-11-19_13:33": "Krystaly mají kvalitu. Lze je brousit, drtit nebo dál zpracovat. Některé suroviny lze destilovat a rozložit na jiné; to odemyká jinou dovednost než Mineralogii (chemie / alchymie).",
            "2026-11-19_13:36": "Katalog výrobků z surovin (drcený křemen → sklo). Viz navrhy/katalog-materialu.md.",
            "2026-11-19_13:39": "Katalog je základ koupitelných receptů. Koupený recept dá průměr; jednotka umožní ladit parametry ke skrytému optimu a vyšší kvalitě.",
        },
        "validace_vytezku": {
            "soucet_promile": 1000,
            "jen_povolene": "každá surovina v přepisu musí být v vytezek_vychozi_promile (nebo vytezek_kusovy) dané horniny",
            "alespon_jedna": True,
            "chybejici_polozka": "chybějící povolená surovina = 0 ‰",
            "kusovy_zvlast": "kusový výnos (drahokamy) se do 1000 ‰ nepočítá; objem buňky vyplní jalovina / suť",
        },
        "blueprint_a_wvb1": {
            "vychozi": "když blok nemá přepis, použije se vytezek_vychozi_promile z této tabulky",
            "tvar_json": {
                "yield_overrides": [
                    {"host_mat_id": 5, "podily_promile": {"blok_horniny": 400, "vapno": 450, "sterk": 150}}
                ]
            },
            "wvb1_navrh_pole": (
                "Nové volitelné pole v hlavičce WVB1 (nový bit ve flags), ne parametry zásobníku "
                "(tabulka shape má pevný počet i32). Formát: u16 počet; N× { u16 host_mat_id; u8 n_prod; "
                "n_prod× { u16 surovina_id; u16 promile } }. Server pole přepočítá / zkontroluje při vydání i při zpracování."
            ),
            "zachovani": (
                "Doporučená dvoukroková varianta: kopání odebere 1 buňku MaterialId do inventáře (rozhodnutí 17:53, "
                "WVB1 bod 4: souhrn − vytěžené + položené). Zpracování pak buňku rozloží na suroviny podle podílů; "
                "součet objemů surovin = objem buňky. Položení terénu spotřebuje blok_horniny (nebo nezpracovanou buňku)."
            ),
            "rarita": (
                "Rarita-v2 (skóre buněk) zůstává. Volitelný bonus kvality z nadstandardních podílů cenných surovin "
                "Jan teprve rozhodne; prahy se teď nemění. Rudné buňky už mají vysoké skóre, nesčítat je dvakrát."
            ),
        },
        "varianty_tezby": {
            "A_brana_trid": {
                "popis": "Nástroj musí dosáhnout nastroj_min, čas je pevný podle třídy (t_navrh_s).",
                "plus": "Jednoduché, čitelné, snadno laditelné.",
                "minus": "Skok mezi třídami, horší nástroj nepomůže ani pomalu.",
            },
            "B_cas_podle_sily": {
                "popis": "Čas = t_zaklad × (UCS / síla_nástroje); slabší nástroj pomaleji, silnější rychleji. Tvrdší než ocel bez trhavin jen velmi pomalu, nebo s prahem.",
                "plus": "Plynulé, sedí s UCS, jeden vzorec.",
                "minus": "Hůř čitelné; hrozí extrémně dlouhé časy u kvarcitu s bronzem.",
            },
            "C_prace_energie": {
                "popis": "Práce = UCS × objem × (1 + CAI/3). Nástroj má výkon a výdrž; opotřebení ~ CAI × objem.",
                "plus": "Nejlíp sedí s reálnou razitelností a abrazí; nezávislé na rozlišení.",
                "minus": "Víc parametrů, hůř vysvětlitelné na streamu.",
            },
            "doporuceni": "Hybrid A+B: tvrdá brána o 1–2 stupně pod minimem (rukou žulu ne), jinak čas podle síly. Trhaviny zrychlí a zvednou podíl suti/prachu (např. +200 ‰ sterk na úkor blok_horniny).",
        },
        "zpracovani_retezce": {
            "status": "hypotéza Jan 13:33, konfigurovatelné, ne rozhodnutí",
            "kvalita_krystalu": {
                "rozsah": [0, 100],
                "urceni": "deterministicky z (seed bloku, MaterialId, index buňky); nejde přerolovat opakovaným kopáním (stejný princip jako nález ze seedu buňky, 17:53)",
                "vliv_bloku": "volitelně posun rozdělení podle rarity bloku nebo nadstandardního podílu v yield_overrides (bohatší vrstva → vyšší střed kvality). Konfigurovatelné váhy.",
                "vliv_na_cenu": "hodnota broušeného kamene roste s kvalitou (navrhovaná křivka: hodnota ~ kvalita², ať špičky jsou vzácné). Drticí výnos kvalitu ničí (vznikne písek / drť stejného objemu).",
            },
            "dovednosti": [
                {"id": "mineralogie", "kroky": ["identifikace"], "poznamka": "hypotéza 13:27; jména po identifikaci rozhodnutí 13:31"},
                {"id": "kamenictvi", "kroky": ["brousit", "drtit"], "poznamka": "oddělené od Mineralogie; název laditelný"},
                {"id": "chemie", "kroky": ["palit", "destilovat", "rozlozit", "tavit"], "poznamka": "Jan 13:33: jiná dovednost než Mineralogie (chemie / alchymie). Odemkne termický rozklad a destilaci."},
            ],
            "operace": [
                {"id": "brousit", "vstup": "krystal / drahokam (kus)", "vystup": "broušený kámen stejného druhu", "zachova_kvalitu": True, "ztrata_objemu": "malá (navrh 5–15 %), konfigurovatelné", "dovednost": "kamenictvi"},
                {"id": "drtit", "vstup": "krystal nebo stavební kámen", "vystup": "křemenný písek / drť (objemový)", "zachova_kvalitu": False, "ztrata_objemu": "0 (objem se zachová, kvalita padá)", "dovednost": "kamenictvi"},
                {"id": "palit", "vstup": "vápenec / dolomit / vápenná surovina", "vystup": "pálené vápno", "zachova_kvalitu": False, "ztrata_objemu": "část uniká jako plyn (herně konfigurovatelné, reálně CO2)", "dovednost": "chemie"},
                {"id": "destilovat", "vstup": "surovina s těkavou složkou (př. rumělka)", "vystup": "čistší látka + zbytek", "zachova_kvalitu": False, "ztrata_objemu": "podle tabulky reakce", "dovednost": "chemie"},
                {"id": "rozlozit", "vstup": "složená surovina", "vystup": "jednodušší suroviny podle tabulky reakcí", "zachova_kvalitu": False, "ztrata_objemu": "součet výstupů = vstup minus ztráta v tabulce", "dovednost": "chemie"},
                {"id": "tavit", "vstup": "ruda + palivo (uhlí aj.)", "vystup": "kov + struska", "zachova_kvalitu": False, "ztrata_objemu": "podle jakosti rudy", "dovednost": "chemie"},
            ],
            "priklady_reakci": [
                {"vstup": "křemen / křišťál", "brousit": "broušený křišťál (drží kvalitu)", "drtit": "křemenný písek", "chemie": None},
                {"vstup": "malachit / měděná ruda", "brousit": "broušený malachit (okrasa)", "drtit": "drť (horší pro tavení)", "chemie": "tavit → měď + struska"},
                {"vstup": "rumělka (HgS)", "brousit": None, "drtit": "prášek k pražení", "chemie": "pražení + destilace → rtuť"},
                {"vstup": "vápenec", "brousit": None, "drtit": "drť / štěrk", "chemie": "pálení → pálené vápno"},
                {"vstup": "sádrovec", "brousit": "alabastr (když kvalita stačí)", "drtit": "sádrový prášek", "chemie": "pálení → sádra"},
                {"vstup": "kamenná sůl", "brousit": None, "drtit": "sůl", "chemie": "rozpuštění / čištění (volitelné)"},
            ],
            "poznamka": "Rumělka ve hře zatím není v katalogu; je to jen příklad řetězce. Tabulka reakcí je samostatná a konfigurovatelná, nepřepisuje výnosy kopání.",
        },
        "znalosti_mineralogie": {
            "status": "hypotéza Jan 13:27; jména po identifikaci jsou rozhodnutí Jan 13:31",
            "urovne": [
                {"id": 0, "nazev": "neznámý", "zobrazeni": "„neznámý minerál“ + viditelné znaky (barva, tvrdost Mohs, hustota)"},
                {"id": 1, "nazev": "znaky", "zobrazeni": "více znaků / testů (vryp, hmotnost, tavení), stále bez jistého jména"},
                {"id": 2, "nazev": "identifikovaný", "zobrazeni": "skutečný název i vlastní název hráče (obě jména zůstanou). Vlastní název může hráč sám smazat (Jan 13:31)."},
            ],
            "pad": "Neznámá surovina stejně padá a jde do inventáře. Lze ji zkoušet ve výrobě i v pokusech. Identifikace je u postavy, ne ve světě (podíly bloku zná server vždy).",
            "postup_tiers": {"popis": "Zlepšení dovednosti odemkne další třídu tvrdosti / vrstvu hornin.", "plus": "Jednoduchý postup, sedí s nástroji.", "minus": "Méně volby, celá třída naráz."},
            "postup_body": {"popis": "Zlepšení dá body na poznání konkrétního materiálu.", "plus": "Hráč si vybere, víc RPG.", "minus": "Víc UI, může být zdlouhavé."},
            "postup_hybrid": {"popis": "Úroveň dovednosti odemkne třídu k poznávání; body nebo pokusy identifikují konkrétní surovinu. Doporučený výchozí přepínač.", "plus": "Oboje laditelné jednou tabulkou.", "minus": "O něco víc pravidel."},
            "pok//usy": "Záměrně split - fix below",
        },
        "materials": materials,
    }


def fix_znalosti(doc: dict) -> None:

    doc["studie"] = "tezba-studie"
    doc["zaznam"] = "T01"
    doc["recepty"] = {
        "status": "hypotéza Jan 13:39, konfigurovatelné, ne rozhodnutí",
        "zaklad": "Koupený recept = průměrná kvalita. Jednotka umožní ladit parametry.",
        "optimum": "Skryté, ne nutně monotónní (okno teploty). Kvalita vstupů omezuje strop.",
        "katalog": "navrhy/katalog-materialu.md",
    }
    doc["znalosti_mineralogie"]["pokusy"] = (
        "Pokusy (tavení, vryp, hustota, kyselina u vápence) můžou zvednout úroveň nebo rovnou identifikovat. "
        "Konfigurovatelné: kolik pokusů / jaký test stačí. Neznámé jde použít naslepo (riziko zmetku)."
    )
    doc["znalosti_mineralogie"].pop("pok//usy", None)


def make_chart(materials: dict) -> None:
    import matplotlib.pyplot as plt
    from matplotlib.patches import Patch

    # jen těžitelná, jedna položka na id (preferuj kanonický klíč bez alias)
    by_id = {}
    for k, v in materials.items():
        if v.get("netezitelne"):
            continue
        if v.get("alias_material_id") is not None and k not in ("granite", "basalt", "limestone", "sand", "clay", "dirt", "snow"):
            # skip aliases except we already skip them if alias set — skip all aliases
            continue
        mid = v["id"]
        if mid in by_id:
            continue
        by_id[mid] = (k, v)
    rows = []
    for k, v in by_id.values():
        rows.append((k, v))
    order_n = {n["id"]: n["idx"] for n in NASTROJE}
    rows.sort(key=lambda kv: (order_n.get(kv[1]["nastroj_min"], 9), -kv[1]["ucs_mpa"], kv[0]))

    colors = {
        "ruka": "#7cb87c",
        "kamen": "#e0c35a",
        "bronz": "#d08a3a",
        "zelezo": "#c44c4c",
        "ocel": "#7a4ea3",
        "trhaviny": "#555555",
    }
    names_cs = {n["id"]: n["nazev"] for n in NASTROJE}

    fig, axes = plt.subplots(1, 2, figsize=(14.5, 10.5), gridspec_kw={"width_ratios": [1.05, 1.15]})
    fig.suptitle("T01 Návrh: tvrdost a pevnost hornin podle minimálního nástroje", fontsize=13, fontweight="bold")

    ax = axes[0]
    for k, v in rows:
        ax.scatter(v["mohs"], v["ucs_mpa"], c=colors[v["nastroj_min"]], s=42, alpha=0.85, edgecolors="k", linewidths=0.3, zorder=3)
    # popisky jen u typických / krajních
    label_keys = {
        "dirt", "sand", "clay", "loess", "gypsum", "rock_salt", "black_coal", "lignite", "shale",
        "limestone", "dolomite", "quartz_sandstone", "conglomerate", "phyllite", "serpentinite",
        "kimberlite", "granite", "basalt", "gabbro", "orthogneiss", "quartzite", "eclogite",
        "peridotite", "amphibolite", "mica_schist", "weathered_granite", "copper", "iron",
        "diamond", "gold", "snow", "subalpine_scree",
    }
    for k, v in rows:
        if k in label_keys:
            ax.annotate(v["nazev"], (v["mohs"], v["ucs_mpa"]), textcoords="offset points", xytext=(4, 3), fontsize=6.5)
    ax.set_xlabel("Mohs (typická, hornina ≈ dominantní minerál)")
    ax.set_ylabel("UCS typická (MPa)")
    ax.set_xlim(-0.2, 10.5)
    ax.set_ylim(-8, 380)
    ax.grid(True, alpha=0.3)
    ax.set_title("Mohs × pevnost v tlaku")
    handles = [Patch(facecolor=colors[i], edgecolor="k", label=names_cs[i]) for i in ["ruka", "kamen", "bronz", "zelezo", "ocel"]]
    ax.legend(handles=handles, loc="upper left", fontsize=8, title="Min. nástroj")

    ax2 = axes[1]
    # výběr reprezentantů po třídách, ať je graf čitelný (všech 70 se vejde na výšku, ale aliasy už jsou pryč)
    labels = [f"{v['id']:>3}  {v['nazev']}" for k, v in rows]
    ucs = [v["ucs_mpa"] for k, v in rows]
    cols = [colors[v["nastroj_min"]] for k, v in rows]
    y = range(len(rows))
    ax2.barh(list(y), ucs, color=cols, edgecolor="k", linewidth=0.2, height=0.8)
    # error? skip, ranges are wide
    ax2.set_yticks(list(y))
    ax2.set_yticklabels(labels, fontsize=5.6)
    ax2.invert_yaxis()
    ax2.set_xlabel("UCS typická (MPa)")
    ax2.set_title("Pevnost podle horniny (barva = min. nástroj)")
    ax2.grid(True, axis="x", alpha=0.3)
    fig.text(
        0.01, 0.01,
        "Typické hodnoty, rozsahy jsou široké (ZDROJE [1]–[7]). Návrh T01 (dříve E65), čeká na Jana. Trhaviny jsou zrychlení, ne další třída v grafu.",
        fontsize=7, ha="left", va="bottom",
    )
    fig.tight_layout(rect=[0, 0.025, 1, 0.96])
    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_PNG, dpi=140)
    plt.close()
    print("wrote", OUT_PNG, "rocks_plotted", len(rows))


def main():
    materials = build_materials()
    # kontrola alias lignite id clash already fine
    doc = document_meta(materials)
    fix_znalosti(doc)
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("wrote", OUT_JSON, "n_materials", len(materials))
    # verify sums
    bad = []
    for k, v in materials.items():
        s = sum(p["promile"] for p in v["vytezek_vychozi_promile"])
        if s != 1000:
            bad.append((k, s))
    if bad:
        raise SystemExit(f"bad sums {bad}")
    make_chart(materials)


if __name__ == "__main__":
    main()
