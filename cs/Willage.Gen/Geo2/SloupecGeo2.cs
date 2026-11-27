namespace Willage.Gen.Geo2;

/// <summary>
/// Vyhodnocení ve sloupci (1.7, K4) jako segmentace svislé přímky: body zlomu a nejisté oblasti ze všech událostí
/// (<see cref="IIntervalyTvaru"/>, <see cref="IIntervalyKontaktu"/>, meze hloubky), stav kusu = <see cref="ChronologieGeo2.BodPred"/>
/// ve středu (jistý kus) nebo na mřížce z_k = k·h, h = t_det/2 (nejistý), hranice mezi vzorky půlením na ε = 2⁻¹⁰ m.
/// Invariant: Stav(z) == Bod(x, y, z) mimo ±ε u hranic a mimo tětivy &lt; t_det (2.8). Vláknově bezpečné (pracovní paměť lokální vláknu).
/// </summary>
public static class SloupecGeo2
{
    public const double Epsilon = 1.0 / 1024.0;

    /// <summary>Úsek se stavem (pracovní forma běhu).</summary>
    public readonly record struct Usek(double Z0, double Z1, StavBodu Stav, DruhHranice HraniceZ0);

    private readonly record struct Vzorkovy(double ZA, double ZB, StavBodu Stav);

    private sealed class Prac
    {
        public readonly SegmentaceSloupce Seg = new();
        public readonly List<double> Body = new();
        public readonly List<(double A, double B)> U = new(), Pov = new();
        public readonly List<Vzorkovy> Vz = new();
        public readonly List<Usek> Prefix = new();
    }
    [ThreadStatic] private static List<Prac>? t_prac;
    [ThreadStatic] private static int t_hloubka;

    /// <summary>Diagnostika (lokální vláknu): počet vyhodnocení <c>Bod</c> ve sloupcích.</summary>
    [ThreadStatic] public static long VolaniBod;

    /// <summary>Běhy sloupce (3.3) přes [0, zMax): pod povrchem z chronologie, nad povrchem <c>NadPovrchem</c>.</summary>
    public static void Behy(ChronologieGeo2 c, double x, double y, double zPov, double zMax, List<Beh> cil)
    {
        cil.Clear();
        var u = Pujc();
        try
        {
            UsekyP(c, c.Udalosti.Count, x, y, zPov, Math.Min(zPov, zMax), u.Prefix, u);
            foreach (var k in u.Prefix) cil.Add(new Beh(k.Z0, k.Z1, Vzorek.Z(k.Stav), k.HraniceZ0));
            if (zPov < zMax) cil.Add(new Beh(Math.Max(zPov, 0), zMax, Vzorek.Z(StavBodu.NadPovrchem), DruhHranice.Presna));
        }
        finally { Vrat(); }
    }

    private static Prac Pujc()
    {
        var l = t_prac ??= new List<Prac>();
        if (t_hloubka == l.Count) l.Add(new Prac());
        return l[t_hloubka++];
    }
    private static void Vrat() => t_hloubka--;

    /// <summary>Úseky po událostech s indexem &lt; <paramref name="pocet"/> přes [0, zTop).</summary>
    public static void Useky(ChronologieGeo2 c, int pocet, double x, double y, double zPov, double zTop, List<Usek> cil)
    {
        var p = Pujc();
        try { UsekyP(c, pocet, x, y, zPov, zTop, cil, p); }
        finally { Vrat(); }
    }

    private static void UsekyP(ChronologieGeo2 c, int pocet, double x, double y, double zPov, double zTop, List<Usek> cil, Prac p)
    {
        cil.Clear();
        if (zTop <= 0) return;
        double h = c.Konfigurace.MinTloustkaDetekceM / 2, eps = Epsilon;
        var seg = p.Seg; seg.Vycisti(0, zTop);
        for (int i = 0; i < pocet; i++)
        {
            var e = c.Udalosti[i];
            if (e.Hloubka.MinM is double mi) seg.Zlom(zPov - mi);
            if (e.Hloubka.MaxM is double ma) seg.Zlom(zPov - ma);
            object? tv = e.Operace == Operace.Uloz ? e.Zasobnik : e.Tvar;
            if (tv is IIntervalyTvaru it) it.Sloupec(x, y, seg); else seg.Nejista(0, zTop);
            if (e.Kontakt is null) continue;
            if (e.Kontakt is IIntervalyKontaktu ik)
            {
                // povolené úseky: stav před kontaktem projde statickými pravidly; ±ε kvůli certifikovaným hranicím prefixu
                var pref = new List<Usek>();
                Useky(c, i, x, y, zPov, zTop, pref);
                double hl0 = e.Hloubka.MaxM is double mx ? zPov - mx : double.NegativeInfinity, hl1 = e.Hloubka.MinM is double mn ? zPov - mn : double.PositiveInfinity;
                p.Pov.Clear();
                foreach (var k in pref)
                {
                    if (!PravidloCile.PovolujeStav(e, k.Stav)) continue;
                    double a = Math.Max(k.Z0 - eps, hl0 - eps), b = Math.Min(k.Z1 + eps, hl1 + eps);
                    if (a < b) p.Pov.Add((a, b));
                }
                if (p.Pov.Count > 0) ik.Sloupec(x, y, p.Pov, h, seg);
            }
            else seg.Nejista(0, zTop);
        }

        // body zlomu a sjednocení nejistých oblastí
        var body = p.Body; body.Clear(); body.Add(0); body.AddRange(seg.Zlomy); body.Add(zTop); body.Sort();
        var U = p.U; U.Clear();
        seg.Nejiste.Sort((a, b) => a.A.CompareTo(b.A));
        foreach (var n in seg.Nejiste)
            if (U.Count > 0 && n.A <= U[^1].B) U[^1] = (U[^1].A, Math.Max(U[^1].B, n.B)); else U.Add(n);

        // vzorky
        var vz = p.Vz; vz.Clear(); int iu = 0;
        void Jisty(double a, double b) { if (b > a) vz.Add(new Vzorkovy(a, b, Bod(c, pocet, x, y, 0.5 * (a + b), zPov))); }
        void Bodovy(double z) => vz.Add(new Vzorkovy(z, z, Bod(c, pocet, x, y, z, zPov)));
        void Nejisty(double a, double b)
        {
            if (b - a <= eps / 2) { Bodovy(0.5 * (a + b)); return; }
            double a2 = a + eps / 4, b2 = b - eps / 4;
            Bodovy(a2);
            for (long k = (long)Math.Floor(a2 / h) + 1; k * h < b2; k++) Bodovy(k * h);
            Bodovy(b2);
        }
        for (int j = 0; j + 1 < body.Count; j++)
        {
            double p0 = body[j], p1 = body[j + 1];
            if (p1 - p0 <= 1e-12) continue;
            while (iu < U.Count && U[iu].B <= p0) iu++;
            double kurzor = p0;
            for (int k = iu; k < U.Count && U[k].A < p1; k++)
            {
                double a = Math.Max(U[k].A, p0), b = Math.Min(U[k].B, p1);
                if (a > kurzor) Jisty(kurzor, a);
                Nejisty(a, b);
                kurzor = b;
            }
            if (kurzor < p1) Jisty(kurzor, p1);
        }
        if (vz.Count == 0) return;

        // běhy
        double start = 0; var druh = DruhHranice.Presna; var cur = vz[0].Stav;
        int ib = 0;
        for (int i = 0; i + 1 < vz.Count; i++)
        {
            var B = vz[i + 1];
            if (B.Stav == cur) continue;
            double lo = vz[i].ZB, hi = B.ZA, hr; DruhHranice dh;
            if (hi - lo <= 1e-12) { hr = lo; dh = DruhHranice.Presna; }
            else
            {
                while (ib < body.Count && body[ib] < lo) ib++;
                if (ib < body.Count && body[ib] <= hi && hi - lo <= eps / 2 + 1e-12) { hr = body[ib]; dh = DruhHranice.Presna; }
                else
                {
                    double a = lo, b = hi; var sa = vz[i].Stav;
                    while (b - a > eps) { double m = 0.5 * (a + b); if (Bod(c, pocet, x, y, m, zPov) == sa) a = m; else b = m; }
                    hr = 0.5 * (a + b); dh = DruhHranice.Certifikovana;
                }
            }
            cil.Add(new Usek(start, hr, cur, druh));
            start = hr; druh = dh; cur = B.Stav;
        }
        cil.Add(new Usek(start, zTop, cur, druh));
    }

    private static StavBodu Bod(ChronologieGeo2 c, int pocet, double x, double y, double z, double zPov)
    {
        VolaniBod++;
        return c.BodPred(pocet, x, y, z, zPov);
    }
}

/// <summary>
/// Rasterizace (3.4): běhy → mřížka s výškou buňky h od z0. Buňka = běh přes střed; je-li střed do ε od hranice, rozhodne <c>Bod</c>.
/// Geologii nemění; libovolná výška buňky.
/// </summary>
public static class Rasterizace
{
    public static void DoMrizky(IReadOnlyList<Beh> behy, double z0, double h, Span<Vzorek> cil, Func<double, Vzorek> bod)
    {
        int j = 0;
        for (int k = 0; k < cil.Length; k++)
        {
            double zc = z0 + (k + 0.5) * h;
            while (j + 1 < behy.Count && behy[j].Z1 <= zc) j++;
            var b = behy[j];
            bool blizko = (j > 0 && zc - b.Z0 <= SloupecGeo2.Epsilon) || (j + 1 < behy.Count && b.Z1 - zc <= SloupecGeo2.Epsilon) || zc < b.Z0 || zc >= b.Z1;
            cil[k] = blizko ? bod(zc) : b.Stav;
        }
    }
}

/// <summary>
/// Uložení bloku po bězích (3.3): na sloupec seznam (z začátku běhu jako float, index do palety vzorků ushort).
/// Konce běhů jsou začátky dalších, poslední končí v zMax. Paleta = různé vzorky bloku (≤ 65 535).
/// </summary>
public sealed class UlozisteBehu
{
    private readonly int[] _start;
    private readonly List<float> _z = new();
    private readonly List<ushort> _i = new();
    private readonly List<Vzorek> _paleta = new();
    private readonly Dictionary<Vzorek, ushort> _id = new();
    public double ZMax { get; }
    public int Sloupcu => _start.Length - 1;
    public int Behu => _z.Count;
    public int Paleta => _paleta.Count;
    /// <summary>Bajty dat: 4 B z + 2 B index na běh, 4 B začátek na sloupec, 20 B na položku palety.</summary>
    public long Bajtu => 6L * _z.Count + 4L * _start.Length + (long)Geo2.Vzorek.Velikost * _paleta.Count;

    public UlozisteBehu(int sloupcu, double zMax) { _start = new int[sloupcu + 1]; ZMax = zMax; }

    /// <summary>Zapíše sloupec <paramref name="sloupec"/>; sloupce se zapisují postupně od 0 (jedno vlákno).</summary>
    public void Zapis(int sloupec, IReadOnlyList<Beh> behy)
    {
        _start[sloupec] = _z.Count;
        foreach (var b in behy)
        {
            if (!_id.TryGetValue(b.Stav, out var id))
            {
                if (_paleta.Count == ushort.MaxValue) throw new OverflowException("paleta vzorků bloku > 65 535");
                id = (ushort)_paleta.Count; _paleta.Add(b.Stav); _id[b.Stav] = id;
            }
            if (_i.Count > _start[sloupec] && _i[^1] == id) continue; // sloučit stejné sousední
            _z.Add((float)b.Z0); _i.Add(id);
        }
        _start[sloupec + 1] = _z.Count;
    }

    /// <summary>Vzorek ve sloupci v z (bez dopočtu Bod u hranic).</summary>
    public Vzorek VzorekV(int sloupec, double z)
    {
        int a = _start[sloupec], b = _start[sloupec + 1] - 1;
        int k = a;
        while (k < b && _z[k + 1] <= z) k++;
        return _paleta[_i[k]];
    }
}
