using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>M0 Planeta (krok 1): seed, rozměry, start, klima planety a přepínače. Výstup = efektivní ParametrySveta (jen ke čtení).</summary>
public sealed class M0Planeta : ModulZaklad
{
    public const string Id_ = "M0";
    public override string Id => Id_;
    public override string Nazev => "Planeta";
    public override IReadOnlyList<string> Zavislosti => Array.Empty<string>();
    public override string Parametry(KontextBehu k) => KanonickeParametry.Pole(k.Parametry, RozdeleniParametru.M0);
    public override object Spust(KontextBehu k) => k.Parametry;
}
