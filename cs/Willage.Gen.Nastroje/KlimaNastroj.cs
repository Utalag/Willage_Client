using System.Diagnostics;
using System.Globalization;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Nastroje;

/// <summary>Krok 7: měření klimatu a biomů (statistiky, výpisy pro obrázky, otisky vyp/zap).</summary>
public static class KlimaNastroj
{
    static readonly CultureInfo C = CultureInfo.InvariantCulture;
    public static string? Planeta;

    static ParametrySveta Ps(long seed, bool klima)
    {
        var p = KonfiguraceSveta.VseZapnuto(ErozeNastroj.D!, seed);
        p.KlimaKrok07 = klima; if (Planeta is not null) p.Klima = Planeta;   // klima = false → stav po kroku 6 (ParametrySveta.Krok06)
        return p;
    }

    /// <summary>klima mapa &lt;kes&gt; &lt;výstup&gt; [--seed s] [--planeta id]</summary>
    public static int Mapa(string[] a, DataSveta d)
    {
        string kes = a[2], outDir = a[3]; long seed = ErozeNastroj.Seed ?? 49;
        var sw = Stopwatch.StartNew();
        var sv = KonfiguraceSveta.Sestav(Ps(seed, true), d, kes, 8);
        long tSestav = sw.ElapsedMilliseconds; double t0 = sv.Mapa!.T.Krok;
        var m = sv.Mapa!; var mk = sv.Klima!.Mapa; var hk = sv.Hydrologie!; var pk = sv.ParametryKlimatu!;
        sw.Restart(); var mk2 = MapaKlimatu.Spocti(m, pk, pk.Planeta(Planeta ?? "mirne"), 8); long tKlima = sw.ElapsedMilliseconds;
        var mk1 = MapaKlimatu.Spocti(m, pk, pk.Planeta(Planeta ?? "mirne"), 1); Oazy.Prekryj(mk1, sv.Oazy, pk);
        Console.WriteLine($"seed {seed}, planeta {Planeta ?? "mirne"}: mapa eroze {SouborMapy.Otisk(m)} (klíč {m.KlicKese[..16]}), klima {mk.Otisk()} (8 vl.) / {mk1.Otisk()} (1 vl.), klíč klimatu {mk.Klic[..16]}");
        Console.WriteLine($"  čas: sestavení s keší {tSestav} ms, klima {tKlima} ms; rovník y = {mk.Zemepis.Y0:F0} m, pásma: {string.Join(" ", mk.Zemepis.Pasma.Select(x => x.id))}, start v segmentu {mk.Radky[(int)(1984 / t0)].Segment} ({mk.Zemepis.IdSegmentu(mk.Radky[(int)(1984 / t0)].Segment)})");
        var t = m.T; int nPev = 0; var bc = new int[11]; double sT = 0, sP = 0, minT = 1e9, maxT = -1e9, minP = 1e9, maxP = -1e9, sW = 0;
        for (int k = 0; k < t.N; k++)
        {
            if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue;
            nPev++; bc[(int)mk.Biom[k]]++; sT += mk.Teplota[k]; sP += mk.Srazky[k]; sW += mk.W[k];
            minT = Math.Min(minT, mk.Teplota[k]); maxT = Math.Max(maxT, mk.Teplota[k]); minP = Math.Min(minP, mk.Srazky[k]); maxP = Math.Max(maxP, mk.Srazky[k]);
        }
        Console.WriteLine(FormattableString.Invariant($"  pevnina: T {minT:F1}…{maxT:F1} °C (průměr {sT / nPev:F1}), P {minP:F0}…{maxP:F0} mm (průměr {sP / nPev:F0}), w průměr {sW / nPev:F2}"));
        Console.WriteLine("  biomy (% pevniny): " + string.Join(", ", Enumerable.Range(1, 10).Select(b => FormattableString.Invariant($"{KlasifikaceBiomu.NazevCs[b]} {100.0 * bc[b] / nPev:F1}"))));
        Console.WriteLine(FormattableString.Invariant($"  poušť {100.0 * bc[(int)BiomKlimatu.Poust] / nPev:F1} % pevniny, step {100.0 * bc[(int)BiomKlimatu.Step] / nPev:F1} %"));
        Stin(m, mk, pk);
        int kor = 0; for (int k = 0; k < t.N; k++) if ((m.Priznaky[k] & MapaEroze.Koryto) != 0) kor++;
        int akt = hk.Pocet(HydrologieKlimatu.Aktivni), suc = hk.Pocet(HydrologieKlimatu.Suche), bez = hk.Pocet(HydrologieKlimatu.BezKoryta);
        Console.WriteLine($"  koryta z eroze {kor} uzlů: aktivní {akt} ({100.0 * akt / kor:F1} %), suchá {suc} ({100.0 * suc / kor:F1} %); dnešní tok mimo koryto {bez} uzlů");
        void V(string n, List<Vodnik> v)
        {
            var q = v.Select(x => x.QLs).OrderBy(x => x).ToArray();
            Console.WriteLine(FormattableString.Invariant($"  vodníci {n}: {v.Count}, Q medián {(q.Length > 0 ? q[q.Length / 2] : 0):F2} l/s, součet {q.Sum():F0} l/s, ve startu 3×3 {v.Count(x => x.X >= 1792 && x.X < 2176 && x.Y >= 1792 && x.Y < 2176)}"));
        }
        V("bez klimatu", sv.VodniciBezKlimatu); V("s klimatem (vč. oáz)", sv.Vodnici);
        Console.WriteLine(FormattableString.Invariant($"  oázy: {sv.Oazy.Count} (Q součet {sv.Oazy.Sum(o => o.QLs):F1} l/s), uzlů biomu oáza {bc[(int)BiomKlimatu.Oaza]} ({100.0 * bc[(int)BiomKlimatu.Oaza] / nPev:F2} % pevniny), hustota v poušti {sv.Oazy.Count / Math.Max(0.01, (bc[(int)BiomKlimatu.Poust] + bc[(int)BiomKlimatu.Oaza]) * t.Krok * t.Krok / 1e6):F2} /km²"));
        bool Blizko(Vodnik a, List<Vodnik> l) => l.Any(b => Math.Abs(b.X - a.X) <= 160 && Math.Abs(b.Y - a.Y) <= 160);
        int zust = sv.VodniciBezKlimatu.Count(x => Blizko(x, sv.Vodnici)), novi = sv.Vodnici.Count(x => !Blizko(x, sv.VodniciBezKlimatu));
        Console.WriteLine($"  vodníci (do 160 m od původního): zůstali/posunuli se {zust}, zanikli {sv.VodniciBezKlimatu.Count - zust}, noví {novi}");
        var vodPoBiomu = sv.Vodnici.GroupBy(x => mk.Biom[x.Uzel]).OrderBy(g => g.Key).Select(g => $"{KlasifikaceBiomu.NazevCs[(int)g.Key]} {g.Count()}");
        var vod0PoBiomu = sv.VodniciBezKlimatu.GroupBy(x => mk.Biom[x.Uzel]).OrderBy(g => g.Key).Select(g => $"{KlasifikaceBiomu.NazevCs[(int)g.Key]} {g.Count()}");
        Console.WriteLine($"  vodníci podle biomu před: {string.Join(", ", vod0PoBiomu)} | po: {string.Join(", ", vodPoBiomu)}");
        Directory.CreateDirectory(outDir);
        using (var w = new BinaryWriter(File.Create(Path.Combine(outDir, "klima.bin"))))
        {
            w.Write(t.Nx); w.Write(t.Ny); w.Write(t.Krok);
            foreach (var x in m.H) w.Write(x);
            w.Write(m.Priznaky);
            foreach (var f in new[] { mk.Teplota, mk.Srazky, mk.W }) foreach (var x in f) w.Write(x);
            foreach (var b in mk.Biom) w.Write((byte)b);
            w.Write(hk.Stav);
            foreach (var x in hk.AKlima) w.Write(x);
            foreach (var x in m.A) w.Write(x);
            foreach (var r in mk.Radky) { w.Write(r.TC); w.Write((double)r.Segment); }
        }
        foreach (var (n, v) in new[] { ("vodnici_pred.csv", sv.VodniciBezKlimatu), ("vodnici_po.csv", sv.Vodnici) })
            File.WriteAllLines(Path.Combine(outDir, n), v.Select(x => FormattableString.Invariant($"{x.X},{x.Y},{x.QLs:F3}")).Prepend("x,y,q_ls"));
        return 0;
    }

    /// <summary>Srážkový stín: relativní srážky (P / základ pásma) na návětří a závětří vyhlazeného terénu.</summary>
    static void Stin(MapaEroze m, MapaKlimatu mk, ParametryKlimatu p)
    {
        var t = m.T; var h = new double[t.N];
        for (int k = 0; k < t.N; k++) h[k] = Math.Max(m.H[k], p.HladinaMoreM);
        int r = (int)Math.Round(p.VyhlazeniTerenuM / t.Krok); var hs = Vyhlazeni.Box(h, t.Nx, t.Ny, r, r);
        // závětří = pevnina, kde v okně 1 km proti větru je hřbet ≥ 8 m nad bodem; návětří = stoupání ≥ 0,01
        double sN = 0, sZ = 0, sR = 0; int nN = 0, nZ = 0, nR = 0; int okno = (int)(1000 / t.Krok);
        for (int j = 0; j < t.Ny; j++)
        {
            var kr = mk.Radky[j]; int smer = kr.PodilZapadu >= 0.5 ? 1 : -1; double pb = kr.SrazkyMm;
            for (int i = 0; i < t.Nx; i++)
            {
                int k = j * t.Nx + i; if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue;
                double rel = mk.Srazky[k] / pb, sk = (hs[t.K(i + smer, j)] - hs[k]) / t.Krok;
                double hreben = 0; for (int o = 1; o <= okno; o++) hreben = Math.Max(hreben, hs[t.K(i - smer * o, j)]);
                if (hreben - hs[k] >= 8 && sk <= 0) { sZ += rel; nZ++; }
                else if (sk >= 0.01) { sN += rel; nN++; }
                else { sR += rel; nR++; }
            }
        }
        Console.WriteLine(FormattableString.Invariant($"  srážkový stín (P / základ pásma): návětří {sN / Math.Max(1, nN):F2} ({nN} uzlů), závětří za hřbetem ≥ 8 m {sZ / Math.Max(1, nZ):F2} ({nZ}), ostatní {sR / Math.Max(1, nR):F2}"));
    }

    /// <summary>klima otisky &lt;kes&gt;: krok 3, voda 14,14 a prameny 3×3 s klimatem vyp/zap (seed 49).</summary>
    public static int Otisky(string[] a, DataSveta d)
    {
        string kes = a[2];
        foreach (bool kl in new[] { false, true })
        {
            var p = Ps(ErozeNastroj.Seed ?? 49, kl);
            var sv = KonfiguraceSveta.Sestav(p, d, kes, 8);
            var (o, _, _) = OtiskKrok3.Spocti(Ps(ErozeNastroj.Seed ?? 49, kl), d, uprav: g => g.Svet.Eroze = sv.Eroze);
            int p33 = 0;
            var v = VodaBlok.Spust(true, d, svet: Ps(ErozeNastroj.Seed ?? 49, kl), geo: g => g.Svet.Eroze = sv.Eroze,
                uprav: fn => { fn.Prameny.Vodnici = new VodniciVeSvete(sv.Vodnici, fn.Geologie).VOblasti; sv.NapojKlima(fn.Prameny); p33 = fn.Prameny.VOblasti(1792, 1792, 2176, 2176).Count; });
            Console.WriteLine($"klima {(kl ? "zap" : "vyp")}: oáz {sv.Oazy.Count}, mapa {SouborMapy.Otisk(sv.Mapa!)}, vodníků {sv.Vodnici.Count}, krok 3 {o}, voda 14,14 {v.otisk} ({v.pramenu} pramenů; 3×3: {p33}){(kl ? $", klima {sv.Klima!.Mapa.Otisk()}, w start {sv.Klima.W(1984, 1984):F2}, biom start {KlasifikaceBiomu.NazevCs[(int)sv.Klima.Biom(1984, 1984)]}, T {sv.Klima.Teplota(1984, 1984):F1} °C, P {sv.Klima.Srazky(1984, 1984):F0} mm" : "")}");
        }
        return 0;
    }

    /// <summary>klima prameny &lt;kes&gt; &lt;x0&gt; &lt;y0&gt; &lt;strana&gt;: počet a výkon pramenů ze seedu ve čtverci bez/s klimatem (planetární svět).</summary>
    public static int Prameny(string[] a, DataSveta d)
    {
        string kes = a[2]; double x0 = double.Parse(a[3], C), y0 = double.Parse(a[4], C), s = double.Parse(a[5], C);
        var p = Ps(ErozeNastroj.Seed ?? 49, true);
        var pe0 = ParametryEroze.ZJson(File.ReadAllText(d.ErozeV1)); p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(pe0.PlanetaXM, pe0.PlanetaYM) + pe0.PasProlnutiM);
        var sv = KonfiguraceSveta.Sestav(p, d, kes, 8);
        var pv = ParametryVody.ZJson(File.ReadAllText(d.VodaV1));
        var kat = Willage.Gen.Materialy.KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var f0 = new PodzemniVodaFn(sv.Geologie, kat, pv); var f1 = new PodzemniVodaFn(sv.Geologie, kat, pv); sv.NapojKlima(f1.Prameny);
        var l0 = f0.Prameny.VOblasti(x0, y0, x0 + s, y0 + s); var l1 = f1.Prameny.VOblasti(x0, y0, x0 + s, y0 + s);
        var k = sv.Klima!;
        Console.WriteLine(FormattableString.Invariant($"prameny ({x0:F0}, {y0:F0}) {s:F0} m, biom {KlasifikaceBiomu.NazevCs[(int)k.Biom(x0 + s / 2, y0 + s / 2)]}, w {k.W(x0 + s / 2, y0 + s / 2):F2}: bez klimatu {l0.Count} ({l0.Sum(x => x.Jmenovity):F1} l/s), s klimatem {l1.Count} ({l1.Sum(x => x.Jmenovity):F1} l/s)"));
        return 0;
    }
}
