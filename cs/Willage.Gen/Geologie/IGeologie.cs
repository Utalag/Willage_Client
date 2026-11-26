namespace Willage.Gen.Geologie;

/// <summary>
/// Co krok 4 potřebuje z funkce světa kroků 1–3 (souřadnice světa v m, z nahoru, 0 = dno sloupce 128 m).
/// Dnes ji dává GDScript (svet_fn.gd / geo_vrstvy.gd) přes adaptér GeologieGd; po portu ji dá C# beze změny volajících.
/// </summary>
public interface IGeologie
{
    /// <summary>Povrch v m (svet_fn.vyska).</summary>
    double Povrch(double x, double y);

    /// <summary>Materiály sloupce, 512 buněk po 0,25 m zdola (geo_vrstvy.vypln_sloupec); nad povrchem 0.</summary>
    byte[] Sloupec(double x, double y);

    /// <summary>Materiál nejvyšší pevné buňky (výchoz horniny na povrchu).</summary>
    int MaterialPovrchu(double x, double y);

    /// <summary>Výška tvaru (bez detailu) – odhad hladiny mince E82 (jen pro kontrolu A12).</summary>
    double VyskaTvar(double x, double y);

    /// <summary>Mince E82 sloupce (vápenec zvednut k odhadu hladiny − 2 m).</summary>
    bool Mince82(double x, double y);
}
