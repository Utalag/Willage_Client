using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>Krok 6d: ostrovy v průlivech, zvlněný okraj pásu švu, klíč keše bez moře, VseKrok06 výchozí zapnuto (nové goldeny).</summary>
public static class TestyKrok06d
{
    /// <summary>Golden: otisk mapy eroze výchozího světa (VseKrok06, seed 49, 32 m) – mění se jen se záměrnou změnou generátoru nebo dat.</summary>
    public const string GoldenMapaVychozi = "08e6ca036c3e2322";

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var json = ParametryMore.ZJson(File.ReadAllText(data.MoreV1));

        T.Sekce("krok 6d: ostrovy v průlivech");
        int celkem = 0; bool vMori = true, max = true;
        foreach (long seed in new long[] { 49, 1, 2, 3, 4, 5, 6, 7 })
        {
            var p = json.Uplatni(new ParametrySveta { Seed = seed });
            var m = new MaskaPevniny(p, new HashSveta(seed));
            celkem += m.Ostrovu; max &= m.Ostrovu <= p.OstrovuPocet;
            var p0 = json.Uplatni(new ParametrySveta { Seed = seed }); p0.OstrovuPocet = 0;
            var m0 = new MaskaPevniny(p0, new HashSveta(seed));
            vMori &= m0.Ostrovu == 0 && (m.Ostrovu == 0 || m.Kanonicky() != m0.Kanonicky());
        }
        T.Je(max && celkem > 0, $"ostrovy v průlivech: {celkem} na 8 seedů, nejvýš OstrovuPocet na seed");
        T.Je(vMori, "OstrovuPocet 0 → žádné ostrovy; jinak jiná maska (klíč)");

        T.Sekce("krok 6d: zvlněný okraj pásu švu, šev v moři");
        bool sev = true; double s1 = 0, s2 = 0; int n = 0;
        foreach (long seed in new long[] { 49, 2, 6, 7 })
        {
            var p = json.Uplatni(new ParametrySveta { Seed = seed });
            var m = new MaskaPevniny(p, new HashSveta(seed));
            for (double y = 600; y < p.PlanetaYM - 600; y += 64)
            {
                for (double x = 0; x < 512; x += 16) if (m.K(x, y) != 0.0) sev = false;
                double x0 = 512; while (x0 < 3000 && m.K(x0, y) < 0.5) x0 += 8;
                if (x0 < 3000) { s1 += x0; s2 += x0 * x0; n++; }
            }
        }
        double sd = n > 1 ? Math.Sqrt(s2 / n - (s1 / n) * (s1 / n)) : 0;
        T.Je(sev, "pás prolnutí švu (512 m) celý v moři i se zvlněním (4 seedy)");
        T.Je(sd > 100, $"pobřeží u švu x ≡ 0 není rovné: směrodatná odchylka vzdálenosti 1. pevniny od švu {sd:F0} m ({n} řádků)");

        T.Sekce("krok 6d: klíč keše bez moře nezávisí na more_v1.json");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1));
        var sv0 = ErozePlanety.SvetPlanety(ParametrySveta.Krok5(), data, pe);
        T.Je(ErozePlanety.Klic(sv0, data, pe) == SouborMapy.KlicKese(sv0.Sd, pe, new[] { data.KlimaPresety, data.PoradiHornin }), "bez moře: klíč = klíč kroku 6 (jen klima a horniny)");

        T.Sekce("krok 6d: VseKrok06 výchozí zapnuto, start beze změny, golden");
        var pj = json.Uplatni(new ParametrySveta()); var pd = new ParametrySveta();
        T.Je(new ParametryMore().Kanonicky() == json.Kanonicky() && new MoreSklon(pj, 49, new HashSveta(49)).Kanonicky() == new MoreSklon(pd, 49, new HashSveta(49)).Kanonicky(),
            "výchozí hodnoty v C# = more_v1.json (Godot bez JSON dostane stejný svět)");
        var gv = new GeologieCs(new ParametrySveta(), data); var g5 = new GeologieCs(ParametrySveta.Krok5(), data);
        bool stejne = true; var r = new Random(6);
        for (int i = 0; i < 300; i++)
        {
            double x = 1792 + r.NextDouble() * 384, y = 1792 + r.NextDouble() * 384;
            if (!gv.Sloupec(x, y).AsSpan().SequenceEqual(g5.Sloupec(x, y))) stejne = false;
        }
        T.Je(gv.Svet.More is not null && gv.Svet.Panve is not null, "výchozí svět má moře i pánve");
        T.Je(stejne, "start 3 × 3: sloupce geologie výchozího světa (bez eroze) = krok 5");
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        var sk = KonfiguraceSveta.Sestav(new ParametrySveta(), data, kes, 8);
        string o = SouborMapy.Otisk(sk.Mapa!);
        T.Je(o == GoldenMapaVychozi, $"golden mapa eroze výchozího světa {o}, vodníků {sk.Vodnici.Count}");
    }
}
