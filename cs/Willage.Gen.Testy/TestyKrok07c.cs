using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Klima;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Syntetický strmý břeh: moře x ≤ 0 (dno 20 m, hluboko pod hladinou moře 60 m), pevnina x &gt; 0 stoupá od 60 m sklonem 0,1.</summary>
sealed class StrmyBreh : IGeologie
{
    public double Povrch(double x, double y) => x <= 0 ? 20 : 60 + 0.1 * x;
    public byte[] Sloupec(double x, double y)
    {
        var a = new byte[512]; double p = Povrch(x, y);
        for (int k = 0; k < 512; k++) { if ((k + 0.5) * 0.25 > p) break; a[k] = 3; }
        return a;
    }
    public int MaterialPovrchu(double x, double y) => 3;
    public double VyskaTvar(double x, double y) => Povrch(x, y);
    public bool Mince82(double x, double y) => false;
    public double VzdalenostOdMore(double x, double y) => Math.Min(16.0, Math.Max(0.0, Math.Round(x)));
    public (double d, double sx, double sy) BrehOdMore(double x, double y, double dosah)
    {
        double d = Math.Max(0.0, x); return d >= dosah ? (dosah, double.NaN, double.NaN) : (d, 0.0, y);
    }
    public bool JeMoreVyska(double x, double y, double vyska) => x <= 0 && vyska < 60;
    public double HladinaMore => 60.0;
}

/// <summary>Krok 7c: oprava propadu hladiny za břehem a hladina podzemní vody podle dobití klimatem (existuje jen kde je dobíjená).</summary>
public static class TestyKrok07c
{
    public static void Spust(KatalogMaterialu kat)
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var pk = ParametryKlimatu.ZJson(File.ReadAllText(data.KlimaV1));

        T.Sekce("krok 7c: oprava propadu hladiny za břehem (mořské dno netáhne pevninskou hladinu dolů)");
        T.Je(pv.HladinaBezMorskychUzlu && new ParametryVody().HladinaBezMorskychUzlu, "oprava je výchozí (voda_v1.json i kód)");
        {
            var g = new StrmyBreh();
            var nova = new RegionalniHladina(g, pv); var stara = new RegionalniHladina(g, pv with { HladinaBezMorskychUzlu = false });
            double minStara = double.MaxValue, minNova = double.MaxValue, maxDiffDaleko = 0; bool nenizsi = true;
            for (double x = 0.5; x <= 200; x += 0.5)
            {
                double a = nova.Surova(x, 0), b = stara.Surova(x, 0);
                if (x <= 30) { minNova = Math.Min(minNova, a); minStara = Math.Min(minStara, b); }
                if (a < b - 1e-9) nenizsi = false;                      // oprava hladinu nikdy nesníží
                if (x > 2 * pv.PolomerHladinyM + 1) maxDiffDaleko = Math.Max(maxDiffDaleko, Math.Abs(a - b));
            }
            T.Je(minStara < 59.0, $"bez opravy hladina za břehem klesne pod hladinu moře (min do 30 m: {minStara:F2} m)");
            T.Je(minNova >= 60.0 - 1e-9, $"s opravou není hladina do 30 m za břehem pod hladinou moře (min {minNova:F3} m)");
            T.Je(nenizsi, "oprava hladinu nikdy nesníží");
            T.Je(maxDiffDaleko < 1e-9, $"dál než průměr okna od moře beze změny ({maxDiffDaleko:E1})");
            double skok = 0, prev = nova.Surova(0.5, 0);
            for (double x = 0.5; x <= 120; x += 0.25) { double v = nova.Surova(x, 0); skok = Math.Max(skok, Math.Abs(v - prev)); prev = v; }
            T.Je(skok < 0.3, $"hladina za břehem je spojitá (max skok na 0,25 m {skok:F3} m)");
            T.Je(Math.Abs(nova.Surova(-5, 0) - 60.0) < 1e-9, "v moři hladina moře");
        }
        {   // skutečný svět seed 49 (strmé a pozvolné pobřeží z řezů kroku 6g): hladina na pevnině do 25 m od břehu nejméně 60 m
            var p = new ParametrySveta { Seed = 49 };
            p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(p.PlanetaXM, p.PlanetaYM) + 2048);
            var g = new GeologieCs(p, data); var more = g.Svet.More!;
            var hn = new RegionalniHladina(g, pv); var hs = new RegionalniHladina(g, pv with { HladinaBezMorskychUzlu = false });
            double minN = double.MaxValue, minS = double.MaxValue; int n = 0;
            foreach (var (x0, y0, ux, uy) in new[] { (22489.4, 5322.3, 0.97, -0.26), (21262.2, 2085.4, -0.35, -0.93) })
            {
                double nrm = Math.Sqrt(ux * ux + uy * uy), dx = ux / nrm, dy = uy / nrm, sb = double.NaN;
                for (double s = 0; s <= 200; s += 0.5)
                {
                    double x = x0 + s * dx, y = y0 + s * dy;
                    bool je = more.JeMore(x, y, g.Povrch(x, y));
                    if (!je && double.IsNaN(sb)) sb = s;
                    if (!double.IsNaN(sb) && s >= sb && s <= sb + 25 && !je) { n++; minN = Math.Min(minN, hn.Surova(x, y)); minS = Math.Min(minS, hs.Surova(x, y)); }
                }
            }
            T.Je(n > 0 && minN >= 60.0 - 1e-6, $"svět 49: do 25 m za břehem hladina na pevnině ≥ hladina moře ({n} bodů, min {minN:F3} m; bez opravy {minS:F3} m)");
        }

        T.Sekce("krok 7c: dobití hladiny (e): bez dobití hladina neexistuje, snížení o SuchoM·(1 − e)");
        {
            var g = new StrmyBreh(); double x = 150, y = 0;
            var h0 = new RegionalniHladina(g, pv);
            double plna = h0.Surova(x, y);
            var h = new RegionalniHladina(g, pv) { Napajeni = (_, _) => 1.0, NapajeniSuchoM = 30 };
            T.Je(h.Surova(x, y) == plna, "e = 1: beze změny");
            h.Napajeni = (_, _) => 0.5; T.Blizko(h.Surova(x, y), plna - 15, 1e-9, "e = 0,5: o polovinu SuchoM níž");
            h.Napajeni = (_, _) => 0.0;
            T.Je(double.IsNaN(h.Surova(x, y)) && double.IsNaN(h.Hladina(x, y)) && !h.Vyver(x, y) && !h.Existuje(x, y), "e = 0: hladina neexistuje (NaN), žádný vývěr");
            T.Je(Math.Abs(h.Surova(-5, 0) - 60.0) < 1e-9, "i při e = 0 je v moři hladina moře");
            double[] es = { 0.01, 0.1, 0.3, 0.6, 1.0 }; bool mono = true; double prev = double.NegativeInfinity;
            foreach (double e in es) { h.Napajeni = (_, _) => e; double v = h.Surova(x, y); if (v <= prev) mono = false; prev = v; }
            T.Je(mono, "čím větší dobití, tím výš hladina");
            T.Je(new RegionalniHladina(g, pv).Napajeni is null, "výchozí: bez dobití (klima vypnuté = staré chování)");

            var prof = ProfilSloupce.Spocti(g.Sloupec(x, y), g.Povrch(x, y), double.NaN, new Propustnost(kat), 0.5);
            T.Je(prof.Nasyceno is null && prof.Zavesena.Count == 0 && prof.Sevrene.Count == 0 && double.IsNaN(prof.Hladina), "profil sloupce bez hladiny: žádná voda");
        }

        T.Sekce("krok 7c: prameny bez hladiny a start 3 × 3");
        {
            var p = new ParametrySveta { Seed = 49 };
            var fn1 = new PodzemniVodaFn(new GeologieCs(p, data), kat, pv);
            var fn0 = new PodzemniVodaFn(new GeologieCs(p, data), kat, pv);
            fn0.Hladina.Napajeni = (_, _) => 0.0;
            var fn2 = new PodzemniVodaFn(new GeologieCs(p, data), kat, pv);
            fn2.Hladina.Napajeni = (_, _) => 1.0;
            int s1 = fn1.Prameny.VOblasti(1792, 1792, 2176, 2176).Count, s0 = fn0.Prameny.VOblasti(1792, 1792, 2176, 2176).Count, s2 = fn2.Prameny.VOblasti(1792, 1792, 2176, 2176).Count;
            T.Je(s1 > 0 && s2 == s1, $"e = 1: stejný počet pramenů jako bez dobití ({s2} = {s1})");
            T.Je(s0 == 0, $"bez hladiny žádný pramen ze seedu ({s0})");
            var pr = fn0.Profil(1984, 1984);
            T.Je(pr.Nasyceno is null && pr.Zavesena.Count == 0, "Profil bez hladiny: žádná nasycená ani zavěšená voda");
        }

        T.Sekce("krok 7c: pole dobití NapajeniVody nad malou mapou");
        {
            var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1)) with { PlanetaXM = 8192, PlanetaYM = 4096, KrokuCasu = 3 };
            var ps = new ParametrySveta { More = true, VseKrok06 = false, StartBlok = new[] { 20, 12 } };
            var sv = ErozePlanety.SvetPlanety(ps, data, pe);
            var m = VypocetEroze.Spocti(ErozePlanety.Podklad(sv, pe), pe, 4, out _);
            var mk = MapaKlimatu.Spocti(m, pk, pk.Planeta("poust"), 4);
            var hk = HydrologieKlimatu.Spocti(m, mk, pe);
            var oa = Oazy.Najdi(m, mk, pk, 49);
            var vod = hk.Vodnici(m, sv, pe); vod.AddRange(oa);
            var n1 = NapajeniVody.Spocti(m, mk, hk, vod, pk); var n2 = NapajeniVody.Spocti(m, mk, hk, vod, pk);
            T.Je(n1.E.SequenceEqual(n2.E), "pole dobití je deterministické");
            T.Je(n1.E.All(e => e >= 0 && e <= 1), "e ∈ [0, 1]");
            double bez = n1.PodilBezHladiny(m);
            T.Je(bez > 0.3, $"pouštní planeta: velká část pevniny je bez hladiny ({100 * bez:F0} %)");
            // pobřeží: uzel pevniny těsně u moře má plné dobití, daleko od moře ne
            int kBreh = -1;
            for (int k = 0; k < m.T.N && kBreh < 0; k++)
            {
                if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue;
                for (int d = 0; d < 4; d++) if ((m.Priznaky[m.T.Soused(k, d)] & MapaEroze.Odtok) != 0) { kBreh = k; break; }
            }
            T.Je(kBreh >= 0 && n1.E[kBreh] > 0.99, "uzel pevniny u moře: plné dobití (pobřežní pás)");
            T.Je(oa.Count == 0 || oa.All(o => n1.E[o.Uzel] > 0.99), "oázy a vodníci: plné dobití v uzlu zdroje");
            var vyp = pk with { HladinaWPrah = 10, HladinaWPlna = 11, HladinaBrehPlneM = 0, HladinaBrehDoM = 1, HladinaZdrojPlneM = 0, HladinaZdrojDoM = 1, HladinaKorytoPlneM = 0, HladinaKorytoDoM = 1 };
            T.Je(NapajeniVody.Spocti(m, mk, hk, vod, vyp).PodilBezHladiny(m) > bez, "bez pobřeží a zdrojů s vysokým prahem je bez hladiny víc");
            var mir = MapaKlimatu.Spocti(m, pk, pk.Planeta("mirne"), 4);
            var hkm = HydrologieKlimatu.Spocti(m, mir, pe);
            double bezM = NapajeniVody.Spocti(m, mir, hkm, hkm.Vodnici(m, sv, pe), pk).PodilBezHladiny(m);
            T.Je(bezM < 0.1 && bezM < bez, $"mírná planeta: skoro všude hladina ({100 * bezM:F1} % bez hladiny, poušť {100 * bez:F0} %)");
            T.Je(n1.Dobiti(1000, 1000) >= 0 && Math.Abs(n1.Dobiti(1000, 1000) - n1.Dobiti(1000 + 8192, 1000 + 4096)) < 1e-9, "dotaz je periodický (torus)");
        }
    }
}
