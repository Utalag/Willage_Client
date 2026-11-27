namespace Willage.Gen.Geo2;

/// <summary>Výkopy (hráč, stavby) jako překryv nad geologií: geologie se nemění, vzorek dostane <see cref="TypProstoru.Vykopano"/>.</summary>
public interface IVykopy
{
    bool Vykopano(double x, double y, double z);
}

/// <summary>Třída buňky pro vodu: vzduch nad povrchem / volný prostor pod povrchem (dutina, výkop) / hornina (propustnost podle materiálu).</summary>
public enum TridaVody : byte { Vzduch = 0, VolnyProstor = 1, Hornina = 2 }

/// <summary>
/// Rozhraní, které bude číst voda místo bajtů sloupce (K7; v K2 se voda na GEO2 nenapojuje). Na rozdíl od dnešního
/// <c>IGeologie.Sloupec</c> (materiál 0 = vzduch i dutina, rozliší je jen povrch) nese každý vzorek typ prostoru.
/// </summary>
public interface IGeologieGeo2
{
    double Povrch(double x, double y);
    Vzorek Vzorek(double x, double y, double z);
    /// <summary>Vzorky ve středech buněk: z = z0 + (k + ½)·krokZ, k = 0 … cil.Length − 1.</summary>
    void Sloupec(double x, double y, double z0, double krokZ, Span<Vzorek> cil);
}

/// <summary>Vzorkování chronologie s volitelným překryvem výkopů. Nic se neukládá; vláknově jako chronologie.</summary>
public sealed class VzorkovacGeo2 : IGeologieGeo2
{
    private readonly ChronologieGeo2 _c;
    private readonly IVykopy? _v;

    public VzorkovacGeo2(ChronologieGeo2 c, IVykopy? vykopy = null)
    {
        if (c.Povrch is null) throw new ArgumentException("chronologie musí mít povrch (ITovarnaTvaru.Povrch)", nameof(c));
        _c = c; _v = vykopy;
    }

    public double Povrch(double x, double y) => _c.Povrch!(x, y);

    public Vzorek Vzorek(double x, double y, double z) => Prekryv(x, y, z, _c.Vzorek(x, y, z));

    public void Sloupec(double x, double y, double z0, double krokZ, Span<Vzorek> cil)
    {
        double zPov = Povrch(x, y);
        for (int k = 0; k < cil.Length; k++)
        {
            double z = z0 + (k + 0.5) * krokZ;
            cil[k] = Prekryv(x, y, z, _c.Vzorek(x, y, z, zPov));
        }
    }

    /// <summary>Výkop: materiál 0, typ Vykopano; geometrický původ a hostitel zůstanou (co tam bylo).</summary>
    private Vzorek Prekryv(double x, double y, double z, Vzorek v) =>
        _v is not null && v.Typ != TypProstoru.NadPovrchem && _v.Vykopano(x, y, z) ? v with { Material = 0, Typ = TypProstoru.Vykopano } : v;
}

/// <summary>Převod vzorků na vstup vody (K7 ho napojí; dnešní voda zůstává na <c>IGeologie</c>).</summary>
public static class ProstorVody
{
    public static TridaVody Trida(in Vzorek v) => v.Typ switch
    {
        TypProstoru.NadPovrchem => TridaVody.Vzduch,
        TypProstoru.DutinaKras or TypProstoru.DutinaJina or TypProstoru.Vykopano => TridaVody.VolnyProstor,
        _ => TridaVody.Hornina,
    };

    /// <summary>Materiály jako dnešní bajtový sloupec (volný prostor i vzduch = 0) a třídy buněk, které dnes voda odvozuje z povrchu.</summary>
    public static void DoSloupce(ReadOnlySpan<Vzorek> vzorky, Span<byte> materialy, Span<TridaVody> tridy)
    {
        for (int k = 0; k < vzorky.Length; k++)
        {
            var t = Trida(vzorky[k]);
            tridy[k] = t;
            materialy[k] = t == TridaVody.Hornina ? (byte)vzorky[k].Material : (byte)0;
        }
    }
}
