using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Tělesa E84 jednoho druhu přes index bloku (K3): stejný výsledek jako <see cref="TvarE84"/> (nejmenší SDF, pořadí <c>Features</c>),
/// ale bez keše staré cesty – po <see cref="Priprav"/> neměnný a vláknově bezpečný (jedna instance pro všechna vlákna, bez <c>Klon()</c>).
/// SDF se počítá jen u instancí, jejichž přesná obálka (<see cref="ObalkaE84"/>) obsahuje bod.
/// </summary>
public sealed class TvarE84Index : ITvarSMaterialem, IPripravaBloku
{
    private readonly GeoVrstvy _g;
    private readonly ZasobnikVrstvySloupce _zas;
    public DruhUtvaru Druh { get; }
    public IndexUtvaruE84? Index { get; private set; }

    public TvarE84Index(GeoVrstvy g, ZasobnikVrstvySloupce zas, DruhUtvaru druh) { _g = g; _zas = zas; Druh = druh; }

    public void Priprav(OblastBloku oblast, int vlaken) => Index = IndexUtvaruE84.Sestav(_g.Svet, Druh, oblast);

    private Utvar? Vyber(double x, double y, double z)
    {
        var ix = Index ?? throw new InvalidOperationException("TvarE84Index: kontext bloku není připraven (KontextBloku.Sestav)");
        int m = ix.MaxVDlazdici;
        Span<int> k = m <= 256 ? stackalloc int[256] : new int[m];
        int n = ix.Kandidati(x, y, z, k);
        Utvar? vyb = null; double best = 0.0;
        var pol = ix.Polozky;
        for (int i = 0; i < n; i++)
        {
            var f = pol[k[i]].F;
            double d = _g.Utvary.Sdf(f, x, y, z);
            if (d < 0.0 && (vyb is null || d <= best)) { best = d; vyb = f; }
        }
        return vyb;
    }

    public bool Obsahuje(double x, double y, double z, out uint instance)
    {
        var f = Vyber(x, y, z);
        instance = f is null ? 0 : (uint)f.Seed;
        return f is not null;
    }

    public int Material(double x, double y, double z, uint instance)
    {
        var f = Vyber(x, y, z)!;
        _zas.Vrstva(x, y, z, out int vrstvaId, out _);
        return _g.Utvary.FeatMat(f, z, vrstvaId);
    }
}
