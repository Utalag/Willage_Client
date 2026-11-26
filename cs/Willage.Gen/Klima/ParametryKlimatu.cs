using System.Text.Json;
using System.Text.Json.Serialization;

namespace Willage.Gen.Klima;

/// <summary>Výchozí klima planety (podle id presetu kroku 2): teploty pásem a srážky planety.</summary>
public sealed record KlimaPlanety
{
    public double TRovnikC { get; init; } = 24.0;
    public double TPolC { get; init; } = -6.0;
    public double SrazkyMmRok { get; init; } = 800.0;
}

/// <summary>Krok 7: parametry klimatu a biomů (data/v1/klima_v1.json). Výchozí hodnoty = PROP krok07.</summary>
public sealed record ParametryKlimatu
{
    // zeměpis a teplota
    public double StartSirkaDeg { get; init; } = 45.0;
    public double StartYM { get; init; } = 1984.0;
    public double VyskovyGradientCNaM { get; init; } = 0.05;
    public double HladinaMoreM { get; init; } = 60.0;
    // srážky podle šířky: P = planeta · max(min, 1 + rovník·g(0,σr) − subtropy·g(φs,σs) + mírné·g(φm,σm) − pól·(φ/90)²)
    public double ARovnik { get; init; } = 0.8;
    public double SigmaRovnikDeg { get; init; } = 15.0;
    public double ASubtropy { get; init; } = 0.75;
    public double SubtropyDeg { get; init; } = 28.0;
    public double SigmaSubtropyDeg { get; init; } = 9.0;
    public double AMirne { get; init; } = 0.3;
    public double MirneDeg { get; init; } = 55.0;
    public double SigmaMirneDeg { get; init; } = 12.0;
    public double APol { get; init; } = 0.6;
    public double MinPodilSrazek { get; init; } = 0.08;
    // vítr a vlhkost
    public bool VetrnePasy { get; init; } = true;
    public double PasatyDoDeg { get; init; } = 30.0;
    public double ZapadniDoDeg { get; init; } = 60.0;
    public double PrechodPasuDeg { get; init; } = 4.0;
    /// <summary>Bez pásů: +1 = vítr od západu (vlhkost se nese k +x), −1 od východu.</summary>
    public int VitrSmer { get; init; } = 1;
    public double DoplneniNadMoremM { get; init; } = 2000.0;
    public double KontinentalitaM { get; init; } = 12000.0;
    public double OrografieZesileni { get; init; } = 60.0;
    public double VlhkostMin { get; init; } = 0.10;
    public double VyhlazeniTerenuM { get; init; } = 256.0;
    public double VyhlazeniSrazekM { get; init; } = 128.0;
    // odtok (Turc) a voda
    public double OdtokReferenceMm { get; init; } = 315.36;   // = 10 l/s/km²
    public double PramenWMax { get; init; } = 2.0;
    public double PramenPravdepodobnostMax { get; init; } = 0.95;
    // biomy (Whittaker + Köppenova mez suchosti P_mez = KoppenA·T + KoppenB)
    public double TLedC { get; init; } = -8.0;
    public double TTundraC { get; init; } = 0.0;
    public double TTajgaC { get; init; } = 5.0;
    public double TTropyC { get; init; } = 20.0;
    public double KoppenA { get; init; } = 20.0;
    public double KoppenB { get; init; } = 140.0;
    public double PoustPodilMeze { get; init; } = 0.5;
    public double PMirnyDestnyMm { get; init; } = 2000.0;
    public double PTropickyLesMm { get; init; } = 1800.0;
    /// <summary>Výchozí klima planety podle id presetu kroku 2 (ParametrySveta.Klima); neznámé id → mirne.</summary>
    public Dictionary<string, KlimaPlanety> Planety { get; init; } = new() { ["mirne"] = new() };

    public KlimaPlanety Planeta(string id) => Planety.TryGetValue(id, out var k) ? k : Planety.TryGetValue("mirne", out var m) ? m : new();

    static readonly JsonSerializerOptions Volby = new() { PropertyNameCaseInsensitive = true, ReadCommentHandling = JsonCommentHandling.Skip };
    public static ParametryKlimatu ZJson(string json) => JsonSerializer.Deserialize<ParametryKlimatu>(json, Volby) ?? new();

    /// <summary>Kanonický zápis (pevné pořadí vlastností, planety seřazené) – do klíče klimatu.</summary>
    public string Kanonicky(string planeta) =>
        JsonSerializer.Serialize(this with { Planety = new() }) + "|" + planeta + "=" + JsonSerializer.Serialize(Planeta(planeta));
}
