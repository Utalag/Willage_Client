using System.Globalization;
using System.Text;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.Vykon;

/// <summary>Měření výkonu GEO1 / K3 / výchozí GEO2 na blocích V8 s opakováním, střídáním cest, mediánem a rozptylem (<c>--jen=GEO2VYKON</c>).</summary>
public static class VykonMereni
{
    public static void Spust(string data, int opakovani, double krokXy, int vlaken, double[]? jedenBlok, string? csv, string stitek)
    {
        T.Sekce($"GEO2 výkon [{stitek}]: GEO1 / K3 / výchozí GEO2, {opakovani} opakování, sloupce po {krokXy} m, {vlaken} vláken");
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        var bloky = jedenBlok is null ? VykonBloky.Seznam(g.Svet) : new List<(string, double, double)> { ("zadaný", jedenBlok[0], jedenBlok[1]) };
        var cesty = new[] { Cesta.Geo1, Cesta.K3, Cesta.Geo2Vychozi };
        var sb = new StringBuilder("stitek;kategorie;x;y;cesta;kontext_median;sloupce_median;celkem_median;celkem_min;celkem_max;relrozptyl;load_pred;cpu_cizi_pred\n");
        var (cpu0, popis0) = VykonZatez.Cizi();
        Console.WriteLine($"  zátěž na začátku: load {VykonZatez.Loadavg()}, cizí procesy CPU {cpu0:F0} %: {popis0}");
        foreach (var (nazev, x, y) in bloky)
        {
            string load = VykonZatez.Loadavg(); var (cpu, popis) = VykonZatez.Cizi();
            var tk = cesty.ToDictionary(c => c, _ => new List<double>()); var ts = cesty.ToDictionary(c => c, _ => new List<double>());
            var kontrolni = cesty.ToDictionary(c => c, _ => new HashSet<ulong>());
            for (int rep = -1; rep < opakovani; rep++)            // rep = −1: zahřívací, vyřazeno
                for (int i = 0; i < cesty.Length; i++)
                {
                    var c = cesty[(i + Math.Max(rep, 0)) % cesty.Length];   // rotace pořadí cest
                    var (k, s, soucet) = VykonCesty.Spust(c, g, kat, d, x, y, krokXy, vlaken);
                    kontrolni[c].Add(soucet);
                    if (rep >= 0) { tk[c].Add(k); ts[c].Add(s); }
                }
            Console.WriteLine($"  blok ({x}, {y}) [{nazev}] load před {load}, cizí CPU {cpu:F0} %");
            var st = new Dictionary<Cesta, Statistika>();
            foreach (var c in cesty)
            {
                var celk = tk[c].Zip(ts[c], (a, b) => a + b).ToList(); var sc = Statistika.Z(celk); st[c] = sc;
                var mk = Statistika.Z(tk[c]); var ms = Statistika.Z(ts[c]);
                Console.WriteLine($"    {c,-12} kontext {mk.Median:F2} + sloupce {ms.Median:F2} = celkem {sc}; kontrolní součet {(kontrolni[c].Count == 1 ? "stejný ve všech opakováních" : "RŮZNÝ!")}");
                T.Je(kontrolni[c].Count == 1, $"{nazev} ({x}, {y}) {c}: výstup stejný ve všech opakováních");
                sb.Append(string.Join(';', stitek, nazev, x.ToString(CultureInfo.InvariantCulture), y.ToString(CultureInfo.InvariantCulture), c, F(mk.Median), F(ms.Median), F(sc.Median), F(sc.Min), F(sc.Max), F(sc.RelRozptyl), load, F(cpu))).Append('\n');
            }
            Console.WriteLine($"    poměr mediánů: K3 / GEO1 ×{st[Cesta.K3].Median / st[Cesta.Geo1].Median:F2}, výchozí / GEO1 ×{st[Cesta.Geo2Vychozi].Median / st[Cesta.Geo1].Median:F2}, výchozí / K3 ×{st[Cesta.Geo2Vychozi].Median / st[Cesta.K3].Median:F2}");
        }
        var (cpu1, popis1) = VykonZatez.Cizi();
        Console.WriteLine($"  zátěž na konci: load {VykonZatez.Loadavg()}, cizí procesy CPU {cpu1:F0} %: {popis1}");
        if (csv is not null) { Directory.CreateDirectory(Path.GetDirectoryName(csv)!); File.WriteAllText(csv, sb.ToString()); }
    }

    private static string F(double v) => v.ToString("F4", CultureInfo.InvariantCulture);
}
