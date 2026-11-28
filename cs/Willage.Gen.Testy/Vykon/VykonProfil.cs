using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.Vykon;

/// <summary>Jedna cesta na jednom bloku opakovaně (pro <c>dotnet-trace</c>): <c>--jen=GEO2PROFIL --blok=ox,oy --cesta=geo1|k3|geo2 [--opak=2]</c>.</summary>
public static class VykonProfil
{
    public static void Spust(string data, double ox, double oy, string cesta, int opak, double krokXy, int vlaken)
    {
        T.Sekce($"GEO2 profil: blok ({ox}, {oy}), cesta {cesta}, {opak}× , krok {krokXy} m, {vlaken} vláken");
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        if (cesta == "hranice") { MikroHranice(g, ox, oy); return; }
        if (cesta == "hranice8") { MikroHranice8(g, ox, oy, vlaken); return; }
        var c = cesta switch { "geo1" => Cesta.Geo1, "k3" => Cesta.K3, _ => Cesta.Geo2Vychozi };
        for (int i = 0; i < opak; i++)
        {
            long a0 = GC.GetTotalAllocatedBytes(), g0 = GC.CollectionCount(0), g1 = GC.CollectionCount(1), g2 = GC.CollectionCount(2); var p0 = GC.GetTotalPauseDuration();
            var (k, s, soucet) = VykonCesty.Spust(c, g, kat, d, ox, oy, krokXy, vlaken);
            Console.WriteLine($"  průchod {i}: kontext {k:F2} s, sloupce {s:F2} s, součet {soucet:X}; GC gen0/1/2 {GC.CollectionCount(0) - g0}/{GC.CollectionCount(1) - g1}/{GC.CollectionCount(2) - g2}, pauzy GC {(GC.GetTotalPauseDuration() - p0).TotalSeconds:F2} s, alokováno {(GC.GetTotalAllocatedBytes() - a0) / 1e9:F1} GB, server GC {System.Runtime.GCSettings.IsServerGC}");
        }
    }

    /// <summary>Mikroměření jednoho volání <c>GeoVrstvy.Hranice(x, y)</c> (1 vlákno): čas a alokace na volání, rozpad na <c>Vahy</c> / <c>VyskaTvar</c> / <c>VyskaW</c> / <c>Vrstvy.Hranice</c>.</summary>
    private static void MikroHranice(GeologieCs g, double ox, double oy)
    {
        const int n = 64; var xs = new List<(double X, double Y)>();
        for (int i = 0; i < n; i++) for (int j = 0; j < n; j++) xs.Add((ox + (i + 0.5) * 2.0, oy + (j + 0.5) * 2.0));
        for (int pr = 0; pr < 3; pr++)
        {
            long a0 = GC.GetAllocatedBytesForCurrentThread(); var sw = System.Diagnostics.Stopwatch.StartNew(); double s = 0;
            foreach (var (x, y) in xs) s += g.Geo.Hranice(x, y).Count;
            double t = sw.Elapsed.TotalSeconds; long ab = GC.GetAllocatedBytesForCurrentThread() - a0;
            a0 = GC.GetAllocatedBytesForCurrentThread(); sw.Restart(); double zv = 0;
            foreach (var (x, y) in xs) { var w = g.Svet.Vahy(x, y); zv += g.Svet.VyskaTvar(x, y) + g.Svet.VyskaW(x, y, w); }
            double tv = sw.Elapsed.TotalSeconds; long av = GC.GetAllocatedBytesForCurrentThread() - a0;
            Console.WriteLine($"  průchod {pr}: Hranice(x, y) {1e6 * t / xs.Count:F0} µs, {ab / (double)xs.Count / 1024:F0} kB na volání; z toho Vahy+VyskaTvar+VyskaW {1e6 * tv / xs.Count:F0} µs, {av / (double)xs.Count / 1024:F1} kB ({s + zv:F0})");
        }
    }

    /// <summary>Totéž ve více vláknech: (a) jedna sdílená instance (jako GEO2 kontext), (b) <c>Klon()</c> na vlákno (jako GEO1).</summary>
    private static void MikroHranice8(GeologieCs g0, double ox, double oy, int vlaken)
    {
        const int n = 128; var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        for (int pr = 0; pr < 3; pr++)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew(); long volani = 0;
            Parallel.For(0, n, opt, i => { long c = 0; for (int j = 0; j < n; j++) c += g0.Geo.Hranice(ox + (i + 0.5), oy + (j + 0.5)).Count; Interlocked.Add(ref volani, n); });
            double a = sw.Elapsed.TotalSeconds; sw.Restart();
            Parallel.For(0, n, opt, () => g0.Klon(), (i, _, g) => { for (int j = 0; j < n; j++) g.Geo.Hranice(ox + (i + 0.5), oy + (j + 0.5)); return g; }, _ => { });
            double b = sw.Elapsed.TotalSeconds;
            Console.WriteLine($"  průchod {pr}: {vlaken} vláken, {volani} volání Hranice: sdílená instance {a:F2} s ({1e6 * a * vlaken / volani:F0} µs jádro-času / volání), Klon na vlákno {b:F2} s ({1e6 * b * vlaken / volani:F0} µs)");
        }
    }
}
