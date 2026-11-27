using System.Collections.Concurrent;

namespace Willage.Gen.Geo2;

/// <summary>
/// Kontaktní plocha cílových vrstev na adaptivní mřížce hranic (6.3, K5): kořeny 1 m na světové mřížce, dělení na 0,5 a 0,25 m.
/// Buňka se přijme, když v kontrolních bodech – střed (úhlopříčka 00–11) a středy hran – mají přesné cílové intervaly stejný počet
/// jako rohy a lineární interpolace se od nich liší nejvýš o τ (<c>tau_m</c>); jinak se buňka rozdělí na 4. Buňka 0,25 m, která τ nesplní,
/// se použije s příznakem <see cref="BodPlochy.Odhad"/> (hranice kontaktu je pak odhad). Rozhodnutí závisí jen na uzlech světové mřížky
/// (1/8 m), takže švy bloků jsou bitově stejné. Trojúhelníky a vzdálenost jako u pevné mřížky (<see cref="HledaniPlochy"/>).
/// Po <see cref="Priprav"/> neměnná a vláknově bezpečná; mimo připravenou oblast počítá na vyžádání (keš, deterministicky).
/// </summary>
public sealed class PlochaVrstevAdaptivni : IPlochaKontaktu, IPripravaBloku, IPlochaSRozsahem, IPlochaSUzly
{
    /// <summary>Jednotka mřížky uzlů [m] (kontrolní body buněk 0,25 m leží na 1/8 m).</summary>
    public const double Jednotka = 0.125;
    private const int Koren = 8; // 1 m v jednotkách

    /// <summary>List mřížky: roh (I, J) a strana S v jednotkách 1/8 m, rozsah z trojúhelníků, příznak odhadu.</summary>
    public readonly record struct List(long I, long J, int S, double Lo, double Hi, bool Odhad);

    private readonly ITvarZasobnikuSHranicemi _z;
    private readonly bool[] _cil;
    public double TauM { get; }
    /// <summary>
    /// true: buňka 1 m se kontroluje ve všech bodech mřížky 0,25 m uvnitř a na hranách (V5 zaručeně ve 100 % sloupců po 0,25 m, uzly
    /// po 0,25 m všude); false: jen střed a středy hran (rychlejší, V5 jen statisticky).
    /// </summary>
    public bool KontrolaPo025 { get; }
    private readonly ConcurrentDictionary<(long, long), double[]> _uzly = new();
    private readonly ConcurrentDictionary<(long, long), List[]> _koreny = new();
    private double[]?[]? _pole; private long _pi0, _pj0; private int _pni, _pnj;
    private List[][]? _kpole; private long _ki0, _kj0; private int _kni, _knj;
    private long _spoctenych;

    public PlochaVrstevAdaptivni(ITvarZasobnikuSHranicemi zasobnik, IEnumerable<int> cilMaterialy, int maxId, double tauM, bool kontrolaPo025 = true)
    {
        if (!(tauM > 0)) throw new ArgumentOutOfRangeException(nameof(tauM));
        _z = zasobnik; TauM = tauM; KontrolaPo025 = kontrolaPo025;
        _cil = new bool[Math.Max(maxId + 1, 1)];
        foreach (var m in cilMaterialy) if (m >= 0 && m < _cil.Length) _cil[m] = true;
    }

    public int PredpocitanychUzlu { get { var p = _pole; int n = 0; if (p is not null) foreach (var u in p) if (u is not null) n++; return n; } }
    public int DopocitanychUzlu => _uzly.Count;
    public double OkrajBunkyM => 1.0;
    /// <summary>Počet volání zásobníku pro uzly (diagnostika V6).</summary>
    public long SpoctenychUzlu => Interlocked.Read(ref _spoctenych);

    /// <summary>Cílové intervaly uzlu (i, j) mřížky 1/8 m.</summary>
    public double[] Uzel(long i, long j)
    {
        var p = _pole;
        if (p is not null)
        {
            long a = i - _pi0, b = j - _pj0;
            if ((ulong)a < (ulong)_pni && (ulong)b < (ulong)_pnj)
            {
                ref var slot = ref p[a * _pnj + b];
                return slot ??= Spocti(i, j); // souběh: stejná hodnota, zápis reference je atomický
            }
        }
        return _uzly.GetOrAdd((i, j), k => Spocti(k.Item1, k.Item2));
    }

    private double[] Spocti(long i, long j)
    {
        Interlocked.Increment(ref _spoctenych);
        return HledaniPlochy.CiloveIntervaly(_z, _cil, i * Jednotka, j * Jednotka);
    }

    /// <summary>Listy kořene 1 m (I, J) v pevném pořadí (dělení 00, 10, 01, 11).</summary>
    public List[] Listy(long I, long J)
    {
        var kp = _kpole;
        if (kp is not null)
        {
            long a = I - _ki0, b = J - _kj0;
            if ((ulong)a < (ulong)_kni && (ulong)b < (ulong)_knj) return kp[a * _knj + b];
        }
        return _koreny.GetOrAdd((I, J), k => Rozdel(k.Item1, k.Item2));
    }

    private List[] Rozdel(long I, long J)
    {
        var o = new List<List>(4);
        Deleni(I * Koren, J * Koren, Koren, o);
        return o.ToArray();
    }

    private void Deleni(long i, long j, int s, List<List> o)
    {
        bool ok = Prijmi(i, j, s);
        if (ok || s == 2)
        {
            var (lo, hi) = HledaniPlochy.RozsahBunky(Uzel(i, j), Uzel(i + s, j), Uzel(i + s, j + s), Uzel(i, j + s));
            o.Add(new List(i, j, s, lo, hi, !ok));
            return;
        }
        int h = s / 2;
        Deleni(i, j, h, o); Deleni(i + h, j, h, o); Deleni(i, j + h, h, o); Deleni(i + h, j + h, h, o);
    }

    /// <summary>Kontrolní body buňky: střed (úhlopříčka 00–11) a středy 4 hran; stejný počet intervalů a |interpolace − přesně| ≤ τ.</summary>
    private bool Prijmi(long i, long j, int s)
    {
        int h = s / 2;
        var c00 = Uzel(i, j); var c10 = Uzel(i + s, j); var c11 = Uzel(i + s, j + s); var c01 = Uzel(i, j + s);
        int n = c00.Length;
        if (c10.Length != n || c11.Length != n || c01.Length != n) return false;
        if (!(Bod(c00, c10, Uzel(i + h, j)) && Bod(c10, c11, Uzel(i + s, j + h)) && Bod(c01, c11, Uzel(i + h, j + s))
            && Bod(c00, c01, Uzel(i, j + h)) && Bod(c00, c11, Uzel(i + h, j + h)))) return false;
        if (!KontrolaPo025 || s <= 4) return true; // buňka 0,5 m: body po 0,25 m = střed a středy hran
        for (int a = 0; a <= s; a += 2)
        for (int b = 0; b <= s; b += 2)
        {
            if ((a == 0 || a == s) && (b == 0 || b == s)) continue;
            var e = Uzel(i + a, j + b);
            var u = HledaniPlochy.Interpolace((i + a) * Jednotka, (j + b) * Jednotka, i * Jednotka, j * Jednotka, s * Jednotka, c00, c10, c11, c01)!;
            if (e.Length != n) return false;
            for (int k = 0; k < n; k++) if (Math.Abs(u[k] - e[k]) > TauM) return false;
        }
        return true;
    }

    private bool Bod(double[] a, double[] b, double[] e)
    {
        if (e.Length != a.Length) return false;
        for (int k = 0; k < e.Length; k++) if (Math.Abs(0.5 * (a[k] + b[k]) - e[k]) > TauM) return false;
        return true;
    }

    /// <summary>K5: kořeny oblasti (+1 m) spočtené předem paralelně; výsledek stejný jako na vyžádání.</summary>
    public void Priprav(OblastBloku o, int vlaken)
    {
        long I0 = (long)Math.Floor(o.X0) - 1, I1 = (long)Math.Floor(o.X1) + 1, J0 = (long)Math.Floor(o.Y0) - 1, J1 = (long)Math.Floor(o.Y1) + 1;
        int kni = checked((int)(I1 - I0 + 1)), knj = checked((int)(J1 - J0 + 1));
        _pi0 = I0 * Koren; _pj0 = J0 * Koren; _pni = kni * Koren + 1; _pnj = knj * Koren + 1;
        _pole = new double[]?[(long)_pni * _pnj];
        var kp = new List[(long)kni * knj][];
        Parallel.For(0, kni, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, a =>
        {
            for (int b = 0; b < knj; b++) kp[(long)a * knj + b] = Rozdel(I0 + a, J0 + b);
        });
        _ki0 = I0; _kj0 = J0; _kni = kni; _knj = knj; _kpole = kp;
    }

    /// <summary>Statistika listů připravené oblasti: počet listů 1 / 0,5 / 0,25 m a odhadnutých.</summary>
    public (long L1, long L05, long L025, long Odhad) Statistika()
    {
        long a = 0, b = 0, c = 0, d = 0;
        if (_kpole is null) return (0, 0, 0, 0);
        foreach (var k in _kpole)
            foreach (var l in k) { if (l.S == 8) a++; else if (l.S == 4) b++; else c++; if (l.Odhad) d++; }
        return (a, b, c, d);
    }

    /// <summary>Interpolované cílové intervaly v (x, y) z listu, který bod obsahuje (V5); null u nespárovatelných rohů. <paramref name="list"/> = ten list.</summary>
    public double[]? Interpoluj(double x, double y, out List list)
    {
        long I = (long)Math.Floor(x), J = (long)Math.Floor(y);
        foreach (var l in Listy(I, J))
        {
            double x0 = l.I * Jednotka, y0 = l.J * Jednotka, g = l.S * Jednotka;
            if (x < x0 || x > x0 + g || y < y0 || y > y0 + g) continue;
            list = l;
            return HledaniPlochy.Interpolace(x, y, x0, y0, g, Uzel(l.I, l.J), Uzel(l.I + l.S, l.J), Uzel(l.I + l.S, l.J + l.S), Uzel(l.I, l.J + l.S));
        }
        throw new InvalidOperationException("bod není v žádném listu kořene");
    }

    public bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy b)
    {
        var h = new HledaniPlochy(x, y, z, rMax);
        long I0 = (long)Math.Floor(x - rMax), I1 = (long)Math.Floor(x + rMax), J0 = (long)Math.Floor(y - rMax), J1 = (long)Math.Floor(y + rMax);
        for (long I = I0; I <= I1; I++)
        {
            double kx = x < I ? I - x : x > I + 1 ? x - I - 1 : 0;
            for (long J = J0; J <= J1; J++)
            {
                double ky = y < J ? J - y : y > J + 1 ? y - J - 1 : 0;
                if (kx * kx + ky * ky > h.Best2) continue;
                foreach (var l in Listy(I, J))
                {
                    double x0 = l.I * Jednotka, x1 = (l.I + l.S) * Jednotka, y0 = l.J * Jednotka, y1 = (l.J + l.S) * Jednotka;
                    double dxc = x < x0 ? x0 - x : x > x1 ? x - x1 : 0, dyc = y < y0 ? y0 - y : y > y1 ? y - y1 : 0;
                    double dzb = z < l.Lo ? l.Lo - z : z > l.Hi ? z - l.Hi : 0;
                    if (l.Lo > l.Hi || dxc * dxc + dyc * dyc + dzb * dzb > h.Best2 * (1 + 1e-9) + 1e-12) continue;
                    h.Bunka(x0, y0, x1, y1, Uzel(l.I, l.J), Uzel(l.I + l.S, l.J), Uzel(l.I + l.S, l.J + l.S), Uzel(l.I, l.J + l.S), l.Odhad);
                }
            }
        }
        b = h.Vysledek;
        return h.Nasel;
    }

    public void RozsahZ(double x, double y, double r, List<(double A, double B)> cil)
    {
        double r2 = r * r;
        long I0 = (long)Math.Floor(x - r), I1 = (long)Math.Floor(x + r), J0 = (long)Math.Floor(y - r), J1 = (long)Math.Floor(y + r);
        for (long I = I0; I <= I1; I++)
        for (long J = J0; J <= J1; J++)
            foreach (var l in Listy(I, J))
            {
                if (l.Lo > l.Hi) continue;
                double x0 = l.I * Jednotka, x1 = (l.I + l.S) * Jednotka, y0 = l.J * Jednotka, y1 = (l.J + l.S) * Jednotka;
                double dxc = x < x0 ? x0 - x : x > x1 ? x - x1 : 0, dyc = y < y0 ? y0 - y : y > y1 ? y - y1 : 0, d2 = dxc * dxc + dyc * dyc;
                if (d2 > r2) continue;
                double dz = Math.Sqrt(r2 - d2) + 1e-9;
                cil.Add((l.Lo - dz, l.Hi + dz));
            }
    }
}
