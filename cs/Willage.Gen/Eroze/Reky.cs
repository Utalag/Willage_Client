namespace Willage.Gen.Eroze;

/// <summary>Řeka = ústí (koryto, jehož příjemce je odtok/moře) s nejdelší cestou korytem proti proudu (hlavní tok).</summary>
public readonly record struct Reka(int Usti, double DelkaM, double PovodiM2);

public static class Reky
{
    /// <summary>Nejdelší cesta korytem k uzlu: dárci mají menší A než příjemce, proto stačí pořadí podle A.</summary>
    public static List<Reka> Najdi(MapaEroze m)
    {
        var t = m.T; var delka = new double[t.N];
        var kor = new List<int>();
        for (int k = 0; k < t.N; k++) if ((m.Priznaky[k] & MapaEroze.Koryto) != 0) kor.Add(k);
        kor.Sort((a, b) => m.A[a] != m.A[b] ? m.A[a].CompareTo(m.A[b]) : a.CompareTo(b));
        var r = new List<Reka>();
        foreach (int k in kor)
        {
            int d = m.Prijemce[k];
            if (d < 0) continue;
            int u = t.Soused(k, d);
            double l = delka[k] + Torus.Delka[d] * t.Krok;
            if ((m.Priznaky[u] & MapaEroze.Odtok) != 0) r.Add(new Reka(k, l, m.A[k]));
            else if (l > delka[u]) delka[u] = l;
        }
        r.Sort((a, b) => b.DelkaM != a.DelkaM ? b.DelkaM.CompareTo(a.DelkaM) : a.Usti.CompareTo(b.Usti));
        return r;
    }
}
