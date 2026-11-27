using System.Collections.Concurrent;

namespace Willage.Gen.Geo2;

/// <summary>
/// Kontaktní plocha cílových vrstev (2.5, rozhodnutí 7A): hranice sjednocení cílových vrstev jako výšková plocha na mřížce
/// hranic s krokem g. Buňka = 2 trojúhelníky s pevnou úhlopříčkou (00–11), d̃ = přesná vzdálenost bod–trojúhelník.
/// Dno světa (z = 0) není kontakt. Rohy s různým počtem cílových intervalů (vyklínění) nejdou spárovat: tam se měří
/// vzdálenost k vrcholům (počítá se jako <see cref="Nesparovanych"/>; chyba až ~g/√2, viz PROP K1b); takový bod má <see cref="BodPlochy.Odhad"/>.
/// K1b: pevný krok g; adaptivní mřížka 1 / 0,5 / 0,25 m s kontrolním bodem (6.3) je K5. Vláknově bezpečná, pokud je zásobník.
/// </summary>
public sealed class PlochaVrstev : IPlochaKontaktu
{
    private readonly ITvarZasobnikuSHranicemi _z;
    private readonly bool[] _cil;
    private readonly ConcurrentDictionary<(long, long), double[]> _uzly = new();
    public double KrokM { get; }
    private long _nesparovanych;
    /// <summary>Počet trojúhelníků s nespárovatelnými rohy, které padly do dosahu (diagnostika).</summary>
    public long Nesparovanych => Interlocked.Read(ref _nesparovanych);

    public PlochaVrstev(ITvarZasobnikuSHranicemi zasobnik, IEnumerable<int> cilMaterialy, int maxId, double krokM)
    {
        if (!(krokM > 0)) throw new ArgumentOutOfRangeException(nameof(krokM));
        _z = zasobnik; KrokM = krokM;
        _cil = new bool[Math.Max(maxId + 1, 1)];
        foreach (var m in cilMaterialy) if (m >= 0 && m < _cil.Length) _cil[m] = true;
    }

    private bool JeCil(int m) => m >= 0 && m < _cil.Length && _cil[m];

    /// <summary>Sloučené cílové intervaly uzlu [a0, b0, a1, b1, …] zdola.</summary>
    public double[] Uzel(long i, long j) => _uzly.GetOrAdd((i, j), k =>
    {
        var s = _z.Sloupec(k.Item1 * KrokM, k.Item2 * KrokM);
        var o = new List<double>();
        foreach (var v in s)
        {
            if (!JeCil(v.Material) || !(v.Z1 > v.Z0)) continue;
            if (o.Count > 0 && Math.Abs(o[^1] - v.Z0) < 1e-9) o[^1] = v.Z1;
            else { o.Add(v.Z0); o.Add(v.Z1); }
        }
        return o.ToArray();
    });

    public bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy b)
    {
        double g = KrokM, best2 = rMax * rMax; bool nasel = false;
        double bx = 0, by = 0, bz = 0, nx = 0, ny = 0, nz = 1; bool odh = false;
        long i0 = (long)Math.Floor((x - rMax) / g), i1 = (long)Math.Floor((x + rMax) / g);
        long j0 = (long)Math.Floor((y - rMax) / g), j1 = (long)Math.Floor((y + rMax) / g);
        for (long i = i0; i <= i1; i++)
        {
            double x0 = i * g, x1 = x0 + g;
            double dxc = x < x0 ? x0 - x : x > x1 ? x - x1 : 0;
            for (long j = j0; j <= j1; j++)
            {
                double y0 = j * g, y1 = y0 + g;
                double dyc = y < y0 ? y0 - y : y > y1 ? y - y1 : 0;
                if (dxc * dxc + dyc * dyc > best2) continue;
                var u00 = Uzel(i, j); var u10 = Uzel(i + 1, j); var u11 = Uzel(i + 1, j + 1); var u01 = Uzel(i, j + 1);
                Trojuhelnik(x0, y0, u00, x1, y0, u10, x1, y1, u11);
                Trojuhelnik(x0, y0, u00, x1, y1, u11, x0, y1, u01);
            }
        }
        b = new BodPlochy(bx, by, bz, nx, ny, nz, Math.Sqrt(best2), odh);
        return nasel;

        void Zkus(double d2, double qx, double qy, double qz, double mx, double my, double mz, bool o = false)
        {
            if (d2 < best2) { best2 = d2; bx = qx; by = qy; bz = qz; nx = mx; ny = my; nz = mz; nasel = true; odh = o; }
        }

        void Trojuhelnik(double ax, double ay, double[] ua, double cx, double cy, double[] uc, double ex, double ey, double[] ue)
        {
            if (ua.Length == 0 && uc.Length == 0 && ue.Length == 0) return;
            if (ua.Length == uc.Length && uc.Length == ue.Length)
            {
                for (int k = 0; k < ua.Length; k++)
                {
                    double ha = ua[k], hc = uc[k], he = ue[k];
                    if ((k & 1) == 0 && ha <= 1e-9 && hc <= 1e-9 && he <= 1e-9) continue; // dno světa
                    double lo = Math.Min(ha, Math.Min(hc, he)), hi = Math.Max(ha, Math.Max(hc, he));
                    double dzc = z < lo ? lo - z : z > hi ? z - hi : 0;
                    if (dzc * dzc > best2) continue;
                    double d2 = Geometrie3.NejblizsiNaTrojuhelniku(x, y, z, ax, ay, ha, cx, cy, hc, ex, ey, he, out var qx, out var qy, out var qz);
                    if (d2 < best2)
                    {
                        var (mx, my, mz) = Geometrie3.Normala(ax, ay, ha, cx, cy, hc, ex, ey, he);
                        Zkus(d2, qx, qy, qz, mx, my, mz);
                    }
                }
                return;
            }
            Interlocked.Increment(ref _nesparovanych);
            Vrcholy(ax, ay, ua); Vrcholy(cx, cy, uc); Vrcholy(ex, ey, ue);
        }

        void Vrcholy(double vx, double vy, double[] u)
        {
            for (int k = 0; k < u.Length; k++)
            {
                if ((k & 1) == 0 && u[k] <= 1e-9) continue;
                double d2 = Geometrie3.D2(x, y, z, vx, vy, u[k]);
                if (d2 < best2) Zkus(d2, vx, vy, u[k], 0, 0, (k & 1) == 0 ? -1 : 1, true);
            }
        }
    }
}
