using Willage.Gen.Eroze;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Výstup M6: načtené parametry vody, průsaku a katalog materiálů; voda se dál počítá líně po blocích (SvetKrok06.Voda).</summary>
public sealed record VystupVody(ParametryVody Parametry, string PrusakJson, KatalogMaterialu Katalog)
{
    public PodzemniVodaFn Voda(SvetKrok06 svet, ParametryVody? pv = null) => svet.Voda(Katalog, pv ?? Parametry, PrusakJson);
}

/// <summary>
/// M6 Voda a průsak (kroky 4, 6e–6g, průsak): hladina, prameny, vodníci, pobřežní pás. Závisí na geologii (M3) a klimatu (M5);
/// v G-1 jen načte a zkontroluje parametry (průsakový koeficient nad katalogem), výpočet zůstává líný jako dnes.
/// </summary>
public sealed class M6VodaAPrusak : ModulZaklad
{
    public const string Id_ = "M6";
    public override string Id => Id_;
    public override string Nazev => "Voda a průsak";
    public override IReadOnlyList<string> Zavislosti => new[] { M3Geologie.Id_, M5KlimaABiomy.Id_ };
    public override IReadOnlyList<string> Soubory => new[] { "v1/voda_v1.json", "v1/prusak_v1.json", "v1/materials-catalog-v1.json" };
    public override string Parametry(KontextBehu k) => KanonickeParametry.Json(k.Nastaveni.Voda) + "|prusak=" + Katalogy.ManifestKatalogu.Sha(System.Text.Encoding.UTF8.GetBytes(k.Nastaveni.PrusakJson.Replace("\r\n", "\n")));

    public override object Spust(KontextBehu k)
    {
        var kat = KatalogMaterialu.ZeSouboru(k.Data.KatalogMaterialu);
        _ = new PrusakKoeficient(kat, k.Nastaveni.PrusakJson);   // kontrola dat průsaku nad katalogem (vyhodí chybu jako dnes)
        return new VystupVody(k.Nastaveni.Voda, k.Nastaveni.PrusakJson, kat);
    }
}
