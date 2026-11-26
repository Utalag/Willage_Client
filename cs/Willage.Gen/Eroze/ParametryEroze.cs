using System.Text.Json;

namespace Willage.Gen.Eroze;

/// <summary>Parametry eroze světa (krok 6, data/v1/eroze_v1.json). Výchozí hodnoty = PROP krok06.</summary>
public sealed record ParametryEroze
{
    // planeta (torus) a mřížka
    public double PlanetaXM { get; init; } = 31360.0;
    public double PlanetaYM { get; init; } = 15616.0;
    public double KrokM { get; init; } = 32.0;
    /// <summary>Pás prolnutí u švu torusu (funkce světa sama periodická není).</summary>
    public double PasProlnutiM { get; init; } = 512.0;
    // odtok a srážky
    /// <summary>Nejnižší podíl buněk podkladu = odtok (base level), tam voda mizí.</summary>
    public double OdtokPodil { get; init; } = 0.02;
    /// <summary>Srážky jako násobek (klima planety zatím jen tímto parametrem).</summary>
    public double Srazky { get; init; } = 1.0;
    public double EpsilonVyplneM { get; init; } = 1e-3;
    // stream power (Braun & Willett 2013, implicitně, n = 1)
    public double K { get; init; } = 1e-5;
    public double M { get; init; } = 0.5;
    public int KrokuCasu { get; init; } = 20;
    public double DtRoku { get; init; } = 1000.0;
    public double MaxEroseM { get; init; } = 20.0;
    // toky a vodníci
    public double AKritM2 { get; init; } = 250_000.0;
    public double SpecifickyOdtokLsKm2 { get; init; } = 10.0;
    public double VodnikVahaKopcu { get; init; } = 0.5;
    // koryto (jemný detail): w = a·Q^0,5, d = c·Q^0,4 (Q v m³/s)
    public double KorytoA { get; init; } = 3.0;
    public double KorytoC { get; init; } = 0.6;
    public double KorytoMinSirkaM { get; init; } = 1.0;
    public double KorytoMaxHloubkaM { get; init; } = 3.0;
    /// <summary>Krok 6b: interpolace E mezi uzly: "bilinearni" (krok 6), "catmullrom", "bspline".</summary>
    public string InterpolaceE { get; init; } = "bilinearni";

    public int Nx => (int)Math.Round(PlanetaXM / KrokM);
    public int Ny => (int)Math.Round(PlanetaYM / KrokM);

    public static ParametryEroze ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryEroze>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();

    /// <summary>Kanonický zápis pro klíč keše (pořadí vlastností je pevné).</summary>
    public string Kanonicky() => JsonSerializer.Serialize(this);
}
