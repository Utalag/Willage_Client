using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;
using Willage.Gen.Voda.Prusak;

namespace Willage.Gen.Testy;

/// <summary>Syntetický břeh: moře x ≤ 0 (povrch 55 m, hladina moře 60 m), pevnina x &gt; 0 (povrch 62 m) z jednoho materiálu.</summary>
sealed class BrehGeologie : IGeologie
{
    private readonly byte _mat;
    public BrehGeologie(byte mat) => _mat = mat;
    public double Povrch(double x, double y) => x <= 0 ? 55 : 62;
    public byte[] Sloupec(double x, double y)
    {
        var a = new byte[512]; double p = Povrch(x, y);
        for (int k = 0; k < 512; k++) { if ((k + 0.5) * 0.25 > p) break; a[k] = _mat; }
        return a;
    }
    public int MaterialPovrchu(double x, double y) => _mat;
    public double VyskaTvar(double x, double y) => Povrch(x, y);
    public bool Mince82(double x, double y) => false;
    public double VzdalenostOdMore(double x, double y) => Math.Min(16.0, Math.Max(0.0, Math.Round(x)));
    public (double d, double sx, double sy) BrehOdMore(double x, double y, double dosah)
    {
        double d = Math.Max(0.0, x); return d >= dosah ? (dosah, double.NaN, double.NaN) : (d, 0.0, y);
    }
    public double HladinaMore => 60.0;
}

/// <summary>Šířka pobřežního pásu z koeficientu průsaku: dosah v čase, horizont, tlak, napojení na hladinu, vypnuto = beze změny.</summary>
public static class TestyPrusakPobrezi
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogMaterialu.ZeSouboru(data.KatalogMaterialu);
        var json = File.ReadAllText(data.PrusakV1);
        var pv0 = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var k = new PrusakKoeficient(kat, json);

        T.Sekce("pobřežní pás z koeficientu průsaku: parametry a dosah v čase");
        T.Je(!new ParametryVody().PrusakPobrezi && !pv0.PrusakPobrezi, "výchozí příznak PrusakPobrezi vypnuto (kód i voda_v1.json)");
        T.Je(pv0.PobrezHorizontDni == 30.0 && new ParametryVody().PobrezHorizontDni == 30.0 && pv0.HladinaPrechodM == 5.0, "horizont 30 dnů, HladinaPrechodM 5 m beze změny");
        PobrezniPas Pas(ParametryVody pv) => new(kat, k, pv with { PrusakPobrezi = true });
        var p30 = Pas(pv0); var p7 = Pas(pv0 with { PobrezHorizontDni = 7 }); var p90 = Pas(pv0 with { PobrezHorizontDni = 90 });
        T.Je(p30.Material(66, 50) == pv0.PobrezMaxM, $"štěrk dosáhne stropu {pv0.PobrezMaxM} m ({p30.Material(66, 50)})");
        double sand = p30.Material(3, 50);
        T.Je(sand > 1.0 && sand < pv0.PobrezMaxM, $"písek za 30 dnů několik metrů ({sand:F2} m)");
        T.Je(p30.Material(54, 50) < 0.1 && p30.Material(12, 50) == 0 && p30.Material(6, 50) == 0, "spraš < 0,1 m, jíl a žula 0");
        T.Je(p30.Material(66, 50) > sand && sand > p30.Material(57, 50) && p30.Material(57, 50) > p30.Material(54, 50), "pořadí: štěrk > písek > zvětralá vulkanika > spraš");
        T.Je(p7.Material(3, 50) < sand && sand < p90.Material(3, 50), "horizont je ladící: 7 < 30 < 90 dnů");
        T.Je(p90.Material(3, 50) < 2 * sand, "písek: s koeficientem se dosah s časem nasycuje (90 dnů < 2× 30 dnů)");
        T.Je(p30.Material(3, 10) < p30.Material(3, 50) && p30.Material(3, 50) < p30.Material(3, 200), "větší spád (tlak) = širší pás");
        long tau = PrusakDosah.CasCistehoBlokuMs(1e-4, 0.35, 0.05);
        long hor = 30 * PrusakDosah.MsDen, max = 1_000_000;
        T.Je(PrusakDosah.DosahMm(255, tau, hor, max) > 4 * PrusakDosah.DosahMm(255, tau, hor / 4, max) - 300, "koeficient 255: dosah roste lineárně s časem");
        T.Je(PrusakDosah.DosahMm(0, tau, hor, max) == 0 && PrusakDosah.DosahMm(178, -1, hor, max) == 0, "koeficient 0 nebo nepropustný materiál = 0");
        T.Je(PrusakDosah.DosahMm(178, tau, hor, max) == PrusakDosah.DosahMm(178, tau, hor, max), "deterministické");

        T.Sekce("pobřežní pás: tlak (rozdíl hladin)");
        int[] sp = { p30.SpadPm(0), p30.SpadPm(1000), p30.SpadPm(5000), p30.SpadPm(20000), p30.SpadPm(10_000_000) };
        T.Je(sp[0] == 10 && sp[2] == 50 && sp[3] == 200 && sp[4] == 500 && sp[1] == 10, $"spád v promile z |Δh|/100 m v mezích 10…500: {string.Join(",", sp)}");
        T.Je(Pas(pv0 with { PrusakTlak = false }).SpadPm(20000) == 50, "bez tlaku stálý spád 50 ‰");
        var sloupec = new BrehGeologie(3).Sloupec(1, 0);
        double ploch = p30.Sirka(sloupec, 62, 0), kopec = p30.Sirka(sloupec, 62, 20000);
        T.Je(kopec > ploch, $"voda z kopce (Δh 20 m) vnikne dál než na ploše ({kopec:F2} > {ploch:F2} m)");

        T.Sekce("pobřežní pás: napojení na hladinu (syntetický břeh)");
        double Rozdil(byte mat, ParametryVody pv, bool pas, double x)
        {
            var g = new BrehGeologie(mat);
            var zakl = new RegionalniHladina(g, pv with { HladinaPrechodM = 0 });
            var h = new RegionalniHladina(g, pv, pas ? Pas(pv) : null);
            return Math.Abs(h.Surova(x, 0) - zakl.Surova(x, 0));
        }
        T.Je(Rozdil(3, pv0, false, 3.0) > 0.01 && Rozdil(3, pv0, false, 6.0) < 1e-9, "vypnuto: pás 5 m konstantně (3 m změna, 6 m beze změny)");
        double w = Pas(pv0).Sirka(new BrehGeologie(3).Sloupec(1, 0), 62, (long)Math.Round((new RegionalniHladina(new BrehGeologie(3), pv0 with { HladinaPrechodM = 0 }).Surova(3, 0) - 60.0) * 1000));
        T.Je(Rozdil(3, pv0, true, w * 0.5) > 0.01 && Rozdil(3, pv0, true, w + 0.5) < 1e-9, $"zapnuto, písek: pás {w:F2} m (uvnitř změna, za pásem původní spád)");
        T.Je(Rozdil(12, pv0, true, 0.5) < 1e-9 && Rozdil(6, pv0, true, 0.5) < 1e-9, "zapnuto, jíl a žula: pás nulový (hladina = původní spád hned za břehem)");
        T.Je(Math.Abs(new RegionalniHladina(new BrehGeologie(12), pv0, Pas(pv0)).Surova(-3, 0) - 60.0) < 1e-9, "v moři hladina moře 60 m i při nulovém pásu");
        var hs = new RegionalniHladina(new BrehGeologie(3), pv0, Pas(pv0)); double maxSkok = 0, prev = hs.Surova(0.01, 0);
        for (double x = 0.05; x < 8; x += 0.05) { double v = hs.Surova(x, 0); maxSkok = Math.Max(maxSkok, Math.Abs(v - prev)); prev = v; }
        T.Je(maxSkok < 0.5, $"hladina přes pás plynulá (max skok po 5 cm {maxSkok:F3} m)");

        T.Sekce("pobřežní pás: hledání břehu s dosahem 16 m shodné se starým (vypnuto beze změny), seed 49");
        var p = new ParametrySveta { Seed = 49 };
        p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(p.PlanetaXM, p.PlanetaYM) + 2048);
        var gc = new GeologieCs(p, data); var more = gc.Svet.More!;
        int n = 0, shoda = 0, naMori = 0; bool vzdal = true;
        foreach (var (x0, y0, ux, uy) in new[] { (21262.2, 2085.4, -0.35, -0.93), (22489.4, 5322.3, 0.97, -0.26) })
        {
            double nr = Math.Sqrt(ux * ux + uy * uy);
            for (double s = 0; s <= 100; s += 2)
            {
                double x = x0 + s * ux / nr, y = y0 + s * uy / nr;
                double a = more.VzdalenostOdMoreJemna(x, y, gc.Povrch), b = more.BrehJemny(x, y, gc.Povrch, 16.0, out _, out _);
                double c = more.BrehJemny(x, y, gc.Povrch, 30.0, out double sx, out double sy);
                n++; if (a == b) shoda++;
                if (c < 30.0 && !double.IsNaN(sx) && c > 0) { naMori++; if (!more.JeMore(sx, sy, gc.Povrch(sx, sy)) || Math.Abs(Math.Sqrt((sx - x) * (sx - x) + (sy - y) * (sy - y)) - c) > 1e-6) vzdal = false; }
            }
        }
        T.Je(shoda == n, $"BrehJemny(16) = VzdalenostOdMoreJemna ({shoda}/{n})");
        T.Je(vzdal && naMori > 0, $"bod břehu (sx, sy) je v moři a ve vzdálenosti d ({naMori} bodů)");
    }
}
