using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>Kontext bloku (K3) pro sadu E84 nad starou cestou: kompilace s indexem těles a příprava pro blok + okraj.</summary>
public static class KontextBlokuE84
{
    /// <summary>Jedna <paramref name="g"/> (bez <c>Klon()</c>) pro všechna vlákna; stará cesta se jen čte.</summary>
    public static (KontextBloku k, VysledekKompilace r) Sestav(GeoVrstvy g, KatalogGeo2 kat, string json, OblastBloku oblast,
        MoznostiKompilace? moznosti = null, int vlaken = 0)
    {
        moznosti ??= MoznostiKompilace.Vychozi;
        var t = new TovarnaE84(g, indexBloku: true);
        var r = KompilatorChronologie.Kompiluj(UdalostiJson.Nacti(json), kat, t, moznosti);
        if (!r.Ok) return (null!, r);
        return (KontextBloku.Sestav(r.Chronologie!, oblast, moznosti.KrokMrizkyHranicM ?? 0.5, vlaken), r);
    }
}
