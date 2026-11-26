using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>
/// Výstup M6: dobití hladiny podzemní vody (krok 7c, null = vypnuto nebo bez klimatu), načtené parametry vody, průsaku a katalog;
/// voda se dál počítá líně po blocích (SvetKrok06.Voda).
/// </summary>
public sealed record VystupVody(NapajeniVody? Napajeni, ParametryVody Parametry, string PrusakJson, KatalogMaterialu Katalog)
{
    public PodzemniVodaFn Voda(SvetKrok06 svet, ParametryVody? pv = null) => svet.Voda(Katalog, pv ?? Parametry, PrusakJson);
}

/// <summary>
/// M6 Voda a průsak (kroky 4, 6e–6g, 7c, průsak): hladina, dobití hladiny podle klimatu (NapajeniVody, 7c), prameny, vodníci,
/// pobřežní pás. Závisí na geologii (M3) a klimatu (M5). Spočte dobití (jako Sestav v 7c, parametry Hladina* z klima_v1.json
/// – jsou v klíči M5, na kterém M6 závisí), načte a zkontroluje parametry vody a průsaku; výpočet vody v blocích zůstává líný.
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
        var e = k.Vystup<VystupEroze>(M4Eroze.Id_); var c = k.Vystup<VystupKlimatu>(M5KlimaABiomy.Id_);
        var nap = c.Zapnuto && c.Parametry!.HladinaKlimaZapnuta ? NapajeniVody.Spocti(e.Mapa!, c.Mapa!, c.Hydrologie!, c.Vodnici, c.Parametry) : null;
        var kat = KatalogMaterialu.ZeSouboru(k.Data.KatalogMaterialu);
        _ = new PrusakKoeficient(kat, k.Nastaveni.PrusakJson);   // kontrola dat průsaku nad katalogem (vyhodí chybu jako dnes)
        return new VystupVody(nap, k.Nastaveni.Voda, k.Nastaveni.PrusakJson, kat);
    }
}
