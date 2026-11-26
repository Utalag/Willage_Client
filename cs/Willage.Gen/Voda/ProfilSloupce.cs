using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda;

/// <summary>Interval výšek v m (lo &lt; hi).</summary>
public readonly record struct Interval(double Lo, double Hi);

/// <summary>Sevřená propustná vrstva mezi dvěma těsněními pod hladinou.</summary>
public readonly record struct SevrenaVrstva(double Lo, double Hi, int Material);

/// <summary>Voda ve sloupci odvozená z geologie a hladiny (nic se neukládá).</summary>
public sealed record ProfilSloupce(double Hladina, double Povrch, Interval? Nasyceno, IReadOnlyList<Interval> Zavesena,
    IReadOnlyList<SevrenaVrstva> Sevrene, bool HladinaVTesneni)
{
    const double C = GeologyGridConstants.CellM;

    /// <summary>
    /// Třídy buněk: vzduch nad povrchem / propustné těleso (vč. dutin pod povrchem) / těsnění.
    /// Volná hladina: od L dolů přes těleso po první těsnění. Zavěšená: film nad těsněním, které leží nad L.
    /// Sevřená: běh tělesa pod volnou zónou ohraničený těsněním shora i zdola (dno sloupce = těsnění).
    /// </summary>
    /// <param name="nitro">maska buněk nitra sopky (krok 5: těsnění), nebo null</param>
    public static ProfilSloupce Spocti(byte[] sloupec, double povrch, double hladina, Propustnost pr, double film, bool[]? nitro = null)
    {
        int n = sloupec.Length;
        int kTop = Math.Min(n - 1, (int)Math.Floor((povrch - 1e-9) / C));   // nejvyšší pevná buňka
        // 0 vzduch nad povrchem, 1 těleso, 2 těsnění
        var t = new byte[n];
        for (int k = 0; k < n; k++)
        {
            int m = sloupec[k];
            if (k > kTop) t[k] = 0;
            else if (nitro is not null && nitro[k]) t[k] = 2;
            else if (m == Propustnost.Vzduch) t[k] = 1;
            else t[k] = pr.Teleso(m) ? (byte)1 : (byte)2;
        }
        // volná hladina
        Interval? nas = null; bool vTes = false; int kDnoVolne = n;
        int kL = Math.Clamp((int)Math.Floor((hladina - 1e-9) / C), 0, kTop);
        if (hladina > 0 && kTop >= 0)
        {
            if (t[kL] == 1)
            {
                int k = kL; while (k - 1 >= 0 && t[k - 1] == 1) k--;
                nas = new Interval(k * C, hladina); kDnoVolne = k;
            }
            else { vTes = true; kDnoVolne = kL; }
        }
        // zavěšená voda: vršek běhu těsnění nad L, nad ním těleso
        var zav = new List<Interval>();
        for (int k = 0; k < kTop; k++)
        {
            if (t[k] != 2 || t[k + 1] != 1) continue;
            double z = (k + 1) * C;
            if (z <= hladina + 1e-9) continue;
            int k2 = k + 1; while (k2 + 1 <= kTop && t[k2 + 1] == 1) k2++;
            double hi = Math.Min(z + film, Math.Min((k2 + 1) * C, povrch));
            if (hi > z + 1e-9) zav.Add(new Interval(z, hi));
        }
        // sevřené vrstvy pod volnou zónou
        var sev = new List<SevrenaVrstva>();
        int kk = 0;
        while (kk < Math.Min(kDnoVolne, kTop + 1))
        {
            if (t[kk] != 1) { kk++; continue; }
            int a = kk; while (kk < n && t[kk] == 1) kk++;
            int b = kk - 1;
            bool dole = a == 0 || t[a - 1] == 2, nahore = b + 1 < n && t[b + 1] == 2;
            if (dole && nahore && (b + 1) * C <= hladina + 1e-9) sev.Add(new SevrenaVrstva(a * C, (b + 1) * C, Prevazujici(sloupec, a, b)));
        }
        return new ProfilSloupce(hladina, povrch, nas, zav, sev, vTes);
    }

    private static int Prevazujici(byte[] s, int a, int b)
    {
        Span<int> c = stackalloc int[256]; int best = s[a];
        for (int k = a; k <= b; k++) { c[s[k]]++; if (c[s[k]] > c[best] || (c[s[k]] == c[best] && s[k] < best)) best = s[k]; }
        return best;
    }
}
