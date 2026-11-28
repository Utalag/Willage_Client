using System.Globalization;
using System.Text;
using Willage.Gen.Geo2;

namespace Willage.Gen.Testy.V8;

/// <summary>Výpis a CSV zprávy V8: kategorie × verdikt, příčiny × zdroje, přechody materiálů, příklady.</summary>
public static class V8Zprava
{
    private static string P(long a, long n) => n == 0 ? "–" : (100.0 * a / n).ToString("F4", CultureInfo.InvariantCulture) + " %";

    public static void Vypis(IReadOnlyList<(string Kategorie, V8Soucty S)> kat, KatalogGeo2 katalog)
    {
        var vse = new V8Soucty(); foreach (var (_, s) in kat) vse.Slouc(s);
        Console.WriteLine("  --- kategorie: buněk, různých, podíl; verdikty (počet buněk) ---");
        foreach (var (n, s) in kat.Append(("CELKEM", vse)))
        {
            var v = s.PodleVerdiktu();
            long G(Verdikt x) => v.GetValueOrDefault(x);
            Console.WriteLine($"  {n,-22} {s.Bunek,14:N0} {s.Ruznych,10:N0} {P(s.Ruznych, s.Bunek),10}  zlepšení {G(Verdikt.Zlepseni):N0}, dle kontraktu {G(Verdikt.DleKontraktu):N0}, tolerance {G(Verdikt.Tolerance):N0}, otevřené {G(Verdikt.Otevrene):N0} ({P(G(Verdikt.Otevrene), s.Bunek)})");
        }
        Console.WriteLine("  --- kvalita skarnu vůči kontraktu (sloupce se skarnem v aspoň jednom systému; pásmo [0,625; 2,375] m eukleidovsky, O1) ---");
        foreach (var (nz, q) in new[] { ("GEO1", vse.Kvalita1), ("GEO2", vse.Kvalita2) })
            Console.WriteLine($"  {nz}: skarn {q.SkarnBunek:N0} buněk; v nekarbonátu (porušení O1) {q.SkarnVNekarbonatu:N0} ({P(q.SkarnVNekarbonatu, q.SkarnBunek)}); tlustší než pásmo {q.SkarnTlustsi:N0} ({P(q.SkarnTlustsi, q.SkarnBunek)}); díry v pásmu karbonátu {q.Diry:N0} ({P(q.Diry, q.KarbonatuVPasmu)} karbonátu v pásmu {q.KarbonatuVPasmu:N0}); s odhadem hranice {q.Odhad:N0}");
        Console.WriteLine("  --- příčiny (celkem), podíl z různých a ze všech buněk ---");
        foreach (var kv in vse.PodlePriciny().OrderByDescending(q => q.Value))
            Console.WriteLine($"  {kv.Key,-24} {Verdikty.Z(kv.Key),-13} {kv.Value,12:N0} {P(kv.Value, vse.Ruznych),10} z různých {P(kv.Value, vse.Bunek),10} ze všech");
        Console.WriteLine("  --- zdroj GEO1 → zdroj GEO2 × příčina ---");
        foreach (var kv in vse.Pary.OrderByDescending(q => q.Value).Take(25))
            Console.WriteLine($"  {kv.Key.Item1,-7} → {kv.Key.Item2,-7} {kv.Key.Item3,-24} {kv.Value,12:N0}");
        string M(int id) => katalog.PodleId(id)?.Klic ?? id.ToString();
        Console.WriteLine("  --- přechody materiálu GEO1 → GEO2 (prvních 15) ---");
        foreach (var kv in vse.Prechody.OrderByDescending(q => q.Value).Take(15))
            Console.WriteLine($"  {M(kv.Key.Item1),-18} → {M(kv.Key.Item2),-18} {kv.Value,12:N0}");
        Console.WriteLine("  --- příklady (x, y, z, GEO1 → GEO2) ---");
        foreach (var kv in vse.Priklady.OrderBy(q => q.Key))
            Console.WriteLine($"  {kv.Key}: " + string.Join("; ", kv.Value.Select(e => $"({e.X:F2}, {e.Y:F2}, {e.Z:F2}) {M(e.M1)}→{M(e.M2)}")));
    }

    public static void Csv(string cesta, IReadOnlyList<(string Kategorie, V8Soucty S)> kat, long seed)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(cesta))!);
        var sb = new StringBuilder("seed;kategorie;zdroj_geo1;zdroj_geo2;pricina;verdikt;bunek\n");
        foreach (var (n, s) in kat)
            foreach (var kv in s.Pary.OrderBy(q => q.Key))
                sb.Append($"{seed};{n};{kv.Key.Item1};{kv.Key.Item2};{kv.Key.Item3};{Verdikty.Z(kv.Key.Item3)};{kv.Value}\n");
        foreach (var (n, s) in kat) sb.Append($"{seed};{n};CELKEM_BUNEK;;;;{s.Bunek}\n");
        File.WriteAllText(cesta, sb.ToString());
    }
}
