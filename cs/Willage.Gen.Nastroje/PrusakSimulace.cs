using System.Globalization;
using System.Text;
using Willage.Gen.Data;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;
using Willage.Gen.Voda.Prusak;

namespace Willage.Gen.Nastroje;

/// <summary>Malé scénáře koeficientu průsaku: dutina 2 × 2 × 6 m pod hladinou 60 m se stěnami z různých materiálů; stávající pravidlo vs. koeficient.</summary>
public static class PrusakSimulace
{
    static readonly CultureInfo C = CultureInfo.InvariantCulture;
    public sealed record Scenar(string Jmeno, int Material, int Bloku, int Dir = 0);

    public static readonly Scenar[] Scenare =
    {
        new("žula 1 blok", 6, 1), new("jíl 10 bloků", 12, 10),
        new("písek 1 blok", 3, 1), new("písek 5 bloků", 3, 5), new("písek 10 bloků", 3, 10),
        new("spraš 1 blok", 54, 1), new("spraš 5 bloků", 54, 5), new("zvětralá žula 5 bloků", 60, 5),
        new("štěrk 1 blok", 66, 1), new("žula 1 blok + 1 díra", 6, 1, 1), new("písek 10 bloků + 1 díra", 3, 10, 1),
    };

    public static ZadaniDutiny Zadani(Scenar s) =>
        new(8, 8, 24, 56.0, 60.0, StenaDutiny.Z(s.Material, s.Bloku), StenaDutiny.Z(s.Material, s.Bloku), StenaDutiny.Z(s.Material, s.Bloku), s.Dir);

    public sealed record Vysledek(string Jmeno, bool Koef, bool Tlak, double T, double PritokLh, double[] Hladiny, double T50S, double T90S, double KonecM);

    public static readonly long[] Casy = { 60, 3600, 86400, 7 * 86400, 30 * 86400 };

    public static Vysledek Spust(Scenar s, PodzemniVodaFn fn, StreamWriter? csv)
    {
        var d = fn.Dutina(Zadani(s));
        // počáteční přítok z prvního kroku (l/h)
        d.Krok(); double pritok = d.ObjemUl / 1e6 / PrusakDutina.KrokS * 3600; // objem v µl → l; l/h
        var d2 = fn.Dutina(Zadani(s));
        var hl = new double[Casy.Length]; double t50 = double.NaN, t90 = double.NaN; int ci = 0; long dalsiCsv = 0;
        long konec = Casy[^1];
        while (d2.Cas < konec)
        {
            d2.Krok();
            if (double.IsNaN(t50) && d2.Plneni >= 0.5) t50 = d2.Cas;
            if (double.IsNaN(t90) && d2.Plneni >= 0.9) t90 = d2.Cas;
            while (ci < Casy.Length && d2.Cas >= Casy[ci]) hl[ci++] = d2.HladinaM;
            if (csv is not null && d2.Cas >= dalsiCsv) { csv.WriteLine($"{s.Jmeno};{(fn.Prusak is null ? "stavajici" : "koeficient") + (fn.P.PrusakTlak ? "+tlak" : "")};{d2.Cas};{d2.HladinaM.ToString("F4", C)};{d2.Plneni.ToString("F6", C)}"); dalsiCsv += 600; }
        }
        long t = !fn.P.PrusakKoeficient ? PrusakUtlum.Jedna : PrusakUtlum.Cesta(Zadani(s).Bocni.Cesta, fn.Prusak);
        return new Vysledek(s.Jmeno, fn.P.PrusakKoeficient, fn.P.PrusakTlak, PrusakUtlum.NaDouble(t), pritok, hl, t50, t90, d2.HladinaM);
    }

    static string Cas(double s) => double.IsNaN(s) ? "nedosaženo" : s < 3600 ? $"{s / 60:F1} min" : s < 86400 ? $"{s / 3600:F1} h" : $"{s / 86400:F1} dne";

    public static int Spust(DataSveta d, string vystup)
    {
        Directory.CreateDirectory(vystup);
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var vyp = VodaBlok.Fn(true, d, pv => pv with { PrusakKoeficient = false, PrusakTlak = false });
        var zap = VodaBlok.Fn(true, d, pv => pv with { PrusakKoeficient = true, PrusakTlak = false });
        var vypT = VodaBlok.Fn(true, d, pv => pv with { PrusakKoeficient = false, PrusakTlak = true });
        var zapT = VodaBlok.Fn(true, d, pv => pv with { PrusakKoeficient = true, PrusakTlak = true });
        var sb = new StringBuilder();
        sb.AppendLine("| scénář | režim | T cesty | přítok na začátku (l/h) | do 50 % | do 90 % | hladina 1 h | 1 den | 7 dnů | 30 dnů (m) |");
        sb.AppendLine("|---|---|---|---|---|---|---|---|---|---|");
        using var csv = new StreamWriter(Path.Combine(vystup, "plneni.csv"));
        csv.WriteLine("scenar;rezim;cas_s;hladina_m;plneni");
        foreach (var s in Scenare)
            foreach (var fn in new[] { vyp, zap, vypT, zapT })
            {
                var r = Spust(s, fn, csv);
                sb.AppendLine($"| {r.Jmeno} | {(r.Koef ? "koeficient" : "stávající")}{(r.Tlak ? " + tlak" : "")} | {(r.Koef ? r.T.ToString("F4", C) : "–")} | {r.PritokLh:F3} | {Cas(r.T50S)} | {Cas(r.T90S)} | {r.Hladiny[1]:F2} | {r.Hladiny[2]:F2} | {r.Hladiny[3]:F2} | {r.Hladiny[4]:F2} |");
            }
        Console.Write(sb.ToString());
        File.WriteAllText(Path.Combine(vystup, "tabulka.md"), sb.ToString());

        // útlum podle tloušťky
        using var u = new StreamWriter(Path.Combine(vystup, "utlum.csv"));
        u.WriteLine("material;bloku;T");
        var k = zap.Prusak!;
        foreach (var (jm, id) in new[] { ("štěrk", 66), ("písek", 3), ("spraš", 54), ("zvětralá žula", 60), ("jíl", 12), ("žula", 6) })
            for (int n = 0; n <= 20; n++) u.WriteLine($"{jm};{n};{PrusakUtlum.NaDouble(PrusakUtlum.Vrstva(k.Koef(id), n)).ToString("F8", C)}");
        Console.WriteLine("koeficienty: " + string.Join(", ", new[] { 66, 3, 54, 60, 12, 6 }.Select(i => $"{kat.Najdi(i)!.Key}={k.Koef(i)}")));
        return 0;
    }
}
