namespace Willage.Gen.Api.Dto;

/// <summary>G-6: vrstva náhledu modulu (tabulka 3.3 plánu 05). Izolace jsou samostatné vrstvy (Relief, RozdilM2M1).</summary>
public enum VrstvaNahleduDto
{
    // M1 funkce světa
    Vyska, Biom, Horniny, Sopky, Masiv, Relief,
    // M2 moře a kontinenty
    Pevnina, More, Panve, Sev, RozdilM2M1,
    // M3 geologie
    MaterialPovrchu, Mince,
}

/// <summary>G-6: režim řezu M3 (izolace jako GeoLab): vše, jen vrstvy, jen útvary + nitro sopek.</summary>
public enum RezimRezuDto { Vse, JenVrstvy, JenUtvary }

/// <summary>
/// G-6: mapa náhledu modulu na mřížce nx × ny (řádky po y) se středy buněk x = X0 + (i + 0,5)·KrokM. Hodnoty float: metry (výška, rozdíl,
/// posun pánví, vzdálenost ke švu), váhy 0–1 (pevnina, masiv, mince), indexy (biom 0–4, sopka −1/index, materiál id), moře 0/1.
/// Oblast M1–M3 = funkce světa 0…SvetMaxM (startovní svět, dnes 4096 m) – ne celá planeta (ta je jen v mapě eroze M4).
/// Cisla: souhrnná čísla náhledu (min, max, podíl moře, počet sopek …).
/// </summary>
public sealed record NahledMapyDto(string Modul, VrstvaNahleduDto Vrstva, bool Izolace, double X0M, double Y0M, double KrokM, int Nx, int Ny,
    float[] Hodnoty, string Popis, IReadOnlyDictionary<string, double> Cisla, double Ms);

/// <summary>
/// G-6: řez modulu úsečkou Od → Do po KrokM (Nx vzorků, středy x = (i + 0,5)·KrokM od Od). PovrchM = povrch modulu (M1, M2, M3);
/// PovrchM1 = povrch M1 pro srovnání v M2 (jinak null); HladinaMoreM (NaN bez moře).
/// M3: Materialy = Nx × Nz bajtů (sloupec po sloupci, odspodu, buňky 0,25 m – jako nástroj „rez“), jinak prázdné.
/// </summary>
public sealed record RezModuluDto(string Modul, SouradniceQ16 Od, SouradniceQ16 Do, double KrokM, int Nx, int Nz, double KrokZM,
    double[] PovrchM, double[]? PovrchM1, double HladinaMoreM, byte[] Materialy, RezimRezuDto Rezim, double Ms)
{
    public byte Material(int ix, int iz) => Materialy[ix * Nz + iz];
}

/// <summary>G-6: materiál pro legendu a „materiál pod kurzorem“ (materialy_v1.csv: id, nazev_cs, barva_hex).</summary>
public sealed record MaterialDto(byte Id, string Nazev, string Skupina, string BarvaHex);
