using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Krok 6f: přechod hladiny podzemní vody na hladinu moře jen v pásu 5 m od břehu, bez výjimky startu.</summary>
public static class TestyKrok06f
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));

        T.Sekce("krok 6f: výchozí přechod 5 m, bez výjimky startu");
        T.Je(pv.HladinaPrechodM == 5.0 && new ParametryVody().HladinaPrechodM == 5.0, "HladinaPrechodM = 5 m v JSON i v C#");

        T.Sekce("krok 6f: start 3 × 3 bez výjimky beze změny, vnitrozemí = původní spád");
        bool start = true, vnitro = true, pas = true;
        foreach (long seed in new long[] { 49, 1, 2, 3, 4, 5, 6, 7, 8, 9 })
        {
            var g = new GeologieCs(new ParametrySveta { Seed = seed }, data);
            var h1 = new RegionalniHladina(g, pv);
            var h0 = new RegionalniHladina(g, pv with { HladinaPrechodM = 0 });
            for (double x = 1792; x < 2176 && start; x += 8)
            for (double y = 1792; y < 2176 && start; y += 8)
                if (h1.Surova(x, y) != h0.Surova(x, y)) start = false;
            var r = new Random((int)seed + 17);
            for (int i = 0; i < 3000; i++)
            {
                double x = r.NextDouble() * 31360, y = r.NextDouble() * 15616, d = g.VzdalenostOdMore(x, y);
                if (d == 0) { if (Math.Abs(h1.Surova(x, y) - 60.0) > 1e-9) pas = false; }
                else if (d >= pv.HladinaPrechodM && h1.Surova(x, y) != h0.Surova(x, y)) vnitro = false;
            }
        }
        T.Je(start, "start 3 × 3: hladina s přechodem 5 m = bez vazby (10 seedů, bez výjimky StartVoda*)");
        T.Je(pas, "v moři hladina přesně 60 m");
        T.Je(vnitro, "za 5 m od břehu = původní hladina ze spádu (krok 4)");
    }
}
