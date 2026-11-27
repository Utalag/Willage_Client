using System.Collections.Concurrent;

namespace Willage.Gen.Geo2;

/// <summary>
/// Kontaktní plocha cílových vrstev (2.5, rozhodnutí 7A): hranice sjednocení cílových vrstev jako výšková plocha na mřížce
/// hranic s krokem g. Buňka = 2 trojúhelníky s pevnou úhlopříčkou (00–11), d̃ = přesná vzdálenost bod–trojúhelník.
/// Dno světa (z = 0) není kontakt. Rohy s různým počtem cílových intervalů (vyklínění) nejdou spárovat: tam se měří
/// vzdálenost k vrcholům (počítá se jako <see cref="Nesparovanych"/>; chyba až ~g/√2, viz PROP K1b); takový bod má <see cref="BodPlochy.Odhad"/>.
/// K1b: pevný krok g; adaptivní mřížka 1 / 0,5 / 0,25 m s kontrolním bodem (6.3) je K5. Vláknově bezpečná, pokud je zásobník.
/// </summary>
public sealed class PlochaVrstev : IPlochaKontaktu, IPripravaBloku
{
    private readonly ITvarZasobnikuSHranicemi _z;
    private readonly bool[] _cil;
    private readonly ConcurrentDictionary<(long, long), double[]> _uzly = new();
    public double KrokM { get; }
    private readonly ThreadLocal<long[]> _nesparovanych = new(() => new long[1], trackAllValues: true);
    /// <summary>Počet trojúhelníků s nespárovatelnými rohy, které padly do dosahu (diagnostika; čítač lokální vláknu, K3).</summary>
    public long Nesparovanych => _nesparovanych.Values.Sum(v => v[0]);
    // K3: předpočtené uzly oblasti bloku (neměnné po Priprav); mimo oblast keš _uzly
    private double[][]? _pole; private long _pi0, _pj0; private int _pni, _pnj;
    // K3: rozsah z trojúhelníků buňky [lo, hi] (prázdná: +∞, −∞) pro odmítnutí celé buňky obálkou; buňka (i, j) = uzly i..i+1, j..j+1
    private double[]? _clo, _chi;
    /// <summary>Počet předpočtených uzlů (K3) a uzlů dopočtených mimo oblast (diagnostika V6).</summary>
    public int PredpocitanychUzlu => _pole?.Length ?? 0;
    public int DopocitanychUzlu => _uzly.Count;

    public PlochaVrstev(ITvarZasobnikuSHranicemi zasobnik, IEnumerable<int> cilMaterialy, int maxId, double krokM)
    {
        if (!(krokM > 0)) throw new ArgumentOutOfRangeException(nameof(krokM));
        _z = zasobnik; KrokM = krokM;
        _cil = new bool[Math.Max(maxId + 1, 1)];
        foreach (var m in cilMaterialy) if (m >= 0 && m < _cil.Length) _cil[m] = true;
    }

    private bool JeCil(int m) => m >= 0 && m < _cil.Length && _cil[m];

    /// <summary>Sloučené cílové intervaly uzlu [a0, b0, a1, b1, …] zdola.</summary>
    public double[] Uzel(long i, long j)
    {
        var p = _pole;
        if (p is not null)
        {
            long a = i - _pi0, b = j - _pj0;
            if ((ulong)a < (ulong)_pni && (ulong)b < (ulong)_pnj) return p[a * _pnj + b];
        }
        return _uzly.GetOrAdd((i, j), k => SpoctiUzel(k.Item1, k.Item2));
    }

    /// <summary>K3: uzly celé oblasti (+1 uzel) spočtené předem, paralelně; výsledek stejný jako <see cref="Uzel"/> na vyžádání.</summary>
    public void Priprav(OblastBloku o, int vlaken)
    {
        double g = KrokM;
        long i0 = (long)Math.Floor(o.X0 / g), i1 = (long)Math.Floor(o.X1 / g) + 1, j0 = (long)Math.Floor(o.Y0 / g), j1 = (long)Math.Floor(o.Y1 / g) + 1;
        int ni = checked((int)(i1 - i0 + 1)), nj = checked((int)(j1 - j0 + 1));
        var pole = new double[(long)ni * nj][];
        Parallel.For(0, ni, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, a =>
        {
            for (int b = 0; b < nj; b++) pole[(long)a * nj + b] = SpoctiUzel(i0 + a, j0 + b);
        });
        var lo = new double[(long)(ni - 1) * (nj - 1)]; var hi = new double[lo.Length];
        Parallel.For(0, ni - 1, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, a =>
        {
            for (int b = 0; b < nj - 1; b++)
            {
                double l = double.PositiveInfinity, h = double.NegativeInfinity;
                var u00 = pole[(long)a * nj + b]; var u10 = pole[(long)(a + 1) * nj + b]; var u11 = pole[(long)(a + 1) * nj + b + 1]; var u01 = pole[(long)a * nj + b + 1];
                RozsahTrojuhelniku(u00, u10, u11, ref l, ref h); RozsahTrojuhelniku(u00, u11, u01, ref l, ref h);
                lo[(long)a * (nj - 1) + b] = l; hi[(long)a * (nj - 1) + b] = h;
            }
        });
        _pi0 = i0; _pj0 = j0; _pni = ni; _pnj = nj; _clo = lo; _chi = hi; _pole = pole;
    }

    /// <summary>Rozsah z všech bodů, které <c>Trojuhelnik</c> v <see cref="Nejblizsi"/> vyhodnotí (stejné vynechání dna světa).</summary>
    private static void RozsahTrojuhelniku(double[] ua, double[] uc, double[] ue, ref double lo, ref double hi)
    {
        if (ua.Length == 0 && uc.Length == 0 && ue.Length == 0) return;
        if (ua.Length == uc.Length && uc.Length == ue.Length)
        {
            for (int k = 0; k < ua.Length; k++)
            {
                double ha = ua[k], hc = uc[k], he = ue[k];
                if ((k & 1) == 0 && ha <= 1e-9 && hc <= 1e-9 && he <= 1e-9) continue;
                lo = Math.Min(lo, Math.Min(ha, Math.Min(hc, he))); hi = Math.Max(hi, Math.Max(ha, Math.Max(hc, he)));
            }
            return;
        }
        foreach (var u in new[] { ua, uc, ue })
            for (int k = 0; k < u.Length; k++)
            {
                if ((k & 1) == 0 && u[k] <= 1e-9) continue;
                lo = Math.Min(lo, u[k]); hi = Math.Max(hi, u[k]);
            }
    }

    private double[] SpoctiUzel(long i, long j)
    {
        var s = _z.Sloupec(i * KrokM, j * KrokM);
        var o = new List<double>();
        foreach (var v in s)
        {
            if (!JeCil(v.Material) || !(v.Z1 > v.Z0)) continue;
            if (o.Count > 0 && Math.Abs(o[^1] - v.Z0) < 1e-9) o[^1] = v.Z1;
            else { o.Add(v.Z0); o.Add(v.Z1); }
        }
        return o.ToArray();
    }

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
                if (_clo is not null)
                {
                    // K3: celá buňka dál než nejlepší (s rezervou na zaokrouhlení) → žádný trojúhelník by nevyhrál (d2 < best2)
                    long a = i - _pi0, c = j - _pj0;
                    if ((ulong)a < (ulong)(_pni - 1) && (ulong)c < (ulong)(_pnj - 1))
                    {
                        long q = a * (_pnj - 1) + c; double lo = _clo[q], hi = _chi![q];
                        double dzb = z < lo ? lo - z : z > hi ? z - hi : 0;
                        if (dxc * dxc + dyc * dyc + dzb * dzb > best2 * (1 + 1e-9) + 1e-12) continue;
                    }
                }
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
            _nesparovanych.Value![0]++;
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
