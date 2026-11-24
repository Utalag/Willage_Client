# Roadmap geologického enginu

## Aktuální stav (v0, algorithmVersion 1, schemaVersion 1)
Hotové:
- Jádro bez Reactu/Three.js: hash, periodický value noise, materiály (ID 0–7), sedimentace, vrásnění (analytická + numerická inverze), zlom (inverze po částech, drcená zóna), zpětná rekonstrukce s historií p0…pN.
- Voxelizace 64³/128³ při 2–0,25 m, přímý průřez, culled mesh, Web Worker.
- UI: časová osa (přidat/odebrat/pořadí/zapnout/izolovat/stav do okamžiku), parametry, 3D/2D, řezy, skrývání materiálů, buňky, barvení podle události, inspektor (klik), scénáře A–E.
- Diagnostika (skutečné měřené hodnoty), 7 in-app testů + jednotkové testy (vitest), export/import JSON, golden vectors.

Nehotové:
- TransformationEvent (metamorfóza, mineralizace, zvětrávání) – jen rozhraní a hák v evaluatoru.
- Eroze povrchu, intruze, sopky, hydrogeologie.
- Periodicita zlomů (torus není úplný).
- Chunkované vyhodnocení pro 0,25 m na 128 m (134 M vzorků).

## Technický dluh
- Vizualizace A je realizována: společný přesný 3D/2D řez, vlastní rozlišení, inspektor, filtry zdrojových vrstev a hranice rastru. Výsledky: `VISUALIZATION_A_RESULTS.md`.
- Architektura v1 je schválena pouze jako návrh; hierarchie, uložená sequence, kompilace/index a B (fáze 3–7) nejsou implementované. V0 JSON ani procesy se nemění.
- Periodicita/neomezené zlomy: samostatný otevřený problém GEO-PERIODIC-FAULT v `TECHNICAL_ISSUES.md`; žádné ořezávání jejich supportu.
- Metriky transformací a testy běží v hlavním vlákně (blokují UI ~1 s).
- Mesh se staví v hlavním vlákně; pro 0,5 m a jemnější přesunout do Workeru a chunkovat.
- Cache sedimentace je jen „poslední sloupec“ – pro náhodný přístup LRU per sloupec.
- Validace parametrů je jen v operacích, ne ve schématu JSON (bez JSON Schema).
- `time` (Ma) je odvozený z pořadí; skutečné geologické stáří zatím nemá vliv.

## Doporučené další kroky
1. Port jádra do C# a ověření proti golden vectors.
2. Chunkované vyhodnocení + mesh ve Workeru (pool Workerů).
3. Periodické zlomy s omezeným rozsahem a útlumem posunu.
4. Eroze povrchu → intruze → kontaktní metamorfóza → mineralizace → sopky → hydrogeologie.
