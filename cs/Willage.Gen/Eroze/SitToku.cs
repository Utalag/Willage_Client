namespace Willage.Gen.Eroze;

/// <summary>Tok od pramene (hlava koryta) po soutok s dříve vedeným tokem nebo po odtok.</summary>
public readonly record struct Tok(int Pramen, int Konec, double DelkaM, int Uzlu);

/// <summary>Říční síť z hotové mapy: koryto = A ≥ A_krit, pramen toku = koryto bez dárce-koryta.</summary>
public static class SitToku
{
    public static void Oznac(MapaEroze m, double aKrit)
    {
        var t = m.T;
        var darcu = new byte[t.N];
        for (int k = 0; k < t.N; k++)
        {
            m.Priznaky[k] &= MapaEroze.Odtok | MapaEroze.Jezero;
            if (m.A[k] >= aKrit) m.Priznaky[k] |= MapaEroze.Koryto;
        }
        for (int k = 0; k < t.N; k++)
            if ((m.Priznaky[k] & MapaEroze.Koryto) != 0 && m.Dolu(k) is int r && r >= 0) darcu[r]++;
        for (int k = 0; k < t.N; k++)
            if ((m.Priznaky[k] & MapaEroze.Koryto) != 0 && darcu[k] == 0) m.Priznaky[k] |= MapaEroze.PramenToku;
    }

    /// <summary>Toky v pořadí indexu pramene; každý vede dolů, dokud nenarazí na již vedený uzel nebo odtok.</summary>
    public static List<Tok> Toky(MapaEroze m)
    {
        var t = m.T; var byl = new bool[t.N]; var vysl = new List<Tok>();
        for (int k = 0; k < t.N; k++)
        {
            if ((m.Priznaky[k] & MapaEroze.PramenToku) == 0) continue;
            int u = k, n = 0; double l = 0;
            while (true)
            {
                byl[u] = true; n++;
                int d = m.Prijemce[u]; if (d < 0) break;
                int r = t.Soused(u, d); l += Torus.Delka[d] * t.Krok;
                if (byl[r]) { u = r; break; }
                u = r;
            }
            vysl.Add(new Tok(k, u, l, n));
        }
        return vysl;
    }

    /// <summary>Celková délka koryt (m): součet hran koryto → příjemce.</summary>
    public static double DelkaKoryt(MapaEroze m)
    {
        double l = 0;
        for (int k = 0; k < m.T.N; k++)
            if ((m.Priznaky[k] & MapaEroze.Koryto) != 0 && m.Prijemce[k] >= 0) l += Torus.Delka[m.Prijemce[k]] * m.T.Krok;
        return l;
    }
}
