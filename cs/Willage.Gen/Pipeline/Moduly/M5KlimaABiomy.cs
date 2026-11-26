using Willage.Gen.Eroze;
using Willage.Gen.Klima;

namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Výstup M5 (krok 7, 7b): mapa klimatu, hydrologie, oázy a dnešní vodníci (síť klimatu + oázy). Zapnuto = false → null.</summary>
public sealed record VystupKlimatu(bool Zapnuto, ParametryKlimatu? Parametry, MapaKlimatu? Mapa, HydrologieKlimatu? Hydrologie, List<Vodnik> Oazy, List<Vodnik> Vodnici)
{
    public static readonly VystupKlimatu Vypnuto = new(false, null, null, null, new(), new());
}

/// <summary>M5 Klima a biomy nad hotovou mapou eroze (mapu nemění, Jan 12:26). Klíč klimatu v mapě = dnešní MapaKlimatu.KlicKlimatu.</summary>
public sealed class M5KlimaABiomy : ModulZaklad
{
    public const string Id_ = "M5";
    public override string Id => Id_;
    public override string Nazev => "Klima a biomy";
    public override IReadOnlyList<string> Zavislosti => new[] { M4Eroze.Id_ };
    public override IReadOnlyList<string> Soubory => new[] { "v1/klima_v1.json" };
    /// <summary>Parametry klimatu bez dobití hladiny 7c (to patří M6, G-2).</summary>
    public override string Parametry(KontextBehu k) => KanonickeParametry.BezVlastnosti(k.Nastaveni.Klima, RozdeleniParametru.KlimaProM6).Kanonicky(k.Parametry.Klima);

    public override object Spust(KontextBehu k)
    {
        var p = k.Parametry; var e = k.Vystup<VystupEroze>(M4Eroze.Id_);
        if (!e.Zapnuto || !p.KlimaKrok07) return VystupKlimatu.Vypnuto;
        var pk = k.Nastaveni.Klima; var m = e.Mapa!;
        var mk = MapaKlimatu.Spocti(m, pk, pk.Planeta(p.Klima), k.Vlaken);
        mk.Klic = MapaKlimatu.KlicKlimatu(m.KlicKese, pk, p.Klima);
        var hk = HydrologieKlimatu.Spocti(m, mk, e.Parametry!);
        var oazy = Oazy.Najdi(m, mk, pk, p.Seed); Oazy.Prekryj(mk, oazy, pk);
        var vod = hk.Vodnici(m, e.SvetPlanety!, e.Parametry!); vod.AddRange(oazy);
        return new VystupKlimatu(true, pk, mk, hk, oazy, vod);
    }
}
