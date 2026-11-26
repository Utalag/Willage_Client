using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Krok 6g: vzdálenost k moři pro hladinu je k skutečnému břehu (JeMore), ne k vrstevnici masky k = 0,5.</summary>
public static class TestyKrok06g
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var p = new ParametrySveta { Seed = 49 };
        p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(p.PlanetaXM, p.PlanetaYM) + 2048);
        var g = new GeologieCs(p, data);
        var h1 = new RegionalniHladina(g, pv);
        var h0 = new RegionalniHladina(g, pv with { HladinaPrechodM = 0 });
        var more = g.Svet.More!;

        T.Sekce("krok 6g: vzdálenost a hladina od skutečného břehu (JeMore), seed 49");

        // stejné úsečky jako řez krok 6f (Jan t948u): pozvolné a strmé pobřeží
        bool more60 = true, pas = true, vnitro = true, neniFallback = true, dist = true;
        int nMore = 0, nPas = 0, nVnitro = 0;
        foreach (var (x0, y0, ux0, uy0, delka, jmeno) in new (double, double, double, double, double, string)[]
        {
            (21262.2, 2085.4, -0.35, -0.93, 120, "pozvolné"),
            (22489.4, 5322.3, 0.97, -0.26, 200, "strmé"),
        })
        {
            double nrm = Math.Sqrt(ux0 * ux0 + uy0 * uy0), ux = ux0 / nrm, uy = uy0 / nrm;
            double sBreh = double.NaN;
            for (double s = 0; s <= delka; s += 0.5)
            {
                double x = x0 + s * ux, y = y0 + s * uy;
                double pov = g.Povrch(x, y);
                bool je = more.JeMore(x, y, pov);
                double d = g.VzdalenostOdMore(x, y);
                double v1 = h1.Surova(x, y), v0 = h0.Surova(x, y);
                if (je)
                {
                    nMore++;
                    if (d != 0 || Math.Abs(v1 - 60.0) > 1e-9) more60 = false;
                }
                else
                {
                    if (double.IsNaN(sBreh) && pov >= 60.0) sBreh = s;
                    if (d < pv.HladinaPrechodM)
                    {
                        nPas++;
                        if (d <= 0 || Math.Abs(v1 - v0) < 1e-9 && Math.Abs(v0 - 60.0) > 1e-6) pas = false;
                    }
                    else
                    {
                        nVnitro++;
                        if (v1 != v0) vnitro = false;
                        // žádný fallback na 60 m: když má terén vlastní spád, hladina ho sleduje
                        if (Math.Abs(v0 - 60.0) > 0.5 && Math.Abs(v1 - 60.0) <= 0.05) neniFallback = false;
                    }
                }
            }
            if (double.IsNaN(sBreh)) { dist = false; continue; }
            // 20 m a 60 m za skutečným břehem: vzdálenost není 0 (chyba 6f: k < 0,5 ⇒ D = 0)
            foreach (double ds in new[] { 20.0, 60.0 })
            {
                double s = sBreh + ds; if (s > delka) continue;
                double x = x0 + s * ux, y = y0 + s * uy, d = g.VzdalenostOdMore(x, y);
                if (d < pv.HladinaPrechodM || d > ds + 3.0) { dist = false; Console.WriteLine($"  CHYBA vzdálenost {jmeno} +{ds} m: D={d:F2} (čekáno mezi {pv.HladinaPrechodM} a {ds + 3} m)"); }
            }
        }
        T.Je(nMore > 0 && more60, $"v moři (JeMore) D = 0 a hladina = 60 m ({nMore} bodů)");
        T.Je(nPas > 0 && pas, $"v pásu {pv.HladinaPrechodM} m od skutečného břehu je přechod ({nPas} bodů)");
        T.Je(nVnitro > 0 && vnitro, $"za {pv.HladinaPrechodM} m od břehu = původní hladina ze spádu ({nVnitro} bodů)");
        T.Je(neniFallback, "za 5 m od břehu žádný fallback na 60 m, když má terén vlastní spád");
        T.Je(dist, "20 m a 60 m za břehem je vzdálenost k moři ~20 / 60 m, ne 0");

        // konkrétní bod z řezu, který Jan viděl: 100 m od začátku strmého úseku (terén ~80 m)
        {
            double nrm = Math.Sqrt(0.97 * 0.97 + 0.26 * 0.26);
            double x = 22489.4 + 100 * 0.97 / nrm, y = 5322.3 + 100 * (-0.26) / nrm;
            T.Je(!more.JeMore(x, y, g.Povrch(x, y)) && g.VzdalenostOdMore(x, y) > 5 && h1.Surova(x, y) == h0.Surova(x, y) && Math.Abs(h1.Surova(x, y) - 60.0) > 1.0,
                $"strmé +100 m: D={g.VzdalenostOdMore(x, y):F2} h1={h1.Surova(x, y):F2} h0={h0.Surova(x, y):F2} (nesmí být 60 m)");
        }
    }
}
