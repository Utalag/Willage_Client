namespace Willage.Gen.Geo2;

/// <summary>
/// Hledání nejbližšího bodu výškové plochy vrstev po buňkách (2.5): buňka = 2 trojúhelníky s pevnou úhlopříčkou 00–11, rohy
/// = sloučené cílové intervaly uzlu [a0, b0, a1, b1, …]. Rohy s různým počtem intervalů → vrcholy s příznakem odhadu.
/// Sdílí pevná (<see cref="PlochaVrstev"/>) i adaptivní (<see cref="PlochaVrstevAdaptivni"/>) mřížka.
/// </summary>
public struct HledaniPlochy
{
    public readonly double X, Y, Z;
    public double Best2, Bx, By, Bz, Nx, Ny, Nz;
    public bool Nasel, Odh;
    public long Nesparovanych;

    public HledaniPlochy(double x, double y, double z, double rMax)
    {
        X = x; Y = y; Z = z; Best2 = rMax * rMax; Bx = By = Bz = Nx = Ny = 0; Nz = 1; Nasel = Odh = false; Nesparovanych = 0;
    }

    public readonly BodPlochy Vysledek => new(Bx, By, Bz, Nx, Ny, Nz, Math.Sqrt(Best2), Odh);

    private void Zkus(double d2, double qx, double qy, double qz, double mx, double my, double mz, bool o)
    {
        if (d2 < Best2) { Best2 = d2; Bx = qx; By = qy; Bz = qz; Nx = mx; Ny = my; Nz = mz; Nasel = true; Odh = o; }
    }

    /// <summary>Buňka [x0, x1] × [y0, y1]; <paramref name="odhad"/> = chyba buňky není zaručena (adaptivní mřížka po 0,25 m nesplnila τ).</summary>
    public void Bunka(double x0, double y0, double x1, double y1, double[] u00, double[] u10, double[] u11, double[] u01, bool odhad = false)
    {
        Trojuhelnik(x0, y0, u00, x1, y0, u10, x1, y1, u11, odhad);
        Trojuhelnik(x0, y0, u00, x1, y1, u11, x0, y1, u01, odhad);
    }

    private void Trojuhelnik(double ax, double ay, double[] ua, double cx, double cy, double[] uc, double ex, double ey, double[] ue, bool odhad)
    {
        if (ua.Length == 0 && uc.Length == 0 && ue.Length == 0) return;
        if (ua.Length == uc.Length && uc.Length == ue.Length)
        {
            for (int k = 0; k < ua.Length; k++)
            {
                double ha = ua[k], hc = uc[k], he = ue[k];
                if ((k & 1) == 0 && ha <= 1e-9 && hc <= 1e-9 && he <= 1e-9) continue; // dno světa
                double lo = Math.Min(ha, Math.Min(hc, he)), hi = Math.Max(ha, Math.Max(hc, he));
                double dzc = Z < lo ? lo - Z : Z > hi ? Z - hi : 0;
                if (dzc * dzc > Best2) continue;
                double d2 = Geometrie3.NejblizsiNaTrojuhelniku(X, Y, Z, ax, ay, ha, cx, cy, hc, ex, ey, he, out var qx, out var qy, out var qz);
                if (d2 < Best2)
                {
                    var (mx, my, mz) = Geometrie3.Normala(ax, ay, ha, cx, cy, hc, ex, ey, he);
                    Zkus(d2, qx, qy, qz, mx, my, mz, odhad);
                }
            }
            return;
        }
        Nesparovanych++;
        Vrcholy(ax, ay, ua); Vrcholy(cx, cy, uc); Vrcholy(ex, ey, ue);
    }

    private void Vrcholy(double vx, double vy, double[] u)
    {
        for (int k = 0; k < u.Length; k++)
        {
            if ((k & 1) == 0 && u[k] <= 1e-9) continue;
            double d2 = Geometrie3.D2(X, Y, Z, vx, vy, u[k]);
            if (d2 < Best2) Zkus(d2, vx, vy, u[k], 0, 0, (k & 1) == 0 ? -1 : 1, true);
        }
    }

    /// <summary>Rozsah z všech bodů, které <see cref="Trojuhelnik"/> vyhodnotí (stejné vynechání dna světa).</summary>
    public static void RozsahTrojuhelniku(double[] ua, double[] uc, double[] ue, ref double lo, ref double hi)
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

    /// <summary>Rozsah z obou trojúhelníků buňky (prázdná: lo = +∞, hi = −∞).</summary>
    public static (double Lo, double Hi) RozsahBunky(double[] u00, double[] u10, double[] u11, double[] u01)
    {
        double lo = double.PositiveInfinity, hi = double.NegativeInfinity;
        RozsahTrojuhelniku(u00, u10, u11, ref lo, ref hi); RozsahTrojuhelniku(u00, u11, u01, ref lo, ref hi);
        return (lo, hi);
    }

    /// <summary>
    /// Lineární interpolace intervalů v bodě buňky [x0, x0 + g]² po trojúhelnících s úhlopříčkou 00–11 (jako plocha kontaktu),
    /// nebo null, když rohy nemají stejný počet intervalů.
    /// </summary>
    public static double[]? Interpolace(double x, double y, double x0, double y0, double g, double[] u00, double[] u10, double[] u11, double[] u01)
    {
        int n = u00.Length;
        if (u10.Length != n || u11.Length != n || u01.Length != n) return null;
        double s = (x - x0) / g, t = (y - y0) / g; var o = new double[n];
        for (int k = 0; k < n; k++)
            o[k] = s >= t ? u00[k] + s * (u10[k] - u00[k]) + t * (u11[k] - u10[k]) : u00[k] + t * (u01[k] - u00[k]) + s * (u11[k] - u01[k]);
        return o;
    }

    /// <summary>Sloučené cílové intervaly zásobníku ve sloupci (x, y) [a0, b0, a1, b1, …] zdola.</summary>
    public static double[] CiloveIntervaly(ITvarZasobnikuSHranicemi z, bool[] cil, double x, double y)
    {
        var s = z.Sloupec(x, y);
        var o = new List<double>();
        foreach (var v in s)
        {
            if (!(v.Material >= 0 && v.Material < cil.Length && cil[v.Material]) || !(v.Z1 > v.Z0)) continue;
            if (o.Count > 0 && Math.Abs(o[^1] - v.Z0) < 1e-9) o[^1] = v.Z1;
            else { o.Add(v.Z0); o.Add(v.Z1); }
        }
        return o.ToArray();
    }
}

/// <summary>Plocha s předpočtenými uzly (diagnostika V6).</summary>
public interface IPlochaSUzly
{
    int PredpocitanychUzlu { get; }
    int DopocitanychUzlu { get; }
    /// <summary>Okraj kontextu, který plocha potřebuje kolem oblasti navíc k R_max (velikost největší buňky) [m].</summary>
    double OkrajBunkyM { get; }
}
