namespace Willage.Gen.Geologie;

/// <summary>
/// Sloupce oblasti po 0,25 m paralelně (Jan 2026-11-26 9:32, rozhodnutí 4). Každé vlákno má vlastní GeologieCs (Klon),
/// sloupce se zapisují na pevné místo podle (ix, iy) → výsledek nezávisí na počtu vláken ani na rozdělení práce
/// (keše jsou čisté funkce s přesným klíčem).
/// </summary>
public static class ParalelniSloupce
{
    /// <summary>Bajty n × n sloupců (pořadí ix, pak iy, pak z), sloupec 0,25 m do 128 m.</summary>
    public static byte[] Oblast(GeologieCs g, double ox, double oy, int n, int vlaken, double krokXy = 0.25)
    {
        const int nz = 512;
        var buf = new byte[(long)n * n * nz];
        var opt = new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, vlaken) };
        Parallel.For(0, n, opt, () => g.Klon(), (ix, _, gl) =>
        {
            for (int iy = 0; iy < n; iy++)
            {
                var s = gl.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0.25, 128.0);
                Array.Copy(s, 0, buf, ((long)ix * n + iy) * nz, nz);
            }
            return gl;
        }, _ => { });
        return buf;
    }
}
