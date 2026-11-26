namespace Willage.Gen.Eroze;

/// <summary>D8 po vyplněném povrchu (O'Callaghan & Mark 1984 [86]) a pořadí buněk podle výšky (pro akumulaci a erozi).</summary>
public static class Smerovani
{
    /// <summary>Směr nejstrmějšího spádu (0–7), −1 u odtoku. Shoda → nižší směr. Paralelně po řádcích, zápis na pevné místo.</summary>
    public static sbyte[] D8(Torus t, double[] fill, bool[] odtok, int vlaken)
    {
        var r = new sbyte[t.N];
        Parallel.For(0, t.Ny, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, j =>
        {
            for (int i = 0; i < t.Nx; i++)
            {
                int k = j * t.Nx + i;
                if (odtok[k]) { r[k] = -1; continue; }
                double best = 0; int bd = -1;
                for (int d = 0; d < 8; d++)
                {
                    double s = (fill[k] - fill[t.Soused(k, d)]) / Torus.Delka[d];
                    if (s > best) { best = s; bd = d; }
                }
                r[k] = (sbyte)bd;
            }
        });
        return r;
    }

    /// <summary>Indexy seřazené podle vyplněné výšky vzestupně (shoda → index); příjemce je vždy dřív než dárce.</summary>
    public static int[] PoradiVzestupne(double[] fill)
    {
        var idx = new int[fill.Length]; for (int k = 0; k < idx.Length; k++) idx[k] = k;
        var klic = ((double[])fill.Clone());
        Array.Sort(klic, idx);                  // nestabilní, proto shody dorovnat podle indexu
        int a = 0;
        while (a < idx.Length)
        {
            int b = a + 1; while (b < idx.Length && klic[b] == klic[a]) b++;
            if (b - a > 1) Array.Sort(idx, a, b - a);
            a = b;
        }
        return idx;
    }

    /// <summary>Plocha povodí (m²) × srážky; pořadí sestupně podle výšky.</summary>
    public static float[] Akumulace(Torus t, sbyte[] prij, int[] vzestupne, double srazky)
    {
        var a = new double[t.N];
        double bunka = t.Krok * t.Krok * srazky;
        for (int n = vzestupne.Length - 1; n >= 0; n--)
        {
            int k = vzestupne[n];
            a[k] += bunka;
            if (prij[k] >= 0) a[t.Soused(k, prij[k])] += a[k];
        }
        var f = new float[t.N]; for (int k = 0; k < t.N; k++) f[k] = (float)a[k];
        return f;
    }
}
