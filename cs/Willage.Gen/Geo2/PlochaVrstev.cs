using System.Collections.Concurrent;

namespace Willage.Gen.Geo2;

/// <summary>
/// Kontaktní plocha cílových vrstev (2.5, rozhodnutí 7A): hranice sjednocení cílových vrstev jako výšková plocha na mřížce
/// hranic s krokem g. Buňka = 2 trojúhelníky s pevnou úhlopříčkou (00–11), d̃ = přesná vzdálenost bod–trojúhelník.
/// Dno světa (z = 0) není kontakt. Rohy s různým počtem cílových intervalů (vyklínění) nejdou spárovat: tam se měří
/// vzdálenost k vrcholům (počítá se jako <see cref="Nesparovanych"/>; chyba až ~g/√2, viz PROP K1b); takový bod má <see cref="BodPlochy.Odhad"/>.
/// K1b: pevný krok g; adaptivní mřížka 1 / 0,5 / 0,25 m s kontrolním bodem (6.3) je K5. Vláknově bezpečná, pokud je zásobník.
/// </summary>
public sealed class PlochaVrstev : IPlochaKontaktu, IPripravaBloku, IPlochaSRozsahem, IPlochaSUzly
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
    public double OkrajBunkyM => KrokM;

    public PlochaVrstev(ITvarZasobnikuSHranicemi zasobnik, IEnumerable<int> cilMaterialy, int maxId, double krokM)
    {
        if (!(krokM > 0)) throw new ArgumentOutOfRangeException(nameof(krokM));
        _z = zasobnik; KrokM = krokM;
        _cil = new bool[Math.Max(maxId + 1, 1)];
        foreach (var m in cilMaterialy) if (m >= 0 && m < _cil.Length) _cil[m] = true;
    }


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
                HledaniPlochy.RozsahTrojuhelniku(u00, u10, u11, ref l, ref h); HledaniPlochy.RozsahTrojuhelniku(u00, u11, u01, ref l, ref h);
                lo[(long)a * (nj - 1) + b] = l; hi[(long)a * (nj - 1) + b] = h;
            }
        });
        _pi0 = i0; _pj0 = j0; _pni = ni; _pnj = nj; _clo = lo; _chi = hi; _pole = pole;
    }

    /// <summary>
    /// K4: kde ve sloupci může být plocha blíž než r. Buňky v dosahu r v rovině xy: rozsah z jejich trojúhelníků (stejný jako v
    /// <see cref="Nejblizsi"/>, včetně vrcholů nespárovaných rohů) ± √(r² − d_xy²). Nadmnožina.
    /// </summary>
    public void RozsahZ(double x, double y, double r, List<(double A, double B)> cil)
    {
        double g = KrokM, r2 = r * r;
        long i0 = (long)Math.Floor((x - r) / g), i1 = (long)Math.Floor((x + r) / g);
        long j0 = (long)Math.Floor((y - r) / g), j1 = (long)Math.Floor((y + r) / g);
        for (long i = i0; i <= i1; i++)
        {
            double x0 = i * g, x1 = x0 + g, dxc = x < x0 ? x0 - x : x > x1 ? x - x1 : 0;
            for (long j = j0; j <= j1; j++)
            {
                double y0 = j * g, y1 = y0 + g, dyc = y < y0 ? y0 - y : y > y1 ? y - y1 : 0, dxy2 = dxc * dxc + dyc * dyc;
                if (dxy2 > r2) continue;
                double lo, hi;
                long a = i - _pi0, c = j - _pj0;
                if (_clo is not null && (ulong)a < (ulong)(_pni - 1) && (ulong)c < (ulong)(_pnj - 1)) { long q = a * (_pnj - 1) + c; lo = _clo[q]; hi = _chi![q]; }
                else
                {
                    lo = double.PositiveInfinity; hi = double.NegativeInfinity;
                    var u00 = Uzel(i, j); var u10 = Uzel(i + 1, j); var u11 = Uzel(i + 1, j + 1); var u01 = Uzel(i, j + 1);
                    HledaniPlochy.RozsahTrojuhelniku(u00, u10, u11, ref lo, ref hi); HledaniPlochy.RozsahTrojuhelniku(u00, u11, u01, ref lo, ref hi);
                }
                if (lo > hi) continue;
                double dz = Math.Sqrt(r2 - dxy2) + 1e-9;
                cil.Add((lo - dz, hi + dz));
            }
        }
    }

    /// <summary>Interpolované cílové intervaly v (x, y) (V5), nebo null u nespárovatelných rohů.</summary>
    public double[]? Interpoluj(double x, double y)
    {
        double g = KrokM; long i = (long)Math.Floor(x / g), j = (long)Math.Floor(y / g);
        return HledaniPlochy.Interpolace(x, y, i * g, j * g, g, Uzel(i, j), Uzel(i + 1, j), Uzel(i + 1, j + 1), Uzel(i, j + 1));
    }

    private double[] SpoctiUzel(long i, long j) => HledaniPlochy.CiloveIntervaly(_z, _cil, i * KrokM, j * KrokM);

    public bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy b)
    {
        double g = KrokM;
        var h = new HledaniPlochy(x, y, z, rMax);
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
                if (dxc * dxc + dyc * dyc > h.Best2) continue;
                if (_clo is not null)
                {
                    // K3: celá buňka dál než nejlepší (s rezervou na zaokrouhlení) → žádný trojúhelník by nevyhrál (d2 < best2)
                    long a = i - _pi0, c = j - _pj0;
                    if ((ulong)a < (ulong)(_pni - 1) && (ulong)c < (ulong)(_pnj - 1))
                    {
                        long q = a * (_pnj - 1) + c; double lo = _clo[q], hi = _chi![q];
                        double dzb = z < lo ? lo - z : z > hi ? z - hi : 0;
                        if (dxc * dxc + dyc * dyc + dzb * dzb > h.Best2 * (1 + 1e-9) + 1e-12) continue;
                    }
                }
                h.Bunka(x0, y0, x1, y1, Uzel(i, j), Uzel(i + 1, j), Uzel(i + 1, j + 1), Uzel(i, j + 1));
            }
        }
        if (h.Nesparovanych > 0) _nesparovanych.Value![0] += h.Nesparovanych;
        b = h.Vysledek;
        return h.Nasel;
    }
}
