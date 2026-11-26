using System.Text.Json;

namespace Willage.Gen.Voda;

/// <summary>Parametry kroku 4 (data/v1/voda_v1.json); výchozí hodnoty = PROP krok04.</summary>
public sealed record ParametryVody
{
    public uint Seed { get; init; } = 49;
    // regionální hladina
    public double MrizkaHladinyM { get; init; } = 8.0;
    public double PolomerHladinyM { get; init; } = 48.0;
    public double HloubkaD0M { get; init; } = 1.5;
    public double ZesileniUdoliBeta { get; init; } = 1.0;
    // profil sloupce
    public double FilmM { get; init; } = 0.5;
    // artéská voda
    public double MrizkaDoplnM { get; init; } = 8.0;
    public double PolomerDoplnM { get; init; } = 192.0;
    // prameny
    public double BunkaPramenuM { get; init; } = 24.0;   // Jan 2026-11-26 9:32: 24 m / 0,6 (dříve 32 m)
    public double KrokKandidatuM { get; init; } = 2.0;
    public double PravdepodobnostBunky { get; init; } = 0.6;
    public double RozestupM { get; init; } = 8.0;
    public double SklonKontakt { get; init; } = 0.5;
    public double QSnih { get; init; } = 4.0;
    public double QKontakt { get; init; } = 1.5;
    public double QKras { get; init; } = 5.0;
    public double QVyver { get; init; } = 1.0;
    public bool Tlakovy { get; init; } = false;
    // krok 5 (Jan 2026-11-26, rozhodnutí 3): nitro sopky (průduch, láva, popel) je pro vodu těsnění; false = krok 4
    public bool SopkaNepropustna { get; init; } = true;
    // krok 6b: hladina se počítá z povrchu před erozí a sníží se o hrubou erozi (koryto pak hladinu odkryje); bez eroze beze změny
    public bool HladinaSledujeErozi { get; init; } = true;

    public static ParametryVody ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryVody>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
}
