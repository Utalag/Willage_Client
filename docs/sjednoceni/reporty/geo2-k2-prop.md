# PROP GEO2 K2: vzorek 3.1, typ prostoru, rozhraní pro vodu, Historie(p)

*Zapsáno před prací 2026-11-27 ~14:40 (Jan t1036u). Kontrakt `docs/sjednoceni/06-geologie-geo2.md` (v3): 3.1, 3.2, 2.1, krok K2 v kap. 5. Větev `geo2-k2-vzorek` z `geo2-k1b-kontakt`.*

## Cíl
1. Plný stav bodu podle 3.1: `Material`, `Typ`, `GeoUdalost`, `GeoInstance`, `Vrstva`, `MaterialPuvodu`, **`HostitelPuvodu`**, **`TypHostitele`**, `PosledniTransformace`, `PocetTransformaci`, **`Priznaky`**; zápis v `Proved` přesně podle tabulky 3.1.
2. `Vzorek` jako kompaktní výstupní struktura (ushort / byte, značka 0xFFFF = žádná), převod z pracovního stavu; změřit velikost.
3. `Priznaky.HraniceOdhad`: bod, o kterém rozhodla odhadnutá vzdálenost (kontakt přes vrcholy u vyklínění, K1b), to nese.
4. Typ prostoru tak, aby voda rozlišila dutinu od vzduchu bez znalosti povrchu: `NadPovrchem`, `DutinaKras`, `DutinaJina`, `Vykopano` (překryv výkopů jako rozhraní nad geologií, ne událost).
5. Rozhraní pro vodu (jen připravit, voda se na GEO2 nenapojuje): třída buňky pro vodu (vzduch / volný prostor / hornina) a vzorkování sloupce.
6. Volitelně `Historie(p)` jako přepočet stejného průchodu (nic se neukládá), invariant: poslední krok = `Vzorek`.

## Mimo K2
- napojení vody na GEO2 (K7), index bloku a výkon (K3), intervaly `Beh` (K4).

## Kritéria
| Test | Očekávání |
|---|---|
| zápis 3.1 | každý řádek tabulky (Uloz, Vnikni do horniny i do dutiny, Odstran, Vypln, Transformuj 1× a 2×) a 6 příkladů 3.1 |
| V1 pole | žíla v pásmu skarnu = křemen s `HostitelPuvodu = skarn`; žádný bod pod povrchem `Neurceno` (syntetika i skutečný svět) |
| Vzorek | převod beze ztráty v rozsahu ushort, značky 0xFFFF, velikost změřená |
| příznaky | syntetická rovina bez příznaku; na skutečném světě bod s odhadem nese `HraniceOdhad` |
| voda | dutiny pod povrchem = volný prostor, vzduch = vzduch; shoda s třídami buněk dnešní vody (`ProfilSloupce`) na sloupcích s krasem; výkop = `Vykopano` s původem |
| Historie | invariant poslední krok == `Bod` na ≥ 10⁴ bodech skutečného světa; počet transformací v historii = `PocetTransformaci` |
| výkon / paměť | čas bloku 128 m proti K1b, bajty na vzorek proti 1 B dnešního sloupce |
| regrese | celá sada 0 chyb, staré otisky beze změny |

## Rizika
- větší pracovní stav = pomalejší průchod (měří se);
- `HraniceOdhad` označí jen body, které kontakt změnil; bod, který kvůli odhadu změněn nebyl, příznak nemá (bez intervalů to nejde poznat).

## Výsledky
*(doplní se po měření)*
