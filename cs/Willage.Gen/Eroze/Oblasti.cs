namespace Willage.Gen.Eroze;

/// <summary>Souvislá oblast uzlů mapy (4-sousedství, periodicky na torusu).</summary>
public readonly record struct Oblast(int Uzel, int Uzlu, double PlochaM2);

/// <summary>Krok 6c: souvislé oblasti (pevniny: kontinenty a ostrovy) podle podmínky na uzlu.</summary>
public static class Oblasti
{
    public static List<Oblast> Najdi(MapaEroze m, Func<int, bool> patri)
    {
        var t = m.T; var byl = new bool[t.N]; var r = new List<Oblast>(); var q = new Queue<int>();
        for (int k = 0; k < t.N; k++)
        {
            if (byl[k] || !patri(k)) continue;
            int n = 0; byl[k] = true; q.Enqueue(k);
            while (q.TryDequeue(out int u))
            {
                n++;
                for (int d = 0; d < 4; d++)
                {
                    int v = t.Soused(u, d);
                    if (!byl[v] && patri(v)) { byl[v] = true; q.Enqueue(v); }
                }
            }
            r.Add(new Oblast(k, n, n * t.Krok * t.Krok));
        }
        r.Sort((a, b) => b.Uzlu != a.Uzlu ? b.Uzlu.CompareTo(a.Uzlu) : a.Uzel.CompareTo(b.Uzel));
        return r;
    }

    /// <summary>Pevnina = uzel, který není moře/odtok.</summary>
    public static List<Oblast> Pevniny(MapaEroze m) => Najdi(m, k => (m.Priznaky[k] & MapaEroze.Odtok) == 0);
}
