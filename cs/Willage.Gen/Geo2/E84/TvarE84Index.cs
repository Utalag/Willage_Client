using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Tělesa E84 jednoho druhu přes index bloku (K3): stejný výsledek jako <see cref="TvarE84"/> (nejmenší SDF, pořadí <c>Features</c>),
/// ale bez keše staré cesty – po <see cref="Priprav"/> neměnný a vláknově bezpečný (jedna instance pro všechna vlákna, bez <c>Klon()</c>).
/// SDF se počítá jen u instancí, jejichž přesná obálka (<see cref="ObalkaE84"/>) obsahuje bod.
/// </summary>
public class TvarE84Index : ITvarSMaterialem, IPripravaBloku, IIntervalyTvaru
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

    internal double SdfPolozky(int i, double x, double y, double z) => _g.Utvary.Sdf(Index!.Polozky[i].F, x, y, z);

    public bool Obsahuje(double x, double y, double z, out uint instance)
    {
        var f = Vyber(x, y, z);
        instance = f is null ? 0 : (uint)f.Seed;
        return f is not null;
    }

    [ThreadStatic] private static List<(double A, double B, int Polozka, bool Jisty)>? t_iv;
    [ThreadStatic] private static List<(double A, double B)>? t_nej;

    /// <summary>
    /// Segmentace sloupce (K4): přesné tětivy elipsoidů (zlomy na koncích, u čočky a žíly i řezy k/4 a hranice vrstev zásobníku –
    /// materiál <see cref="Utvary.FeatMat"/>), O šumových těles a překryvy sourozenců jako nejisté. Vše oříznuto obálkou položky.
    /// </summary>
    public void Sloupec(double x, double y, SegmentaceSloupce s)
    {
        var ix = Index ?? throw new InvalidOperationException("TvarE84Index: kontext bloku není připraven (KontextBloku.Sestav)");
        int m = ix.MaxVDlazdici;
        Span<int> k = m <= 256 ? stackalloc int[256] : new int[m];
        int n = ix.KandidatiSloupce(x, y, k);
        if (n == 0) return;
        var iv = t_iv ??= new(); iv.Clear();
        var nej = t_nej ??= new();
        var pr = Primka.Svisla(x, y);
        bool fast = _g.Utvary.Fast;
        for (int i = 0; i < n; i++)
        {
            var pol = ix.Polozky[k[i]];
            double lo = Math.Max(pol.Z0, s.Z0), hi = Math.Min(pol.Z1, s.Z1);
            if (lo >= hi) continue;
            if (PrimkaE84.JeElipsoid(pol.F.K))
            {
                if (PrimkaE84.Tetiva(pol.F, pr, 0, out var t0, out var t1) && PrunikyPrimky.Prunik(t0, t1, lo, hi, out var a, out var b) && a < b)
                    iv.Add((a, b, k[i], true));
            }
            else
            {
                nej.Clear(); PrimkaE84.Nejiste(pol.F, pr, fast, nej);
                foreach (var (a0, b0) in nej)
                    if (PrunikyPrimky.Prunik(a0, b0, lo, hi, out var a, out var b) && a < b) iv.Add((a, b, k[i], false));
            }
        }
        List<Hranice>? hr = null;
        for (int i = 0; i < iv.Count; i++)
        {
            var (a, b, ip, jisty) = iv[i];
            if (!jisty) { s.Nejista(a, b); continue; }
            s.Zlom(a); s.Zlom(b);
            var f = ix.Polozky[ip].F;
            if (f.K is DruhUtvaru.Cocka or DruhUtvaru.Zila)
            {
                for (double z = Math.Floor(a * 4) / 4 + 0.25; z < b; z += 0.25) s.Zlom(z);
                hr ??= _zas.HraniceSloupce(x, y);
                foreach (var h in hr) { if (h.Z0 > a && h.Z0 < b) s.Zlom(h.Z0); if (h.Z1 > a && h.Z1 < b) s.Zlom(h.Z1); }
            }
            // překryv sourozenců: rozhodne nejmenší SDF
            for (int j = 0; j < i; j++)
                if (iv[j].Polozka != ip && PrunikyPrimky.Prunik(a, b, iv[j].A, iv[j].B, out var c, out var d) && c < d) s.Nejista(c, d);
        }
    }

    public int Material(double x, double y, double z, uint instance)
    {
        var f = Vyber(x, y, z)!;
        _zas.Vrstva(x, y, z, out int vrstvaId, out _);
        return _g.Utvary.FeatMat(f, z, vrstvaId);
    }
}
