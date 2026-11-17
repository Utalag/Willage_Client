# Formát uloženého bloku WVB1 (návrh Willage-ideas, 2026-11-17 18:20, čeká na Jana)

Kontext: Jan 18:12 přesunul generátor a simulaci na klienta. Klient po usazení a dopočtu posílá celé pole bloku, server validuje a ukládá.

## Kontejner (little-endian)
| Pole | Typ | Poznámka |
|---|---|---|
| magic | 4 B `WVB1` | |
| format_ver | u8 | 1 |
| flags | u8 | bit0 vrstva vody, bit1 vrstva variant, bit2 vegetace |
| dims | u8 sx, u8 sz, u16 sy | vždy 16, 16, 64 |
| block_id | u64 | id bloku v DB |
| seed | u64 | |
| recipe_id, recipe_ver | u16, u16 | louka/kopec/hora/písčina + verze receptu |
| gen_ver, sim_ver | u16, u16 | verze generátoru a simulace klienta |
| placement | u8 mirror, u8 rot, i8 shift, 4× u8 sides | volby vložení |
| revision | u32 | pořadí uložení bloku (optimistická zámka) |
| parent_hash | 32 B | hash předchozí revize (0 u první) |
| summary | u16 počet + N× (u16 mat_id, u32 count) | souhrn materiálů po simulaci |
| water_total | u32 | součet vody, pevná čárka 1/4096 buňky |
| stack | u16 počet + N× (u16 mat_id, u32 count, u8 shape, u16 params_len, bytes params) | zásobník materiálů ze serveru v pořadí zpracování (gen-v3); server ho porovná s tím, co vydal |
| stack_hash | 32 B | SHA-256 zásobníku, jak ho vydal server (rychlé porovnání bez dekódování) |
| shortfall | u16 počet + N× (u16 mat_id, u32 count) | nerozmístěné buňky rud proti vydanému cíli; server přijme do 1 % cíle u každé rudy |
| layers_len | u32 | délka komprimovaných dat |
| layers | bytes | komprimované vrstvy, viz níže |
| hash | 32 B | SHA-256 přes vše výše (kanonicky, nekomprimované vrstvy) |

## Vrstvy (před kompresí)
- Pořadí buněk jako v prototypu: `idx = (x*16 + z)*64 + y`, y je výška (0 dno). Sloupce jsou souvislé, takže RLE i komprese pracují dobře.
- `material`: u8 na buňku (16 384 B). Mat.COUNT je teď 12, rezerva do 255.
- `variant` (volitelná): u8.
- `water` (volitelná): u16 pevná čárka 0..65535 = 0..1 objemu buňky (vzduch) nebo pórů.
- Vegetace zvlášť jako seznam (jako veg.gd), ne buněčná vrstva.

## Komprese
- Vrstvy za sebou, pak **deflate** (raw). Godot to umí nativně (`PackedByteArray.compress(FileAccess.COMPRESSION_DEFLATE)`), .NET taky (`System.IO.Compression.DeflateStream`), bez dalších knihoven. Zstd by byl o něco lepší, ale v .NET potřebuje NuGet; dá se přidat přes `flags` později.
- Odhad: přírodní blok je většinou sloupce vrstev a vzduchu, po deflate řádově jednotky kB (nutno změřit na `vectors/`).

## Hash
- SHA-256 (Godot `HashingContext`, .NET `SHA256`). Počítá se přes hlavičku bez pole `hash` a přes **nekomprimované** vrstvy, aby nezávisel na úrovni komprese.
- Hash je kontrola integrity a řetězení revizí (`parent_hash`), ne ochrana proti podvodu – klient ho umí spočítat sám. Server ho vždy přepočítá.

## Validace na serveru
1. Rozměr, verze, délky, hash sedí (server přepočítá z dekomprimovaných dat).
2. Jen povolené materiály (globální seznam + co dovoluje recept).
3. Souhrn v hlavičce = skutečný souhrn z pole (server přepočítá, hlavičce nevěří).
4. **Zachování materiálů:** simulace zemin (sesuvy, sypání) jen přesouvá buňky, takže souhrn po simulaci = souhrn před simulací. U další revize: nový souhrn = předchozí souhrn − vytěžené buňky z delta-v0 + položené buňky. Voda se nezachovává (prameny, výpar), kontroluje se jen horní mez.
5. Výška: posun ±1–4 vrstvy a celkem 64.

## Očekávaný souhrn z receptu a seedu (otevřená otázka)
- **Doporučení:** postupně portovat generátor do C# a ověřit ho proti testovacím vektorům prototypu (`godot-prototyp -- --export-vectors` → `vectors/vectors.json`, výstup je bajtově stabilní). Pak server spočítá očekávané pole/souhrn sám a podvrh první revize nejde.
- **Mezikrok, dokud port není:** první revizi server přijme se statistickou kontrolou (souhrn musí ležet v rozsahu, který recept a rarita dovolují), všechny další revize už hlídá přesně podle bodu 4. Klient může volitelně poslat i surový souhrn před simulací.
- Generátor i simulace musí být deterministické (seedovaný hash `stable_hash.gd`, pevná čárka u vody), jinak přesná kontrola nepůjde.

## Úprava 18:35 (dohoda s Willage-backend, čeká na Jana)
- Očekávaný souhrn rud určuje server při vydání bloku (základ z receptu a seedu + bonus). Port generátoru do C# kvůli kontrole rud proto není potřeba; server kontroluje každou rudu přesně proti vydanému cíli (minus shortfall) a součet pevných buněk.
- Jíl z ložiska má vlastní MaterialId ClayDeposit, základní generování nikdy nevytvoří ID rudy.
- Voda je jen vrstva `water` (u16), v souhrnu jako objem; vodní rezervoáry z generování (cave-v0) jdou do této vrstvy.

## Úprava 19:00 – zásobník gen-v3 (Jan 18:58, čeká na schválení)
- Generátor nerozlišuje druhy materiálů. Vstup je seřazený zásobník ze serveru `[(mat_id, count, shape, params)]`; položky se zpracují v daném pořadí, každá se šíří jen do hlíny a nic nepřepisuje. Pořadí určuje server (výchozí od nejméně početného, recept může změnit), klient nic neřadí.
- Hlavička nese `stack` a `stack_hash`. Server ověří, že `stack_hash` = hash zásobníku, který vydal, a že výsledný souhrn = počty ze zásobníku (minus shortfall) + zbytek hlína.
- `params` je u každé položky kanonicky serializovaný slovník tvaru (pevné pořadí klíčů, celá čísla), aby hash seděl v Godotu i .NET.
- **Upřesnění 19:01 (dohoda s Willage-backend):** `params` = posloupnost i32 little-endian v pevném pořadí podle tabulky shape v katalogu (např. pocket = [maxHromada, lzMin, lzMax], vein = [maxHromada, lzMin, lzMax, inertia‰, branch‰]); `params_len` = 4 × počet. Jen celá čísla (pravděpodobnosti v ‰ nebo 0–65535). Celá hlavička je little-endian. `stack_hash` = SHA-256 přesných bajtů zásobníku od u16 počtu po poslední params. Neznámý shape nebo špatná délka params → chyba `world.stack_invalid`.
