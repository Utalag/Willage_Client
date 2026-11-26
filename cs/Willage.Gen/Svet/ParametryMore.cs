using System.Text.Json;

namespace Willage.Gen.Svet;

/// <summary>Krok 6b/6c: ladicí parametry moře, kontinentů, sklonu a pánví z data/v1/more_v1.json (výchozí = hodnoty v ParametrySveta).</summary>
public sealed record ParametryMore
{
    public double PodilMore { get; init; } = 0.30;
    public double OdchylkaMoreProcBodu { get; init; } = 5.0;
    public double HladinaMoreM { get; init; } = 60.0;
    public double HloubkaMoreM { get; init; } = 25.0;
    public double SklonKontinentu { get; init; } = 0.002;
    public double SklonOdPobreziM { get; init; } = 1400.0;
    public int KontinentuMin { get; init; } = 2;
    public int KontinentuMax { get; init; } = 4;
    public double KontinentVelikost { get; init; } = 1.0;
    public double Clenitost { get; init; } = 1.0;
    public double ClenitostSila { get; init; } = 0.35;
    public int SumVln { get; init; } = 48;
    public int WarpVln { get; init; } = 24;
    public double SumLambdaMinM { get; init; } = 600.0;
    public double SumLambdaMaxM { get; init; } = 8000.0;
    public double WarpLambdaMinM { get; init; } = 2000.0;
    public double WarpM { get; init; } = 1200.0;
    public double MorePrechod { get; init; } = 0.04;
    public double RezervaSevuM { get; init; } = 512.0;
    public double SevPrechodM { get; init; } = 400.0;
    public double SevMekkySpad { get; init; } = 0.4;
    public double SevMekkyPasM { get; init; } = 3000.0;
    public double StartPolomerM { get; init; } = 400.0;
    public double StartPrechodM { get; init; } = 1200.0;
    public double StartRezerva { get; init; } = 0.05;
    public double MrizkaPrahuM { get; init; } = 128.0;
    public double MrizkaVzdalenostiM { get; init; } = 64.0;
    public int PanviPocet { get; init; } = 4;
    public double PanevPolomerM { get; init; } = 1500.0;
    public double PanevHloubkaM { get; init; } = 15.0;

    public static ParametryMore ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryMore>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();

    /// <summary>Zapíše parametry do parametrů světa (přepínače More/Panve/VseKrok06 nemění).</summary>
    public ParametrySveta Uplatni(ParametrySveta p)
    {
        p.PodilMore = PodilMore; p.OdchylkaMoreProcBodu = OdchylkaMoreProcBodu; p.HladinaMoreM = HladinaMoreM; p.HloubkaMoreM = HloubkaMoreM;
        p.SklonKontinentu = SklonKontinentu; p.SklonOdPobreziM = SklonOdPobreziM;
        p.KontinentuMin = KontinentuMin; p.KontinentuMax = KontinentuMax; p.KontinentVelikost = KontinentVelikost;
        p.Clenitost = Clenitost; p.ClenitostSila = ClenitostSila; p.SumVln = SumVln; p.WarpVln = WarpVln;
        p.SumLambdaMinM = SumLambdaMinM; p.SumLambdaMaxM = SumLambdaMaxM; p.WarpLambdaMinM = WarpLambdaMinM; p.WarpM = WarpM;
        p.MorePrechod = MorePrechod; p.RezervaSevuM = RezervaSevuM; p.SevPrechodM = SevPrechodM; p.SevMekkySpad = SevMekkySpad; p.SevMekkyPasM = SevMekkyPasM;
        p.StartPolomerM = StartPolomerM; p.StartPrechodM = StartPrechodM; p.StartRezerva = StartRezerva;
        p.MrizkaPrahuM = MrizkaPrahuM; p.MrizkaVzdalenostiM = MrizkaVzdalenostiM;
        p.PanviPocet = PanviPocet; p.PanevPolomerM = PanevPolomerM; p.PanevHloubkaM = PanevHloubkaM;
        return p;
    }

    /// <summary>Kanonický zápis všech ladicích parametrů (klíč keše).</summary>
    public string Kanonicky() => JsonSerializer.Serialize(this);
}
