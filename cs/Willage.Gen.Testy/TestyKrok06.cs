using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>Krok 6: eroze světa na malém torusu (2048 × 1024 m, krok 32 m) – periodicita, determinismus, invarianty.</summary>
public static class TestyKrok06
{
    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 2048, PlanetaYM = 1024, KrokuCasu = 5, AKritM2 = 50_000 };
        var svet = ErozePlanety.SvetPlanety(new ParametrySveta(), data, pe);
        var pod = ErozePlanety.Podklad(svet, pe);

        T.Sekce("krok 6: periodický podklad");
        double maxPer = 0, mimoPas = 0;
        for (int s = 0; s < 400; s++)
        {
            double x = 13.7 * s % 2048, y = 7.3 * s % 1024;
            maxPer = Math.Max(maxPer, Math.Abs(pod.Vyska(x, y) - pod.Vyska(x + 2048, y - 1024)));
            if (x >= 512 && y >= 512) mimoPas = Math.Max(mimoPas, Math.Abs(pod.Vyska(x, y) - svet.Vyska(x, y)));
        }
        T.Je(maxPer < 1e-9, $"f(x) = f(x + P) (max {maxPer:G3})");
        T.Je(mimoPas == 0, "mimo pás prolnutí = povrch světa");

        T.Sekce("krok 6: hrubá mapa");
        var m1 = VypocetEroze.Spocti(pod, pe, 1, out _);
        var m4 = VypocetEroze.Spocti(pod, pe, 4, out _);
        T.Je(SouborMapy.Otisk(m1) == SouborMapy.Otisk(m4), $"1 vs 4 vlákna: stejný otisk {SouborMapy.Otisk(m1)}");
        bool eOk = true; for (int k = 0; k < m1.T.N; k++) { double e = m1.E(k); if (e < 0 || e > pe.MaxEroseM + 1e-4) eOk = false; }
        T.Je(eOk, "0 ≤ E ≤ MaxEroseM");
        int bezOdtoku = 0;
        for (int k = 0; k < m1.T.N; k++)
        {
            int u = k, n = 0;
            while (m1.Prijemce[u] >= 0 && n <= m1.T.N) { u = m1.Dolu(u); n++; }
            if ((m1.Priznaky[u] & MapaEroze.Odtok) == 0) bezOdtoku++;
        }
        T.Je(bezOdtoku == 0, "každý uzel teče do odtoku (bez cyklů)");
        double sOdtok = 0; for (int k = 0; k < m1.T.N; k++) if (m1.Prijemce[k] < 0) sOdtok += m1.A[k];
        T.Blizko(sOdtok, 2048.0 * 1024.0 * pe.Srazky, 1.0, "plocha do odtoků = plocha planety");

        T.Sekce("krok 6: uložení a jemná funkce");
        string f = Path.Combine(Path.GetTempPath(), $"eroze_test_{Environment.ProcessId}.wger");
        m1.KlicKese = SouborMapy.KlicKese(svet.Sd, pe, data.SouborySveta);
        SouborMapy.Uloz(f, m1, svet.Sd);
        var n1 = SouborMapy.Nacti(f, m1.KlicKese);
        T.Je(n1 is not null && SouborMapy.Otisk(n1) == SouborMapy.Otisk(m1), "WGER uložit/načíst = stejný otisk");
        T.Je(SouborMapy.Nacti(f, "jiny") is null, "jiný klíč keše → přepočítat");
        File.Delete(f);
        var ef = new ErozeSvetaFn(m1, pe);
        double maxSev = 0, maxKrok = 0;
        for (double y = 0.1; y < 1024; y += 3.7)
        {
            maxSev = Math.Max(maxSev, Math.Abs(ef.Hloubka(2048 - 0.01, y) - ef.Hloubka(0.01, y)));
            maxKrok = Math.Max(maxKrok, Math.Abs(ef.Hloubka(700 - 0.01, y) - ef.Hloubka(700.01, y)));
        }
        T.Je(maxSev < 0.05, $"hloubka eroze spojitá přes šev torusu (max skok 2 cm: {maxSev:F4} m)");
        T.Je(maxKrok < 0.05, $"hloubka eroze spojitá uvnitř (max skok 2 cm: {maxKrok:F4} m)");
        var s0 = new SvetFn(new ParametrySveta(), data);
        double h0 = s0.Vyska(2000.3, 1900.7); s0.Eroze = ef; double h1 = s0.Vyska(2000.3, 1900.7), t1 = s0.VyskaTvar(2000.3, 1900.7);
        s0.Eroze = null;
        T.Blizko(h0 - h1, ef.Hloubka(2000.3, 1900.7), 1e-12, "přepínač: povrch − hloubka eroze");
        T.Je(t1 == s0.VyskaTvar(2000.3, 1900.7), "tvar (VyskaTvar) eroze nemění");
    }
}
