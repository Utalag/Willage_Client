using Willage.Gen.Eroze;

namespace Willage.Gen.Klima;

/// <summary>
/// Krok 7c (Jan 13:24): dobití hladiny podzemní vody e ∈ [0, 1] na mřížce mapy klimatu (32 m, torus).
/// e = max(e_w, e_zdrojů), e_w = smoothstep(HladinaWPrah, HladinaWPlna, w); zdroje: pobřeží (uzly moře), aktivní koryta, vodníci a oázy
/// (uvnitř plného poloměru 1, dál smoothstep do nuly). e = 0 znamená bez hladiny. Bilineárně periodicky jako klima; deterministické
/// (jen z map, bez náhody), nezávislé na vláknech.
/// </summary>
public sealed class NapajeniVody
{
    public Torus T { get; }
    public float[] E { get; }
    private readonly double _px, _py;

    NapajeniVody(Torus t) { T = t; E = new float[t.N]; _px = t.Nx * t.Krok; _py = t.Ny * t.Krok; }

    static double Smooth(double a, double b, double x) { if (b <= a) return x >= b ? 1.0 : 0.0; double t = Math.Clamp((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }

    public static NapajeniVody Spocti(MapaEroze m, MapaKlimatu mk, HydrologieKlimatu hk, IEnumerable<Vodnik> zdroje, ParametryKlimatu p)
    {
        var t = m.T; var r = new NapajeniVody(t); var e = r.E;
        var more = new bool[t.N];
        for (int k = 0; k < t.N; k++)
        {
            more[k] = (m.Priznaky[k] & MapaEroze.Odtok) != 0;
            e[k] = more[k] ? 1f : (float)Smooth(p.HladinaWPrah, p.HladinaWPlna, mk.W[k]);
        }
        void Razit(int i, int j, double plne, double doM)
        {
            int rc = (int)Math.Ceiling(doM / t.Krok);
            for (int dj = -rc; dj <= rc; dj++)
            for (int di = -rc; di <= rc; di++)
            {
                double d = Math.Sqrt((double)di * di + (double)dj * dj) * t.Krok;
                if (d >= doM) continue;
                float v = d <= plne ? 1f : (float)(1.0 - Smooth(plne, doM, d));
                int q = t.K(i + di, j + dj);
                if (v > e[q]) e[q] = v;
            }
        }
        // pobřeží: uzly moře sousedící s pevninou
        for (int j = 0; j < t.Ny; j++)
        for (int i = 0; i < t.Nx; i++)
        {
            int k = j * t.Nx + i;
            if (!more[k]) continue;
            bool breh = false;
            for (int d = 0; d < 4 && !breh; d++) if (!more[t.Soused(k, d)]) breh = true;
            if (breh) Razit(i, j, p.HladinaBrehPlneM, p.HladinaBrehDoM);
        }
        // aktivní koryta a dnešní tok mimo koryto
        for (int k = 0; k < t.N; k++)
            if ((hk.Stav[k] & (HydrologieKlimatu.Aktivni | HydrologieKlimatu.BezKoryta)) != 0)
                Razit(k % t.Nx, k / t.Nx, p.HladinaKorytoPlneM, p.HladinaKorytoDoM);
        // vodníci a oázy
        foreach (var z in zdroje) Razit(z.I, z.J, p.HladinaZdrojPlneM, p.HladinaZdrojDoM);
        return r;
    }

    /// <summary>Dobití v bodě (bilineárně, periodicky); ≤ 0 = bez hladiny.</summary>
    public double Dobiti(double x, double y)
    {
        double fx = PeriodickyPodklad.Zabal(x, _px) / T.Krok, fy = PeriodickyPodklad.Zabal(y, _py) / T.Krok;
        int i = (int)Math.Floor(fx), j = (int)Math.Floor(fy); double u = fx - i, v = fy - j;
        return (E[T.K(i, j)] * (1 - u) + E[T.K(i + 1, j)] * u) * (1 - v) + (E[T.K(i, j + 1)] * (1 - u) + E[T.K(i + 1, j + 1)] * u) * v;
    }

    /// <summary>Podíl uzlů s e ≤ 0 (bez hladiny) mezi uzly pevniny.</summary>
    public double PodilBezHladiny(MapaEroze m)
    {
        int n = 0, b = 0;
        for (int k = 0; k < T.N; k++) { if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue; n++; if (E[k] <= 0f) b++; }
        return n == 0 ? 0 : (double)b / n;
    }
}
