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

Větev `geo2-k2-vzorek` (z `geo2-k1b-kontakt`): d33adb2 PROP, 8727dc8 stav + Vzorek + Historie + odhad, 2810e75 rozhraní pro vodu, a05944f testy. Push neproběhl (token není k dispozici).

**Testy:** GEO2 138/138 (K1a + K1b + K2), celá sada 662/662, chyb 0, staré otisky beze změny. Mimo `Geo2/` a `TestyGeo2*` se mění jen `Program.cs` (registrace testů); stará cesta nedotčena.

| Kritérium | Výsledek |
|---|---|
| Zápis podle tabulky 3.1 (všechny řádky) | splněno, syntetická sada Sada31 (uloz / intruze / kras / sopka / vyplň / 2× transformace) |
| V1: žíla ve skarnové zóně má HostitelPuvodu = skarn | splněno; žádný bod pod povrchem není Neurceno |
| Kompaktní Vzorek | 20 B (Pack=1), pracovní StavBodu 44 B; StavBodu → Vzorek → StavBodu bezeztrátově; id ≥ 0xFFFF hází OverflowException |
| HraniceOdhad | koule 0 bodů; blok E84 (1024,512) po 2 m: 7 583 skarnových bodů, 90 s příznakem (1,19 %); mimo kontakt 0 |
| Historie(p) = přepočet stejným průchodem | 12 000 bodů: poslední krok == Bod, kroky na sebe navazují, počet transformací sedí |
| TypProstoru pro vodu | 40 náhodných sloupců s dutinou (0–4096 m), 20 462 buněk, 156 krasových: shoda tříd s dnešní vodou 100,000 % mimo 18 horních částečných buněk; žádné chyby typu |
| Výkopy | překryv Vykopano (materiál 0, původ zachován), nad povrchem nic, mimo geologii |

**Výkon** (celý blok (1024,512) po 0,25 m, 134 M buněk, střídavě 2 běhy): stará cesta 5,8–6,7 s; GEO2 K1b 29,0 / 31,8 s, K2 33,1 / 32,0 s → dopad K2 v šumu (≈ 0–10 %). Shoda materiálů beze změny 99,771 %.

**Paměť vzorku:** 20 B / vzorek proti 1 B v dnešním sloupci. Plný blok 0,25 m jako pole Vzorků by měl ~2,7 GB, takže Vzorek je výstupní/dotazový formát, ne úložiště; ukládat se má po bězích (runs) nebo jen materiál + odkaz (K4).

**Negativní / omezení:**
- HraniceOdhad se nastavuje jen na bodech, které kontakt opravdu změnil a rozhodl záložní vrchol; body těsně mimo pásmo v místech vyklínění příznak nemají.
- Dnešní voda bere buňku se středem nad povrchem jako dutinu, GEO2 jako vzduch (18 buněk). Rozdíl je v definici, ne chyba; řeší se při napojení vody.
- Voda není napojena, existuje jen rozhraní (IGeologieGeo2, ProstorVody, VzorkovacGeo2).
- Vykopano je překryv, ne geologická událost (Historie ho nezná).
- Reálný svět E84 nemá žádný bod s PocetTransformaci > 1; vícenásobná transformace je ověřena jen synteticky.
- GEO2 je stále ~5× pomalejší než stará cesta, to je práce K3.
