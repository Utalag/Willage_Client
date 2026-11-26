using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>
/// Krok 6c: moře a mírný sklon pevniny podle masky pevniny (MaskaPevniny, nepravidelné kontinenty na torusu).
/// k = podíl pevniny z masky; moře: od k = 0,5 dolů se povrch plynule sníží o (H + reliéf nad neutrální výškou),
/// při k = 0 je dno pod hladinou vždy. Pevnina (k ≥ 0,5) se nemění kromě sklonu S·max(0, D − D0), D = vzdálenost
/// k moři z hrubé mřížky (Dijkstra 8-sousedů na torusu, bilineárně), D0 ≥ největší D ve startu → start beze změny.
/// </summary>
public sealed class MoreSklon
{
    private readonly ParametrySveta _p;
    public MaskaPevniny Maska { get; }
    private readonly float[] _d; private readonly int _nx, _ny; private readonly double _s;
    public double D0 { get; }

    public MoreSklon(ParametrySveta p, long sd, HashSveta h)
    {
        _p = p;
        Maska = new MaskaPevniny(p, h);
        // vzdálenost k moři na hrubé mřížce
        _s = p.MrizkaVzdalenostiM; _nx = (int)Math.Round(p.PlanetaXM / _s); _ny = (int)Math.Round(p.PlanetaYM / _s);
        var more = new bool[_nx * _ny];
        Parallel.For(0, _ny, j => { for (int i = 0; i < _nx; i++) more[j * _nx + i] = Maska.K(i * _s, j * _s) < 0.5; });
        _d = Vzdalenost(more, _nx, _ny, _s);
        // D0: sklon začne až za startem (start 3 × 3 + jeden uzel kolem)
        double dmax = 0, x0 = p.StartBlok[0] * p.BlokM, y0 = p.StartBlok[1] * p.BlokM;
        for (int i = (int)Math.Floor(x0 / _s) - 1; i <= (int)Math.Ceiling((x0 + 3 * p.BlokM) / _s) + 1; i++)
        for (int j = (int)Math.Floor(y0 / _s) - 1; j <= (int)Math.Ceiling((y0 + 3 * p.BlokM) / _s) + 1; j++)
            dmax = Math.Max(dmax, _d[Mod(j, _ny) * _nx + Mod(i, _nx)]);
        D0 = Math.Max(p.SklonOdPobreziM, dmax);
        StartNaPevnine = Maska.StartMin >= Maska.Prah + p.MorePrechod;
        StartBezPosunu = StartNaPevnine;
    }

    public double Podil => Maska.Podil;
    public bool StartNaPevnine { get; }
    public bool StartBezPosunu { get; }

    private static int Mod(int a, int n) { int r = a % n; return r < 0 ? r + n : r; }

    private static float[] Vzdalenost(bool[] more, int nx, int ny, double s)
    {
        var d = new float[nx * ny]; Array.Fill(d, float.MaxValue);
        var q = new PriorityQueue<int, (float, int)>();
        for (int k = 0; k < d.Length; k++) if (more[k]) { d[k] = 0; q.Enqueue(k, (0f, k)); }
        int[] dx = { 1, -1, 0, 0, 1, 1, -1, -1 }, dy = { 0, 0, 1, -1, 1, -1, 1, -1 };
        float[] w = { 1, 1, 1, 1, MathF.Sqrt(2), MathF.Sqrt(2), MathF.Sqrt(2), MathF.Sqrt(2) };
        while (q.TryDequeue(out int k, out var pr))
        {
            if (pr.Item1 > d[k]) continue;
            int i = k % nx, j = k / nx;
            for (int n = 0; n < 8; n++)
            {
                int v = Mod(j + dy[n], ny) * nx + Mod(i + dx[n], nx);
                float nd = d[k] + w[n] * (float)s;
                if (nd < d[v]) { d[v] = nd; q.Enqueue(v, (nd, v)); }
            }
        }
        return d;
    }

    /// <summary>Vzdálenost k moři (m), bilineárně z hrubé mřížky, periodicky.</summary>
    public double VzdalenostOdMore(double x, double y)
    {
        double fx = x / _s, fy = y / _s; int i = (int)Math.Floor(fx), j = (int)Math.Floor(fy); double u = fx - i, v = fy - j;
        double D(int a, int b) => _d[Mod(b, _ny) * _nx + Mod(a, _nx)];
        return (D(i, j) * (1 - u) + D(i + 1, j) * u) * (1 - v) + (D(i, j + 1) * (1 - u) + D(i + 1, j + 1) * u) * v;
    }

    /// <summary>Krok 6e: vzdálenost k moři pro hladinu podzemní vody; start 3 × 3 je chráněn (vzdálenost se tam zvětší, takže se hladina k moři neváže – otisky startu beze změny).</summary>
    public double VzdalenostProVodu(double x, double y)
    {
        double d = VzdalenostOdMore(x, y);
        double dst = Maska.VzdalenostOdStartu(x, y);
        return d + 1.0e5 * (1.0 - Gd.Smoothstep(_p.StartVodaOchranaM, _p.StartVodaOchranaM + _p.StartVodaPrechodM, dst));
    }

    public string Kanonicky() => FormattableString.Invariant(
        $"more6d|{_p.PlanetaXM}|{_p.PlanetaYM}|{_p.HladinaMoreM}|{_p.HloubkaMoreM}|{_p.MorePrechod}|{_p.SklonKontinentu}|{_p.SklonOdPobreziM}|{_p.MrizkaVzdalenostiM}|{D0:R}|{_p.PodilMore}|{_p.OdchylkaMoreProcBodu}|{_p.KontinentuMin}|{_p.KontinentuMax}|{_p.KontinentVelikost}|{_p.Clenitost}|{_p.ClenitostSila}|{_p.SumVln}|{_p.WarpVln}|{_p.SumLambdaMinM}|{_p.SumLambdaMaxM}|{_p.WarpLambdaMinM}|{_p.WarpM}|{_p.RezervaSevuM}|{_p.SevPrechodM}|{_p.SevMekkySpad}|{_p.SevMekkyPasM}|{_p.StartPolomerM}|{_p.StartPrechodM}|{_p.StartRezerva}|{_p.MrizkaPrahuM}|{_p.OstrovuPocet}|{_p.OstrovPolomerM}|{_p.OstrovVyska}|{_p.SevZvlneniM}|{_p.SevZvlneniLambdaMinM}|{_p.SevZvlneniLambdaMaxM}|") + Maska.Kanonicky();

    public double Pevnina(double x, double y) => Maska.K(x, y);

    /// <summary>Povrch s mořem a sklonem (před stropem povrchu). Pevnina k ≥ 0,5 jen + sklon; k = 1 a sklon 0 → h beze změny.</summary>
    public double Aplikuj(double x, double y, double h, double neutral)
    {
        double k = Maska.K(x, y);
        double g = 1.0 - Gd.Smoothstep(0.0, 0.5, k);
        double sklon = _p.SklonKontinentu * Math.Max(0.0, VzdalenostOdMore(x, y) - D0);
        return h + sklon - g * (_p.HloubkaMoreM + Math.Max(0.0, h - neutral));
    }

    /// <summary>Moře: k &lt; 0,5 a povrch pod hladinou moře.</summary>
    public bool JeMore(double x, double y, double vyska) => vyska < _p.HladinaMoreM && Pevnina(x, y) < 0.5;
}
