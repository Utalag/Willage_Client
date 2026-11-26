using Willage.Gen.Geologie;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>
/// M3 Geologie (kroky 3, 5): GeologieCs (vrstvy, útvary, mince E82, nitro sopky) nad vlastní funkcí světa (bez eroze).
/// Erozi do ní napojuje až M7 (jediné místo mutace).
/// </summary>
public sealed class M3Geologie : ModulZaklad
{
    public const string Id_ = "M3";
    public override string Id => Id_;
    public override string Nazev => "Geologie";
    public override IReadOnlyList<string> Zavislosti => new[] { M2MoreAKontinenty.Id_ };
    public override IReadOnlyList<string> Soubory => new[]
    {
        "teren/poradi_hornin.json", "materialy_v1.csv", "v1/utvary_hostitele.json", "v1/sum_hornin_v1.csv", "teren/mineraly_hostitele.json",
    };
    public override string Parametry(KontextBehu k) => KanonickeParametry.Pole(k.Parametry, RozdeleniParametru.M3);
    public override object Spust(KontextBehu k) => new GeologieCs(k.Parametry.Kopie(), k.Data);
}
