namespace Willage.Gen.Eroze;

/// <summary>Jezero = souvislá oblast uzlů s příznakem Jezero (4-sousedství, periodicky); hladina = úroveň vyplnění.</summary>
public readonly record struct Jezero(int Uzel, int Uzlu, double PlochaM2, double HladinaM, double MaxHloubkaM);

public static class Jezera
{
    public static List<Jezero> Najdi(MapaEroze m)
    {
        var t = m.T; var byl = new bool[t.N]; var r = new List<Jezero>(); var fronta = new Queue<int>();
        int[] d4 = { 0, 1, 2, 3 };
        for (int k = 0; k < t.N; k++)
        {
            if (byl[k] || (m.Priznaky[k] & MapaEroze.Jezero) == 0) continue;
            int n = 0; double hl = double.MinValue, hmax = 0;
            byl[k] = true; fronta.Enqueue(k);
            while (fronta.TryDequeue(out int u))
            {
                n++; hl = Math.Max(hl, m.Vypln[u]); hmax = Math.Max(hmax, m.Vypln[u] - m.H[u]);
                foreach (int d in d4)
                {
                    int v = t.Soused(u, d);
                    if (!byl[v] && (m.Priznaky[v] & MapaEroze.Jezero) != 0) { byl[v] = true; fronta.Enqueue(v); }
                }
            }
            r.Add(new Jezero(k, n, n * t.Krok * t.Krok, hl, hmax));
        }
        r.Sort((a, b) => b.Uzlu != a.Uzlu ? b.Uzlu.CompareTo(a.Uzlu) : a.Uzel.CompareTo(b.Uzel));
        return r;
    }
}
