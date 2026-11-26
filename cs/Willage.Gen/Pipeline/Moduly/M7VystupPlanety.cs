using Willage.Gen.Eroze;
using Willage.Gen.Geologie;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Souhrn planety pro diagnostiku a budoucí WPLN (G-3): otisky a počty.</summary>
public sealed record SouhrnPlanety(string? OtiskMapy, string? KlicMapy, string? OtiskKlimatu, string? KlicKlimatu, int Vodniku, int Oaz, string ManifestSouhrn);

public sealed record VystupPlanety(SvetKrok06 Svet, SouhrnPlanety Souhrn);

/// <summary>
/// M7 Výstup planety: sestaví SvetKrok06 ve stejném tvaru jako dnešní KonfiguraceSveta.Sestav (napojí erozi do geologie M3)
/// a souhrn otisků. Klíč bere i souhrn manifestu (planeta zapisuje verze katalogů), proto ho změní i soubor, který žádný modul nečte.
/// </summary>
public sealed class M7VystupPlanety : ModulZaklad
{
    public const string Id_ = "M7";
    public override string Id => Id_;
    public override string Nazev => "Výstup planety";
    public override IReadOnlyList<string> Zavislosti => new[] { M3Geologie.Id_, M4Eroze.Id_, M5KlimaABiomy.Id_, M6VodaAPrusak.Id_ };
    public override string Parametry(KontextBehu k) => "manifest=" + k.Manifest.Souhrn;

    public override object Spust(KontextBehu k)
    {
        var p = k.Parametry;
        var g = k.Vystup<GeologieCs>(M3Geologie.Id_);
        var e = k.Vystup<VystupEroze>(M4Eroze.Id_);
        var c = k.Vystup<VystupKlimatu>(M5KlimaABiomy.Id_);
        var v = k.Vystup<VystupVody>(M6VodaAPrusak.Id_);
        g.Svet.Eroze = e.Eroze;
        SvetKrok06 s;
        if (!e.Zapnuto) s = new SvetKrok06 { Geologie = g };
        else if (!c.Zapnuto) s = new SvetKrok06 { Geologie = g, Mapa = e.Mapa, Eroze = e.Eroze, Vodnici = e.Vodnici };
        else s = new SvetKrok06
        {
            Geologie = g, Mapa = e.Mapa, Eroze = e.Eroze, Vodnici = c.Vodnici, VodniciBezKlimatu = e.Vodnici, Oazy = c.Oazy,
            Klima = new Klima.KlimaSvetaFn(c.Mapa!), Hydrologie = c.Hydrologie, ParametryKlimatu = c.Parametry, Napajeni = v.Napajeni,
        };
        var sh = new SouhrnPlanety(e.Mapa is null ? null : SouborMapy.Otisk(e.Mapa), e.Mapa?.KlicKese, c.Mapa?.Otisk(), c.Mapa?.Klic, s.Vodnici.Count, s.Oazy.Count, k.Manifest.Souhrn);
        return new VystupPlanety(s, sh);
    }
}
