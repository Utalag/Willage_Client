namespace Willage.Gen.Geo2;

/// <summary>Obdélník bloku v rovině xy [m], hranice včetně.</summary>
public readonly record struct OblastBloku(double X0, double Y0, double X1, double Y1)
{
    public static OblastBloku Ctverec(double ox, double oy, double strana) => new(ox, oy, ox + strana, oy + strana);
    public OblastBloku Rozsir(double m) => new(X0 - m, Y0 - m, X1 + m, Y1 + m);
    public bool Obsahuje(double x, double y) => x >= X0 && x <= X1 && y >= Y0 && y <= Y1;
}

/// <summary>
/// Tvar, zásobník nebo plocha, která si před výpočtem bloku postaví neměnná data (index, předpočtené uzly) pro oblast s okrajem (3.5).
/// Po přípravě MUSÍ být vláknově bezpečná bez zámků (3.6).
/// </summary>
public interface IPripravaBloku
{
    void Priprav(OblastBloku oblastSOkrajem, int vlaken);
}

/// <summary>
/// Kontext bloku (kap. 3.5, K3): neměnný, postavený celý předem pro blok + okraj. Drží jednu chronologii pro všechna vlákna
/// (náhrada <c>GeologieCs.Klon()</c> na vlákno); tvary a plochy kontaktu si v <see cref="IPripravaBloku.Priprav"/> postaví index
/// těles po dlaždicích a předpočtené uzly. Okraj = Σ (R_max + η) přes kontakty + 1 uzel mřížky hranic (bod q′ kontaktu a uzly
/// nejbližšího bodu plochy leží v něm). Výsledek je bitově stejný jako chronologie bez kontextu.
/// </summary>
public sealed class KontextBloku : IGeologieGeo2
{
    public ChronologieGeo2 Chronologie { get; }
    public OblastBloku Oblast { get; }
    public double OkrajM { get; }
    public OblastBloku OblastSOkrajem => Oblast.Rozsir(OkrajM);
    /// <summary>Počet připravených objektů (tvary, zásobníky, plochy).</summary>
    public int Pripravenych { get; }
    private readonly VzorkovacGeo2 _v;

    private KontextBloku(ChronologieGeo2 c, OblastBloku o, double okraj, int pripravenych)
    {
        Chronologie = c; Oblast = o; OkrajM = okraj; Pripravenych = pripravenych; _v = new VzorkovacGeo2(c);
    }

    /// <summary>Okraj kontextu [m]: Σ (R_max + η) přes kontaktní pásma (prefix může obsahovat starší kontakt) + krok mřížky hranic.</summary>
    public static double Okraj(ChronologieGeo2 c, double krokMrizkyM)
    {
        double o = krokMrizkyM;
        foreach (var e in c.Udalosti)
            if (e.Kontakt is KontaktniPasmo k) o += k.RMaxM + k.Parametry.HloubkaVzorkuM;
        return o;
    }

    public static KontextBloku Sestav(ChronologieGeo2 c, OblastBloku oblast, double krokMrizkyM, int vlaken = 0)
    {
        if (vlaken <= 0) vlaken = Environment.ProcessorCount;
        double okraj = Okraj(c, krokMrizkyM);
        var os = oblast.Rozsir(okraj);
        var hotovo = new HashSet<object>(ReferenceEqualityComparer.Instance);
        void P(object? x) { if (x is IPripravaBloku p && hotovo.Add(p)) p.Priprav(os, vlaken); }
        foreach (var e in c.Udalosti)
        {
            P(e.Tvar); P(e.Zasobnik);
            if (e.Kontakt is KontaktniPasmo k) foreach (var pl in k.Plochy) P(pl);
        }
        return new KontextBloku(c, oblast, okraj, hotovo.Count);
    }

    public double Povrch(double x, double y) => _v.Povrch(x, y);
    public Vzorek Vzorek(double x, double y, double z) => _v.Vzorek(x, y, z);
    public void Sloupec(double x, double y, double z0, double krokZ, Span<Vzorek> cil) => _v.Sloupec(x, y, z0, krokZ, cil);
    public StavBodu Bod(double x, double y, double z, double zPov) => Chronologie.Bod(x, y, z, zPov);
}
