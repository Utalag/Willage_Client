using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Výstup M4: svět planety, parametry eroze, mapa (WGER), eroze světa a vodníci kroku 6. Zapnuto = false → vše null.</summary>
public sealed record VystupEroze(bool Zapnuto, SvetFn? SvetPlanety, ParametryEroze? Parametry, MapaEroze? Mapa, ErozeSvetaFn? Eroze, List<Vodnik> Vodnici)
{
    public static readonly VystupEroze Vypnuto = new(false, null, null, null, null, new());
}

/// <summary>
/// M4 Eroze planety (krok 6): přesně jako KonfiguraceSveta.Sestav – svět planety z {Seed, VseKrok06, StartBlok} + more_v1.json
/// (ostatní parametry vstupu do mapy dnes nevstupují, viz PROP G-1), mapa z keše WGER s dnešním klíčem, ErozeSvetaFn, vodníci.
/// </summary>
public sealed class M4Eroze : ModulZaklad
{
    public const string Id_ = "M4";
    public override string Id => Id_;
    public override string Nazev => "Eroze planety";
    public override IReadOnlyList<string> Zavislosti => new[] { M2MoreAKontinenty.Id_ };
    public override IReadOnlyList<string> Soubory => new[] { "v1/eroze_v1.json" };
    /// <summary>Celé parametry eroze (i pole pro koryta a vodníky, která klíč WGER vynechává – výstup M4 vodníky obsahuje).</summary>
    public override string Parametry(KontextBehu k) => KanonickeParametry.Json(k.Nastaveni.Eroze);

    public override object Spust(KontextBehu k)
    {
        var p = k.Parametry;
        if (!p.VseKrok06) return VystupEroze.Vypnuto;
        var pe = k.Nastaveni.Eroze;
        var pp = ErozePlanety.NactiMore(new ParametrySveta { Seed = p.Seed, VseKrok06 = true, StartBlok = (int[])p.StartBlok.Clone() }, k.Data);
        var sp = ErozePlanety.SvetPlanety(pp, k.Data, pe);
        var m = ErozePlanety.Mapa(sp, k.Data, pe, k.Kes, k.Vlaken);
        return new VystupEroze(true, sp, pe, m, new ErozeSvetaFn(m, pe), Vodnici.Najdi(m, sp, pe));
    }
}
