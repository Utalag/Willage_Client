namespace Willage.Gen.Eroze;

/// <summary>
/// Priority-flood s ε (Barnes, Lehman, Mulla 2014 [20]) na torusu: vyplní bezodtoká místa od odtoků, každá buňka pak má
/// souseda níž aspoň o ε. Shoda výšek → nižší index (deterministické).
/// </summary>
public static class PriorityFlood
{
    public static double[] Vypln(Torus t, ReadOnlySpan<double> h, ReadOnlySpan<bool> odtok, double eps)
    {
        var fill = h.ToArray();
        var done = new bool[t.N];
        var q = new PriorityQueue<int, (double, int)>(t.N / 8, Comparer<(double, int)>.Default);
        for (int k = 0; k < t.N; k++) if (odtok[k]) { done[k] = true; q.Enqueue(k, (fill[k], k)); }
        while (q.TryDequeue(out int k, out _))
        {
            for (int d = 0; d < 8; d++)
            {
                int j = t.Soused(k, d);
                if (done[j]) continue;
                done[j] = true;
                if (fill[j] < fill[k] + eps) fill[j] = fill[k] + eps;
                q.Enqueue(j, (fill[j], j));
            }
        }
        return fill;
    }
}
