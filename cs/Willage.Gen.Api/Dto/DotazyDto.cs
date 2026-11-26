namespace Willage.Gen.Api.Dto;

/// <summary>Sloupec geologie 0,25 m (MaterialId u8 odspodu) a povrch.</summary>
public sealed record SloupecDto(SouradniceQ16 Poloha, double PovrchM, byte[] Materialy);

/// <summary>Bod povrchu: výška, materiál povrchu, moře, klima (null bez klimatu).</summary>
public sealed record BodDto(SouradniceQ16 Poloha, double PovrchM, int MaterialPovrchu, bool More, double? TeplotaC, double? SrazkyMm, string? Biom);

/// <summary>
/// Řez povrchem mezi dvěma body (vzorky po krokM). Jednotky (G-3 review): vodorovné polohy jsou Q16, PovrchM a KrokM jsou
/// double metry (výška nad dnem sloupce 0–128 m, krok vzorku) – převod do Q16 dělá volající (SouradniceQ16.JednotekNaMetr).
/// </summary>
public sealed record RezDto(SouradniceQ16 Od, SouradniceQ16 Do, double KrokM, double[] PovrchM);

public enum VrstvaMapyDto { Vyska, Eroze, Teplota, Srazky, Biom }

/// <summary>
/// Mapa vrstvy na hrubé mřížce planety (nx × ny, řádky po y, hodnoty float): mapa eroze / klimatu po KrokM metrech (dnes 32 m),
/// **ne buňky 0,25 m**. KrokM a hodnoty výšky jsou double/float metry (G-3 review: zdokumentováno, nepřevádí se).
/// </summary>
public sealed record MapaDto(VrstvaMapyDto Vrstva, int Nx, int Ny, double KrokM, float[] Hodnoty);
