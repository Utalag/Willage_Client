using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>
/// M1 Funkce světa (krok 2): SvetFn – mapa biomů, reliéf, masiv, sopky, mapa hornin. Výstup = funkce světa bez moře a pánví
/// (izolace „jen reliéf“; náhledy G-6), staví se líně až při prvním čtení (hotový svět ji nepotřebuje).
/// Dnešní SvetFn moře staví ve stejném konstruktoru, proto M2 staví vlastní SvetFn.
/// </summary>
public sealed record VystupFunkceSveta(Lazy<SvetFn> BezMore)
{
    public SvetFn Svet => BezMore.Value;
}

public sealed class M1FunkceSveta : ModulZaklad
{
    public const string Id_ = "M1";
    public override string Id => Id_;
    public override string Nazev => "Funkce světa";
    public override IReadOnlyList<string> Zavislosti => new[] { M0Planeta.Id_ };
    public override IReadOnlyList<string> Soubory => new[] { "klima_presety.csv" };
    public override string Parametry(KontextBehu k) => KanonickeParametry.Pole(k.Parametry, RozdeleniParametru.M1);

    public override object Spust(KontextBehu k)
    {
        var p = k.Parametry.Kopie(); p.More = false; p.Panve = false; p.VseKrok06 = false;
        var d = k.Data;
        return new VystupFunkceSveta(new Lazy<SvetFn>(() => new SvetFn(p, d)));
    }
}
