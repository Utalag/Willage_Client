using System.Text.Json;
using System.Text.Json.Serialization;

namespace Willage.Gen.Klima;

/// <summary>Jedno předdefinované klimatické pásmo (od rovníku k pólu: tropy, subtropy, mirne, chladne, polarni).</summary>
public sealed record PasmoKlimatu
{
    public bool Zapnuto { get; init; } = true;
    /// <summary>Váha šířky pásma (po vypnutí jiných se zbylá pásma vyplní poměrně).</summary>
    public double Podil { get; init; } = 1.0;
    /// <summary>Teplota hladiny moře na rovníkové hraně pásma (°C).</summary>
    public double TOdC { get; init; } = 15.0;
    /// <summary>Teplota na polární hraně pásma (°C).</summary>
    public double TDoC { get; init; } = 10.0;
    /// <summary>Násobek srážek planety v pásmu.</summary>
    public double SrazkyK { get; init; } = 1.0;
    /// <summary>+1 = vlhkost nese vítr od západu (k +x), −1 od východu.</summary>
    public int Vitr { get; init; } = 1;
}

/// <summary>Klima planety: složení pásem a srážky planety. Pásma jsou pevně v pořadí <see cref="ParametryKlimatu.IdPasem"/>.</summary>
public sealed record KlimaPlanety
{
    public double SrazkyMmRok { get; init; } = 1000.0;
    public string StartPasmo { get; init; } = "mirne";
    public Dictionary<string, PasmoKlimatu> Pasma { get; init; } = new();

    /// <summary>Zapnutá pásma v pořadí od rovníku k pólu (neznámá id se ignorují).</summary>
    public List<(string id, PasmoKlimatu p)> Zapnuta() =>
        ParametryKlimatu.IdPasem.Where(id => Pasma.TryGetValue(id, out var p) && p.Zapnuto && p.Podil > 0).Select(id => (id, Pasma[id])).ToList();
}

/// <summary>Krok 7: parametry klimatu a biomů (data/v1/klima_v1.json). Výchozí hodnoty = PROP krok07.</summary>
public sealed record ParametryKlimatu
{
    /// <summary>Pevné pořadí předdefinovaných pásem od rovníku k pólu.</summary>
    public static readonly string[] IdPasem = { "tropy", "subtropy", "mirne", "chladne", "polarni" };
    public static readonly string[] NazevPasmaCs = { "tropy", "subtropy", "mírné", "chladné", "polární" };
    // zeměpis a teplota
    public double StartYM { get; init; } = 1984.0;
    public double VyskovyGradientCNaM { get; init; } = 0.05;
    public double HladinaMoreM { get; init; } = 60.0;
    /// <summary>Šířka krátkého plynulého přechodu mezi pásmy (m).</summary>
    public double PrechodPasmaM { get; init; } = 400.0;
    // vítr a vlhkost (směr větru určují pásma)
    public double DoplneniNadMoremM { get; init; } = 2000.0;
    public double KontinentalitaM { get; init; } = 20000.0;
    public double OrografieZesileni { get; init; } = 60.0;
    public double VlhkostMin { get; init; } = 0.10;
    public double VyhlazeniTerenuM { get; init; } = 256.0;
    public double VyhlazeniSrazekM { get; init; } = 128.0;
    // oázy / artéské prameny v pouštích
    public bool OazaZapnuta { get; init; } = true;
    public double OazaBunkaM { get; init; } = 1000.0;
    public double OazaPravdepodobnost { get; init; } = 0.3;
    public double OazaQLs { get; init; } = 3.0;
    public double OazaPolomerM { get; init; } = 96.0;
    public bool OazaVeStepi { get; init; } = false;
    // krok 7c (Jan 13:24): hladina podzemní vody podle dobití. Existuje jen tam, kde je dobíjená (odtok w nad prahem, pobřeží, aktivní koryta,
    // oázy a vodníci); mezi tím je tím hlubší, čím menší dobití; bez dobití (poušť) není vůbec (NaN). Vypnuto = hladina všude jako v kroku 7b.
    public bool HladinaKlimaZapnuta { get; init; } = true;
    /// <summary>Odtok w, pod kterým není bez jiného zdroje hladina vůbec.</summary>
    public double HladinaWPrah { get; init; } = 0.05;
    /// <summary>Odtok w, od kterého je hladina plně dobitá (sklonová hladina bez snížení); mezi prahem a plným smoothstep.</summary>
    public double HladinaWPlna { get; init; } = 0.3;
    /// <summary>Snížení hladiny (m) při nejmenším dobití nad nulou (e → 0+).</summary>
    public double HladinaSuchoM { get; init; } = 30.0;
    /// <summary>Pobřeží: do této vzdálenosti od moře plné dobití (m), do HladinaBrehDoM se smoothstep ztrácí.</summary>
    public double HladinaBrehPlneM { get; init; } = 100.0;
    public double HladinaBrehDoM { get; init; } = 400.0;
    /// <summary>Aktivní koryta a dnešní tok mimo koryto.</summary>
    public double HladinaKorytoPlneM { get; init; } = 48.0;
    public double HladinaKorytoDoM { get; init; } = 160.0;
    /// <summary>Vodníci a oázy.</summary>
    public double HladinaZdrojPlneM { get; init; } = 96.0;
    public double HladinaZdrojDoM { get; init; } = 250.0;
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
