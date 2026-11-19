# Deník – tezba-studie (těžba a rozklad hornin)

Deník má tři bloky: **A. Použité směry**, **B. Zamítnuté směry** a **C. Návrhy optimalizací**.
Každá položka obsahuje: **Směr** · **Zlepšení** · **Komplikace** · případně **Rozhodnutí** / **Další krok** a datum.
Stav u použitých směrů: ✅ rozhodnuto Janem · 🧪 ve zkoušce (zatím bez rozhodnutí) · 💡 hypotéza.
Zdroje se uvádějí jen jako značky [n] podle `ZDROJE.md` této studie.
Číslování záznamů: T01, T02, … (T01 = dříve E65 v blueprint-studii).

Skupiny: 1 Vlastnosti a těžba · 2 Zpracování, znalosti a recepty

---

# A. Použité směry

## 1 Vlastnosti a těžba

### ✅ Výnosy hornin: seznam surovin a podíly podle vrstvy blueprintu (2026-11-19 13:23, rozhodnutí Jana)
- **Směr:** každá hornina má seznam získatelných surovin (i více druhů). Při definici vrstev blueprintu může blok přepsat procenta toho, co z horniny po zpracování vypadne. Součet podílů je 100 %. Smí jen suroviny povolené u té horniny.
- **Vztah k 17:53:** kopání dál dává 1 buňku materiálu + šanci na nález. Přepis podílů se týká **zpracování** té buňky, ne změny souhrnu MaterialId v bloku.
- **Další krok:** tvar dat, validace a napojení na WVB1 jsou v návrhu T01. Jan rozhodne o dvoukroku (kopání, pak zpracování) vs rozkladu hned při kopání.

### ✅ Po identifikaci zůstanou obě jména (2026-11-19 13:31, rozhodnutí Jana)
- **Směr:** až postava surovinu pozná, zůstane vlastní název, který jí dal hráč, i skutečný název. Vlastní název může hráč sám smazat.
- **Další krok:** platí pro model znalostí v T01 (úroveň „identifikovaný“). Varianty pojmenování se už nenavrhují.

### 💡 Hypotéza: Mineralogie, řetězce zpracování a koupitelné recepty (2026-11-19 13:27–13:39, Jan)
- 13:27: zpracování rozloží horninu v poměrech bloku. Mineralogie poznává, co to je. Zlepšení dovednosti buď odemkne další třídu hornin, nebo dá body na konkrétní materiál. Neznámé suroviny stejně padají (jako „neznámý minerál“ se znaky barva / tvrdost / hustota) a jdou zkoušet.
- 13:33: krystaly mají kvalitu. Lze je brousit, drtit nebo dál zpracovat. Některé suroviny lze destilovat a rozložit; to odemyká jinou dovednost (chemie / alchymie).
- 13:36: katalog běžných výrobků z těchto surovin (sklo, vápno, malta, kovy, …). Příklad: drcený křemen → sklo.
- 13:39: popisy v katalogu jsou základ koupitelných receptů. Koupený recept řekne co a jak, ale dá jen průměrnou kvalitu. Ve výrobní jednotce (pec, dílna, huť) lze recept ladit (poměry, teplota, čas, přísady, čistota vstupů) a kvalitu výrazně zlepšit.
- **Další krok:** rozepsáno v `navrhy/horniny-vlastnosti-tezba.md` a `navrhy/katalog-materialu.md`. Čeká na rozhodnutí.

### 🧪 T01 (dříve E65): vlastnosti a těžba hornin, katalog výrobků, jen návrh (2026-11-19 13:43, přesun 13:55 · `data/horniny_tezba_navrh.json`, `navrhy/horniny-vlastnosti-tezba.md`, `navrhy/katalog-materialu.md`, shot `65_horniny_tezba.png`)
- **Směr:** Jan chtěl jít do hornin, nejdřív vlastnosti a těžbu (tvrdost, výnos, nástroje). Navazuje na rozhodnutí 13:23 a 13:31 a na hypotézy 13:27–13:39. Sdílené vodní tabulky se nemění. Do git se z této studie commituje zvlášť, až to Jan řekne.
- **Zlepšení:** je zapsané, co už existuje (pořadí 0–63, load/cantilever, rarita-v2, výnos 17:53, hostitelé minerálů, WVB1). Nová tabulka má typické Mohs, UCS, hustotu, CAI, třídu nástroje, čas na buňku 0,5 m a výchozí podíly surovin [1]–[12]. Návrh přepisu podílů v blueprintu / WVB1, varianty času A/B/C, model znalostí a řetězců. Katalog výrobků přidává jednotky a laditelné parametry kvality (koupitelný recept = průměr).
- **Komplikace:** rozsahy UCS jsou široké, typická hodnota může přehodit třídu (gabro vs žula). Jakost rudných buněk je herní abstrakce, ne průměr ložiska [8][9][23]. Historický čas po × 144 je u tvrdé skály na streamu dlouhý, proto je v tabulce i kratší návrh. Ve hře se nic nezkoušelo.
- **Další krok:** Jan vybere otevřené otázky v návrhu (dvoukrok, čas, recepty, Mineralogie).

## 2 Zpracování, znalosti a recepty

(Rozhodnutí 13:23, 13:31 a hypotézy 13:27–13:39 jsou zapsané výše u T01, protože vznikly společně s návrhem vlastností.)

---

# B. Zamítnuté směry

Zatím prázdné.

---

# C. Návrhy optimalizací

Zatím prázdné. Otevřené otázky pro Jana jsou v `README.md`.
