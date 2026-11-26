using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda;

/// <summary>
/// Krok 4: funkce světa III – podzemní voda a prameny. Skládá hladinu, profil sloupce, doplňování a prameny;
/// sama nic neukládá. Vstupem je jen geologie (IGeologie) a parametry se seedem.
/// </summary>
public sealed class PodzemniVodaFn
{
    public IGeologie Geologie { get; }
    public Propustnost Propustnost { get; }
    public ParametryVody P { get; }
    public RegionalniHladina Hladina { get; }
    public Doplnovani Doplnovani { get; }
    public Prameny Prameny { get; }

    public PodzemniVodaFn(IGeologie geologie, KatalogMaterialu katalog, ParametryVody p)
    {
        Geologie = geologie as KesGeologie ?? new KesGeologie(geologie);
        Propustnost = new Propustnost(katalog);
        P = p;
        Hladina = new RegionalniHladina(Geologie, p);
        Doplnovani = new Doplnovani(Geologie, p);   // výchoz v nitru sopky se při SopkaNepropustna nepočítá (viz Doplnovani)
        Prameny = new Prameny(Geologie, Hladina, Propustnost, p);
    }

    public ProfilSloupce Profil(double x, double y) =>
        ProfilSloupce.Spocti(Geologie.Sloupec(x, y), Geologie.Povrch(x, y), Hladina.Hladina(x, y), Propustnost, P.FilmM, Nitro(x, y));

    /// <summary>Maska nitra sopky, když je přepínač SopkaNepropustna zapnutý.</summary>
    public bool[]? Nitro(double x, double y) => P.SopkaNepropustna ? Geologie.NitroSopky(x, y) : null;

    /// <summary>Tlaková výška sevřené vrstvy (= výška doplňování) nebo null.</summary>
    public double? TlakovaVyska(double x, double y, SevrenaVrstva v) => Doplnovani.Vyska(x, y, v.Material)?.vyska;

    /// <summary>Skutečný výkon pramene ve výchozím světě (sousední buňky z geologie).</summary>
    public VykonPramene.Vysledek Vykon(Pramen s)
    {
        Span<int> sous = stackalloc int[6];
        var col = Geologie.Sloupec(s.X, s.Y);
        int kz = s.Kz;
        var ni = Nitro(s.X, s.Y);
        sous[0] = kz + 1 < col.Length && (kz + 1) * GeologyGridConstants.CellM < Geologie.Povrch(s.X, s.Y) ? (ni?[kz + 1] == true ? -1 : col[kz + 1]) : 0;
        sous[1] = kz > 0 ? (ni?[kz - 1] == true ? -1 : col[kz - 1]) : 6;
        double c = GeologyGridConstants.CellM;
        int i = 2;
        foreach (var (dx, dy) in new[] { (c, 0.0), (-c, 0.0), (0.0, c), (0.0, -c) })
        {
            double nx = s.X + dx, ny = s.Y + dy;
            sous[i++] = (kz + 0.5) * c < Geologie.Povrch(nx, ny) ? (Nitro(nx, ny)?[kz] == true ? -1 : Geologie.Sloupec(nx, ny)[kz]) : 0;
        }
        double strop = (Doplnovani.Vyska(s.X, s.Y, s.AkviferMaterial)?.vyska ?? Hladina.Surova(s.X, s.Y)) - s.Z;
        return VykonPramene.Spocti(s.Jmenovity, sous, Propustnost, P.Tlakovy, strop);
    }

    /// <summary>Hladina na mřížce bloku 128 m (středy buněk kroku krok, řádky po y).</summary>
    public BlokVody Blok(int bx, int by, double krok, bool profily)
    {
        int n = (int)Math.Round(GeologyGridConstants.BlockM / krok);
        double x0 = bx * GeologyGridConstants.BlockM, y0 = by * GeologyGridConstants.BlockM;
        var b = new BlokVody(bx, by, krok, n);
        for (int j = 0; j < n; j++)
        for (int i = 0; i < n; i++)
        {
            double x = x0 + (i + 0.5) * krok, y = y0 + (j + 0.5) * krok;
            int k = j * n + i;
            b.Povrch[k] = Geologie.Povrch(x, y);
            b.Surova[k] = Hladina.Surova(x, y);
            b.L[k] = Math.Min(b.Surova[k], b.Povrch[k]);
            if (profily) b.Profily[k] = Profil(x, y);
        }
        b.Prameny.AddRange(Prameny.VOblasti(x0, y0, x0 + GeologyGridConstants.BlockM, y0 + GeologyGridConstants.BlockM));
        return b;
    }
}

/// <summary>Výsledek funkce na mřížce jednoho bloku (jen pro testy a zobrazení, neukládá se).</summary>
public sealed class BlokVody
{
    public int Bx { get; }
    public int By { get; }
    public double Krok { get; }
    public int N { get; }
    public double[] Povrch { get; }
    public double[] Surova { get; }
    public double[] L { get; }
    public ProfilSloupce?[] Profily { get; }
    public List<Pramen> Prameny { get; } = new();

    public BlokVody(int bx, int by, double krok, int n)
    {
        Bx = bx; By = by; Krok = krok; N = n;
        Povrch = new double[n * n]; Surova = new double[n * n]; L = new double[n * n]; Profily = new ProfilSloupce?[n * n];
    }
}
