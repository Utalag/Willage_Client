# PROP GEO2: přeměření výkonu GEO1 / K3 / výchozí GEO2 (Jan t1044u, bod 3)

*Zapsáno před experimentem 2026-11-28 ~03:10. Větev `geo2-vykon-mereni` z `geo2-vychozi`. Kontrakt V6: čas na boxu je jen doplňkový (primární je odstraněná práce);
měří se na boxu, NE na počítači Jana (vyžadovalo by schvalování).*

## Zátěž boxu (zjištěno před měřením, 2026-11-28 03:09)
Cizí procesy `grep` PID **295547** a **297041** (`grep -o … jc_AI%20developer.html`) běží od 2026-11-27 ~ 21:00, každý ~ 100 % jednoho jádra (RSS 4,9 GB a 0,6 GB). Nejsou moje,
**nezabíjím je**, jen zaznamenávám. Box má 8 jader, takže 8 vláken měřených cest sdílí ~ 6 volných jader; load average před měřením bývá 4–8.
Nástroj zaznamenává před každým blokem `loadavg` a CPU cizích procesů a po měření uvádí rozptyl.

## Co se měří
Pro každý blok 128 m (stejných 11 bloků jako V8: 5 náhodných, 2 šev mince, 2 hornatina / strmé, svah a okraj sopky), sloupce po 0,25 m, z po 0,25 m, 512 buněk na sloupec:

| Cesta | Definice |
|---|---|
| **GEO1** | `GeoVrstvy.VyplnSloupec` (stará cesta), `Klon()` na vlákno |
| **K3** | kontext bloku s pevnou mřížkou hranic 0,5 m, `Sloupec` po bodech (`SloupecPoBodech`, tj. stav kódu po K3: bod po buňce) |
| **GEO2 výchozí** | kontext se zaručenou adaptivní mřížkou, `Sloupec` z běhů (výchozí od `geo2-vychozi`) |
| **GEO2 + kontakt rychle** | totéž s úpravou z bodu 2 (`geo2-kontakt-rychle`), jen jako samostatný binární běh (dočasný merge, nepushuje se) |

Čas = kontext (sestavení, u GEO1 žádný) + sloupce, zvlášť i celkem. Každá cesta v každém bloku **R = 5 opakování** (+ 1 zahřívací vyřazené), cesty se střídají (rotace pořadí),
aby posun zátěže nezvýhodnil jednu z nich. Uvádí se **medián, min, max a relativní rozptyl** ((max − min) / medián) a poměr mediánů proti GEO1 a proti K3.
Navíc 1 vlákno na 2 blocích (sloupce po 0,5 m, R = 3), aby se oddělil vliv cizí zátěže.

## Kritéria / co z toho plyne
- Výchozí GEO2 ne výrazně pomalejší než K3 (Jan t1042u). Cílový práh z V8 návrhu: ≤ ×1,5 GEO1.
- Rozptyl < 15 % → čísla jsou vypovídající; vyšší rozptyl se uvede a výsledek označí jako orientační.
- Kontrola správnosti: kontrolní součet výstupu každé cesty se v opakováních shoduje (determinismus).

## Rizika
- Cizí `grep` (2 jádra) zkresluje čas; střídání cest a medián z 5 opakování to zmírní, ne odstraní.
- Paměťová zátěž (cizí 4,9 GB RSS) – box má 15 GB, měřený proces potřebuje < 1 GB (sloupce se nekladou do paměti, jen kontrolní součet).
