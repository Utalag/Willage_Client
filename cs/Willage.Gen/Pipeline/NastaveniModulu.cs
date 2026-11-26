using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Voda;

namespace Willage.Gen.Pipeline;

/// <summary>
/// Parametry modulů M4–M6 načtené z JSON v data/v1 (dnešní stav). Konfigurátor (G-2, G-5) je bude moci přepsat v paměti;
/// klíč modulu pak bere přepsanou hodnotu (kanonicky) i SHA souboru.
/// </summary>
public sealed class NastaveniModulu
{
    public ParametryEroze Eroze { get; init; } = new();
    public ParametryKlimatu Klima { get; init; } = new();
    public ParametryVody Voda { get; init; } = new();
    public string PrusakJson { get; init; } = "";

    public static NastaveniModulu ZDat(DataSveta d) => new()
    {
        Eroze = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)),
        Klima = ParametryKlimatu.ZJson(File.ReadAllText(d.KlimaV1)),
        Voda = ParametryVody.ZJson(File.ReadAllText(d.VodaV1)),
        PrusakJson = File.ReadAllText(d.PrusakV1),
    };
}
