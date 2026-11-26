using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Výstup M4: svět planety, parametry eroze, mapa (WGER), eroze světa a vodníci kroku 6. Zapnuto = false → vše null.</summary>
public sealed record VystupEroze(bool Zapnuto, SvetFn? SvetPlanety, ParametryEroze? Parametry, MapaEroze? Mapa, ErozeSvetaFn? Eroze, List<Vodnik> Vodnici)
{
    public static readonly VystupEroze Vypnuto = new(false, null, null, null, null, new());
}

/// <summary>
/// M4 Eroze planety (krok 6): jako původní KonfiguraceSveta.Sestav – svět planety z {Seed, VseKrok06, StartBlok}, moře (M2) ze vstupu
/// a jinak more_v1.json (reliéf M1 do mapy dnes nevstupuje, viz PROP G-1), mapa z keše WGER s dnešním klíčem, ErozeSvetaFn, vodníci.
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
        var pp = new ParametrySveta { Seed = p.Seed, VseKrok06 = true, StartBlok = (int[])p.StartBlok.Clone() };
        // G-2: moře planety = moře vstupu (pole M2), aby maska startu a mapy eroze byla stejná i při moři nastaveném v ParametrySveta.
        // Výchozí pole M2 = more_v1.json, výchozí svět se nemění. Reliéf (M1) planeta dál bere výchozí (nález G-1, beze změny).
        foreach (var n in RozdeleniParametru.M2) { var f = typeof(ParametrySveta).GetField(n)!; f.SetValue(pp, f.GetValue(p)); }
        ErozePlanety.NactiMore(pp, k.Data);
        var sp = ErozePlanety.SvetPlanety(pp, k.Data, pe);
        var m = ErozePlanety.Mapa(sp, k.Data, pe, k.Kes, k.Vlaken);
        return new VystupEroze(true, sp, pe, m, new ErozeSvetaFn(m, pe), Vodnici.Najdi(m, sp, pe));
    }
}
