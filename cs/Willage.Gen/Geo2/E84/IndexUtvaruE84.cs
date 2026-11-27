using Willage.Gen.Geologie;
using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Index těles jednoho druhu E84 po dlaždicích 8 × 8 m (3.5, K3): instance, jejichž obálka zasahuje do oblasti, ve stejném pořadí
/// jako <see cref="TvorbaUtvaru.Features"/> (gi, pak gj). Instance se berou z veřejného <c>Features</c> v jejich středu (stará cesta
/// se nemění, bez reflexe); parametry mřížky útvarů čte z veřejné tabulky <see cref="TvorbaUtvaru.Mrizka"/>.
/// Kandidát v bodě musí splnit i podmínku rozsahu buněk <c>Features</c> (|gi·g − x| v dosahu r), takže výsledek je bitově stejný.
/// Neměnný, vláknově bezpečný.
/// </summary>
public sealed class IndexUtvaruE84
{
    public const double DlazdiceM = 8.0;

    /// <summary>Řádek tabulky mřížky útvarů staré cesty (<see cref="TvorbaUtvaru.Mrizka"/>): klíč, krok mřížky g, četnost, dosah hledání r.</summary>
    public static (string Klic, double G, double Cet, double R) Mrizka(DruhUtvaru d)
    {
        foreach (var m in TvorbaUtvaru.Mrizka) if (m.Druh == d) return (m.Klic, m.G, m.Cet, m.R);
        throw new ArgumentOutOfRangeException(nameof(d), d, "druh není v tabulce mřížky útvarů");
    }

    /// <summary>Instance s přesnou obálkou O (průnik s obálkou staré cesty) a buňkou mřížky.</summary>
    public readonly record struct Polozka(Utvar F, long Gi, long Gj, double X0, double Y0, double Z0, double X1, double Y1, double Z1);

    public DruhUtvaru Druh { get; }
    public OblastBloku Oblast { get; }
    public IReadOnlyList<Polozka> Polozky => _p;
    private readonly Polozka[] _p;
    private readonly int[] _start, _idx; // CSR: dlaždice → indexy položek
    private readonly int _nx, _ny;
    private readonly double _g, _r;

    private IndexUtvaruE84(DruhUtvaru d, OblastBloku o, Polozka[] p, int[] start, int[] idx, int nx, int ny)
    {
        Druh = d; Oblast = o; _p = p; _start = start; _idx = idx; _nx = nx; _ny = ny;
        for (int k = 0; k + 1 < start.Length; k++) MaxVDlazdici = Math.Max(MaxVDlazdici, start[k + 1] - start[k]);
        var m = Mrizka(d); _g = m.G; _r = m.R;
    }

    public static IndexUtvaruE84 Sestav(SvetFn s, DruhUtvaru druh, OblastBloku o)
    {
        var (klic, g, cet, r) = Mrizka(druh);
        var tv = new TvorbaUtvaru(s); // vlastní keš, sdílená stará cesta se nedotkne
        long gi0 = Gd.Floori((o.X0 - r) / g), gi1 = Gd.Floori((o.X1 + r) / g);
        long gj0 = Gd.Floori((o.Y0 - r) / g), gj1 = Gd.Floori((o.Y1 + r) / g);
        var pol = new List<Polozka>();
        for (long gi = gi0; gi <= gi1; gi++)
        for (long gj = gj0; gj <= gj1; gj++)
        {
            long hsh = StableHash.Mix(s.Sd, "E84_" + klic, gi * 7919 + gj);
            if (VNoise.U(hsh) >= cet) continue;
            double cx = gi * g + VNoise.U(StableHash.Mix(hsh, "R", 1)) * g, cy = gj * g + VNoise.U(StableHash.Mix(hsh, "R", 2)) * g;
            Utvar? f = null;
            foreach (var c in tv.Features(cx, cy))
                if (c.K == druh && c.Seed == (hsh & 0x7FFFFFFF) && c.P[0] == cx && c.P[1] == cy) { f = c; break; }
            if (f is null) throw new InvalidOperationException($"útvar {klic} ({gi}, {gj}) nenalezen ve Features – tabulka mřížky nesedí se starou cestou");
            var b = f.Box;
            if (b[3] < o.X0 || b[0] > o.X1 || b[4] < o.Y0 || b[1] > o.Y1) continue;
            var e = ObalkaE84.Presna(f);
            if (e[3] < e[0] || e[4] < e[1] || e[5] < e[2]) continue; // prázdná
            pol.Add(new Polozka(f, gi, gj, e[0], e[1], e[2], e[3], e[4], e[5]));
        }
        int nx = Math.Max(1, (int)Math.Ceiling((o.X1 - o.X0) / DlazdiceM)), ny = Math.Max(1, (int)Math.Ceiling((o.Y1 - o.Y0) / DlazdiceM));
        var seznamy = new List<int>[nx * ny];
        for (int k = 0; k < seznamy.Length; k++) seznamy[k] = new List<int>();
        for (int k = 0; k < pol.Count; k++)
        {
            var p = pol[k];
            int ax = Dl(p.X0, o.X0, nx), bx = Dl(p.X1, o.X0, nx), ay = Dl(p.Y0, o.Y0, ny), by = Dl(p.Y1, o.Y0, ny);
            for (int i = ax; i <= bx; i++) for (int j = ay; j <= by; j++) seznamy[i * ny + j].Add(k);
        }
        var start = new int[seznamy.Length + 1];
        for (int k = 0; k < seznamy.Length; k++) start[k + 1] = start[k] + seznamy[k].Count;
        var idx = new int[start[^1]];
        for (int k = 0; k < seznamy.Length; k++) seznamy[k].CopyTo(idx, start[k]);
        return new IndexUtvaruE84(druh, o, pol.ToArray(), start, idx, nx, ny);
    }

    private static int Dl(double v, double v0, int n) => Math.Clamp((int)Math.Floor((v - v0) / DlazdiceM), 0, n - 1);

    /// <summary>Kandidáti v bodě (pořadí <c>Features</c>): obálka O obsahuje bod a buňka je v dosahu hledání <c>Features</c>.</summary>
    public int Kandidati(double x, double y, double z, Span<int> cil)
    {
        if (!Oblast.Obsahuje(x, y)) throw new InvalidOperationException($"bod ({x}, {y}) mimo kontext bloku {Oblast}");
        int t = Dl(x, Oblast.X0, _nx) * _ny + Dl(y, Oblast.Y0, _ny);
        long gi0 = Gd.Floori((x - _r) / _g), gi1 = Gd.Floori((x + _r) / _g), gj0 = Gd.Floori((y - _r) / _g), gj1 = Gd.Floori((y + _r) / _g);
        int n = 0;
        for (int k = _start[t]; k < _start[t + 1]; k++)
        {
            ref readonly var p = ref _p[_idx[k]];
            if (p.Gi < gi0 || p.Gi > gi1 || p.Gj < gj0 || p.Gj > gj1) continue;
            if (x < p.X0 || x > p.X1 || y < p.Y0 || y > p.Y1 || z < p.Z0 || z > p.Z1) continue;
            cil[n++] = _idx[k];
        }
        return n;
    }

    /// <summary>Nejvíc položek v jedné dlaždici (velikost pracovního pole kandidátů).</summary>
    public int MaxVDlazdici { get; }
}
