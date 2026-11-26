namespace Willage.Gen.Klima;

/// <summary>
/// Srážky se srážkovým stínem: vlhkost q (0–1) se nese větrem po řádcích torusu. Nad mořem se doplňuje k 1,
/// nad pevninou prší r = q·(1 + G·max(0, sklon po větru)) a vlhkost ubývá o r·ds/L_kont (stoupání = víc deště
/// a rychlejší vysychání → stín za hřbetem). Průchody kolem planety se opakují, dokud se vlhkost na startu neustálí
/// (periodické řešení nezávislé na volbě startu; nejvýš MaxPruchodu).
/// </summary>
public static class Srazky
{
    /// <summary>Relativní srážky r (násobek základu pásma) jednoho řádku.</summary>
    public static void Radek(ReadOnlySpan<double> hs, ReadOnlySpan<bool> more, int smer, double ds, ParametryKlimatu p, Span<double> r)
    {
        int nx = hs.Length, start = 0; double q = 0.5;
        for (int i = 0; i < nx; i++) if (more[i]) { start = i; q = 1.0; break; }
        double dopl = Math.Min(1.0, ds / p.DoplneniNadMoremM);
        for (int lap = 0; lap < MaxPruchodu; lap++)
        {
            double q0 = q;
            Pruchod(hs, more, smer, ds, p, r, start, dopl, ref q);
            if (Math.Abs(q - q0) < 1e-13) break;
        }
    }

    public const int MaxPruchodu = 12;

    static void Pruchod(ReadOnlySpan<double> hs, ReadOnlySpan<bool> more, int smer, double ds, ParametryKlimatu p, Span<double> r, int start, double dopl, ref double q)
    {
        int nx = hs.Length;
        for (int n = 0; n < nx; n++)
        {
            int i = Mod(start + smer * n, nx);
            double ri;
            if (more[i]) { q += (1 - q) * dopl; ri = q; }
            else
            {
                double sklon = (hs[Mod(i + smer, nx)] - hs[i]) / ds;
                ri = q * (1 + p.OrografieZesileni * Math.Max(0, sklon));
                q = Math.Max(p.VlhkostMin, q - ri * ds / p.KontinentalitaM);
            }
            r[i] = ri;
        }
    }

    static int Mod(int a, int n) { int m = a % n; return m < 0 ? m + n : m; }
}
