#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""T02 — strom rozkladu hornin: data, validace, mermaid, obrázky.

Spouštění z libovolného adresáře:
    python3 /workspace/willage-ideas/tezba-studie/tools/strom02.py

Graphviz (`dot`) v prostředí není; obrázky kreslí matplotlib (vrstvené rozložení).
"""

from __future__ import annotations

import json
import math
import sys
import textwrap
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties, fontManager
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
import networkx as nx

ROOT = Path(__file__).resolve().parents[1]
DATA_T01 = ROOT / "data" / "horniny_tezba_navrh.json"
OUT_JSON = ROOT / "data" / "strom_rozkladu.json"
OUT_MD = ROOT / "navrhy" / "strom-hornin.md"
OUT_SHOTS = ROOT / "shots"
FONT_PATH = Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf")
FONT_BOLD = Path("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf")

# --- typografie (čitelné na telefonu) ---------------------------------------
if FONT_PATH.exists():
    fontManager.addfont(str(FONT_PATH))
    fontManager.addfont(str(FONT_BOLD))
    FONT = FontProperties(fname=str(FONT_PATH))
    FONTB = FontProperties(fname=str(FONT_BOLD))
    FAMILY = "Liberation Sans"
else:
    FONT = FontProperties(family="DejaVu Sans")
    FONTB = FontProperties(family="DejaVu Sans", weight="bold")
    FAMILY = "DejaVu Sans"

plt.rcParams["font.family"] = FAMILY
plt.rcParams["axes.unicode_minus"] = False

# --- skupiny stromu ---------------------------------------------------------
TRIDY = {
    "vyvreliny": {
        "nazev": "Vyvřeliny",
        "popis": "Hlubinné i výlevné horniny plastu, krystalinika a masivů.",
    },
    "premenene": {
        "nazev": "Přeměněné",
        "popis": "Ruly, svory, kvarcit, eklogit, hadec a kontaktní skarn.",
    },
    "usazene": {
        "nazev": "Usazené",
        "popis": "Vápence, pískovce, evapority, uhelné sloje a flyš.",
    },
    "rudy": {
        "nazev": "Rudy a ložiska",
        "popis": "Žíly, kapsy a uhelné vrstvy v zóně rud (T01, zona=rudy).",
    },
    "zeminy": {
        "nazev": "Zeminy a sypké",
        "popis": "Půdy, písek, jíl, spraše, zvětraliny, suť a sníh.",
    },
}

SKUPINA_TRIDA = {
    "zula": "vyvreliny",
    "cedic": "vyvreliny",
    "gabro": "vyvreliny",
    "peridotit": "vyvreliny",
    "kimberlit": "vyvreliny",
    "eklogit": "premenene",
    "rula": "premenene",
    "svor": "premenene",
    "fylit": "premenene",
    "kvarcit": "premenene",
    "amfibolit": "premenene",
    "hadec": "premenene",
    "vapenec": "usazene",
    "dolomit": "usazene",
    "piskovec": "usazene",
    "prachovec": "usazene",
    "slepenec": "usazene",
    "evap_sul": "usazene",
    "evap_sad": "usazene",
    "uhli": "usazene",
    "lignit": "usazene",
    "bridlice": "usazene",
    "flys": "usazene",
    "puda": "zeminy",
    "pisek": "zeminy",
    "sterk": "zeminy",
    "jil": "zeminy",
    "spras": "zeminy",
    "zvetr": "zeminy",
    "snih": "zeminy",
}

# skarn je kontaktní přeměna, i když T01 má skupinu vapenec
KEY_TRIDA = {"skarn": "premenene"}

RODINA_NAZEV = {
    "zula": "žula a masivy",
    "cedic": "čedič a výlevy",
    "gabro": "gabro a norit",
    "peridotit": "peridotit",
    "kimberlit": "kimberlit",
    "eklogit": "eklogit",
    "rula": "rula a granulit",
    "svor": "svor",
    "fylit": "fylit",
    "kvarcit": "kvarcit",
    "amfibolit": "amfibolit",
    "hadec": "hadec",
    "vapenec": "vápenec",
    "dolomit": "dolomit",
    "piskovec": "pískovec",
    "prachovec": "prachovec",
    "slepenec": "slepence",
    "evap_sul": "sůl (halit)",
    "evap_sad": "sádrovec",
    "uhli": "černé uhlí",
    "lignit": "hnědé uhlí",
    "bridlice": "břidlice",
    "flys": "flyš",
    "puda": "půda a hlína",
    "pisek": "písek",
    "sterk": "štěrk a suť",
    "jil": "jíl",
    "spras": "spraš",
    "zvetr": "zvětraliny",
    "snih": "sníh / led",
    "ruda_med": "měděná žíla",
    "ruda_fe": "železná ruda",
    "drahokam": "drahokamy",
    "skarn": "skarn",
}

# Suroviny, které postava pozná i bez Mineralogie (základní výnos).
ZAKLADNI_SUROVINY = {
    "blok_horniny",
    "sterk",
    "pisek",
    "jil",
    "hlina",
    "snih",
    "prach",
    "jalovina",
    "uhli",
    "lignit",
    "sul",
    "sadrovec",
    "kremenny_pisek",
}

DOVEDNOSTI = {
    "mineralogie": "Mineralogie (rozpoznání minerálů a rud)",
    "kamenictvi": "Kamenictví (drcení, broušení, kvádry)",
    "chemie": "Chemie / alchymie (pálení, pražení, destilace, loužení)",
    "hutnictvi": "Hutnictví (tavení kovů, koksování, slévání)",
    "sklarstvi": "Sklářství",
    "hrncirstvi": "Hrnčířství / keramika",
    "zednictvi": "Zednictví (hašení, malta, cihly)",
    "kovarstvi": "Kovářství (ocel, kalení)",
    "uhlistvi": "Uhlířství (dřevěné uhlí) — vstup zvenku, ne z horniny",
}

OPERACE = {
    "slozeni": "typické minerální složení (orientační, ne herní výnos)",
    "tezba": "výchozí výnos po zpracování buňky (T01, ‰ objemu)",
    "odpovida": "minerál se po uvolnění stává touto surovinou",
    "drtit": "drcení",
    "brousit": "broušení / leštění",
    "palit": "pálení / kalcinace",
    "prazit": "pražení (sulfidy, rumělka)",
    "hasit": "hašení vápna",
    "michat": "míchání malty / směsi",
    "tavit": "tavení kovu",
    "tavit_sklo": "tavení skla",
    "palit_keramiku": "výpal keramiky / porcelánu",
    "palit_cihly": "výpal cihel",
    "destilovat": "destilace",
    "louzit": "loužení",
    "koksovat": "koksování uhlí",
    "ryzovat": "ryžování / ryzí kov",
    "slevat": "slévání slitin",
    "cementovat": "nauhličení / kalení oceli",
    "karbonatace": "karbonatace (vápno zpět na kalcit) — záměrný cyklus",
}

# Minerály (uzly typ=mineral). Zdroje typického složení: [29]–[36].
MINERALY = {
    "kremen": {"nazev": "křemen", "vzorec": "SiO₂", "zdroje": [29, 34]},
    "zivec_k": {"nazev": "draselný živec", "vzorec": "KAlSi₃O₈", "zdroje": [29]},
    "plagioklas": {"nazev": "plagioklas", "vzorec": "Na-Ca živec", "zdroje": [29, 30, 31]},
    "slida": {"nazev": "slída", "vzorec": "biotit / muskovit", "zdroje": [29, 33]},
    "pyroxen": {"nazev": "pyroxen", "vzorec": None, "zdroje": [30, 31, 32]},
    "olivin": {"nazev": "olivín", "vzorec": "(Mg,Fe)₂SiO₄", "zdroje": [30, 32]},
    "magnetit": {"nazev": "magnetit", "vzorec": "Fe₃O₄", "zdroje": [31, 36]},
    "hematit": {"nazev": "hematit", "vzorec": "Fe₂O₃", "zdroje": [36]},
    "spinel": {"nazev": "spinel", "vzorec": None, "zdroje": [32]},
    "karbonat_min": {"nazev": "karbonát (v kimberlitu)", "vzorec": "kalcit / dolomit", "zdroje": [32]},
    "granat_min": {"nazev": "granát", "vzorec": None, "zdroje": [33]},
    "ilmenit": {"nazev": "ilmenit", "vzorec": "FeTiO₃", "zdroje": [36]},
    "rutil": {"nazev": "rutil", "vzorec": "TiO₂", "zdroje": [33]},
    "amfibol": {"nazev": "amfibol", "vzorec": None, "zdroje": [33]},
    "chlorit": {"nazev": "chlorit", "vzorec": None, "zdroje": [33]},
    "kalcit": {"nazev": "kalcit", "vzorec": "CaCO₃", "zdroje": [35]},
    "dolomit_min": {"nazev": "dolomit", "vzorec": "CaMg(CO₃)₂", "zdroje": [35]},
    "jil_min": {"nazev": "jílové minerály", "vzorec": "kaolinit, illit…", "zdroje": [34]},
    "halit": {"nazev": "halit", "vzorec": "NaCl", "zdroje": [35]},
    "sadrovec_min": {"nazev": "sádrovec", "vzorec": "CaSO₄·2H₂O", "zdroje": [35]},
    "anhydrit": {"nazev": "anhydrit", "vzorec": "CaSO₄", "zdroje": [35]},
    "uhli_org": {"nazev": "organický uhlík", "vzorec": "C", "zdroje": [34]},
    "pyrit": {"nazev": "pyrit", "vzorec": "FeS₂", "zdroje": [34]},
    "malachit": {"nazev": "malachit", "vzorec": "Cu₂CO₃(OH)₂", "zdroje": [36]},
    "serpentin": {"nazev": "serpentin", "vzorec": None, "zdroje": [32]},
    "horninove_ulomky": {"nazev": "horninové úlomky", "vzorec": None, "zdroje": []},
    "organika": {"nazev": "organická příměs", "vzorec": "humus", "zdroje": []},
    "led": {"nazev": "led / sníh", "vzorec": "H₂O", "zdroje": []},
    "zlato_nativni": {"nazev": "ryzí zlato", "vzorec": "Au", "zdroje": [37]},
    "spodumen": {"nazev": "spodumen", "vzorec": "LiAlSi₂O₆", "zdroje": [38]},
    "kassiterit": {"nazev": "kasiterit", "vzorec": "SnO₂", "zdroje": [38]},
    "kolumbit": {"nazev": "kolumbit-tantalit", "vzorec": "Nb-Ta", "zdroje": [38]},
    "korund": {"nazev": "korund", "vzorec": "Al₂O₃", "zdroje": []},
    "beryl": {"nazev": "beryl", "vzorec": "Be₃Al₂Si₆O₁₈", "zdroje": []},
}

# Typické složení podle skupiny těžby, součet 1000 ‰. Orientační středy rozsahů [29]–[36].
SLOZENI_SKUPINA = {
    "zula": [("kremen", 300), ("zivec_k", 350), ("plagioklas", 250), ("slida", 100)],
    "cedic": [("plagioklas", 500), ("pyroxen", 350), ("olivin", 100), ("magnetit", 50)],
    "gabro": [("plagioklas", 450), ("pyroxen", 400), ("olivin", 100), ("magnetit", 50)],
    "peridotit": [("olivin", 700), ("pyroxen", 250), ("spinel", 50)],
    "kimberlit": [("olivin", 550), ("pyroxen", 200), ("karbonat_min", 150), ("slida", 100)],
    "eklogit": [("granat_min", 500), ("pyroxen", 450), ("rutil", 50)],
    "rula": [("kremen", 300), ("zivec_k", 250), ("plagioklas", 200), ("slida", 150), ("amfibol", 100)],
    "svor": [("slida", 400), ("kremen", 350), ("plagioklas", 150), ("granat_min", 100)],
    "fylit": [("slida", 400), ("kremen", 300), ("chlorit", 200), ("jil_min", 100)],
    "kvarcit": [("kremen", 920), ("slida", 80)],
    "amfibolit": [("amfibol", 550), ("plagioklas", 350), ("granat_min", 100)],
    "hadec": [("serpentin", 850), ("magnetit", 100), ("olivin", 50)],
    "vapenec": [("kalcit", 950), ("jil_min", 50)],
    "dolomit": [("dolomit_min", 850), ("kalcit", 150)],
    "piskovec": [("kremen", 800), ("zivec_k", 100), ("kalcit", 100)],
    "prachovec": [("jil_min", 500), ("kremen", 400), ("slida", 100)],
    "slepenec": [("kremen", 500), ("horninove_ulomky", 350), ("kalcit", 150)],
    "evap_sul": [("halit", 950), ("sadrovec_min", 50)],
    "evap_sad": [("sadrovec_min", 850), ("anhydrit", 150)],
    "uhli": [("uhli_org", 800), ("jil_min", 150), ("pyrit", 50)],
    "lignit": [("uhli_org", 650), ("jil_min", 250), ("kremen", 100)],
    "bridlice": [("jil_min", 650), ("kremen", 250), ("uhli_org", 100)],
    "flys": [("kremen", 400), ("jil_min", 350), ("kalcit", 250)],
    "puda": [("organika", 200), ("jil_min", 250), ("kremen", 250), ("zivec_k", 200), ("kalcit", 100)],
    "pisek": [("kremen", 850), ("zivec_k", 150)],
    "sterk": [("horninove_ulomky", 600), ("kremen", 300), ("zivec_k", 100)],
    "jil": [("jil_min", 850), ("kremen", 150)],
    "spras": [("kremen", 400), ("kalcit", 300), ("jil_min", 300)],
    "zvetr": [("kremen", 400), ("jil_min", 300), ("zivec_k", 200), ("horninove_ulomky", 100)],
    "snih": [("led", 1000)],
}

SLOZENI_KEY = {
    "skarn": [("kalcit", 400), ("granat_min", 300), ("pyroxen", 300)],
    "pegmatite": [("zivec_k", 450), ("kremen", 400), ("slida", 150)],
    "fe_ti_zone": [("plagioklas", 400), ("pyroxen", 300), ("magnetit", 150), ("ilmenit", 150)],
    "grass": [("organika", 300), ("jil_min", 250), ("kremen", 250), ("zivec_k", 200)],
    "copper": [("malachit", 400), ("kremen", 300), ("kalcit", 300)],
    "iron": [("magnetit", 500), ("hematit", 200), ("kremen", 300)],
    "fe_ti": [("ilmenit", 350), ("magnetit", 250), ("plagioklas", 250), ("pyroxen", 150)],
    "gold": [("kremen", 800), ("pyrit", 180), ("zlato_nativni", 20)],
    "rare_metal": [("zivec_k", 350), ("kremen", 300), ("spodumen", 200), ("kassiterit", 100), ("kolumbit", 50)],
    "diamond": [("olivin", 350), ("pyroxen", 250), ("kremen", 200), ("granat_min", 200)],
    "gem": [("kremen", 500), ("korund", 200), ("beryl", 150), ("slida", 150)],
    "garnet": [("granat_min", 500), ("slida", 200), ("kremen", 200), ("pyroxen", 100)],
}

# Minerál po uvolnění odpovídá surovině (nebo kusu).
MINERAL_NA_SUROVINU = {
    "kremen": "kremenny_pisek",
    "kalcit": "vapno",
    "dolomit_min": "vapno",
    "jil_min": "jil",
    "halit": "sul",
    "sadrovec_min": "sadrovec",
    "uhli_org": "uhli",
    "malachit": "ruda_med",
    "magnetit": "ruda_zelezo",
    "hematit": "ruda_zelezo",
    "ilmenit": "ruda_fe_ti",
    "zlato_nativni": "ruda_zlato",
    "spodumen": "ruda_vzacne",
    "kassiterit": "ruda_vzacne",
    "kolumbit": "ruda_vzacne",
    "granat_min": "granaty",
    "korund": "drahokamy",
    "beryl": "drahokamy",
    "led": "snih",
    "organika": "hlina",
    "horninove_ulomky": "sterk",
}

# Výrobky z katalogu (navrhy/katalog-materialu.md) + prvky a vnější vstupy.
VYROBKY = {
    "palene_vapno": {"nazev": "pálené vápno", "katalog": "Pálené vápno", "zdroje": [13, 14]},
    "hasene_vapno": {"nazev": "hašené vápno", "katalog": "Hašené vápno", "zdroje": [13, 14]},
    "malta": {"nazev": "malta", "katalog": "Malta", "zdroje": [13, 14]},
    "cement": {"nazev": "cement", "katalog": "Cement", "zdroje": [22]},
    "sadra": {"nazev": "sádra", "katalog": "Sádra", "zdroje": [15]},
    "cihla": {"nazev": "cihla", "katalog": "Cihla", "zdroje": [27]},
    "keramika": {"nazev": "keramika", "katalog": "Keramika (nádoby, kachle)", "zdroje": [27]},
    "glazura": {"nazev": "glazura", "katalog": "Glazura", "zdroje": [16, 27]},
    "porcelan": {"nazev": "porcelán", "katalog": "Porcelán (později)", "zdroje": [27]},
    "sklo": {"nazev": "sklo", "katalog": "Sklo", "zdroje": [16, 17]},
    "med": {"nazev": "měď (kov)", "katalog": "Měď", "zdroje": [18]},
    "cin": {"nazev": "cín (kov)", "katalog": "Cín", "zdroje": [19]},
    "bronz": {"nazev": "bronz", "katalog": "Bronz", "zdroje": [18]},
    "zelezo": {"nazev": "železo (kov)", "katalog": "Železo", "zdroje": [20, 23]},
    "ocel": {"nazev": "ocel", "katalog": "Ocel", "zdroje": [28]},
    "olovo": {"nazev": "olovo (kov)", "katalog": "Olovo", "zdroje": []},
    "koks": {"nazev": "koks", "katalog": "Koks", "zdroje": [21]},
    "sul_cista": {"nazev": "čištěná sůl", "katalog": "Sůl", "zdroje": [26]},
    "pigment_okr": {"nazev": "okr (pigment)", "katalog": "Pigmenty", "zdroje": [24]},
    "pigment_malachit": {"nazev": "malachitový pigment", "katalog": "Pigmenty", "zdroje": [24, 36]},
    "pigment_saze": {"nazev": "saze / čerň", "katalog": "Pigmenty", "zdroje": [21, 24]},
    "brouseny_kamen": {"nazev": "broušený kámen", "katalog": "Broušené kameny a drahokamy", "zdroje": []},
    "brouseny_diamant": {"nazev": "broušený diamant", "katalog": "Broušené kameny a drahokamy", "zdroje": [9]},
    "brouseny_granat": {"nazev": "broušený granát", "katalog": "Broušené kameny a drahokamy", "zdroje": []},
    "struska": {"nazev": "struska", "katalog": "Struska (odpad hutí)", "zdroje": [20]},
    "rtut": {"nazev": "rtuť", "katalog": None, "zdroje": [25], "poznamka": "V T01 jako příklad destilace (rumělka); v tabulce hornin rumělka není."},
    "titan_konc": {"nazev": "titanový koncentrát", "katalog": None, "zdroje": [36]},
    "lithium_konc": {"nazev": "lithný koncentrát", "katalog": None, "zdroje": [38]},
}

PRVKY = {
    "Cu": {"nazev": "měď (prvek)"},
    "Fe": {"nazev": "železo (prvek)"},
    "Ti": {"nazev": "titan (prvek)"},
    "Au": {"nazev": "zlato (prvek)"},
    "C": {"nazev": "uhlík (prvek)"},
    "Si": {"nazev": "křemík (prvek)"},
    "Ca": {"nazev": "vápník (prvek)"},
    "Sn": {"nazev": "cín (prvek)"},
    "Li": {"nazev": "lithium (prvek)"},
    "Ta": {"nazev": "tantal (prvek)"},
    "Hg": {"nazev": "rtuť (prvek)"},
    "Pb": {"nazev": "olovo (prvek)"},
}

VNEJSI = {
    "drevo": {"nazev": "dřevo (vnější vstup)"},
    "drevene_uhli": {"nazev": "dřevěné uhlí", "katalog": "Dřevěné uhlí", "zdroje": [21]},
    "soda": {"nazev": "soda / potaš (tavidlo)"},
}

# Procesy: vstupy a výstupy v ‰ hmoty vsázky (hrubě, reálný řád).
# plati_pro_skupiny omezuje, z které horniny daný blok kamene lze takto vést.
PROCESY = [
    {
        "id": "uhli_drevene",
        "operace": "palit",
        "dovednost": "uhlistvi",
        "vstupy": [("vnejsi:drevo", 1000)],
        "vystupy": [("vnejsi:drevene_uhli", 250), ("vyrobek:pigment_saze", 20)],
        "popis": "Uhlířství: dřevo v milíři na dřevěné uhlí (vstup zvenku, ne z horniny).",
        "zdroje": [21],
    },
    {
        "id": "drtit_blok",
        "operace": "drtit",
        "dovednost": "kamenictvi",
        "vstupy": [("surovina:blok_horniny", 1000)],
        "vystupy": [("surovina:sterk", 900), ("surovina:prach", 100)],
        "popis": "Drcení kvádru na štěrk a prach.",
    },
    {
        "id": "drtit_blok_kremen",
        "operace": "drtit",
        "dovednost": "kamenictvi",
        "vstupy": [("surovina:blok_horniny", 1000)],
        "vystupy": [("surovina:kremenny_pisek", 250), ("surovina:sterk", 700), ("surovina:prach", 50)],
        "plati_pro_skupiny": ["zula", "kvarcit", "piskovec"],
        "popis": "Z křemenem bohatých hornin se při drcení uvolní i křemenný písek.",
    },
    {
        "id": "drtit_kremen_min",
        "operace": "drtit",
        "dovednost": "kamenictvi",
        "vstupy": [("mineral:kremen", 1000)],
        "vystupy": [("surovina:kremenny_pisek", 1000)],
        "popis": "Drcení křemene na sklářský písek.",
    },
    {
        "id": "palit_vapno",
        "operace": "palit",
        "dovednost": "chemie",
        "vstupy": [("surovina:vapno", 1000)],
        "vystupy": [("vyrobek:palene_vapno", 560)],
        "popis": "Kalcinace CaCO₃ → CaO + CO₂; hmotnostní výtěžek okolo 56 %.",
        "zdroje": [13, 14],
    },
    {
        "id": "palit_kalcit",
        "operace": "palit",
        "dovednost": "chemie",
        "vstupy": [("mineral:kalcit", 1000)],
        "vystupy": [("vyrobek:palene_vapno", 560)],
        "popis": "Stejná kalcinace přímo z kalcitu.",
        "zdroje": [13, 14],
    },
    {
        "id": "palit_dolomit",
        "operace": "palit",
        "dovednost": "chemie",
        "vstupy": [("mineral:dolomit_min", 1000)],
        "vystupy": [("vyrobek:palene_vapno", 500)],
        "popis": "Pálený dolomit (směs CaO+MgO); výtěžek je hrubý.",
        "zdroje": [13, 14],
    },
    {
        "id": "hasit_vapno",
        "operace": "hasit",
        "dovednost": "zednictvi",
        "vstupy": [("vyrobek:palene_vapno", 1000)],
        "vystupy": [("vyrobek:hasene_vapno", 1300)],
        "popis": "Hašení: CaO + H₂O → Ca(OH)₂. Hmotnost naroste vodou.",
        "zdroje": [13, 14],
    },
    {
        "id": "michat_maltu",
        "operace": "michat",
        "dovednost": "zednictvi",
        "vstupy": [("vyrobek:hasene_vapno", 250), ("surovina:pisek", 750)],
        "vystupy": [("vyrobek:malta", 1000)],
        "popis": "Vápenná malta: hašené vápno + písek.",
        "zdroje": [13, 14],
    },
    {
        "id": "karbonatace_malt",
        "operace": "karbonatace",
        "dovednost": None,
        "vstupy": [("vyrobek:malta", 1000)],
        "vystupy": [("mineral:kalcit", 200), ("surovina:pisek", 750)],
        "cyklus": True,
        "popis": "Záměrný cyklus: malta tvrdne příjmem CO₂ a vrací kalcit.",
        "zdroje": [13, 14],
    },
    {
        "id": "palit_cement",
        "operace": "palit",
        "dovednost": "chemie",
        "vstupy": [("surovina:vapno", 800), ("surovina:jil", 200)],
        "vystupy": [("vyrobek:cement", 700)],
        "popis": "Hrubý slínek: vápenec + jíl, výpal, mletí. Pozdější výrobek.",
        "zdroje": [22],
    },
    {
        "id": "palit_sadru",
        "operace": "palit",
        "dovednost": "chemie",
        "vstupy": [("surovina:sadrovec", 1000)],
        "vystupy": [("vyrobek:sadra", 840)],
        "popis": "Sádrovec ztratí část krystalové vody (sádra).",
        "zdroje": [15],
    },
    {
        "id": "palit_cihly",
        "operace": "palit_cihly",
        "dovednost": "zednictvi",
        "vstupy": [("surovina:jil", 850), ("surovina:pisek", 150)],
        "vystupy": [("vyrobek:cihla", 900)],
        "popis": "Formování a výpal cihel.",
        "zdroje": [27],
    },
    {
        "id": "palit_keramiku",
        "operace": "palit_keramiku",
        "dovednost": "hrncirstvi",
        "vstupy": [("surovina:jil", 1000)],
        "vystupy": [("vyrobek:keramika", 900)],
        "popis": "Výpal nádob a kachlů z jílu.",
        "zdroje": [27],
    },
    {
        "id": "glazura",
        "operace": "tavit",
        "dovednost": "hrncirstvi",
        "vstupy": [("surovina:kremenny_pisek", 500), ("surovina:jil", 200), ("vyrobek:palene_vapno", 150), ("surovina:ruda_med", 50)],
        "vystupy": [("vyrobek:glazura", 850)],
        "popis": "Křemen + tavidlo + barvicí oxid (třeba měď). Poměry hrubé.",
        "zdroje": [16, 27],
    },
    {
        "id": "porcelan",
        "operace": "palit_keramiku",
        "dovednost": "hrncirstvi",
        "vstupy": [("surovina:jil", 500), ("surovina:kremenny_pisek", 250), ("mineral:zivec_k", 250)],
        "vystupy": [("vyrobek:porcelan", 850)],
        "popis": "Později: kaolin (zde jíl) + křemen + živec. Chybí zvlášť kaolin.",
        "zdroje": [27],
    },
    {
        "id": "tavit_sklo",
        "operace": "tavit_sklo",
        "dovednost": "sklarstvi",
        "vstupy": [("surovina:kremenny_pisek", 740), ("vnejsi:soda", 160), ("vyrobek:palene_vapno", 100)],
        "vystupy": [("vyrobek:sklo", 900)],
        "popis": "Sodnovápenaté sklo: hrubě 74 % SiO₂, 16 % soda, 10 % vápno.",
        "zdroje": [16, 17],
    },
    {
        "id": "tavit_med",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_med", 1000), ("vnejsi:drevene_uhli", 200)],
        "vystupy": [("vyrobek:med", 400), ("vyrobek:struska", 500)],
        "popis": "Tavení malachitu / měděné rudy s dřevěným uhlím. Výtěžek je herní, ne 100 % kovu.",
        "zdroje": [18],
    },
    {
        "id": "louzit_med",
        "operace": "louzit",
        "dovednost": "chemie",
        "vstupy": [("surovina:ruda_med", 1000)],
        "vystupy": [("vyrobek:med", 300)],
        "popis": "Loužení oxidických měděných rud (slabší, pozdější cesta).",
        "zdroje": [18],
    },
    {
        "id": "tavit_cin",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_vzacne", 1000), ("vnejsi:drevene_uhli", 200)],
        "vystupy": [("vyrobek:cin", 150), ("vyrobek:lithium_konc", 100), ("vyrobek:struska", 600)],
        "popis": "Směsný koncentrát Li-Sn-Ta: část cínu se vytaví, Li/Ta zůstanou v koncentrátu. Hrubé.",
        "zdroje": [19, 38],
    },
    {
        "id": "slevat_bronz",
        "operace": "slevat",
        "dovednost": "hutnictvi",
        "vstupy": [("vyrobek:med", 900), ("vyrobek:cin", 100)],
        "vystupy": [("vyrobek:bronz", 1000)],
        "popis": "Bronz typicky okolo 10 % cínu.",
        "zdroje": [18],
    },
    {
        "id": "tavit_zelezo",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_zelezo", 1000), ("vnejsi:drevene_uhli", 400)],
        "vystupy": [("vyrobek:zelezo", 500), ("vyrobek:struska", 400)],
        "popis": "Přímá redukce železné rudy dřevěným uhlím (ne vysoká pec).",
        "zdroje": [20],
    },
    {
        "id": "tavit_zelezo_koks",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_zelezo", 1000), ("vyrobek:koks", 400)],
        "vystupy": [("vyrobek:zelezo", 550), ("vyrobek:struska", 400)],
        "popis": "Pozdější cesta: koks místo dřevěného uhlí.",
        "zdroje": [20, 21],
    },
    {
        "id": "tavit_fe_ti",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_fe_ti", 1000), ("vnejsi:drevene_uhli", 400)],
        "vystupy": [("vyrobek:zelezo", 300), ("vyrobek:titan_konc", 250), ("vyrobek:struska", 350)],
        "popis": "Titanomagnetit: část Fe do kovu, Ti do strusky / koncentrátu.",
        "zdroje": [36],
    },
    {
        "id": "cementovat_ocel",
        "operace": "cementovat",
        "dovednost": "kovarstvi",
        "vstupy": [("vyrobek:zelezo", 980), ("vyrobek:koks", 20)],
        "vystupy": [("vyrobek:ocel", 1000)],
        "popis": "Nauhličení a kalení; uhlík může dát i dřevěné uhlí.",
        "zdroje": [28],
    },
    {
        "id": "cementovat_ocel_drevo",
        "operace": "cementovat",
        "dovednost": "kovarstvi",
        "vstupy": [("vyrobek:zelezo", 980), ("vnejsi:drevene_uhli", 20)],
        "vystupy": [("vyrobek:ocel", 1000)],
        "popis": "Stejné nauhličení dřevěným uhlím.",
        "zdroje": [28],
    },
    {
        "id": "koksovat",
        "operace": "koksovat",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:uhli", 1000)],
        "vystupy": [("vyrobek:koks", 700), ("vyrobek:pigment_saze", 30)],
        "popis": "Suchá destilace černého uhlí na koks. Hnědé uhlí je na koks slabé.",
        "zdroje": [21],
    },
    {
        "id": "cistit_sul",
        "operace": "destilovat",
        "dovednost": "chemie",
        "vstupy": [("surovina:sul", 1000)],
        "vystupy": [("vyrobek:sul_cista", 900)],
        "popis": "Rozpuštění a krystalizace / odpaření solanky. Destilace je tu širší pojem čištění.",
        "zdroje": [26],
    },
    {
        "id": "ryzovat_zlato",
        "operace": "ryzovat",
        "dovednost": "hutnictvi",
        "vstupy": [("surovina:ruda_zlato", 1000)],
        "vystupy": [("prvek:Au", 50)],
        "popis": "Ryžování a tavení koncentrátu. Podíl kovu je herní abstrakce; ve skutečnosti g/t [37].",
        "zdroje": [37],
    },
    {
        "id": "louzit_zlato",
        "operace": "louzit",
        "dovednost": "chemie",
        "vstupy": [("surovina:ruda_zlato", 1000)],
        "vystupy": [("prvek:Au", 40)],
        "popis": "Pozdější loužení (moderní cesta). Bez postupu a bez kyanidu v návrhu.",
        "zdroje": [37],
    },
    {
        "id": "louzit_lithium",
        "operace": "louzit",
        "dovednost": "chemie",
        "vstupy": [("vyrobek:lithium_konc", 1000)],
        "vystupy": [("prvek:Li", 80), ("prvek:Ta", 20)],
        "popis": "Loužení lithného / tantalového koncentrátu. Velmi hrubé, pozdější chemie.",
        "zdroje": [38],
    },
    {
        "id": "brousit_drahokamy",
        "operace": "brousit",
        "dovednost": "kamenictvi",
        "vstupy": [("surovina:drahokamy", 1000)],
        "vystupy": [("vyrobek:brouseny_kamen", 800)],
        "popis": "Broušení a leštění; část hmoty padne jako odpad.",
        "zdroje": [28],
    },
    {
        "id": "brousit_diamant",
        "operace": "brousit",
        "dovednost": "kamenictvi",
        "vstupy": [("surovina:diamanty", 1000)],
        "vystupy": [("vyrobek:brouseny_diamant", 700)],
        "popis": "Broušení diamantu. Kvalita krystalu z T01 (semínko / vzácnost).",
        "zdroje": [28],
    },
    {
        "id": "brousit_granat",
        "operace": "brousit",
        "dovednost": "kamenictvi",
        "vstupy": [("surovina:granaty", 1000)],
        "vystupy": [("vyrobek:brouseny_granat", 800)],
        "popis": "Broušení granátu (šperk i brusivo).",
        "zdroje": [28],
    },
    {
        "id": "pigment_okr",
        "operace": "drtit",
        "dovednost": "chemie",
        "vstupy": [("mineral:hematit", 1000)],
        "vystupy": [("vyrobek:pigment_okr", 900)],
        "popis": "Mletí hematitu na okr.",
        "zdroje": [24],
    },
    {
        "id": "pigment_malachit",
        "operace": "drtit",
        "dovednost": "chemie",
        "vstupy": [("mineral:malachit", 1000)],
        "vystupy": [("vyrobek:pigment_malachit", 900)],
        "popis": "Mletí malachitu na zelený pigment (nespálený).",
        "zdroje": [24, 36],
    },
    {
        "id": "struska_sterk",
        "operace": "drtit",
        "dovednost": "kamenictvi",
        "vstupy": [("vyrobek:struska", 1000)],
        "vystupy": [("surovina:sterk", 800), ("surovina:prach", 200)],
        "popis": "Struska jako kamenivo / zásyp. Není cyklus suroviny kovu.",
        "zdroje": [20],
    },
    {
        "id": "med_na_prvek",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("vyrobek:med", 1000)],
        "vystupy": [("prvek:Cu", 1000)],
        "popis": "Kov je prvek Cu (čistota závisí na hutnictví).",
    },
    {
        "id": "zelezo_na_prvek",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("vyrobek:zelezo", 1000)],
        "vystupy": [("prvek:Fe", 1000)],
        "popis": "Kov je prvek Fe.",
    },
    {
        "id": "cin_na_prvek",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("vyrobek:cin", 1000)],
        "vystupy": [("prvek:Sn", 1000)],
        "popis": "Kov je prvek Sn.",
    },
    {
        "id": "titan_na_prvek",
        "operace": "louzit",
        "dovednost": "chemie",
        "vstupy": [("vyrobek:titan_konc", 1000)],
        "vystupy": [("prvek:Ti", 200), ("prvek:Fe", 100)],
        "popis": "Pozdější chemie titanu z ilmenitu. Výtěžek hrubý.",
        "zdroje": [36],
    },
    {
        "id": "koks_uhlik",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("vyrobek:koks", 1000)],
        "vystupy": [("prvek:C", 1000)],
        "popis": "Koks je téměř čistý uhlík.",
    },
    {
        "id": "kremen_kremik",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("mineral:kremen", 1000)],
        "vystupy": [("prvek:Si", 470)],
        "popis": "Křemen je SiO₂; prvek Si se v rané hře neodděluje (jen znalost).",
    },
    {
        "id": "vapno_vápnik",
        "operace": "odpovida",
        "dovednost": None,
        "vstupy": [("vyrobek:palene_vapno", 1000)],
        "vystupy": [("prvek:Ca", 710)],
        "popis": "CaO obsahuje vápník; oddělení prvku ve hře není cíl.",
    },
    {
        "id": "olovo_chybi_ruda",
        "operace": "tavit",
        "dovednost": "hutnictvi",
        "vstupy": [],
        "vystupy": [("vyrobek:olovo", 1000)],
        "popis": "Olovo je v katalogu, ale v tabulce hornin chybí galenit / olověná ruda.",
        "mezera": True,
    },
    {
        "id": "rtut_chybi_rumelka",
        "operace": "prazit",
        "dovednost": "chemie",
        "vstupy": [],
        "vystupy": [("vyrobek:rtut", 1000), ("prvek:Hg", 1000)],
        "popis": "Pražení a destilace rumělky (příklad z T01). V tabulce hornin rumělka není.",
        "mezera": True,
        "zdroje": [25],
    },
]


# =============================================================================
# Sestavení uzlů a hran
# =============================================================================

def nid(*parts: str) -> str:
    return ":".join(parts)


def trida_horniny(key: str, rec: dict) -> str | None:
    if rec.get("netezitelne"):
        return None
    if rec.get("alias_material_id") is not None:
        return None
    if rec.get("zona") == "rudy":
        return "rudy"
    if key in KEY_TRIDA:
        return KEY_TRIDA[key]
    sk = rec.get("skupina_tezba")
    return SKUPINA_TRIDA.get(sk)


def slozeni_pro(key: str, rec: dict) -> list[tuple[str, int]]:
    if key in SLOZENI_KEY:
        return list(SLOZENI_KEY[key])
    sk = rec.get("skupina_tezba")
    if sk in SLOZENI_SKUPINA:
        return list(SLOZENI_SKUPINA[sk])
    raise KeyError(f"Chybí složení pro {key} / {sk}")


def rodina_id(key: str, rec: dict, trida: str) -> str:
    if trida == "rudy":
        return key  # každé ložisko zvlášť
    if key == "skarn":
        return "skarn"
    if key == "fe_ti_zone":
        return "fe_ti_zone"
    if key == "pegmatite":
        return "pegmatite"
    return rec.get("skupina_tezba")


def rodina_nazev(rid: str, rec: dict) -> str:
    if rid == "fe_ti_zone":
        return "zóna Fe-Ti (gabro)"
    if rid == "pegmatite":
        return "pegmatit"
    if rid in RODINA_NAZEV:
        return RODINA_NAZEV[rid]
    return rec.get("nazev") or rid


def load_t01() -> dict:
    return json.loads(DATA_T01.read_text(encoding="utf-8"))


def build_tree(t01: dict) -> dict:
    uzly: dict[str, dict] = {}
    hrany: list[dict] = []

    def add_node(i: str, typ: str, nazev: str, **extra):
        if i in uzly:
            return
        node = {"id": i, "typ": typ, "nazev": nazev}
        node.update({k: v for k, v in extra.items() if v is not None})
        uzly[i] = node

    def add_edge(**kw):
        e = {k: v for k, v in kw.items() if v is not None}
        if "id" not in e:
            e["id"] = f"e{len(hrany)+1:04d}"
        hrany.append(e)

    # suroviny z T01
    for sk, sv in t01["suroviny"].items():
        add_node(
            nid("surovina", sk),
            "surovina",
            sv.get("nazev") or sk,
            t01_id=sv.get("id"),
            kusovy=bool(sv.get("kusovy")),
            zakladni=sk in ZAKLADNI_SUROVINY,
            popis=sv.get("popis"),
        )

    for mid, mv in MINERALY.items():
        add_node(
            nid("mineral", mid),
            "mineral",
            mv["nazev"],
            vzorec=mv.get("vzorec"),
            zdroje=mv.get("zdroje") or [],
        )

    for vid, vv in VYROBKY.items():
        add_node(
            nid("vyrobek", vid),
            "vyrobek",
            vv["nazev"],
            katalog=vv.get("katalog"),
            zdroje=vv.get("zdroje") or [],
            poznamka=vv.get("poznamka"),
        )

    for pid, pv in PRVKY.items():
        add_node(nid("prvek", pid), "prvek", pv["nazev"], symbol=pid)

    for xid, xv in VNEJSI.items():
        add_node(
            nid("vnejsi", xid),
            "vnejsi",
            xv["nazev"],
            katalog=xv.get("katalog"),
            zdroje=xv.get("zdroje") or [],
        )

    # mezery: chybějící rudy z katalogu / T01
    add_node(
        nid("mezera", "galenit"),
        "mezera",
        "galenit (v tabulce hornin chybí)",
        popis="Katalog má olovo, ale žádná hornina ho nedává.",
    )
    add_node(
        nid("mezera", "rumelka"),
        "mezera",
        "rumělka (v tabulce hornin chybí)",
        popis="T01 uvádí destilaci rtuti z rumělky jako příklad, ložisko není.",
    )

    mats = t01["materials"]
    horniny_keys = []
    for key, rec in mats.items():
        trida = trida_horniny(key, rec)
        if trida is None:
            continue
        horniny_keys.append(key)
        rid = rodina_id(key, rec, trida)
        add_node(
            nid("hornina", key),
            "hornina",
            rec.get("nazev") or key,
            material_key=key,
            material_id=rec.get("id"),
            trida=trida,
            zona=rec.get("zona"),
            kind=rec.get("kind"),
            skupina_tezba=rec.get("skupina_tezba"),
            rodina=rid,
            rodina_nazev=rodina_nazev(rid, rec),
        )

        # složení
        slo = slozeni_pro(key, rec)
        if sum(p for _, p in slo) != 1000:
            raise ValueError(f"Složení {key} nesčítá 1000 ‰: {slo} = {sum(p for _, p in slo)}")
        for min_id, prom in slo:
            add_edge(
                od=nid("hornina", key),
                do=nid("mineral", min_id),
                operace="slozeni",
                dovednost="mineralogie",
                promile=prom,
                zakladni=False,
                vstupy=[nid("hornina", key)],
                vystupy=[nid("mineral", min_id)],
                popis="Typické minerální složení (orientační).",
            )

        # výnosy ‰
        vytezek = rec.get("vytezek_vychozi_promile") or []
        s = sum(it["promile"] for it in vytezek)
        if s != 1000:
            raise ValueError(f"Výnos {key} nesčítá 1000 ‰: {s}")
        ma_zakladni = False
        for it in vytezek:
            su = it["surovina"]
            zak = su in ZAKLADNI_SUROVINY
            if zak:
                ma_zakladni = True
            add_edge(
                od=nid("hornina", key),
                do=nid("surovina", su),
                operace="tezba",
                dovednost=None if zak else "mineralogie",
                identifikace="mineralogie" if not zak else None,
                promile=it["promile"],
                zakladni=zak,
                vstupy=[nid("hornina", key)],
                vystupy=[nid("surovina", su)],
            )
        for it in rec.get("vytezek_kusovy") or []:
            su = it["surovina"]
            zak = su in ZAKLADNI_SUROVINY
            if zak:
                ma_zakladni = True
            add_edge(
                od=nid("hornina", key),
                do=nid("surovina", su),
                operace="tezba",
                dovednost="mineralogie",
                identifikace="mineralogie",
                kusovy=True,
                kusu_na_bunku_05=it.get("kusu_na_bunku_05"),
                zakladni=False,
                vstupy=[nid("hornina", key)],
                vystupy=[nid("surovina", su)],
                popis="Kusový nález (mimo součet 1000 ‰).",
            )
        if not ma_zakladni:
            raise ValueError(f"Hornina {key} nemá žádný základní výnos")

    # minerál → surovina
    for min_id, su in MINERAL_NA_SUROVINU.items():
        add_edge(
            od=nid("mineral", min_id),
            do=nid("surovina", su),
            operace="odpovida",
            dovednost="mineralogie",
            vstupy=[nid("mineral", min_id)],
            vystupy=[nid("surovina", su)],
            popis="Po uvolnění / rozpoznání odpovídá surovině z T01.",
        )

    # procesy
    for pr in PROCESY:
        vstupy = list(pr.get("vstupy") or [])
        vystupy = list(pr.get("vystupy") or [])
        if pr.get("mezera"):
            if pr["id"] == "olovo_chybi_ruda":
                vstupy = [("mezera:galenit", 1000)]
            elif pr["id"] == "rtut_chybi_rumelka":
                vstupy = [("mezera:rumelka", 1000)]
        in_ids = [a for a, _ in vstupy]
        out_ids = [a for a, _ in vystupy]
        for src, pin in vstupy:
            for dst, pout in vystupy:
                add_edge(
                    od=src,
                    do=dst,
                    operace=pr["operace"],
                    dovednost=pr.get("dovednost"),
                    proces=pr["id"],
                    vstup_promile=pin,
                    vystup_promile=pout,
                    vstupy=in_ids,
                    vystupy=out_ids,
                    plati_pro_skupiny=pr.get("plati_pro_skupiny"),
                    cyklus=bool(pr.get("cyklus")),
                    mezera=bool(pr.get("mezera")),
                    popis=pr.get("popis"),
                    zdroje=pr.get("zdroje"),
                )

    doc = {
        "_popis": (
            "T02 strom rozkladu: hornina → minerály (typické složení) a výchozí suroviny "
            "(T01, ‰) → další zpracování na výrobky a prvky. Základní výnos je vždy známý "
            "bez Mineralogie. Složení je orientační, ne herní zákon. Bez commitu."
        ),
        "version": 1,
        "status": "navrh",
        "datum": "2026-11-19",
        "studie": "tezba-studie",
        "zaznam": "T02",
        "zdroje": list(range(7, 10)) + list(range(13, 29)) + list(range(29, 39)),
        "tridy": TRIDY,
        "dovednosti": DOVEDNOSTI,
        "operace": OPERACE,
        "zakladni_suroviny": sorted(ZAKLADNI_SUROVINY),
        "procesy": PROCESY,
        "uzly": list(uzly.values()),
        "hrany": hrany,
        "statistiky": {},  # doplní validace
        "mezery": [
            "Olovo je v katalogu, v tabulce hornin chybí galenit.",
            "Rumělka / rtuť je příklad z T01, ložisko v tabulce není.",
            "Kaolin pro porcelán není oddělený od jílu.",
            "Soda / potaš je vnější tavidlo, ne výnos horniny.",
            "Dřevěné uhlí je z dřeva, ne z horniny.",
            "Podíl ryzího zlata ve složení buňky (20 ‰) je herní abstrakce; reálně g/t [37].",
            "Směs Li-Sn-Ta v jedné surovině ruda_vzacne je hrubá; reálně jdou odděleně.",
            "Složení drahokamové kapsy (korund+beryl) je nejisté — T01 typ nespecifikuje.",
            "Výtěžky tavení (400–550 ‰ kovu) jsou herní, ne stechiometrie ložiska.",
            "Hnědé uhlí je v návrhu hlavně palivo; na koks ho nevedu (slabá koksovatelnost).",
            "Pigmenty z malachitu a hematitu jsou v datech (procesy pigment_*), na obrázku kovů je kreslím jen jako součást katalogu, ne jako hlavní větev tavení.",
        ],
    }
    return doc, uzly, hrany


# =============================================================================
# Validace
# =============================================================================

def validate(doc: dict) -> list[str]:
    chyby: list[str] = []
    uzly = {n["id"]: n for n in doc["uzly"]}
    hrany = doc["hrany"]

    # každý od/do a vstupy/výstupy existuje
    for e in hrany:
        for pole in ("od", "do"):
            if e[pole] not in uzly:
                chyby.append(f"Hrana {e['id']}: {pole}={e[pole]} neexistuje")
        for pole in ("vstupy", "vystupy"):
            for i in e.get(pole) or []:
                if i not in uzly:
                    chyby.append(f"Hrana {e['id']}: {pole} obsahuje neznámé {i}")

    horniny = [n for n in doc["uzly"] if n["typ"] == "hornina"]
    for h in horniny:
        tez = [e for e in hrany if e["od"] == h["id"] and e["operace"] == "tezba" and not e.get("kusovy")]
        slo = [e for e in hrany if e["od"] == h["id"] and e["operace"] == "slozeni"]
        s_t = sum(e["promile"] for e in tez)
        s_s = sum(e["promile"] for e in slo)
        if s_t != 1000:
            chyby.append(f"{h['id']}: výnos {s_t} ‰ ≠ 1000")
        if s_s != 1000:
            chyby.append(f"{h['id']}: složení {s_s} ‰ ≠ 1000")
        if not any(e.get("zakladni") for e in tez):
            chyby.append(f"{h['id']}: chybí základní výnos")

    # cykly
    G = nx.DiGraph()
    G.add_nodes_from(uzly)
    cyklus_hrany = set()
    for e in hrany:
        G.add_edge(e["od"], e["do"], id=e["id"], cyklus=bool(e.get("cyklus")))
        if e.get("cyklus"):
            cyklus_hrany.add((e["od"], e["do"]))

    # hledáme cykly; přípustný je jen ten, který obsahuje označenou hranu
    try:
        raw_cycles = list(nx.simple_cycles(G))
    except Exception as exc:  # noqa: BLE001
        chyby.append(f"Hledání cyklů selhalo: {exc}")
        raw_cycles = []

    neschvalene = []
    schvalene = []
    for cyc in raw_cycles:
        edges = list(zip(cyc, cyc[1:] + [cyc[0]]))
        if any(ed in cyklus_hrany for ed in edges):
            schvalene.append(cyc)
        else:
            neschvalene.append(cyc)
    if neschvalene:
        # jednoduché cykly mohou být dlouhé; vypiš krátké
        ukaz = neschvalene[:8]
        chyby.append(
            f"Nepovolené cykly ({len(neschvalene)}): "
            + "; ".join(" → ".join(c + [c[0]]) for c in ukaz)
        )
    doc["cykly_schvalene"] = [" → ".join(c + [c[0]]) for c in schvalene]
    return chyby


def statistiky(doc: dict) -> dict:
    uzly = doc["uzly"]
    hrany = doc["hrany"]
    typ = defaultdict(int)
    for n in uzly:
        typ[n["typ"]] += 1
    trida = defaultdict(int)
    for n in uzly:
        if n["typ"] == "hornina":
            trida[n["trida"]] += 1
    oper = defaultdict(int)
    for e in hrany:
        oper[e["operace"]] += 1
    return {
        "uzlu": len(uzly),
        "hran": len(hrany),
        "hornin": typ["hornina"],
        "mineralu": typ["mineral"],
        "surovin": typ["surovina"],
        "vyrobku": typ["vyrobek"],
        "prvku": typ["prvek"],
        "vnejsich": typ["vnejsi"],
        "mezer_uzlu": typ["mezera"],
        "hornin_podle_tridy": dict(trida),
        "hran_podle_operace": dict(oper),
        "procesu": len(doc["procesy"]),
        "operaci_unikatnich": len({e["operace"] for e in hrany}),
    }


# =============================================================================
# Mermaid + markdown
# =============================================================================

def _m_id(i: str) -> str:
    return i.replace(":", "_").replace("-", "_")


def _m_label(text: str) -> str:
    return text.replace('"', "'")


def mermaid_flowchart(title: str, edges: list[tuple[str, str, str]], nodes: dict[str, str], direction: str = "TB") -> str:
    """edges: (od_id, do_id, popisek hrany). nodes: id -> label."""
    lines = [f"```mermaid", f"flowchart {direction}"]
    used = set()
    for a, b, _ in edges:
        used.add(a)
        used.add(b)
    for i in used:
        lines.append(f'  {_m_id(i)}["{_m_label(nodes[i])}"]')
    for a, b, lab in edges:
        if lab:
            lines.append(f"  {_m_id(a)} -->|{_m_label(lab)}| {_m_id(b)}")
        else:
            lines.append(f"  {_m_id(a)} --> {_m_id(b)}")
    lines.append("```")
    return "\n".join(lines)


def compact_family_edges(doc: dict, trida: str, operace: str) -> tuple[dict[str, str], list[tuple[str, str, str]]]:
    """Seskupí horniny stejné rodiny, pokud mají stejné hrany dané operace."""
    uzly = {n["id"]: n for n in doc["uzly"]}
    families: dict[str, list[dict]] = defaultdict(list)
    for n in doc["uzly"]:
        if n["typ"] == "hornina" and n["trida"] == trida:
            families[n["rodina"]].append(n)

    labels: dict[str, str] = {}
    edges: list[tuple[str, str, str]] = []
    seen = set()
    for rid, members in families.items():
        fid = f"rodina:{trida}:{rid}"
        names = [m["nazev"] for m in members]
        if len(members) == 1:
            labels[fid] = members[0]["nazev"]
        else:
            labels[fid] = f"{members[0]['rodina_nazev']} ({len(members)})"
        # hrany vezmi z prvního člena; ověř, že ostatní jsou stejné
        def sig(h):
            rel = [
                (e["do"], e.get("promile"), e.get("kusovy"), e.get("zakladni"))
                for e in doc["hrany"]
                if e["od"] == h["id"] and e["operace"] == operace
            ]
            return tuple(sorted(rel, key=lambda x: str(x)))

        s0 = sig(members[0])
        if any(sig(m) != s0 for m in members[1:]):
            # rozpad na jednotlivé horniny
            for m in members:
                hid = m["id"]
                labels[hid] = m["nazev"]
                for e in doc["hrany"]:
                    if e["od"] == hid and e["operace"] == operace:
                        dst = e["do"]
                        labels[dst] = uzly[dst]["nazev"]
                        lab = _edge_lab(e)
                        key = (hid, dst, lab)
                        if key not in seen:
                            seen.add(key)
                            edges.append(key)
            continue
        for e in doc["hrany"]:
            if e["od"] == members[0]["id"] and e["operace"] == operace:
                dst = e["do"]
                labels[dst] = uzly[dst]["nazev"]
                lab = _edge_lab(e)
                key = (fid, dst, lab)
                if key not in seen:
                    seen.add(key)
                    edges.append(key)
    return labels, edges


def _edge_lab(e: dict) -> str:
    bits = []
    if e.get("zakladni"):
        bits.append("zákl.")
    if e.get("promile") is not None and e.get("operace") in ("tezba", "slozeni"):
        bits.append(f"{e['promile']} ‰")
    elif e.get("kusovy"):
        bits.append("kus")
    elif e.get("operace") not in ("tezba", "slozeni", "odpovida"):
        bits.append(e["operace"])
        if e.get("dovednost"):
            bits.append(e["dovednost"])
    return ", ".join(bits)


def procesy_pro_tridu(
    doc: dict,
    trida: str,
    exclude_expand: set[str] | None = None,
    only_suroviny: set[str] | None = None,
    skip_procesy: set[str] | None = None,
    only_procesy: set[str] | None = None,
) -> tuple[dict[str, str], list[tuple[str, str, str]]]:
    """Zpracovatelské hrany ze surovin, které tato třída opravdu těží.

    Minerály gangue (kalcit → vápno, křemen → písek) nespouští celý cizí strom.
    Spoluvstupy (soda, dřevěné uhlí, vápno z jiné skupiny) se jen zobrazí, dál se z nich nevětví.
    """
    uzly = {n["id"]: n for n in doc["uzly"]}
    exclude_expand = exclude_expand or set()
    skip_procesy = skip_procesy or set()
    only_procesy = only_procesy or set()
    start = set()
    for n in doc["uzly"]:
        if n["typ"] == "hornina" and n["trida"] == trida:
            for e in doc["hrany"]:
                if e["od"] == n["id"] and e["operace"] == "tezba":
                    if only_suroviny is not None:
                        sid = e["do"].split(":", 1)[-1]
                        allowed = {x.split(":")[-1] for x in only_suroviny}
                        if sid not in allowed:
                            continue
                    start.add(e["do"])

    proc_ops = {e["operace"] for e in doc["hrany"]} - {"slozeni", "tezba"}
    by_src = defaultdict(list)
    all_by_proc = defaultdict(list)
    loose_edges = []
    for e in doc["hrany"]:
        if e["operace"] in proc_ops and not e.get("mezera"):
            by_src[e["od"]].append(e)
            if e.get("proces"):
                all_by_proc[e["proces"]].append(e)
            else:
                loose_edges.append(e)

    def blocked(i: str) -> bool:
        short = i.split(":", 1)[-1]
        return i in exclude_expand or short in exclude_expand or nid("surovina", short) in exclude_expand

    FUEL = {"vnejsi:drevene_uhli", "vnejsi:drevo", "vnejsi:soda", "vyrobek:koks"}

    def is_fuel(i: str) -> bool:
        return i in FUEL or i.split(":", 1)[-1] in {"drevene_uhli", "drevo", "soda", "koks"}

    def is_foreign_ore(i: str) -> bool:
        if i in start:
            return False
        short = i.split(":", 1)[-1]
        return short.startswith("ruda_") or short in {
            "drahokamy", "diamanty", "granaty", "uhli", "lignit",
        }

    def mains_of(e: dict) -> list[str]:
        ins = list(e.get("vstupy") or [e["od"]])
        m = [i for i in ins if not is_fuel(i)]
        return m or ins

    active = set(start)
    shown = set(start)
    used_edges: list[dict] = []
    seen_e = set()
    changed = True
    while changed:
        changed = False
        for src in list(active):
            if blocked(src):
                continue
            batch = []
            seen_proc = set()
            for e in by_src.get(src, []):
                pr = e.get("proces")
                if pr and pr in skip_procesy:
                    continue
                if pr and only_procesy and pr not in only_procesy:
                    continue
                if src not in mains_of(e):
                    continue
                if pr:
                    if pr in seen_proc:
                        continue
                    seen_proc.add(pr)
                    batch.extend(all_by_proc.get(pr, [e]))
                else:
                    batch.append(e)
            for e in batch:
                if is_foreign_ore(e["od"]):
                    continue
                key = (e["od"], e["do"], e.get("proces"), e.get("operace"))
                if key in seen_e:
                    continue
                seen_e.add(key)
                used_edges.append(e)
                if e["do"] not in shown:
                    shown.add(e["do"])
                    if not blocked(e["do"]):
                        active.add(e["do"])
                        changed = True
                for inp in e.get("vstupy") or []:
                    if is_foreign_ore(inp):
                        continue
                    if inp not in shown:
                        shown.add(inp)
                    if inp in start and not blocked(inp) and inp not in active:
                        active.add(inp)
                        changed = True

    labels = {i: uzly[i]["nazev"] for i in shown if i in uzly}
    edges = []
    seen = set()
    for e in used_edges:
        if e["od"] in shown and e["do"] in shown:
            lab = _edge_lab(e)
            key = (e["od"], e["do"], lab)
            if key not in seen:
                seen.add(key)
                edges.append(key)
    return labels, edges


# u rud nespouštět z jaloviny a křemenného písku celý sklářský / vápenický strom
RUDY_EXCLUDE_EXPAND = {
    "kremenny_pisek",
    "vapno",
    "jil",
    "pisek",
    "sterk",
    "jalovina",
    "prach",
    "blok_horniny",
    "hlina",
}

RUDY_KOVY = {
    "ruda_med",
    "ruda_zelezo",
    "ruda_fe_ti",
    "ruda_zlato",
    "ruda_vzacne",
}
RUDY_OSTATNI = {
    "drahokamy",
    "diamanty",
    "granaty",
    "uhli",
    "lignit",
}

# Vedlejší cesty, které na obrázku kovů jen pletou (glazura z mědi, kamenivo ze strusky).
RUDY_KOVY_SKIP = {"glazura", "porcelan", "tavit_sklo", "struska_sterk", "palit_cihly", "palit_keramiku"}

USAZENE_STAVBA = {
    "palit_vapno",
    "palit_kalcit",
    "palit_dolomit",
    "hasit_vapno",
    "michat_maltu",
    "karbonatace_malt",
    "palit_cement",
    "palit_sadru",
    "palit_cihly",
}
USAZENE_OHEN = {
    "palit_keramiku",
    "glazura",
    "porcelan",
    "tavit_sklo",
    "koksovat",
    "cistit_sul",
    "koks_uhlik",
}



def _filter_keep(labels, edges, keep=None, drop=None):
    """Nechá jen uzly z keep (suffix nebo plné id), případně vyhodí drop."""
    if not keep and not drop:
        return labels, edges
    def ok(i: str) -> bool:
        short = i.split(":", 1)[-1]
        if drop and (i in drop or short in drop):
            return False
        if not keep:
            return True
        return i in keep or short in keep or i.split(":", 1)[-1] in keep
    used = set()
    new_e = []
    for a, b, lab in edges:
        if ok(a) and ok(b):
            new_e.append((a, b, lab))
            used.add(a)
            used.add(b)
    # pokud keep obsahuje start, který zůstal bez hran, necháme ho být
    new_l = {k: v for k, v in labels.items() if k in used}
    return new_l, new_e


# Specifikace rozdělených obrázků kovů. Klíče s podtržítkem (_keep, _drop) se před
# procesy_pro_tridu odstraní.
RUDY_PROC_SPECS = [
    (
        "Měď a bronz",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"ruda_med"},
            "only_procesy": {"tavit_med", "louzit_med", "slevat_bronz", "med_na_prvek", "pigment_malachit"},
            "_drop": {"struska"},
        },
    ),
    (
        "Železo, ocel a Fe-Ti",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"ruda_zelezo", "ruda_fe_ti"},
            "only_procesy": {
                "tavit_zelezo",
                "tavit_zelezo_koks",
                "tavit_fe_ti",
                "cementovat_ocel",
                "cementovat_ocel_drevo",
                "zelezo_na_prvek",
                "titan_na_prvek",
                "pigment_okr",
            },
            "_drop": {"struska"},
        },
    ),
    (
        "Cín",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"ruda_vzacne"},
            "only_procesy": {"tavit_cin", "cin_na_prvek"},
            "_keep": {"ruda_vzacne", "cin", "Sn"},
        },
    ),
    (
        "Zlato",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"ruda_zlato"},
            "only_procesy": {"ryzovat_zlato", "louzit_zlato"},
        },
    ),
    (
        "Vzácné kovy (Li, Ta)",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"ruda_vzacne"},
            "only_procesy": {"tavit_cin", "louzit_lithium"},
            "_keep": {"ruda_vzacne", "lithium_konc", "Li", "Ta"},
        },
    ),
    (
        "Uhlí a koks",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"uhli", "lignit"},
            "only_procesy": {"koksovat", "koks_uhlik"},
        },
    ),
    (
        "Drahokamy a broušení",
        {
            "exclude_expand": RUDY_EXCLUDE_EXPAND,
            "only_suroviny": {"drahokamy", "diamanty", "granaty"},
            "only_procesy": {"brousit_drahokamy", "brousit_diamant", "brousit_granat"},
        },
    ),
]


def _proc_kwargs(kw: dict) -> dict:
    return {k: v for k, v in kw.items() if not k.startswith("_")}


def write_markdown(doc: dict) -> None:
    st = doc["statistiky"]
    lines = []
    a = lines.append
    a("# Strom hornin, obsah a další rozklad surovin")
    a("")
    a("Návrh **T02** studie `tezba-studie` (Jan 14:19, 2026-11-19). Strom je datový: `data/strom_rozkladu.json`, obrázky `shots/T02_strom_*.png`, sestavení a kontrola `tools/strom02.py`.")
    a("")
    a("Krátké věty. Čísla složení jsou typická, ne herní zákon. Výnosy ‰ beru z T01. Výrobky odkazují na [katalog materiálů](katalog-materialu.md). Zdroje v `ZDROJE.md`.")
    a("")
    a("## Jak strom číst")
    a("")
    a("- **Hornina** se rozpadá dvěma směry: typické **složení minerálů** (Mineralogie) a **výchozí výnos surovin** po zpracování buňky (T01, součet 1000 ‰).")
    a("- **Základní výnos** (kámen, štěrk, písek, jíl, hlína, sůl, uhlí, sádrovec, jalovina, křemenný písek, sníh, prach) postava pozná vždy. Rudy, vápno jako surovina a drahokamy potřebují Mineralogii — stejně ale vypadnou (hypotéza T01, 13:27).")
    a("- Ze surovin, které skupina opravdu těží, vedou operace na **výrobky** katalogu a nakonec na **prvky**. U hrany je dovednost. Spoluvstupy z jiné skupiny (soda, dřevěné uhlí, vápno ke sklu) se jen ukážou.")
    a("- Horské faciální názvy (masiv, stěna, jehla…) dědí složení i výnos své skupiny. V diagramech jsou sloučené do rodiny.")
    a("- Hašení a tvrdnutí malty tvoří **záměrný cyklus** zpět na kalcit (na obrázku popisek „cyklus: kalcit“, ne zpětná šipka). Jiné cykly strom nemá.")
    a("- Detailní obrázky jsou řetězce **zleva doprava**, jeden pruh na surovinu nebo výrobek. Huby (struska, dřevěné uhlí, koks jako palivo, soda) nejsou samostatné uzly — jsou v popisku hrany (`+ dřevěné uhlí`).")
    a("")
    a("## Počty")
    a("")
    a(f"- Hornin (bez aliasů a vzduchu): **{st['hornin']}** — " + ", ".join(f"{TRIDY[k]['nazev'].lower()} {v}" for k, v in st['hornin_podle_tridy'].items()) + ".")
    a(f"- Minerálů: **{st['mineralu']}**. Surovin T01: **{st['surovin']}**. Výrobků: **{st['vyrobku']}**. Prvků: **{st['prvku']}**. Vnějších vstupů: **{st['vnejsich']}** (dřevo, dřevěné uhlí, soda).")
    a(f"- Uzlů celkem: **{st['uzlu']}**. Hran: **{st['hran']}**. Procesů zpracování: **{st['procesu']}**. Unikátních operací: **{st['operaci_unikatnich']}**.")
    a("")
    a("## Přehled skupin")
    a("")
    a("```mermaid")
    a("flowchart TB")
    a('  V["Vyvřeliny"] --> KQ["křemen, živec, olivín"]')
    a('  P["Přeměněné"] --> KM["slída, granát, kalcit ve skarnu"]')
    a('  U["Usazené"] --> KU["kalcit, jíl, uhlík, halit, sádrovec"]')
    a('  R["Rudy a ložiska"] --> KR["malachit, magnetit, ilmenit, zlato"]')
    a('  Z["Zeminy a sypké"] --> KZ["jíl, křemen, hlína"]')
    a('  KQ --> SV["stavební kámen, křemenný písek"]')
    a('  KM --> SV')
    a('  KU --> VA["vápno, sůl, sádra, koks"]')
    a('  KR --> KO["měď, železo, ocel, bronz, Au"]')
    a('  KZ --> CI["cihla, keramika, malta"]')
    a('  SV --> SK["sklo"]')
    a('  VA --> CE["malta, cement, sádra"]')
    a("```")
    a("")
    a("Obrázek: `shots/T02_strom_prehled.png`.")
    a("")

    shot_map = {
        "vyvreliny": ["T02_strom_vyvreliny_slozeni.png", "T02_strom_vyvreliny_vynosy.png", "T02_strom_vyvreliny_zpracovani.png"],
        "premenene": [
            "T02_strom_premenene_slozeni.png",
            "T02_strom_premenene_vynosy.png",
            "T02_strom_premenene_zpracovani_stavba.png",
            "T02_strom_premenene_zpracovani_ohen.png",
        ],
        "usazene": ["T02_strom_usazene_slozeni.png", "T02_strom_usazene_vynosy.png", "T02_strom_usazene_zpracovani_stavba.png", "T02_strom_usazene_zpracovani_ohen.png"],
        "rudy": [
            "T02_strom_rudy_slozeni.png",
            "T02_strom_rudy_vynosy.png",
            "T02_strom_rudy_zpracovani_med.png",
            "T02_strom_rudy_zpracovani_zelezo.png",
            "T02_strom_rudy_zpracovani_cin.png",
            "T02_strom_rudy_zpracovani_zlato.png",
            "T02_strom_rudy_zpracovani_vzacne.png",
            "T02_strom_rudy_zpracovani_uhli.png",
            "T02_strom_rudy_zpracovani_kameny.png",
        ],
        "zeminy": ["T02_strom_zeminy_slozeni.png", "T02_strom_zeminy_vynosy.png", "T02_strom_zeminy_zpracovani.png"],
    }

    for trida, meta in TRIDY.items():
        a(f"## {meta['nazev']}")
        a("")
        a(meta["popis"])
        members = [n for n in doc["uzly"] if n["typ"] == "hornina" and n["trida"] == trida]
        members.sort(key=lambda n: (n["rodina"], n["material_id"], n["material_key"]))
        fam = defaultdict(list)
        for n in members:
            fam[n["rodina"]].append(n)
        a("")
        a(f"Hornin v této skupině: {len(members)}.")
        a("")
        for rid, ms in fam.items():
            naz = ms[0]["rodina_nazev"]
            jmena = ", ".join(f"{m['nazev']} (`{m['material_key']}`, id {m['material_id']})" for m in ms)
            a(f"- **{naz}:** {jmena}.")
        a("")
        a("### Složení")
        a("")
        lab, ed = compact_family_edges(doc, trida, "slozeni")
        a(mermaid_flowchart("slozeni", ed, lab))
        a("")
        a("### Výnosy")
        a("")
        a("Základní vždy známý výnos je v datech `zakladni` a v popisku hrany `zákl.`")
        a("")
        lab2, ed2 = compact_family_edges(doc, trida, "tezba")
        a(mermaid_flowchart("tezba", ed2, lab2))
        a("")
        a("### Další rozklad a zpracování")
        a("")
        if trida == "rudy":
            for nadpis, kw in RUDY_PROC_SPECS:
                lab_x, ed_x = procesy_pro_tridu(doc, trida, **_proc_kwargs(kw))
                lab_x, ed_x = _filter_keep(lab_x, ed_x, kw.get("_keep"), kw.get("_drop"))
                a(nadpis + ":")
                a("")
                a(mermaid_flowchart("p", ed_x, lab_x) if ed_x else "Chybí hrany.")
                a("")
        elif trida == "usazene":
            lab_s, ed_s = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_STAVBA)
            a("Stavební vápno, malta, cement, sádra, cihly:")
            a("")
            a(mermaid_flowchart("stavba", ed_s, lab_s) if ed_s else "Chybí hrany.")
            a("")
            lab_o, ed_o = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_OHEN)
            a("Oheň a chemie: sklo, keramika, koks, sůl:")
            a("")
            a(mermaid_flowchart("ohen", ed_o, lab_o) if ed_o else "Chybí hrany.")
        else:
            lab3, ed3 = procesy_pro_tridu(doc, trida)
            if ed3:
                a(mermaid_flowchart("zpracovani", ed3, lab3))
            else:
                a("V této skupině zatím není navázané další zpracování (nemělo by nastat).")
        a("")
        shots = ", ".join(f"`shots/{s}`" for s in shot_map[trida])
        a(f"Obrázky: {shots}.")
        a("")

    a("## Dovednosti u kroků")
    a("")
    for k, v in DOVEDNOSTI.items():
        a(f"- **{k}:** {v}")
    a("")
    a("Mineralogie odemyká rozpoznání minerálů a výnosů, které nejsou základní. Kamenictví drtí a brousí. Chemie pálí, praží, čistí a louží. Hutnictví taví a slévá. Sklářství, hrnčířství, zednictví a kovářství navazují na katalog (T01).")
    a("")
    a("## Mezery a nejistoty")
    a("")
    for m in doc["mezery"]:
        a(f"- {m}")
    a("")
    a("Otevřené pro Jana: má se složení minerálů ve hře stát vlastní vrstvou znalostí, nebo stačí výnos surovin? Mají olovo a rumělka dostat vlastní ložiska? Má se `ruda_vzacne` rozdělit na Li / Sn / Ta? Je 20 ‰ zlata ve složení buňky přijatelná abstrakce, nebo má složení zůstat u křemene a pyritu a kov jen jako kusový nález?")
    a("")
    a("## Soubory")
    a("")
    a("- `data/strom_rozkladu.json`")
    a("- `navrhy/strom-hornin.md` (tento text, generovaný skriptem)")
    a("- `tools/strom02.py`")
    a("- `shots/T02_strom_prehled.png` a detaily skupin (složení, výnosy, zpracování)")
    a("")
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


# =============================================================================
# Obrázky (matplotlib, zleva doprava, pruhy; bez Graphvizu)
# =============================================================================

COLORS = {
    "skupina": "#5C4B8A",
    "hornina": "#8B5A2B",
    "rodina": "#8B5A2B",
    "mineral": "#1F7A6E",
    "surovina": "#C26A12",
    "vyrobek": "#2E7D3A",
    "prvek": "#3D5A80",
    "vnejsi": "#5A5A5A",
    "mezera": "#8A3B3B",
    "klic": "#1F7A6E",
}

# Huby v detailech nekreslíme jako box — jen anotace na hraně.
HUB_ANNOT = {
    "vyrobek:struska": "struska",
    "vnejsi:drevene_uhli": "dřevěné uhlí",
    "vnejsi:drevo": "dřevo",
    "vnejsi:soda": "soda / potaš",
}
HUB_FUEL = {
    "vyrobek:koks": "koks",
}

# Globální součet křížení pro report (naplní kreslení).
CROSSINGS: list[tuple[str, int]] = []


def typ_of(i: str, uzly: dict) -> str:
    if i.startswith("rodina:"):
        return "rodina"
    if i.startswith("skupina:"):
        return "skupina"
    if i.startswith("klic:"):
        return "klic"
    prefix = i.split(":", 1)[0]
    if prefix in COLORS:
        return prefix
    return uzly[i]["typ"] if i in uzly else "hornina"


def wrap_label(text: str, width: int = 16) -> str:
    return "\n".join(textwrap.wrap(text, width=width) or [text])


def _ccw(a, b, c) -> int:
    """Orientace: 1 / -1 / 0."""
    v = (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
    if abs(v) < 1e-12:
        return 0
    return 1 if v > 0 else -1


def _seg_intersect(p1, p2, q1, q2) -> bool:
    """Pravý kříž dvou úseček (sdílený vrchol se nepočítá — to řeší volající)."""
    o1, o2 = _ccw(p1, p2, q1), _ccw(p1, p2, q2)
    o3, o4 = _ccw(q1, q2, p1), _ccw(q1, q2, p2)
    if o1 == 0 or o2 == 0 or o3 == 0 or o4 == 0:
        return False  # dotyk / kolinearita nebereme jako křížení
    return o1 != o2 and o3 != o4


def count_crossings(pos: dict[str, tuple[float, float]], edges: list[tuple[str, str, str]]) -> int:
    segs = []
    seen = set()
    for a, b, _lab in edges:
        if a not in pos or b not in pos or a == b:
            continue
        key = tuple(sorted((a, b)))
        if key in seen:
            continue
        seen.add(key)
        segs.append((pos[a], pos[b], a, b))
    n = 0
    for i in range(len(segs)):
        p1, p2, a1, a2 = segs[i]
        for j in range(i + 1, len(segs)):
            q1, q2, b1, b2 = segs[j]
            if len({a1, a2, b1, b2}) < 4:
                continue
            if _seg_intersect(p1, p2, q1, q2):
                n += 1
    return n


def merge_lab(*parts: str) -> str:
    bits = []
    seen = set()
    for p in parts:
        if not p:
            continue
        for bit in str(p).split(","):
            b = bit.strip()
            if b and b not in seen:
                seen.add(b)
                bits.append(b)
    return ", ".join(bits)


def collapse_hubs(
    labels: dict[str, str],
    edges: list[tuple[str, str, str]],
    keep_hubs: set[str] | None = None,
    extra_hubs: dict[str, str] | None = None,
) -> tuple[dict[str, str], list[tuple[str, str, str]]]:
    """Strusku, dřevěné uhlí, sodu a koks-jako-palivo smaže z uzlů a přidá na hranu."""
    keep_hubs = keep_hubs or set()
    hubs = {**HUB_ANNOT, **(extra_hubs or {})}
    for k, v in HUB_FUEL.items():
        if k not in keep_hubs:
            hubs[k] = v
    hub_ids = {i for i in hubs if i not in keep_hubs}

    # Zpětné cykly (karbonatace) → anotace „cyklus: kalcit“, ne šipka.
    cycle_notes: dict[str, str] = {}
    work = []
    for a, b, lab in edges:
        if lab and "karbonatace" in lab:
            cycle_notes[a] = merge_lab(cycle_notes.get(a, ""), "cyklus: kalcit")
            continue
        work.append((a, b, lab))
    edges = work

    incoming = defaultdict(list)
    outgoing = defaultdict(list)
    for a, b, lab in edges:
        incoming[b].append((a, lab))
        outgoing[a].append((b, lab))

    new_edges: list[tuple[str, str, str]] = []
    seen = set()

    def add(a, b, lab):
        key = (a, b, lab)
        if a == b:
            return
        if key in seen:
            return
        seen.add(key)
        new_edges.append((a, b, lab))

    for a, b, lab in edges:
        if a in hub_ids or b in hub_ids:
            continue
        extras = []
        for src, sl in incoming.get(b, []):
            if src in hub_ids:
                extras.append("+ " + hubs[src])
        for dst, dl in outgoing.get(a, []):
            if dst in hub_ids:
                extras.append("+ " + hubs[dst])
        if a in cycle_notes:
            extras.append(cycle_notes[a])
        if b in cycle_notes:
            extras.append(cycle_notes[b])
        add(a, b, merge_lab(lab, *extras))

    # most přes hub: A → hub → B
    for h in hub_ids:
        preds = [a for a, _ in incoming.get(h, []) if a not in hub_ids]
        succs = [b for b, _ in outgoing.get(h, []) if b not in hub_ids]
        for a in preds:
            for b in succs:
                add(a, b, merge_lab("+ " + hubs[h]))

    # sloučit rovnoběžné hrany A→B (tavit i loužit atd.) do jednoho popisku
    bundled = defaultdict(list)
    order = []
    for a, b, lab in new_edges:
        key = (a, b)
        if key not in bundled:
            order.append(key)
        bundled[key].append(lab)
    new_edges = [(a, b, merge_lab(*bundled[(a, b)])) for a, b in order]

    used = {a for a, b, _ in new_edges} | {b for a, b, _ in new_edges}
    new_labels = {k: v for k, v in labels.items() if k in used and k not in hub_ids}
    return new_labels, new_edges


def longest_path_depth(edges, skip_labs=None) -> dict[str, int]:
    skip_labs = skip_labs or set()
    nodes = set()
    preds = defaultdict(set)
    for a, b, lab in edges:
        if lab in skip_labs:
            continue
        nodes.add(a)
        nodes.add(b)
        preds[b].add(a)
    depth: dict[str, int] = {}

    def d(n: str, stack: frozenset[str] = frozenset()) -> int:
        if n in depth:
            return depth[n]
        if n in stack:
            return 0
        ps = preds.get(n) or set()
        if not ps:
            depth[n] = 0
            return 0
        depth[n] = 1 + max(d(p, stack | {n}) for p in ps)
        return depth[n]

    for n in nodes:
        d(n)
    return depth


def barycenter_order(columns: list[list[str]], edges) -> list[list[str]]:
    """Urovná uzly ve sloupcích podle barycentra sousedů, ať je méně křížení."""
    if not columns:
        return columns
    succs = defaultdict(set)
    preds = defaultdict(set)
    for a, b, _ in edges:
        succs[a].add(b)
        preds[b].add(a)

    cols = [list(c) for c in columns]

    def pos_map():
        m = {}
        for ci, col in enumerate(cols):
            for ri, n in enumerate(col):
                m[n] = (ci, ri)
        return m

    for _ in range(10):
        # zleva doprava
        pm = pos_map()
        for ci in range(1, len(cols)):
            def key(n, ci=ci):
                nb = [pm[p][1] for p in preds[n] if p in pm]
                return (sum(nb) / len(nb) if nb else pm.get(n, (ci, 0))[1], n)
            cols[ci] = sorted(cols[ci], key=key)
        # zprava doleva
        pm = pos_map()
        for ci in range(len(cols) - 2, -1, -1):
            def key2(n, ci=ci):
                nb = [pm[s][1] for s in succs[n] if s in pm]
                return (sum(nb) / len(nb) if nb else pm.get(n, (ci, 0))[1], n)
            cols[ci] = sorted(cols[ci], key=key2)
    return cols


def lanes_from_starts(labels, edges) -> list[list[tuple[str, int]]]:
    """Jeden pruh na kořen (uzel bez vstupu). Uzly se v pruzích mohou opakovat (bez křížení mezi pruhy)."""
    preds = defaultdict(set)
    succs = defaultdict(list)
    nodes = set(labels)
    for a, b, lab in edges:
        nodes.add(a)
        nodes.add(b)
        preds[b].add(a)
        succs[a].append((b, lab))
    starts = [n for n in nodes if not preds[n]]
    # stabilní pořadí: suroviny, minerály, zbytek
    def start_key(n):
        t = n.split(":")[0]
        order = {"surovina": 0, "mineral": 1, "rodina": 0, "hornina": 0, "vyrobek": 2, "vnejsi": 3, "prvek": 4}
        return (order.get(t, 5), labels.get(n, n))

    starts = sorted(starts, key=start_key)
    if not starts:
        starts = sorted(nodes)

    depth_global = longest_path_depth(edges)
    lanes = []
    for s in starts:
        # podstrom dosažitelný ze startu
        seen = {s}
        stack = [s]
        while stack:
            x = stack.pop()
            for y, _ in succs.get(x, []):
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        # hloubka v tomto pruhu: nejdelší cesta od s
        local = {s: 0}
        changed = True
        while changed:
            changed = False
            for a, b, _ in edges:
                if a in local and b in seen:
                    nd = local[a] + 1
                    if nd > local.get(b, -1):
                        local[b] = nd
                        changed = True
        lane = [(n, local[n]) for n in seen if n in local]
        # kdyby nějaký uzel zůstal, dej ho podle globální hloubky
        lane.sort(key=lambda t: (t[1], labels.get(t[0], t[0])))
        lanes.append(lane)
    return lanes


def layout_family_lanes(labels, edges) -> tuple[dict[str, tuple[float, float]], list[tuple[str, str, str]], dict[str, str]]:
    """1-k-N: jeden pruh na rodinu, cíle zleva doprava. Klíče cílů jsou unikátní (rodina+cíl)."""
    by_src = defaultdict(list)
    for a, b, lab in edges:
        by_src[a].append((b, lab))
    # zachovej pořadí první výskytu
    order = []
    seen = set()
    for a, b, _ in edges:
        if a not in seen:
            seen.add(a)
            order.append(a)
    pos = {}
    draw_labels = {}
    draw_edges = []
    n_lanes = max(len(order), 1)
    for li, src in enumerate(order):
        y = (n_lanes - 1 - li) * 2.45
        pos[src] = (0.0, float(y))
        draw_labels[src] = labels.get(src, src)
        tgts = by_src[src]
        for ti, (dst, lab) in enumerate(tgts):
            key = f"{src}||{dst}"
            pos[key] = (1.0 + ti, float(y))
            share = lab or ""
            name = labels.get(dst, dst)
            draw_labels[key] = f"{name}\n{share}".strip() if share else name
            draw_edges.append((src, key, ""))
    return pos, draw_edges, draw_labels


def layout_process_lanes(labels, edges) -> tuple[dict[str, tuple[float, float]], list[tuple[str, str, str]], dict[str, str]]:
    """Řetězce zleva doprava, jeden pruh na vstupní surovinu. V pruhu vrstvy podle nejdelší cesty."""
    lanes = lanes_from_starts(labels, edges)
    pos = {}
    draw_labels = {}
    draw_edges = []
    STEP = 0.82
    BOX = 0.54
    PAD = 0.35

    def lane_span(lane):
        by_d = defaultdict(list)
        for n, d in lane:
            by_d[d].append(n)
        kmax = max((len(v) for v in by_d.values()), default=1)
        return max(2.45, (kmax - 1) * STEP + BOX + PAD)

    spans = [lane_span(L) for L in lanes]
    # pruhy shora dolů, střed pruhu
    tops = []
    y_cursor = 0.0
    for sp in spans:
        tops.append(y_cursor)
        y_cursor += sp
    # překlopit: první pruh nahoře
    total = y_cursor
    n_lanes = max(len(lanes), 1)
    for li, lane in enumerate(lanes):
        sp = spans[li]
        y = total - tops[li] - sp / 2
        # sloupce v pruhu
        by_d = defaultdict(list)
        for n, d in lane:
            by_d[d].append(n)
        cols = [by_d[d] for d in range(max(by_d) + 1)] if by_d else []
        ids = {n for n, _ in lane}
        local_e = [(a, b, lab) for a, b, lab in edges if a in ids and b in ids]
        cols = barycenter_order(cols, local_e)
        for d, col in enumerate(cols):
            k = max(len(col), 1)
            for ri, n in enumerate(col):
                key = f"L{li}:{n}"
                off = 0.0 if k == 1 else (ri - (k - 1) / 2) * STEP
                pos[key] = (float(d), float(y) + off)
                draw_labels[key] = labels.get(n, n)
        # hrany v pruhu
        key_of = {n: f"L{li}:{n}" for n, _ in lane}
        for a, b, lab in local_e:
            if a in key_of and b in key_of:
                draw_edges.append((key_of[a], key_of[b], lab))
    return pos, draw_edges, draw_labels


def typ_of_draw(i: str, uzly: dict) -> str:
    # klíče "L0:surovina:x" nebo "src||dst"
    raw = i
    if "||" in i:
        raw = i.split("||", 1)[1]
    if i.startswith("L") and ":" in i:
        raw = i.split(":", 1)[1]
    return typ_of(raw, uzly)


def draw_lr(
    path: Path,
    title: str,
    subtitle: str,
    pos: dict[str, tuple[float, float]],
    labels: dict[str, str],
    edges: list[tuple[str, str, str]],
    uzly: dict,
    footnote: str,
) -> int:
    """Kreslí uzly v souřadnicích (sloupec, pruh), šipky zleva doprava. Vrací počet křížení."""
    if not pos:
        # prázdný placeholder ať nepadá
        fig, ax = plt.subplots(figsize=(10, 4), dpi=150)
        ax.axis("off")
        ax.text(0.5, 0.5, "Žádné hrany", ha="center", fontproperties=FONT)
        fig.savefig(path, dpi=150, facecolor="white", bbox_inches="tight")
        plt.close(fig)
        CROSSINGS.append((path.name, 0))
        return 0

    # sloučit rovnoběžné hrany i u přehledu / složení
    bundled = defaultdict(list)
    order = []
    for a, b, lab in edges:
        key = (a, b)
        if key not in bundled:
            order.append(key)
        bundled[key].append(lab)
    edges = [(a, b, merge_lab(*bundled[(a, b)])) for a, b in order]

    # rozteč sloupců, ať se boxy a popisky na telefonu nepřekrývají
    X_PITCH = 1.70
    pos = {k: (x * X_PITCH, y) for k, (x, y) in pos.items()}

    xs = [p[0] for p in pos.values()]
    ys = [p[1] for p in pos.values()]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    n_cols = (max_x - min_x) / X_PITCH + 1
    n_rows = max((max_y - min_y) / 2.45 + 1, 1)

    box_w = 1.00
    box_h = 0.54
    w = max(10.5, 2.05 * n_cols + 1.8)
    h = max(5.4, 1.35 * max(n_rows, 1) + 2.6)
    fig, ax = plt.subplots(figsize=(w, h), dpi=155)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    ax.set_xlim(min_x - 1.0, max_x + 1.0)
    ax.set_ylim(min_y - 1.70, max_y + 1.85)
    ax.axis("off")

    n_cross = count_crossings(pos, edges)

    # šipky: z pravého boku do levého
    for a, b, lab in edges:
        if a not in pos or b not in pos:
            continue
        x1, y1 = pos[a]
        x2, y2 = pos[b]
        ax.annotate(
            "",
            xy=(x2 - box_w / 2 + 0.02, y2),
            xytext=(x1 + box_w / 2 - 0.02, y1),
            arrowprops=dict(
                arrowstyle="-|>",
                color="#444444",
                lw=1.15,
                shrinkA=0,
                shrinkB=0,
                connectionstyle="arc3,rad=0.0",
            ),
        )
        if lab:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + 0.36
            ax.text(
                mx,
                my,
                lab,
                ha="center",
                va="center",
                fontsize=8,
                color="#222",
                fontproperties=FONT,
                bbox=dict(boxstyle="round,pad=0.12", facecolor="white", edgecolor="#dddddd", linewidth=0.4, alpha=0.96),
                zorder=8,
            )

    for i, (x, y) in pos.items():
        typ = typ_of_draw(i, uzly)
        color = COLORS.get(typ, "#444")
        box = FancyBboxPatch(
            (x - box_w / 2, y - box_h / 2),
            box_w,
            box_h,
            boxstyle="round,pad=0.02,rounding_size=0.04",
            facecolor=color,
            edgecolor="none",
            zorder=5,
        )
        ax.add_patch(box)
        ax.text(
            x,
            y,
            wrap_label(labels.get(i, i), 16),
            ha="center",
            va="center",
            fontsize=10.5,
            color="white",
            fontproperties=FONTB,
            zorder=6,
            linespacing=1.15,
        )

    ax.text(0.5 * (min_x + max_x), max_y + 1.45, title, ha="center", va="top", fontsize=16.5, fontproperties=FONTB, color="#111")
    if subtitle:
        ax.text(0.5 * (min_x + max_x), max_y + 1.10, subtitle, ha="center", va="top", fontsize=10, fontproperties=FONT, color="#333")

    used = {typ_of_draw(i, uzly) for i in pos}
    mapping = [
        ("skupina", "skupina", COLORS["skupina"]),
        ("klic", "klíčový obsah", COLORS["klic"]),
        ("hornina", "hornina / rodina", COLORS["hornina"]),
        ("rodina", "hornina / rodina", COLORS["hornina"]),
        ("mineral", "minerál", COLORS["mineral"]),
        ("surovina", "surovina", COLORS["surovina"]),
        ("vyrobek", "výrobek", COLORS["vyrobek"]),
        ("prvek", "prvek", COLORS["prvek"]),
        ("vnejsi", "vnější vstup", COLORS["vnejsi"]),
        ("mezera", "mezera", COLORS["mezera"]),
    ]
    seen = set()
    wanted = []
    for typ, name, col in mapping:
        if typ in used and name not in seen:
            wanted.append((name, col))
            seen.add(name)
    lx = min_x - 0.45
    ly = min_y - 1.05
    for name, col in wanted:
        ax.add_patch(
            FancyBboxPatch((lx, ly - 0.08), 0.16, 0.16, boxstyle="round,pad=0.01", facecolor=col, edgecolor="none", zorder=5, clip_on=False)
        )
        ax.text(lx + 0.20, ly, name, ha="left", va="center", fontsize=8.5, fontproperties=FONT, color="#222")
        lx += 1.15

    ax.text(
        0.5 * (min_x + max_x),
        min_y - 1.42,
        footnote + f"  ·  křížení hran: {n_cross}",
        ha="center",
        va="bottom",
        fontsize=8,
        fontproperties=FONT,
        color="#555",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout(pad=0.35)
    fig.savefig(path, dpi=155, facecolor="white", bbox_inches="tight", pad_inches=0.28)
    plt.close(fig)
    CROSSINGS.append((path.name, n_cross))
    return n_cross


def draw_overview_lr(path, title, subtitle, labels, edges, layers, uzly, footnote) -> int:
    """Přehled: sloupce zleva doprava, barycenter, typové barvy."""
    cols = [list(c) for c in layers]
    cols = barycenter_order(cols, edges)
    pos = {}
    for ci, col in enumerate(cols):
        k = max(len(col), 1)
        for ri, n in enumerate(col):
            # horní = vyšší y
            y = (k - 1) / 2 - ri
            pos[n] = (float(ci), float(y))
    return draw_lr(path, title, subtitle, pos, labels, edges, uzly, footnote)


def make_images(doc: dict) -> list[Path]:
    global CROSSINGS
    CROSSINGS = []
    uzly = {n["id"]: n for n in doc["uzly"]}
    paths: list[Path] = []
    OUT_SHOTS.mkdir(parents=True, exist_ok=True)

    for old in OUT_SHOTS.glob("T02_strom_*.png"):
        old.unlink()

    # --- přehled (zleva doprava; obsah stejný) ---
    labels = {
        "skupina:vyvreliny": "Vyvřeliny",
        "skupina:premenene": "Přeměněné",
        "skupina:usazene": "Usazené",
        "skupina:rudy": "Rudy a ložiska",
        "skupina:zeminy": "Zeminy a sypké",
        "klic:kremen": "křemen, živec, olivín",
        "klic:slida": "slída, granát, kalcit",
        "klic:kalcit": "kalcit, jíl, uhlík, sůl",
        "klic:rudy": "malachit, magnetit, zlato",
        "klic:jil": "jíl, písek, hlína",
        "surovina:kamen": "stavební kámen, křemenný písek",
        "surovina:vapno_s": "vápno, sůl, uhlí, sádrovec",
        "surovina:rudy_s": "měděná a železná ruda",
        "surovina:zem_s": "jíl, písek, hlína",
        "vyrobek:sklo_s": "sklo",
        "vyrobek:malta_s": "malta, cement, sádra",
        "vyrobek:kovy_s": "měď, železo, ocel, bronz",
        "vyrobek:cihla_s": "cihla, keramika",
        "vyrobek:koks_s": "koks, pigmenty, broušené kameny",
    }
    edges = [
        ("skupina:vyvreliny", "klic:kremen", ""),
        ("skupina:premenene", "klic:slida", ""),
        ("skupina:usazene", "klic:kalcit", ""),
        ("skupina:rudy", "klic:rudy", ""),
        ("skupina:zeminy", "klic:jil", ""),
        ("klic:kremen", "surovina:kamen", ""),
        ("klic:slida", "surovina:kamen", ""),
        ("klic:kalcit", "surovina:vapno_s", ""),
        ("klic:rudy", "surovina:rudy_s", ""),
        ("klic:jil", "surovina:zem_s", ""),
        ("surovina:kamen", "vyrobek:sklo_s", "sklářství"),
        ("surovina:vapno_s", "vyrobek:malta_s", "chemie, zednictví"),
        ("surovina:vapno_s", "vyrobek:koks_s", "hutnictví"),
        ("surovina:rudy_s", "vyrobek:kovy_s", "hutnictví"),
        ("surovina:zem_s", "vyrobek:cihla_s", "hrnčířství"),
        ("surovina:kamen", "vyrobek:koks_s", "kamenictví"),
    ]
    layers = [
        ["skupina:vyvreliny", "skupina:premenene", "skupina:usazene", "skupina:rudy", "skupina:zeminy"],
        ["klic:kremen", "klic:slida", "klic:kalcit", "klic:rudy", "klic:jil"],
        ["surovina:kamen", "surovina:vapno_s", "surovina:rudy_s", "surovina:zem_s"],
        ["vyrobek:sklo_s", "vyrobek:malta_s", "vyrobek:kovy_s", "vyrobek:cihla_s", "vyrobek:koks_s"],
    ]
    # pět pruhů (jedna skupina = jeden řetězec), bez sdílených uzlů
    ov_labels = {
        "V0": "Vyvřeliny", "V1": "křemen, živec, olivín", "V2": "stavební kámen, křemenný písek", "V3": "sklo",
        "P0": "Přeměněné", "P1": "slída, granát, kalcit", "P2": "stavební kámen, křemenný písek", "P3": "kámen / granáty",
        "U0": "Usazené", "U1": "kalcit, jíl, uhlík, sůl", "U2": "vápno, sůl, uhlí, sádrovec", "U3": "malta, cement, sádra",
        "R0": "Rudy a ložiska", "R1": "malachit, magnetit, zlato", "R2": "měděná a železná ruda", "R3": "měď, železo, ocel, bronz",
        "Z0": "Zeminy a sypké", "Z1": "jíl, písek, hlína", "Z2": "jíl, písek, hlína", "Z3": "cihla, keramika",
    }
    # typové prefixy, ať barvy sedí
    ov_map = {
        "V0": "skupina:vyvreliny", "P0": "skupina:premenene", "U0": "skupina:usazene",
        "R0": "skupina:rudy", "Z0": "skupina:zeminy",
        "V1": "klic:kremen", "P1": "klic:slida", "U1": "klic:kalcit", "R1": "klic:rudy", "Z1": "klic:jil",
        "V2": "surovina:kamen", "P2": "surovina:kamen", "U2": "surovina:vapno_s", "R2": "surovina:rudy_s", "Z2": "surovina:zem_s",
        "V3": "vyrobek:sklo_s", "P3": "vyrobek:koks_s", "U3": "vyrobek:malta_s", "R3": "vyrobek:kovy_s", "Z3": "vyrobek:cihla_s",
    }
    ov_labels_draw = {}
    ov_pos = {}
    ov_edges = []
    lanes_ov = ["V", "P", "U", "R", "Z"]
    for li, pref in enumerate(lanes_ov):
        y = (len(lanes_ov) - 1 - li) * 1.85
        for c in range(4):
            kid = f"{pref}{c}"
            hid = ov_map[kid]
            ov_pos[hid if pref == "V" and False else kid] = (float(c), y)  # noqa: unique keys
        # use unique keys with typ via typ_of_draw? typ_of_draw looks at prefix.
        # Better store typ in a side map: use ids like skupina:V0? 
    # přepiš čistěji jednoznačnými id
    ov_pos = {}
    ov_lab = {}
    ov_edges = []
    typ_alias = {}
    rows = [
        ("skupina:V", "Vyvřeliny", "klic:V", "křemen, živec, olivín", "surovina:V", "stavební kámen, křemenný písek", "vyrobek:V", "sklo"),
        ("skupina:P", "Přeměněné", "klic:P", "slída, granát, kalcit", "surovina:P", "stavební kámen, křemenný písek", "vyrobek:P", "kámen / granáty"),
        ("skupina:U", "Usazené", "klic:U", "kalcit, jíl, uhlík, sůl", "surovina:U", "vápno, sůl, uhlí, sádrovec", "vyrobek:U", "malta, cement, sádra"),
        ("skupina:R", "Rudy a ložiska", "klic:R", "malachit, magnetit, zlato", "surovina:R", "měděná a železná ruda", "vyrobek:R", "měď, železo, ocel, bronz"),
        ("skupina:Z", "Zeminy a sypké", "klic:Z", "jíl, písek, hlína", "surovina:Z", "jíl, písek, hlína", "vyrobek:Z", "cihla, keramika"),
    ]
    for li, row in enumerate(rows):
        y = (len(rows) - 1 - li) * 2.45
        ids = []
        for c in range(4):
            i, name = row[2 * c], row[2 * c + 1]
            ov_pos[i] = (float(c), y)
            ov_lab[i] = name
            ids.append(i)
        for a, b in zip(ids, ids[1:]):
            ov_edges.append((a, b, ""))
    pth = OUT_SHOTS / "T02_strom_prehled.png"
    draw_lr(
        pth,
        "Strom hornin — přehled skupin",
        "Jeden pruh = jedna skupina, zleva doprava: skupina → minerály → suroviny → výrobky",
        ov_pos,
        ov_lab,
        ov_edges,
        uzly,
        "T02 · typické složení je orientační · výnosy z T01",
    )
    paths.append(pth)

    def save_family(path: Path, title, sub, lab, ed, footnote):
        pos, de, dl = layout_family_lanes(lab, ed)
        draw_lr(path, title, sub, pos, dl, de, uzly, footnote)
        paths.append(path)

    def save_proc(path: Path, title, sub, lab, ed, keep_hubs=None, extra_hubs=None):
        if not ed:
            return
        lab2, ed2 = collapse_hubs(lab, ed, keep_hubs=keep_hubs, extra_hubs=extra_hubs)
        if not ed2:
            return
        pos, de, dl = layout_process_lanes(lab2, ed2)
        draw_lr(path, title, sub, pos, dl, de, uzly, "T02 · poměry vsázky jsou hrubé · huby (+ dřevěné uhlí, struska, soda) jsou na hraně")
        paths.append(path)

    for trida, meta in TRIDY.items():
        naz = meta["nazev"]
        lab_s, ed_s = compact_family_edges(doc, trida, "slozeni")
        save_family(
            OUT_SHOTS / f"T02_strom_{trida}_slozeni.png",
            f"{naz} — typické složení",
            "Jeden pruh = jedna rodina hornin. Minerály zleva doprava, podíl v ‰ (typický střed, ne herní zákon).",
            lab_s,
            ed_s,
            "T02 · složení v ‰ je typický střed z reálných hornin · součet 1000 ‰",
        )
        lab_t, ed_t = compact_family_edges(doc, trida, "tezba")
        save_family(
            OUT_SHOTS / f"T02_strom_{trida}_vynosy.png",
            f"{naz} — výchozí výnosy",
            "Jeden pruh = jedna rodina. zákl. = vždy známé bez Mineralogie. Součet 1000 ‰.",
            lab_t,
            ed_t,
            "T02 · výnosy z data/horniny_tezba_navrh.json · kusové nálezy jsou mimo součet 1000 ‰",
        )

        if trida == "rudy":
            file_of = {
                "Měď a bronz": "T02_strom_rudy_zpracovani_med.png",
                "Železo, ocel a Fe-Ti": "T02_strom_rudy_zpracovani_zelezo.png",
                "Cín": "T02_strom_rudy_zpracovani_cin.png",
                "Zlato": "T02_strom_rudy_zpracovani_zlato.png",
                "Vzácné kovy (Li, Ta)": "T02_strom_rudy_zpracovani_vzacne.png",
                "Uhlí a koks": "T02_strom_rudy_zpracovani_uhli.png",
                "Drahokamy a broušení": "T02_strom_rudy_zpracovani_kameny.png",
            }
            for nadpis, kw in RUDY_PROC_SPECS:
                lab_x, ed_x = procesy_pro_tridu(doc, trida, **_proc_kwargs(kw))
                lab_x, ed_x = _filter_keep(lab_x, ed_x, kw.get("_keep"), kw.get("_drop"))
                keep = {"vyrobek:koks"} if "Uhlí" in nadpis else set()
                extra = {"vyrobek:cin": "cín"} if "Měď" in nadpis else None
                save_proc(OUT_SHOTS / file_of[nadpis], f"{naz} — {nadpis}", "Řetězec zleva doprava. Palivo a struska jsou popisek hrany.", lab_x, ed_x, keep_hubs=keep, extra_hubs=extra)
        elif trida == "usazene":
            lab_s, ed_s = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_STAVBA)
            save_proc(
                OUT_SHOTS / "T02_strom_usazene_zpracovani_stavba.png",
                f"{naz} — vápno, malta, cement, cihly",
                "Kalcinace, hašení, malta (cyklus zpět na kalcit), cement, sádra, cihly.",
                lab_s,
                ed_s,
            )
            lab_o, ed_o = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_OHEN)
            save_proc(
                OUT_SHOTS / "T02_strom_usazene_zpracovani_ohen.png",
                f"{naz} — sklo, keramika, koks, sůl",
                "Křemenný písek a jíl na sklo a keramiku, uhlí na koks, čištění soli.",
                lab_o,
                ed_o,
                keep_hubs={"vyrobek:koks"},
            )
        elif trida == "premenene":
            lab_s, ed_s = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_STAVBA)
            save_proc(
                OUT_SHOTS / "T02_strom_premenene_zpracovani_stavba.png",
                f"{naz} — vápno a stavba (skarn)",
                "Skarn dává vápno; dál hašení, malta, cement, cihly. cyklus zpět na kalcit.",
                lab_s,
                ed_s,
            )
            lab_o, ed_o = procesy_pro_tridu(doc, trida, only_procesy=USAZENE_OHEN | {"drtit_blok", "drtit_blok_kremen", "drtit_kremen_min"})
            save_proc(
                OUT_SHOTS / "T02_strom_premenene_zpracovani_ohen.png",
                f"{naz} — kámen, sklo, keramika",
                "Drcení kvádru, křemenný písek na sklo a keramiku.",
                lab_o,
                ed_o,
            )
        else:
            lab_p, ed_p = procesy_pro_tridu(doc, trida)
            save_proc(
                OUT_SHOTS / f"T02_strom_{trida}_zpracovani.png",
                f"{naz} — další rozklad surovin",
                "Jeden pruh na vstupní surovinu, zleva doprava k výrobku.",
                lab_p,
                ed_p,
            )

    return paths


# =============================================================================
# Main
# =============================================================================

def main() -> int:
    t01 = load_t01()
    doc, _uzly, _hrany = build_tree(t01)
    chyby = validate(doc)
    doc["statistiky"] = statistiky(doc)
    if chyby:
        print("VALIDACE SELHALA:", file=sys.stderr)
        for c in chyby:
            print(" -", c, file=sys.stderr)
        OUT_JSON.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return 1
    OUT_JSON.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(doc)
    paths = make_images(doc)
    st = doc["statistiky"]
    print("T02 OK")
    print(f"  hornin={st['hornin']} mineralu={st['mineralu']} surovin={st['surovin']} vyrobku={st['vyrobku']} prvku={st['prvku']} procesu={st['procesu']} operaci={st['operaci_unikatnich']}")
    print(f"  uzlu={st['uzlu']} hran={st['hran']} podle_tridy={st['hornin_podle_tridy']}")
    print(f"  json={OUT_JSON}")
    print(f"  md={OUT_MD}")
    for p in paths:
        print(f"  shot={p} ({p.stat().st_size} B)")
    print("  krizeni hran (úsečky se protínají, bez sdíleného vrcholu):")
    total = 0
    for name, n in CROSSINGS:
        print(f"    {name}: {n}")
        total += n
    print(f"  krizeni_celkem={total}")
    if doc.get("cykly_schvalene"):
        print("  schvalene cykly:")
        for c in doc["cykly_schvalene"]:
            print("   ", c)
    return 0


if __name__ == "__main__":
    sys.exit(main())
