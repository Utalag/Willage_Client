namespace Willage.Gen.Geologie;

/// <summary>
/// Co krok 4 potřebuje z funkce světa kroků 1–3 (souřadnice světa v m, z nahoru, 0 = dno sloupce 128 m).
/// Nativně ji dává GeologieCs (krok 5); GDScript přes most GeologieGd zůstává jako reference pro porovnání.
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

    /// <summary>Síla mince E82 0–1 (krok 5: spojitý přechod přes šev bloků); výchozí = mince jako 0/1.</summary>
    double Mince82Sila(double x, double y) => Mince82(x, y) ? 1.0 : 0.0;

    /// <summary>Maska buněk sloupce v nitru sopky (průduch, láva, popel), nebo null mimo sopku. Krok 5: voda je bere jako těsnění.</summary>
    bool[]? NitroSopky(double x, double y) => null;

    /// <summary>Leží bod (z v m) v tělese sopky?</summary>
    bool VNitruSopky(double x, double y, double z) => false;

    /// <summary>Krok 6b: povrch před erozí světa (bez eroze = Povrch).</summary>
    double PovrchBezEroze(double x, double y) => Povrch(x, y);

    /// <summary>Krok 6b: hrubá hloubka eroze světa v bodě (bez koryta), bez eroze 0.</summary>
    double ErozeHruba(double x, double y) => 0.0;
}
