using System.Diagnostics;

namespace Willage.Gen.Eroze;

/// <summary>Časy fází výpočtu (ms).</summary>
public sealed record CasyEroze(long PodkladMs, long ErozeMs, long SitMs);

/// <summary>
/// Hrubá mapa eroze celé planety jednou: navzorkovat periodický podklad → odtoky (nejnižší podíl) → opakovaně
/// [priority-flood → D8 → akumulace → stream power] → konečné směrování a síť toků. Paralelní je jen vzorkování
/// a D8 (pevná místa zápisu); flood, akumulace a eroze jsou sekvenční → výsledek nezávisí na počtu vláken.
/// </summary>
public static class VypocetEroze
{
    public static MapaEroze Spocti(PeriodickyPodklad podklad, ParametryEroze p, int vlaken, out CasyEroze casy)
    {
        var sw = Stopwatch.StartNew();
        var t = new Torus(p.Nx, p.Ny, p.KrokM);
        var m = new MapaEroze(t);
        Parallel.For(0, t.Ny, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, j =>
        {
            for (int i = 0; i < t.Nx; i++) { int k = j * t.Nx + i; m.H0[k] = (float)podklad.Vyska(i * t.Krok, j * t.Krok); }
        });
        long tPodklad = sw.ElapsedMilliseconds;

        var odtok = podklad.Svet.More is { } more ? OdtokMore(t, m.H0, more) : Odtoky(m.H0, p.OdtokPodil);
        var h = new double[t.N]; for (int k = 0; k < t.N; k++) h[k] = m.H0[k];
        double[] fill = h; int[] poradi = Array.Empty<int>(); sbyte[] prij = m.Prijemce;
        for (int s = 0; s <= p.KrokuCasu; s++)
        {
            fill = PriorityFlood.Vypln(t, h, odtok, p.EpsilonVyplneM);
            prij = Smerovani.D8(t, fill, odtok, vlaken);
            poradi = Smerovani.PoradiVzestupne(fill);
            m.A = Smerovani.Akumulace(t, prij, poradi, p.Srazky);
            if (s < p.KrokuCasu) StreamPower.Krok(t, h, m.H0, m.A, prij, poradi, p);
        }
        long tEroze = sw.ElapsedMilliseconds;

        m.Prijemce = prij;
        for (int k = 0; k < t.N; k++)
        {
            m.H[k] = (float)Math.Min(h[k], m.H0[k]);
            if (odtok[k]) m.Priznaky[k] |= MapaEroze.Odtok;
            else if (fill[k] > h[k] + 0.05) m.Priznaky[k] |= MapaEroze.Jezero;
        }
        SitToku.Oznac(m, p.AKritM2);
        casy = new CasyEroze(tPodklad, tEroze - tPodklad, sw.ElapsedMilliseconds - tEroze);
        return m;
    }

    /// <summary>Krok 6b: odtok = moře (uzly v mořském pásu pod hladinou moře).</summary>
    public static bool[] OdtokMore(Torus t, float[] h0, Willage.Gen.Svet.MoreSklon more)
    {
        var o = new bool[t.N];
        for (int k = 0; k < t.N; k++) { var (x, y) = t.Poloha(k); o[k] = more.JeMore(x, y, h0[k]); }
        return o;
    }

    /// <summary>Odtoky = nejnižší podíl buněk podkladu (shoda → nižší index).</summary>
    public static bool[] Odtoky(float[] h0, double podil)
    {
        var idx = new int[h0.Length]; for (int k = 0; k < idx.Length; k++) idx[k] = k;
        var klic = new (float, int)[h0.Length]; for (int k = 0; k < h0.Length; k++) klic[k] = (h0[k], k);
        Array.Sort(klic);
        int n = Math.Max(1, (int)(podil * h0.Length));
        var o = new bool[h0.Length]; for (int i = 0; i < n; i++) o[klic[i].Item2] = true;
        return o;
    }
}
