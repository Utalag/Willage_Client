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
    // G-7 – M4 eroze (mapa planety, uzly 32 m): výška po erozi, posun eroze H0 − H (izolace), log10 plochy povodí, hloubka jezer, koryta
    VyskaPlanety, PosunEroze, Toky, Jezera, Koryta,
    // G-7 – M5 klima: teplota °C, srážky mm/rok, odtok w, biom klimatu (BiomKlimatu), stav koryt (HydrologieKlimatu), izolace biom bez oáz
    Teplota, Srazky, OdtokW, BiomKlimatu, KorytaKlimatu, BiomBezOaz,
    // G-7 – M6 voda: hloubka hladiny pod povrchem (NaN = bez hladiny), hladina m n. m., dobití 7c, vývěr 0/1, pobřežní pás (0 / 1 hladina = moře / 2 moře),
    // izolace jen hladina (hloubka bez bodů) / jen prameny (povrch + body); 7d zvodnělá zóna = ZÁSTUPNÁ (NaN, Jan: odloženo)
    Hladina, HladinaAbs, Dobiti, Vyver, PobrezniPas, JenHladina, JenPrameny, ZvodnelaZona7d,
}

/// <summary>G-7: bod v náhledu nebo řezu (vodník, oáza, pramen). S = poloha podél úsečky řezu (m), jinak NaN; Z = výška vývěru (m) nebo NaN.</summary>
public sealed record BodNahleduDto(double X, double Y, string Druh, double QLs, double S = double.NaN, double Z = double.NaN);

/// <summary>G-7: řádek tabulky pásem klimatu M5 (konfigurace pásma + změřené hodnoty na pevnině mapy v jeho segmentech).</summary>
public sealed record PasmoNahleduDto(string Id, string Nazev, double Podil, double TOdC, double TDoC, double SrazkyK, int Vitr,
    double UOd, double UDo, double PodilPevniny, double TPrumerC, double PPrumerMm, double WPrumer, string HlavniBiom, double PodilHlavnihoBiomu);

/// <summary>G-6: režim řezu M3 (izolace jako GeoLab): vše, jen vrstvy, jen útvary + nitro sopek.</summary>
public enum RezimRezuDto { Vse, JenVrstvy, JenUtvary }

/// <summary>
/// G-6: mapa náhledu modulu na mřížce nx × ny (řádky po y) se středy buněk x = X0 + (i + 0,5)·KrokM. Hodnoty float: metry (výška, rozdíl,
/// posun pánví, vzdálenost ke švu), váhy 0–1 (pevnina, masiv, mince), indexy (biom 0–4, sopka −1/index, materiál id), moře 0/1.
/// Oblast M1–M3 = funkce světa 0…SvetMaxM (startovní svět, dnes 4096 m) – ne celá planeta (ta je jen v mapě eroze M4).
/// Cisla: souhrnná čísla náhledu (min, max, podíl moře, počet sopek …).
/// </summary>
public sealed record NahledMapyDto(string Modul, VrstvaNahleduDto Vrstva, bool Izolace, double X0M, double Y0M, double KrokM, int Nx, int Ny,
    float[] Hodnoty, string Popis, IReadOnlyDictionary<string, double> Cisla, double Ms)
{
    /// <summary>G-7: body v oblasti (vodníci M4, oázy a vodníci M5, prameny M6); null = vrstva bez bodů (izolace).</summary>
    public IReadOnlyList<BodNahleduDto>? Body { get; init; }
    /// <summary>G-7: vrstva je zástupná (7d) – hodnoty NaN, bez logiky.</summary>
    public bool Zastupny { get; init; }
}

/// <summary>
/// G-6: řez modulu úsečkou Od → Do po KrokM (Nx vzorků, středy x = (i + 0,5)·KrokM od Od). PovrchM = povrch modulu (M1, M2, M3);
/// PovrchM1 = povrch M1 pro srovnání v M2 (jinak null); HladinaMoreM (NaN bez moře).
/// M3: Materialy = Nx × Nz bajtů (sloupec po sloupci, odspodu, buňky 0,25 m – jako nástroj „rez“), jinak prázdné.
/// </summary>
public sealed record RezModuluDto(string Modul, SouradniceQ16 Od, SouradniceQ16 Do, double KrokM, int Nx, int Nz, double KrokZM,
    double[] PovrchM, double[]? PovrchM1, double HladinaMoreM, byte[] Materialy, RezimRezuDto Rezim, double Ms)
{
    public byte Material(int ix, int iz) => Materialy[ix * Nz + iz];
    /// <summary>G-7 M6: surová hladina podzemní vody 7c (m, NaN = bez hladiny), jinak null.</summary>
    public double[]? HladinaPodzemniM { get; init; }
    /// <summary>G-7: další řady podél řezu (M4 eroze_m; M5 teplota_c, srazky_mm, w; M6 dobiti).</summary>
    public IReadOnlyDictionary<string, double[]>? Rady { get; init; }
    /// <summary>G-7: body u řezu (M6 prameny do 150 m od úsečky, S podél úsečky).</summary>
    public IReadOnlyList<BodNahleduDto>? Body { get; init; }
    /// <summary>G-7: zástupné části řezu (dnes 7d zvodnělá zóna a strop hladiny u pobřeží – Jan: odloženo).</summary>
    public IReadOnlyList<string> Zastupne { get; init; } = Array.Empty<string>();
}

/// <summary>G-6: materiál pro legendu a „materiál pod kurzorem“ (materialy_v1.csv: id, nazev_cs, barva_hex).</summary>
public sealed record MaterialDto(byte Id, string Nazev, string Skupina, string BarvaHex);
