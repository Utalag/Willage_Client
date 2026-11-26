using System.Text.Json;

namespace Willage.Gen.Svet;

/// <summary>Krok 6b: ladicí parametry moře, sklonu a pánví z data/v1/more_v1.json (výchozí = hodnoty v ParametrySveta).</summary>
public sealed record ParametryMore
{
    public double PodilMore { get; init; } = 0.30;
    public double OdchylkaMoreProcBodu { get; init; } = 5.0;
    public double StredMoreM { get; init; } = -1.0;
    public double RezervaSevuM { get; init; } = 512.0;
    public double HladinaMoreM { get; init; } = 60.0;
    public double MorePrechodM { get; init; } = 300.0;
    public double HloubkaMoreM { get; init; } = 25.0;
    public double PobreziSumM { get; init; } = 300.0;
    public double PobreziVlnaM { get; init; } = 1500.0;
    public double SklonKontinentu { get; init; } = 0.002;
    public double SklonOdPobreziM { get; init; } = 1400.0;
    public int PanviPocet { get; init; } = 4;
    public double PanevPolomerM { get; init; } = 1500.0;
    public double PanevHloubkaM { get; init; } = 15.0;

    public static ParametryMore ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryMore>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();

    /// <summary>Zapíše parametry do parametrů světa (přepínače More/Panve nemění).</summary>
    public ParametrySveta Uplatni(ParametrySveta p)
    {
        p.PodilMore = PodilMore; p.OdchylkaMoreProcBodu = OdchylkaMoreProcBodu; p.StredMoreM = StredMoreM; p.RezervaSevuM = RezervaSevuM; p.HladinaMoreM = HladinaMoreM; p.MorePrechodM = MorePrechodM;
        p.HloubkaMoreM = HloubkaMoreM; p.PobreziSumM = PobreziSumM; p.PobreziVlnaM = PobreziVlnaM;
        p.SklonKontinentu = SklonKontinentu; p.SklonOdPobreziM = SklonOdPobreziM;
        p.PanviPocet = PanviPocet; p.PanevPolomerM = PanevPolomerM; p.PanevHloubkaM = PanevHloubkaM;
        return p;
    }
}
