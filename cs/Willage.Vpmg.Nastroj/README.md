# Willage.Vpmg.Nastroj (T-1, rozhodnutí N7)

Samostatný nástroj VPMG nad **připnutým commitem Willage_Dev** (net10.0). Kód Dev se nekopíruje ani neupravuje – projekt odkazuje
`Willage.World.Materials` a `Willage.World.Vpmg` v připnuté kopii `.willage-dev/<commit>/` (obnovitelná keš, v `.gitignore`).
Klient (net9: `cs/Willage.Materialy.Api`, Godot) s nástrojem mluví mimo proces (JSON řádky, režim `server`).

```bash
cs/Willage.Vpmg.Nastroj/priprav_dev.sh            # stáhne commit z godot-prototyp/data/vpmg/dev_pin.json (token jen z env, maskovaně)
cs/Willage.Vpmg.Nastroj/priprav_dev.sh --zdroj /cesta/k/klonu/Willage_Dev   # bez sítě
dotnet build -c Release cs/Willage.Vpmg.Nastroj
N=cs/Willage.Vpmg.Nastroj/bin/Release/net10.0/Willage.Vpmg.Nastroj.dll
dotnet $N info | golden | katalog godot-prototyp/data/v1/materials-catalog-v1.json
dotnet $N --katalog godot-prototyp/data/v1/materials-catalog-v1.json spust 52 0xC0FFEE00 /tmp/52.png [--navrh '{"grainScalePermille":0}']
dotnet $N --katalog … server   # {"id":1,"prikaz":"spust","materialId":52,"seed":3237998080} → {"ok":true,"checksum":1756279408,"rgba":"…"}
```

Změna pinu: `dev_pin.json` (`commit`) **a** `WillageDevCommit` v csproj; test T-1 hlídá shodu (nástroj hlásí commit, pin ho čte).
