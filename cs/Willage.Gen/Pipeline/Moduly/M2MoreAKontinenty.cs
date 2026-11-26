using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>M2 Moře a kontinenty (kroky 6b–6d): SvetFn startovního světa s MaskaPevniny, MoreSklon a Panve podle přepínačů M0.</summary>
public sealed class M2MoreAKontinenty : ModulZaklad
{
    public const string Id_ = "M2";
    public override string Id => Id_;
    public override string Nazev => "Moře a kontinenty";
    public override IReadOnlyList<string> Zavislosti => new[] { M1FunkceSveta.Id_ };
    public override IReadOnlyList<string> Soubory => new[] { "v1/more_v1.json" };
    public override string Parametry(KontextBehu k) => KanonickeParametry.Pole(k.Parametry, RozdeleniParametru.M2);
    public override object Spust(KontextBehu k) => new SvetFn(k.Parametry.Kopie(), k.Data);
}
