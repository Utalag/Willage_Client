namespace Willage.Gen.Api.Dto;

/// <summary>Sloupec geologie 0,25 m (MaterialId u8 odspodu) a povrch.</summary>
public sealed record SloupecDto(SouradniceQ16 Poloha, double PovrchM, byte[] Materialy);

/// <summary>Bod povrchu: výška, materiál povrchu, moře, klima (null bez klimatu).</summary>
public sealed record BodDto(SouradniceQ16 Poloha, double PovrchM, int MaterialPovrchu, bool More, double? TeplotaC, double? SrazkyMm, string? Biom);

/// <summary>Řez povrchem mezi dvěma body (vzorky po krokM).</summary>
public sealed record RezDto(SouradniceQ16 Od, SouradniceQ16 Do, double KrokM, double[] PovrchM);

public enum VrstvaMapyDto { Vyska, Eroze, Teplota, Srazky, Biom }

/// <summary>Mapa vrstvy na mřížce planety (nx × ny, řádky po y), hodnoty float.</summary>
public sealed record MapaDto(VrstvaMapyDto Vrstva, int Nx, int Ny, double KrokM, float[] Hodnoty);
