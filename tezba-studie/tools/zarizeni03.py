#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""T03 — základní stroje, stavby a zařízení na zpracování surovin.

Spouštění:
    python3 /workspace/willage-ideas/tezba-studie/tools/zarizeni03.py

Sestaví data/zarizeni.json, navrhy/zarizeni.md a shots/T03_zarizeni.png
a zkontroluje, že každá operace i každá hrana stromu T02 má aspoň jedno zařízení.
"""

from __future__ import annotations

import json
import sys
import textwrap
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties, fontManager
from matplotlib.patches import FancyBboxPatch, Rectangle

ROOT = Path(__file__).resolve().parents[1]
STROM_JSON = ROOT / "data" / "strom_rozkladu.json"
OUT_JSON = ROOT / "data" / "zarizeni.json"
OUT_MD = ROOT / "navrhy" / "zarizeni.md"
OUT_SHOT = ROOT / "shots" / "T03_zarizeni.png"
FONT_PATH = Path("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf")
FONT_BOLD = Path("/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf")

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

VEKY = {
    "primitivni": {
        "nazev": "Primitivní",
        "popis": "Pravěk až starověk: ruka, oheň, jednoduchá jáma nebo pec z hlíny a kamene.",
    },
    "stredovek": {
        "nazev": "Středověk",
        "popis": "Voda, měchy, vodní kolo, hamr, sklářská pec, alembik, kovárna.",
    },
    "rane_prumyslove": {
        "nazev": "Raně průmyslové",
        "popis": "Koks, mechanický drtič, cementářská pec, průmyslové loužení. Ne vysoká pec.",
    },
}

TYPY = {
    "nastroj": "nástroj",
    "stroj": "stroj",
    "stavba": "stavba",
    "zarizeni": "zařízení",
}

ENERGIE = {
    "ruka": "ruka",
    "voda": "voda",
    "zvire": "zvíře",
    "ohen": "oheň",
    "drevene_uhli": "dřevěné uhlí",
}

# typ barev na snímku
TYP_BARVA = {
    "nastroj": "#6B4F3A",
    "stroj": "#2C5F8A",
    "stavba": "#8B3A2A",
    "zarizeni": "#2E6B5A",
}

# ---------------------------------------------------------------------------
# Katalog jednotek (zdroj pravdy; skript z něj zapíše JSON).
# operace + procesy pokrývají strom T02. Hamr je ve výčtu, ale T02 nemá
# samostatnou operaci kování lupy — je označen mimo_strom.
# ---------------------------------------------------------------------------

ZARIZENI: list[dict] = [
    {
        "id": "nastroj_tezba",
        "nazev": "Těžební nářadí",
        "typ": "nastroj",
        "operace": ["tezba"],
        "procesy": [],
        "vstupy": ["typ:hornina"],
        "vystupy": [
            "surovina:blok_horniny", "surovina:sterk", "surovina:pisek",
            "surovina:jil", "surovina:hlina", "surovina:uhli", "surovina:sul",
            "surovina:jalovina",
        ],
        "energie": ["ruka"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": None,
        "stavi_se_z": ["vnejsi:drevo", "surovina:blok_horniny", "vyrobek:med", "vyrobek:bronz", "vyrobek:zelezo", "vyrobek:ocel"],
        "ladici_parametry": ["cas", "volba_nastroje"],
        "popis": (
            "Rýč, špičák, kladivo a později kovový krumpáč, kterými se buňka horniny "
            "uvolní. Výchozí výnosy (operace tezba) vznikají tady, ne v peci: základ "
            "je vždy známý (kámen, štěrk, písek, jíl…), ruda a drahokamy potřebují "
            "Mineralogii k určení, ale z buňky padnou. Třída nástroje z T01 (ruka → "
            "kámen → bronz → železo → ocel) určuje, co vůbec jde kopat a jak dlouho. "
            "Energie je ruční práce; trhaviny v T01 jsou volitelná zkratka, ne nutná brána."
        ),
        "zdroje": [10, 11, 12],
    },
    {
        "id": "stul_mineralogie",
        "nazev": "Zkušební stůl",
        "typ": "zarizeni",
        "operace": ["slozeni", "odpovida"],
        "procesy": [
            "med_na_prvek", "zelezo_na_prvek", "cin_na_prvek",
            "koks_uhlik", "kremen_kremik", "vapno_vápnik",
        ],
        "vstupy": ["typ:hornina", "typ:mineral", "typ:vyrobek", "typ:surovina"],
        "vystupy": ["typ:mineral", "typ:surovina", "typ:prvek"],
        "energie": ["ruka"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "mineralogie",
        "stavi_se_z": ["vnejsi:drevo", "surovina:blok_horniny", "vyrobek:sklo", "vyrobek:keramika", "vyrobek:med"],
        "ladici_parametry": ["cas", "typ_zkousky"],
        "popis": (
            "Lupa, vryp, střep, eventualmente slabá kyselina a srovnávací vzorky. "
            "Tady se čte typické minerální složení horniny (operace slozeni) a přiřazuje "
            "se, který minerál po uvolnění odpovídá které surovině nebo který kov je "
            "který prvek (odpovida). Nic se tu netaví; je to poznání, ne pec. "
            "Bez tohoto kroku hráč vidí jen základní výnosy z T01."
        ),
        "zdroje": [7, 36],
    },
    {
        "id": "stoupa",
        "nazev": "Drtič / stoupa",
        "typ": "stroj",
        "operace": ["drtit"],
        "procesy": ["drtit_blok", "drtit_blok_kremen", "struska_sterk"],
        "vstupy": ["surovina:blok_horniny", "vyrobek:struska"],
        "vystupy": ["surovina:sterk", "surovina:prach", "surovina:kremenny_pisek"],
        "energie": ["ruka", "voda", "zvire"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "kamenictvi",
        "stavi_se_z": ["surovina:blok_horniny", "vnejsi:drevo", "vyrobek:zelezo"],
        "ladici_parametry": ["cas", "velikost_zrna", "pomer_vsazky"],
        "popis": (
            "Těžké pěchy, později vodní stoupa: kámen nebo železné baňky padají na kvádr "
            "nebo strusku a drtí je na štěrk, prach a z křemenných hornin i sklářský písek. "
            "Agricola popisuje stoupy u rudních úpraven už v 16. století; ruční palice je "
            "starší. Jemnější mletí nechává mlýn. Poměr frakcí a doba drcení se ladí; "
            "příliš jemný prach je na stavbu horší, na pigment naopak potřeba."
        ),
        "zdroje": [39, 52],
    },
    {
        "id": "mlyn",
        "nazev": "Mlýn",
        "typ": "stroj",
        "operace": ["drtit"],
        "procesy": ["drtit_kremen_min", "pigment_okr", "pigment_malachit"],
        "vstupy": ["mineral:kremen", "mineral:hematit", "mineral:malachit"],
        "vystupy": ["surovina:kremenny_pisek", "vyrobek:pigment_okr", "vyrobek:pigment_malachit"],
        "energie": ["ruka", "voda", "zvire"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "kamenictvi",
        "stavi_se_z": ["surovina:blok_horniny", "vnejsi:drevo", "vyrobek:zelezo", "vyrobek:cihla", "vyrobek:malta"],
        "ladici_parametry": ["cas", "jemnost", "pomer_vsazky"],
        "popis": (
            "Mlýnské kameny, běhoun a ležák, poháněné vodou, zvířetem nebo rukou. "
            "Mele křemen na sklářský písek a železité nebo měděné minerály na pigment "
            "(okru, malachit). Stejný mlýn později mele i slínek na cement. Jemnost "
            "mletí rozhoduje o tavení skla i o krytí barvy; přemletí je ztráta času "
            "a prachu. Stoupa drtí hrubě, mlýn mele."
        ),
        "zdroje": [24, 36, 40, 53],
    },
    {
        "id": "brusna_dilna",
        "nazev": "Brusná dílna",
        "typ": "stavba",
        "operace": ["brousit"],
        "procesy": ["brousit_drahokamy", "brousit_diamant", "brousit_granat"],
        "vstupy": ["surovina:drahokamy", "surovina:diamanty", "surovina:granaty"],
        "vystupy": ["vyrobek:brouseny_kamen", "vyrobek:brouseny_diamant", "vyrobek:brouseny_granat"],
        "energie": ["ruka", "voda"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "kamenictvi",
        "stavi_se_z": ["vnejsi:drevo", "surovina:blok_horniny", "vyrobek:zelezo", "vyrobek:brouseny_granat"],
        "ladici_parametry": ["cas", "zrnitost_brusu", "tlak"],
        "popis": (
            "Kotouče, pískovcové a později kovové disky se zrnem (sám granát slouží "
            "jako brusivo — smyčka katalogu). Brousí a leští drahokamy, diamant a granát; "
            "část hmoty padne jako odpad. Ruční práce, u větších kamenů vodní kolo. "
            "Čas, tlak a posloupnost zrnitosti ladí lesk a riziko praskliny."
        ),
        "zdroje": [51],
    },
    {
        "id": "vapenka",
        "nazev": "Vápenka",
        "typ": "stavba",
        "operace": ["palit"],
        "procesy": ["palit_vapno", "palit_kalcit", "palit_dolomit"],
        "vstupy": ["surovina:vapno", "mineral:kalcit", "mineral:dolomit_min"],
        "vystupy": ["vyrobek:palene_vapno"],
        "energie": ["ohen", "drevene_uhli"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["surovina:blok_horniny", "vyrobek:cihla", "vyrobek:malta", "surovina:jil"],
        "ladici_parametry": ["teplota", "cas", "palivo", "velikost_kusu"],
        "popis": (
            "Šachtová nebo polní pec, ve které se vápenec nebo dolomit pálí na pálené "
            "vápno (CaCO₃ → CaO + CO₂). Historicky stačí žár zhruba 800–950 °C, tedy "
            "méně než na sklo. Palivo je dřevo, dřevěné uhlí nebo později uhlí — síra "
            "z uhlí ale vápno špiní. Nedopal nechá uhličitan, přepal zhorší hašení. "
            "Pec sama se staví z kamene a cihel spojených maltou, kterou tahle pec umožňuje."
        ),
        "zdroje": [13, 14, 41],
    },
    {
        "id": "pec_sadra",
        "nazev": "Sádrová pec",
        "typ": "zarizeni",
        "operace": ["palit"],
        "procesy": ["palit_sadru"],
        "vstupy": ["surovina:sadrovec"],
        "vystupy": ["vyrobek:sadra"],
        "energie": ["ohen"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vyrobek:cihla", "surovina:blok_horniny", "vyrobek:zelezo", "vyrobek:malta"],
        "ladici_parametry": ["teplota", "cas"],
        "popis": (
            "Nízkoteplotní pec nebo kotel, ve kterém sádrovec ztratí část krystalové "
            "vody a stane se sádrou. Teplota je podstatně nižší než u vápna (řádově "
            "150–180 °C). Přepal („mrtvá sádra“) už s vodou dobře netuhne, nedopal "
            "nechá surový kámen. Palivo stačí dřevo, není potřeba dřevěné uhlí."
        ),
        "zdroje": [15],
    },
    {
        "id": "hasici_jama",
        "nazev": "Hasicí jáma",
        "typ": "zarizeni",
        "operace": ["hasit"],
        "procesy": ["hasit_vapno"],
        "vstupy": ["vyrobek:palene_vapno"],
        "vystupy": ["vyrobek:hasene_vapno"],
        "energie": ["ruka"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "zednictvi",
        "stavi_se_z": ["surovina:blok_horniny", "vyrobek:cihla", "vnejsi:drevo", "surovina:pisek"],
        "ladici_parametry": ["pomer_vody", "cas", "teplota"],
        "popis": (
            "Jáma nebo kád, kde se pálené vápno hasí vodou na hašené vápno "
            "(CaO + H₂O → Ca(OH)₂). Reakce je silně exotermní — malá jáma z kamene "
            "a cihel to musí vydržet. Málo vody spálí kaši, moc vody ji zředí. "
            "Čas zrání (i dny až týdny u vápenné kaše) ladí plasticitu malty. "
            "Energie je jen lidská práce a teplo reakce, ne přidaný oheň."
        ),
        "zdroje": [13, 14],
    },
    {
        "id": "dilna_zednicka",
        "nazev": "Zednická dílna / mísírna",
        "typ": "stavba",
        "operace": ["michat"],
        "procesy": ["michat_maltu"],
        "vstupy": ["vyrobek:hasene_vapno", "surovina:pisek"],
        "vystupy": ["vyrobek:malta"],
        "energie": ["ruka"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "zednictvi",
        "stavi_se_z": ["vnejsi:drevo", "surovina:blok_horniny", "vyrobek:cihla", "vyrobek:zelezo"],
        "ladici_parametry": ["pomer_vapno_pisek", "pomer_vody", "cas"],
        "popis": (
            "Koryto, později míchačka, kde se hašené vápno spojuje s pískem na maltu. "
            "Klasický poměr je zhruba jeden díl vápna na dva až tři díly písku; přesné "
            "optimum je ve hře skryté (hypotéza receptů 13:39). Špinavý nebo příliš "
            "jemný písek maltu zhorší. Práce je ruční. Malta odsud jde na stavbu, "
            "kde tvrdne karbonatací."
        ),
        "zdroje": [13, 14],
    },
    {
        "id": "stavba_vapenna",
        "nazev": "Vápenná zeď a omítka",
        "typ": "stavba",
        "operace": ["karbonatace"],
        "procesy": ["karbonatace_malt"],
        "vstupy": ["vyrobek:malta"],
        "vystupy": ["mineral:kalcit", "surovina:pisek"],
        "energie": [],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "zednictvi",
        "stavi_se_z": ["vyrobek:malta", "vyrobek:cihla", "surovina:blok_horniny", "vyrobek:palene_vapno"],
        "ladici_parametry": ["cas", "vlhkost", "tloustka"],
        "popis": (
            "Hotová zeď, klenba nebo omítka z vápenné malty. Není to pec: malta na "
            "vzduchu přijímá CO₂ a vrací se na kalcit (vápenný cyklus, jediný "
            "schválený cyklus ve stromu T02). Tvrdnutí trvá týdny až roky, vlhko "
            "pomáhá, příliš rychlé vyschnutí škodí. Písek v maltě zůstává, kalcit "
            "se teoreticky dá z trosek znovu pálit ve vápence — uzavřená smyčka."
        ),
        "zdroje": [13, 14],
    },
    {
        "id": "cihelna",
        "nazev": "Cihelna",
        "typ": "stavba",
        "operace": ["palit_cihly"],
        "procesy": ["palit_cihly"],
        "vstupy": ["surovina:jil", "surovina:pisek"],
        "vystupy": ["vyrobek:cihla"],
        "energie": ["ohen"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "zednictvi",
        "stavi_se_z": ["surovina:jil", "surovina:hlina", "surovina:blok_horniny", "vyrobek:cihla", "vyrobek:malta"],
        "ladici_parametry": ["teplota", "cas", "pomer_jil_pisek", "cas_suseni"],
        "popis": (
            "Formování jílu s trochou písku, sušení a výpal v polní peci nebo později "
            "v kroužcové peci. Cihly samy pak staví další pece, vápenky i tuto cihelnu "
            "— další smyčka katalogu. Teplota a rovnoměrnost žáru rozhodují o pevnosti "
            "a barvě; nedopal je měkký, přepal slinuje a křiví. Palivo je dřevo, později "
            "uhlí. Sušení před výpalem je stejně důležité jako sám žár."
        ),
        "zdroje": [27],
    },
    {
        "id": "milir",
        "nazev": "Milíř",
        "typ": "zarizeni",
        "operace": ["palit"],
        "procesy": ["uhli_drevene"],
        "vstupy": ["vnejsi:drevo"],
        "vystupy": ["vnejsi:drevene_uhli", "vyrobek:pigment_saze"],
        "energie": ["ohen"],
        "vek": "primitivni",
        "vek_do": "stredovek",
        "dovednost": "uhlistvi",
        "stavi_se_z": ["vnejsi:drevo", "surovina:hlina", "surovina:prach", "surovina:jil"],
        "ladici_parametry": ["cas", "tesnost", "druh_dreva"],
        "popis": (
            "Hromada dřeva zasypaná hlínou a prachem, s řízeným přístupem vzduchu. "
            "Dřevo se suchou destilací mění na dřevěné uhlí, vedlejším produktem jsou "
            "saze. Uhlí je palivo i redukční činidlo dýmačky a kelímku — bez milíře "
            "stojí hutnictví. Příliš vzduchu spálí vsázku na popel, málo vzduchu nechá "
            "syrové dřevo. Pozdější retorta je čistší, ale milíř je základní jednotka."
        ),
        "zdroje": [21],
    },
    {
        "id": "pec_cement",
        "nazev": "Cementářská pec",
        "typ": "stavba",
        "operace": ["palit"],
        "procesy": ["palit_cement"],
        "vstupy": ["surovina:vapno", "surovina:jil"],
        "vystupy": ["vyrobek:cement"],
        "energie": ["ohen", "drevene_uhli"],
        "vek": "rane_prumyslove",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vyrobek:cihla", "surovina:blok_horniny", "vyrobek:zelezo", "vyrobek:malta", "vyrobek:ocel"],
        "ladici_parametry": ["teplota", "cas", "pomer_vapno_jil", "jemnost_mleti"],
        "popis": (
            "Výpal směsi vápence a jílu na slínek a následné mletí (mlýn). Portlandský "
            "cement je podstatně mladší než vápenná malta a chce vyšší žár než vápenka. "
            "Ve stromu je to pozdější výrobek; poměry vsázky a teplota jsou hrubé, "
            "ne moderní rotační pec se všemi přísadami. Palivo je uhlí nebo koks."
        ),
        "zdroje": [22],
    },
    {
        "id": "pec_hrncirska",
        "nazev": "Hrnčířská pec",
        "typ": "stavba",
        "operace": ["palit_keramiku", "tavit"],
        "procesy": ["palit_keramiku", "porcelan", "glazura"],
        "vstupy": [
            "surovina:jil", "surovina:kremenny_pisek", "mineral:zivec_k",
            "vyrobek:palene_vapno", "surovina:ruda_med",
        ],
        "vystupy": ["vyrobek:keramika", "vyrobek:porcelan", "vyrobek:glazura"],
        "energie": ["ohen", "drevene_uhli"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "hrncirstvi",
        "stavi_se_z": ["surovina:jil", "surovina:hlina", "vyrobek:cihla", "surovina:blok_horniny", "vyrobek:malta"],
        "ladici_parametry": ["teplota", "cas", "pomer_vsazky", "atmosfera"],
        "popis": (
            "Komorová nebo jámová pec na výpal nádob, kachlů a později porcelánu "
            "(jíl / kaolin, křemen, živec). Ve stejné dílně se taví i glazura "
            "(křemen, tavidlo, barvicí oxid třeba z mědi). Teplota, atmosféra "
            "(oxidační / redukční) a poměry vsázky ladí barvu, slinutí a praskliny. "
            "Porcelán je pozdější výrobek; kaolin ve stromu ještě není oddělený od jílu."
        ),
        "zdroje": [16, 27, 49],
    },
    {
        "id": "pec_sklarska",
        "nazev": "Sklářská pec",
        "typ": "stavba",
        "operace": ["tavit_sklo"],
        "procesy": ["tavit_sklo"],
        "vstupy": ["surovina:kremenny_pisek", "vnejsi:soda", "vyrobek:palene_vapno"],
        "vystupy": ["vyrobek:sklo"],
        "energie": ["ohen", "drevene_uhli"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "sklarstvi",
        "stavi_se_z": ["vyrobek:cihla", "surovina:blok_horniny", "surovina:jil", "vyrobek:malta", "vyrobek:zelezo"],
        "ladici_parametry": ["teplota", "cas", "pomer_vsazky", "cas_chlazeni"],
        "popis": (
            "Pánvová pec na sodnovápenaté sklo: křemenný písek, soda nebo potaž z popela "
            "a vápno jako stabilizátor. Čistý křemen taje až kolem 1700 °C, tavidlo teplotu "
            "sníží. K peci patří chladicí pec — rychlé chlazení sklo roztrhne. Poměry vsázky, "
            "čistota písku a křivka chlazení jsou hlavní ladění kvality (čirost, bubliny, praskliny)."
        ),
        "zdroje": [16, 17],
    },
    {
        "id": "kelimek",
        "nazev": "Kelímek a slévárna",
        "typ": "zarizeni",
        "operace": ["tavit", "slevat"],
        "procesy": ["tavit_med", "tavit_cin", "slevat_bronz", "olovo_chybi_ruda"],
        "vstupy": [
            "surovina:ruda_med", "surovina:ruda_vzacne", "vnejsi:drevene_uhli",
            "vyrobek:med", "vyrobek:cin", "mezera:galenit",
        ],
        "vystupy": ["vyrobek:med", "vyrobek:cin", "vyrobek:bronz", "vyrobek:olovo", "vyrobek:struska", "vyrobek:lithium_konc"],
        "energie": ["ohen", "drevene_uhli"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "hutnictvi",
        "stavi_se_z": ["vyrobek:keramika", "surovina:jil", "surovina:blok_horniny", "vyrobek:cihla", "vyrobek:zelezo"],
        "ladici_parametry": ["teplota", "cas", "pomer_paliva", "pomer_slitiny"],
        "popis": (
            "Žáruvzdorný kelímek v malé peci nebo výhni: tavení mědi (zhruba 1100–1200 °C) "
            "a cínu s dřevěným uhlím jako palivem i redukcí, pak slévání bronzu (typicky "
            "okolo 5–10 % cínu). Sem patří i olovo, až bude ve hře galenit (teď mezera). "
            "Železo se tu netaví — na to je dýmačka. Ladí se teplota, čas, podíl uhlí a "
            "poměr slitiny; výtěžek kovu ve stromu je herní, ne stechiometrie."
        ),
        "zdroje": [18, 19, 48],
    },
    {
        "id": "dymacka",
        "nazev": "Dmýchací pec / výheň (dýmačka)",
        "typ": "stavba",
        "operace": ["tavit"],
        "procesy": ["tavit_zelezo", "tavit_zelezo_koks", "tavit_fe_ti"],
        "vstupy": ["surovina:ruda_zelezo", "surovina:ruda_fe_ti", "vnejsi:drevene_uhli", "vyrobek:koks"],
        "vystupy": ["vyrobek:zelezo", "vyrobek:struska", "vyrobek:titan_konc"],
        "energie": ["ruka", "voda", "drevene_uhli", "ohen"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "hutnictvi",
        "stavi_se_z": ["surovina:jil", "surovina:hlina", "surovina:blok_horniny", "vyrobek:cihla", "vyrobek:zelezo"],
        "ladici_parametry": ["teplota", "cas", "pomer_ruda_palivo", "intenzita_dmechu"],
        "popis": (
            "Nízká šachtová pec (dýmačka): železná ruda a dřevěné uhlí, vzduch měchy "
            "(ruka nebo vodní kolo). Nevzniká tekuté surové železo jako ve vysoké peci, "
            "ale lupa kovu a struska, kterou je potřeba dokovat na hamru. Pozdější cesta "
            "dává koks místo uhlí (raně průmyslové), pořád ale ne blast furnace. "
            "Titanomagnetit nechá část titanu v koncentrátu. Ladí se dmych, poměr vsázky a čas."
        ),
        "zdroje": [20, 21, 36, 52],
    },
    {
        "id": "hamr",
        "nazev": "Hamr",
        "typ": "stroj",
        "operace": [],
        "procesy": [],
        "vstupy": ["vyrobek:zelezo"],
        "vystupy": ["vyrobek:zelezo"],
        "energie": ["voda", "ruka"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "kovarstvi",
        "stavi_se_z": ["vnejsi:drevo", "vyrobek:zelezo", "surovina:blok_horniny", "vyrobek:cihla", "vyrobek:malta"],
        "ladici_parametry": ["cas", "teplota", "intenzita_uderu"],
        "mimo_strom": (
            "Kování lupy z dýmačky na použitelnou tyč; ve stromu T02 není samostatná "
            "operace, navazuje na tavit železa."
        ),
        "popis": (
            "Těžké vodní kladivo (hamr) nebo ruční perlík, kterým se z lupy dýmačky "
            "vykove struska a spojí zrna železa do tyče nebo prutu. Bez tohoto kroku "
            "není „železo (kov)“ ze stromu ještě použitelný výrobek. Hamr stojí u toku, "
            "pohání ho vodní kolo; výheň vedle drží žár. Ve stromu T02 není samostatná "
            "operace kování — proto je hamr v seznamu, ale validační skript ho nepočítá "
            "jako pokrytí žádné hrany."
        ),
        "zdroje": [20, 42, 52],
    },
    {
        "id": "kovarna",
        "nazev": "Kovárna",
        "typ": "stavba",
        "operace": ["cementovat"],
        "procesy": ["cementovat_ocel", "cementovat_ocel_drevo"],
        "vstupy": ["vyrobek:zelezo", "vyrobek:koks", "vnejsi:drevene_uhli"],
        "vystupy": ["vyrobek:ocel"],
        "energie": ["ohen", "drevene_uhli", "ruka"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "kovarstvi",
        "stavi_se_z": ["surovina:blok_horniny", "vyrobek:cihla", "vyrobek:malta", "vyrobek:zelezo", "vnejsi:drevo"],
        "ladici_parametry": ["teplota", "cas", "zdroj_uhliku", "kaleni"],
        "popis": (
            "Výheň, kovadliny a cementační skříň: železo se dlouho žíhá v uhlíkaté "
            "sypké vsázce (dřevěné uhlí nebo koks) a povrch se nauhličí na ocel "
            "(cementace). Navazuje kalení a popouštění. Čas se měří ve dnech, ne v "
            "minutách; teplota a zdroj uhlíku ladí hloubku cementace a riziko zkřehnutí. "
            "Bez dýmačky a hamru nemá kovárna co zpracovat."
        ),
        "zdroje": [28, 50],
    },
    {
        "id": "splav",
        "nazev": "Ryžovací splav",
        "typ": "zarizeni",
        "operace": ["ryzovat"],
        "procesy": ["ryzovat_zlato"],
        "vstupy": ["surovina:ruda_zlato"],
        "vystupy": ["prvek:Au"],
        "energie": ["voda", "ruka"],
        "vek": "primitivni",
        "vek_do": "rane_prumyslove",
        "dovednost": "hutnictvi",
        "stavi_se_z": ["vnejsi:drevo", "surovina:blok_horniny", "vyrobek:zelezo"],
        "ladici_parametry": ["prutok_vody", "cas", "sklon", "velikost_zrna"],
        "popis": (
            "Dřevěný žlab s příčkami, případně jen pánvička: proud vody oddělí těžké "
            "ryzí zlato od písku. Energie je voda a ruka, žádný oheň. Podíl kovu ve "
            "stromu je herní abstrakce; ve skutečnosti se zlato počítá v g/t. "
            "Ladí se sklon, průtok a zrnitost vsázky — moc vody odnese i zlato, málo "
            "vody nevyplaví jalovinu. Navazující loužení je jiná, pozdější cesta."
        ),
        "zdroje": [37, 44],
    },
    {
        "id": "louzici_kade",
        "nazev": "Loužicí kádě",
        "typ": "zarizeni",
        "operace": ["louzit"],
        "procesy": ["louzit_med", "louzit_zlato", "louzit_lithium", "titan_na_prvek"],
        "vstupy": [
            "surovina:ruda_med", "surovina:ruda_zlato",
            "vyrobek:lithium_konc", "vyrobek:titan_konc",
        ],
        "vystupy": ["vyrobek:med", "prvek:Au", "prvek:Li", "prvek:Ta", "prvek:Ti", "prvek:Fe"],
        "energie": ["ruka", "ohen"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vnejsi:drevo", "vyrobek:keramika", "vyrobek:sklo", "vyrobek:med", "vyrobek:cihla"],
        "ladici_parametry": ["cas", "teplota", "koncentrace", "pomer_louzidla"],
        "popis": (
            "Kádě a koryta, ve kterých se kov louží do roztoku a pak sráží: oxidická "
            "měď, zlato (pozdější cesta vedle ryžování), lithium a tantal z pegmatitového "
            "koncentrátu i titan z titanomagnetitu. Středověká alchymie to zkouší v malém; "
            "průmyslové loužení je raně průmyslové. Luhidlo, čas, teplota a koncentrace "
            "jsou laditelné; špatný poměr nechá kov v jalovině nebo sežere kád."
        ),
        "zdroje": [18, 37, 38, 45],
    },
    {
        "id": "alembik",
        "nazev": "Destilační přístroj / alembik",
        "typ": "zarizeni",
        "operace": ["destilovat"],
        "procesy": [],
        "vstupy": ["mezera:rumelka", "surovina:sul"],
        "vystupy": ["vyrobek:rtut", "prvek:Hg", "vyrobek:sul_cista"],
        "energie": ["ohen"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vyrobek:med", "vyrobek:keramika", "vyrobek:sklo", "surovina:jil"],
        "ladici_parametry": ["teplota", "cas"],
        "popis": (
            "Alembik: kotlík, helma a chladič. Slouží k destilaci par — u rumělky po "
            "pražení ke kondenzaci rtuti, obecně k čištění kapalin. Operace destilovat "
            "ve stromu je u soli použitá v širším smyslu (čištění); vlastní sůl vaří "
            "solivar, alembik ho jen zastřešuje jako laboratorní obdobu odparu. "
            "Staví se z keramiky, později z mědi a skla. Teplota a čas ladí, co přejde do jímky."
        ),
        "zdroje": [25, 43],
    },
    {
        "id": "solivar",
        "nazev": "Solivar",
        "typ": "stavba",
        "operace": ["destilovat"],
        "procesy": ["cistit_sul"],
        "vstupy": ["surovina:sul"],
        "vystupy": ["vyrobek:sul_cista"],
        "energie": ["ohen"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vyrobek:cihla", "vyrobek:zelezo", "vnejsi:drevo", "vyrobek:malta", "surovina:blok_horniny"],
        "ladici_parametry": ["teplota", "cas", "krystalizace"],
        "popis": (
            "Varna solanky: kamenná sůl se rozpustí, nečistoty se usadí a voda se "
            "odpaří v pánvích nad ohněm (nebo na slunci v teplejším kraji). Ve stromu "
            "je to operace destilovat v širším smyslu čištění, ne pravá destilace par. "
            "Teplota, čas odparu a řízená krystalizace ladí čistotu. Palivo je dřevo; "
            "pánve jsou železné, dům z cihel a dřeva."
        ),
        "zdroje": [26, 47],
    },
    {
        "id": "prazirna",
        "nazev": "Pražírna",
        "typ": "stavba",
        "operace": ["prazit"],
        "procesy": ["rtut_chybi_rumelka"],
        "vstupy": ["mezera:rumelka"],
        "vystupy": ["vyrobek:rtut", "prvek:Hg"],
        "energie": ["ohen"],
        "vek": "stredovek",
        "vek_do": "rane_prumyslove",
        "dovednost": "chemie",
        "stavi_se_z": ["vyrobek:cihla", "surovina:blok_horniny", "vyrobek:malta", "vyrobek:keramika"],
        "ladici_parametry": ["teplota", "cas", "pristup_vzduchu"],
        "popis": (
            "Pec na pražení rud za přístupu vzduchu. Ve stromu je konkrétně pražení "
            "rumělky (HgS) a jímání par rtuti — v tabulce hornin rumělka zatím chybí, "
            "jde o mezeru z T01. Historicky se stejně praží i sulfidy před tavením. "
            "Teplota, čas a vzduch rozhodují, jestli síra odejde a kov se neuteče. "
            "Jímání par patří k alembiku; obě jednotky se doplňují."
        ),
        "zdroje": [25, 46],
    },
    {
        "id": "koksovna",
        "nazev": "Koksovna",
        "typ": "stavba",
        "operace": ["koksovat"],
        "procesy": ["koksovat"],
        "vstupy": ["surovina:uhli"],
        "vystupy": ["vyrobek:koks", "vyrobek:pigment_saze"],
        "energie": ["ohen"],
        "vek": "rane_prumyslove",
        "vek_do": "rane_prumyslove",
        "dovednost": "hutnictvi",
        "stavi_se_z": ["vyrobek:cihla", "surovina:blok_horniny", "vyrobek:zelezo", "vyrobek:malta", "vyrobek:ocel"],
        "ladici_parametry": ["teplota", "cas", "tesnost"],
        "popis": (
            "Retorta nebo komora, ve které se černé uhlí zahřívá bez vzduchu na koks "
            "a saze. Analogie milíře, ale surovina je uhlí, ne dřevo, a jednotka je "
            "raně průmyslová. Koks pak živí pozdější cestu dýmačky a cementaci oceli. "
            "Hnědé uhlí ve stromu větev na koks nemá. Tesnost a čas ladí pevnost koksu; "
            "vzduch vsázku spálí."
        ),
        "zdroje": [21],
    },
]


def typ_label(typ: str) -> str:
    return TYPY.get(typ, typ)


def vek_label(vek: str) -> str:
    return VEKY[vek]["nazev"] if vek in VEKY else vek


def energie_label(items: list[str]) -> str:
    if not items:
        return "bez přidané energie (vzduch)"
    return ", ".join(ENERGIE.get(e, e) for e in items)


def load_strom() -> dict:
    if not STROM_JSON.exists():
        raise SystemExit(f"chybí strom T02: {STROM_JSON}")
    return json.loads(STROM_JSON.read_text(encoding="utf-8"))


def node_ids(strom: dict) -> set[str]:
    return {u["id"] for u in strom["uzly"]}


def known_typy(strom: dict) -> set[str]:
    return {u["typ"] for u in strom["uzly"]} | {"hornina", "mineral", "surovina", "vyrobek", "prvek", "vnejsi", "mezera"}


def ref_ok(ref: str, ids: set[str], typy: set[str]) -> bool:
    if ref in ids:
        return True
    if ref.startswith("typ:"):
        return ref.split(":", 1)[1] in typy
    return False


def validate(strom: dict, devices: list[dict]) -> list[str]:
    chyby: list[str] = []
    ids = node_ids(strom)
    typy = known_typy(strom)
    ops_strom = set(strom["operace"].keys())
    proc_by_id = {p["id"]: p for p in strom["procesy"]}
    dovednosti = set(strom["dovednosti"].keys())

    seen_ids: set[str] = set()
    ops_covered: set[str] = set()
    proc_covered: set[str] = set()
    op_to_dev: dict[str, list[str]] = defaultdict(list)
    proc_to_dev: dict[str, list[str]] = defaultdict(list)

    for d in devices:
        did = d["id"]
        if did in seen_ids:
            chyby.append(f"duplicitní id zařízení: {did}")
        seen_ids.add(did)
        if d["typ"] not in TYPY:
            chyby.append(f"{did}: neznámý typ {d['typ']}")
        if d["vek"] not in VEKY:
            chyby.append(f"{did}: neznámý věk {d['vek']}")
        if d.get("vek_do") and d["vek_do"] not in VEKY:
            chyby.append(f"{did}: neznámý vek_do {d['vek_do']}")
        for e in d.get("energie") or []:
            if e not in ENERGIE:
                chyby.append(f"{did}: neznámá energie {e}")
        skill = d.get("dovednost")
        if skill and skill not in dovednosti:
            chyby.append(f"{did}: neznámá dovednost {skill}")
        for op in d.get("operace") or []:
            if op not in ops_strom:
                chyby.append(f"{did}: operace {op} není ve stromu")
            else:
                ops_covered.add(op)
                op_to_dev[op].append(did)
        for pid in d.get("procesy") or []:
            if pid not in proc_by_id:
                chyby.append(f"{did}: proces {pid} není ve stromu")
            else:
                proc_covered.add(pid)
                proc_to_dev[pid].append(did)
                pop = proc_by_id[pid]["operace"]
                if pop not in (d.get("operace") or []) and not d.get("mimo_strom"):
                    chyby.append(f"{did}: proces {pid} má operaci {pop}, zařízení ji nemá v operace")
        for ref in (d.get("vstupy") or []) + (d.get("vystupy") or []) + (d.get("stavi_se_z") or []):
            if not ref_ok(ref, ids, typy):
                chyby.append(f"{did}: odkaz {ref} není uzel stromu ani typ:*")
        if not d.get("popis"):
            chyby.append(f"{did}: chybí popis")
        if not d.get("stavi_se_z"):
            chyby.append(f"{did}: chybí stavi_se_z (smyčka katalogu)")
        if not d.get("ladici_parametry"):
            chyby.append(f"{did}: chybí ladici_parametry")

    # každá operace stromu
    missing_ops = sorted(ops_strom - ops_covered)
    if missing_ops:
        chyby.append("operace bez zařízení: " + ", ".join(missing_ops))

    # každá hrana
    uncovered_edges = []
    for h in strom["hrany"]:
        op = h["operace"]
        if op not in ops_covered:
            uncovered_edges.append(h.get("id", f"{h['od']}->{h['do']}"))
    if uncovered_edges:
        chyby.append(f"hrany bez zařízení ({len(uncovered_edges)}): " + ", ".join(uncovered_edges[:12]))

    # každý proces (kromě těch, které by byly čistě mimo — tady chceme všechny)
    missing_proc = sorted(set(proc_by_id) - proc_covered)
    if missing_proc:
        chyby.append("procesy bez zařízení: " + ", ".join(missing_proc))

    return chyby


def coverage_report(strom: dict, devices: list[dict]) -> dict:
    op_to_dev: dict[str, list[str]] = defaultdict(list)
    for d in devices:
        for op in d.get("operace") or []:
            op_to_dev[op].append(d["id"])
    hran_podle_op: dict[str, int] = defaultdict(int)
    for h in strom["hrany"]:
        hran_podle_op[h["operace"]] += 1
    return {
        "zarizeni": len(devices),
        "s_operaci": sum(1 for d in devices if d.get("operace")),
        "mimo_strom": [d["id"] for d in devices if d.get("mimo_strom")],
        "operace_pokryte": {op: {"hrany": hran_podle_op[op], "zarizeni": op_to_dev[op]} for op in strom["operace"]},
        "hran_celkem": len(strom["hrany"]),
        "hran_pokrytych": sum(1 for h in strom["hrany"] if h["operace"] in op_to_dev),
    }


def build_doc(strom: dict, devices: list[dict]) -> dict:
    nazvy = {u["id"]: u.get("nazev", u["id"]) for u in strom["uzly"]}
    return {
        "_popis": "T03 základní stroje, stavby a zařízení na zpracování (operace stromu T02).",
        "version": 1,
        "status": "navrh",
        "datum": "2026-11-19",
        "studie": "tezba-studie",
        "zaznam": "T03",
        "zdroje": sorted({z for d in devices for z in d.get("zdroje") or []}),
        "veky": VEKY,
        "typy": TYPY,
        "energie": ENERGIE,
        "zarizeni": devices,
        "pokryti": coverage_report(strom, devices),
        "nazvy_uzlu": {k: nazvy[k] for k in sorted(nazvy) if not k.startswith("hornina:")},
    }


def labels_of(refs: list[str], nazvy: dict[str, str]) -> str:
    out = []
    for r in refs:
        if r.startswith("typ:"):
            typ = r.split(":", 1)[1]
            out.append({
                "hornina": "libovolná hornina",
                "mineral": "libovolný minerál",
                "surovina": "libovolná surovina",
                "vyrobek": "libovolný výrobek",
                "prvek": "libovolný prvek",
            }.get(typ, "libovolný " + typ))
        else:
            out.append(nazvy.get(r, r.split(":", 1)[-1].replace("_", " ")))
    return ", ".join(out)


def write_markdown(strom: dict, devices: list[dict]) -> None:
    nazvy = {u["id"]: u.get("nazev", u["id"]) for u in strom["uzly"]}
    op_cs = strom["operace"]
    skill_cs = strom["dovednosti"]
    cov = coverage_report(strom, devices)
    a: list[str] = []
    a.append("# Základní stroje, stavby a zařízení na zpracování")
    a.append("")
    a.append("Stav: **návrh** (T03, Jan 19. 11. 2026 14:49). Čeká na Jana. Herní kód se nemění.")
    a.append("")
    a.append(
        "Navazuje na strom operací v [strom-hornin.md](strom-hornin.md) (T02) a na "
        "výrobní jednotky zmíněné v [katalog-materialu.md](katalog-materialu.md) (T01). "
        "Zdroje jsou značky [n] podle `ZDROJE.md` této studie."
    )
    a.append("")
    a.append(
        "Účel: ke každé operaci stromu přiřadit aspoň jednu reálnou jednotku — nástroj, "
        "stroj, stavbu nebo zařízení — a uzavřít smyčku katalogu (jednotka se staví "
        "z materiálů, které tyhle jednotky samy vyrábějí). Koupitelný recept (hypotéza 13:39) "
        "se ladí právě tady: teplota, čas, poměry."
    )
    a.append("")
    a.append("## Pokrytí stromu")
    a.append("")
    a.append(
        f"Ve stromu je **{len(strom['operace'])} operací** a **{cov['hran_celkem']} hran**; "
        f"pokrytých hran je **{cov['hran_pokrytych']}**. Zařízení je **{cov['zarizeni']}** "
        f"(z toho {len(cov['mimo_strom'])} mimo strom: {', '.join(cov['mimo_strom']) or '—'})."
    )
    a.append("")
    a.append("| operace | hrany | zařízení |")
    a.append("|---|---:|---|")
    for op, meta in strom["operace"].items():
        rec = cov["operace_pokryte"][op]
        devs = ", ".join("`" + i + "`" for i in rec["zarizeni"]) or "—"
        a.append(f"| `{op}` ({meta}) | {rec['hrany']} | {devs} |")
    a.append("")
    a.append("## Podle věku")
    a.append("")
    by_vek: dict[str, list[dict]] = defaultdict(list)
    for d in devices:
        by_vek[d["vek"]].append(d)
    for vek in VEKY:
        a.append(f"### {VEKY[vek]['nazev']}")
        a.append("")
        a.append(VEKY[vek]["popis"])
        a.append("")
        for d in by_vek[vek]:
            do = f" (až {vek_label(d['vek_do']).lower()})" if d.get("vek_do") and d["vek_do"] != d["vek"] else ""
            skill = skill_cs[d["dovednost"]] if d.get("dovednost") else "bez zvláštní dovednosti (běžná práce / třída nástroje T01)"
            ops = ", ".join(f"`{o}`" for o in (d.get("operace") or [])) or "— (není ve stromu T02)"
            procs = ", ".join(f"`{p}`" for p in (d.get("procesy") or [])) or "—"
            src = "".join(f"[{n}]" for n in d.get("zdroje") or [])
            a.append(f"#### {d['nazev']}")
            a.append("")
            a.append(f"- **Typ:** {typ_label(d['typ'])}. **Věk:** {vek_label(d['vek']).lower()}{do}.")
            a.append(f"- **Energie:** {energie_label(d.get('energie') or [])}.")
            a.append(f"- **Dovednost:** {skill}.")
            a.append(f"- **Operace stromu:** {ops}.")
            a.append(f"- **Procesy:** {procs}.")
            a.append(f"- **Vstupy:** {labels_of(d.get('vstupy') or [], nazvy) or '—'}.")
            a.append(f"- **Výstupy:** {labels_of(d.get('vystupy') or [], nazvy) or '—'}.")
            a.append(f"- **Staví se z:** {labels_of(d.get('stavi_se_z') or [], nazvy)}.")
            a.append(f"- **Ladění receptu:** {', '.join(d.get('ladici_parametry') or [])}.")
            a.append(f"- **Jak:** {d['popis']} {src}")
            if d.get("mimo_strom"):
                a.append(f"- **Mimo strom:** {d['mimo_strom']}")
            a.append("")
    a.append("## Smyčka katalogu")
    a.append("")
    a.append(
        "Vápenka, cihelna a zednická dílna dávají cihlu, maltu a kámen, z nichž se staví "
        "další pece. Milíř dává dřevěné uhlí pro kelímek i dýmačku. Dýmačka a hamr dají "
        "železo na nástroje, hamr i kování pěchů stoupy. Brusná dílna používá broušený granát "
        "jako brusivo. To je záměr: jednotka není zvenku, patří do stejného stromu materiálů."
    )
    a.append("")
    a.append("## Mezery a otevřené otázky")
    a.append("")
    a.append("- Hamr ve stromu T02 nemá vlastní operaci (kování lupy). Má se doplnit, nebo stačí jako navazující krok dýmačky?")
    a.append("- Má dýmačka s koksem zůstat dýmačkou, nebo později přejít na vysokou pec (teď mimo rozsah)?")
    a.append("- Solivar používá operaci `destilovat` v širším smyslu čištění; oddělit odpar od pravé destilace?")
    a.append("- Které jednotky jsou ve vesnici od začátku (stoupa, milíř, vápenka, cihelna) a které až s receptem / věkem?")
    a.append("- Kapacita, počet obsluhy a herní čas jednotek nejsou v tomto záznamu (jen laditelné parametry receptu).")
    a.append("")
    OUT_MD.write_text("\n".join(a) + "\n", encoding="utf-8")


def wrap(text: str, width: int) -> list[str]:
    return textwrap.wrap(text, width=width, break_long_words=False, break_on_hyphens=True) or [""]


def draw_image(strom: dict, devices: list[dict]) -> None:
    """Svislý plakát: tři věky, v každém karty zařízení a co vyrábějí. Čitelné na telefonu."""
    nazvy = {u["id"]: u.get("nazev", u["id"]) for u in strom["uzly"]}
    by_vek: dict[str, list[dict]] = defaultdict(list)
    for d in devices:
        by_vek[d["vek"]].append(d)

    # layout v palcích; úzký formát na telefon (2 sloupce karet)
    col_w = 4.55
    left_m = 0.28
    right_m = 0.28
    fig_w = left_m + right_m + 2 * col_w + 0.18
    header_h = 1.55
    section_h = 0.72
    # výška karty podle počtu řádků popisku výstupů
    def card_lines(d: dict) -> int:
        outs = labels_of(d.get("vystupy") or [], nazvy)
        title = 1
        sub = 1
        prod = max(1, len(wrap("→ " + outs, 42)))
        return title + sub + prod

    def section_height(devs: list[dict]) -> float:
        rows = (len(devs) + 1) // 2
        # projít po dvojicích, výška řádku = max karet
        h = 0.0
        for i in range(rows):
            pair = devs[i * 2 : i * 2 + 2]
            lines = max(card_lines(d) for d in pair)
            h += 0.28 + lines * 0.22 + 0.16  # padding + text + gap
        return section_h + h + 0.10

    heights = [section_height(by_vek[v]) for v in VEKY]
    footer_h = 0.85
    fig_h = header_h + sum(heights) + footer_h

    fig, ax = plt.subplots(figsize=(fig_w, fig_h), dpi=180)
    ax.set_xlim(0, fig_w)
    ax.set_ylim(0, fig_h)
    ax.axis("off")
    fig.patch.set_facecolor("#F7F4EE")
    ax.set_facecolor("#F7F4EE")

    # titulek, podtitul, legenda — každý na vlastním řádku, bez překryvu
    ax.text(fig_w / 2, fig_h - 0.16, "Zařízení na zpracování surovin", ha="center", va="top",
            fontsize=18, fontproperties=FONTB, color="#1A1A1A")
    ax.text(fig_w / 2, fig_h - 0.52, "T03  ·  podle věku  ·  co vyrábějí  ·  strom T02",
            ha="center", va="top", fontsize=10, fontproperties=FONT, color="#333")

    legend_items = list(TYPY.items())
    box_w = 1.35
    total_leg = len(legend_items) * box_w
    lx = (fig_w - total_leg) / 2
    ly = fig_h - 1.22
    for typ, lab in legend_items:
        ax.add_patch(FancyBboxPatch((lx, ly), 0.20, 0.16,
                                    boxstyle="round,pad=0.02,rounding_size=0.04",
                                    facecolor=TYP_BARVA[typ], edgecolor="none", zorder=3))
        ax.text(lx + 0.28, ly + 0.08, lab, ha="left", va="center", fontsize=9,
                fontproperties=FONT, color="#222")
        lx += box_w

    y_cursor = fig_h - header_h
    vek_barva_bg = {
        "primitivni": "#EFE4D4",
        "stredovek": "#DDE6EF",
        "rane_prumyslove": "#E4E4E0",
    }
    vek_barva_tx = {
        "primitivni": "#6B4F3A",
        "stredovek": "#2C5F8A",
        "rane_prumyslove": "#333333",
    }

    for vek, h_sec in zip(VEKY, heights):
        y0 = y_cursor - h_sec
        ax.add_patch(Rectangle((0.12, y0 + 0.04), fig_w - 0.24, h_sec - 0.04,
                               facecolor=vek_barva_bg[vek], edgecolor="none", zorder=0))
        ax.text(0.28, y_cursor - 0.08, VEKY[vek]["nazev"].upper(),
                ha="left", va="top", fontsize=13, fontproperties=FONTB, color=vek_barva_tx[vek])
        ax.text(0.28, y_cursor - 0.36, VEKY[vek]["popis"],
                ha="left", va="top", fontsize=8, fontproperties=FONT, color="#444")

        devs = by_vek[vek]
        y_row = y_cursor - section_h
        for i in range(0, len(devs), 2):
            pair = devs[i:i + 2]
            lines = max(card_lines(d) for d in pair)
            card_h = 0.28 + lines * 0.22
            for j, d in enumerate(pair):
                x = left_m + j * (col_w + 0.18)
                yb = y_row - card_h
                color = TYP_BARVA[d["typ"]]
                ax.add_patch(FancyBboxPatch(
                    (x, yb), col_w, card_h,
                    boxstyle="round,pad=0.03,rounding_size=0.08",
                    facecolor="#FFFcf7", edgecolor=color, linewidth=1.6, zorder=2,
                ))
                # pruh typu vlevo
                ax.add_patch(Rectangle((x, yb), 0.10, card_h, facecolor=color, edgecolor="none", zorder=3))
                ty = yb + card_h - 0.14
                ax.text(x + 0.22, ty, d["nazev"], ha="left", va="center",
                        fontsize=11, fontproperties=FONTB, color="#111", zorder=4)
                typ_e = f"{typ_label(d['typ'])}  ·  {energie_label(d.get('energie') or [])}"
                ax.text(x + 0.22, ty - 0.22, typ_e, ha="left", va="center",
                        fontsize=8, fontproperties=FONT, color="#444", zorder=4)
                outs = labels_of(d.get("vystupy") or [], nazvy)
                prod_lines = wrap("→  " + outs, 42)
                py = ty - 0.44
                for ln in prod_lines:
                    ax.text(x + 0.22, py, ln, ha="left", va="center",
                            fontsize=8.5, fontproperties=FONT, color="#1A1A1A", zorder=4)
                    py -= 0.20
            y_row = y_row - card_h - 0.16
        y_cursor = y0

    ax.text(
        fig_w / 2, 0.42,
        "T03  ·  každá operace stromu T02 má aspoň jedno zařízení  ·  hamr kuje lupu (mimo strom)  ·  hypotéza, čeká na Jana",
        ha="center", va="center", fontsize=7.5, fontproperties=FONT, color="#555",
    )
    ax.text(
        fig_w / 2, 0.20,
        "Zdroje [13]–[28], [36]–[53] v ZDROJE.md  ·  energie: ruka, voda, zvíře, oheň, dřevěné uhlí",
        ha="center", va="center", fontsize=7.5, fontproperties=FONT, color="#555",
    )
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
    OUT_SHOT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_SHOT, dpi=180, facecolor=fig.get_facecolor())
    plt.close(fig)


def main() -> int:
    strom = load_strom()
    devices = ZARIZENI
    chyby = validate(strom, devices)
    if chyby:
        print("VALIDACE SELHALA:", file=sys.stderr)
        for c in chyby:
            print(" -", c, file=sys.stderr)
        return 1
    doc = build_doc(strom, devices)
    OUT_JSON.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(strom, devices)
    draw_image(strom, devices)
    cov = doc["pokryti"]
    print("T03 OK")
    print(f"  zarizeni={cov['zarizeni']} mimo_strom={cov['mimo_strom']}")
    print(f"  operaci={len(strom['operace'])} hran={cov['hran_celkem']} pokrytych={cov['hran_pokrytych']}")
    print(f"  procesu={len(strom['procesy'])}")
    print(f"  json={OUT_JSON}")
    print(f"  md={OUT_MD}")
    print(f"  shot={OUT_SHOT} ({OUT_SHOT.stat().st_size} B)")
    for op, rec in cov["operace_pokryte"].items():
        print(f"  op {op}: hrany={rec['hrany']} dev={','.join(rec['zarizeni'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
