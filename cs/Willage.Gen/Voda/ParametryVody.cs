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
    // profil sloupce
    public double FilmM { get; init; } = 0.5;
    // artéská voda
    public double MrizkaDoplnM { get; init; } = 8.0;
    public double PolomerDoplnM { get; init; } = 192.0;
    // prameny
    public double BunkaPramenuM { get; init; } = 32.0;
    public double KrokKandidatuM { get; init; } = 2.0;
    public double PravdepodobnostBunky { get; init; } = 0.6;
    public double RozestupM { get; init; } = 8.0;
    public double SklonKontakt { get; init; } = 0.5;
    public double QSnih { get; init; } = 4.0;
    public double QKontakt { get; init; } = 1.5;
    public double QKras { get; init; } = 5.0;
    public double QVyver { get; init; } = 1.0;
    public bool Tlakovy { get; init; } = false;

    public static ParametryVody ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryVody>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
}
