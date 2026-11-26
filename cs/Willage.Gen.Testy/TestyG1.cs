using System.Diagnostics;
using System.Reflection;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Katalogy;
using Willage.Gen.Materialy;
using Willage.Gen.Pipeline;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>G-1: graf modulů M0–M7, manifest katalogů (SHA všech dat), izolace klíčů modulů, pipeline = původní Sestav.</summary>
public static class TestyG1
{
    sealed class Umely : ModulZaklad
    {
        readonly string _id; readonly string[] _z;
        public Umely(string id, params string[] z) { _id = id; _z = z; }
        public override string Id => _id;
        public override string Nazev => _id;
        public override IReadOnlyList<string> Zavislosti => _z;
        public override string Parametry(KontextBehu k) => "";
        public override object Spust(KontextBehu k) => _id;
    }

    static bool Hodi(Action a) { try { a(); return false; } catch (ArgumentException) { return true; } }
    static string S(IEnumerable<string> s) => string.Join(",", s);

    /// <summary>Moduly, jejichž klíč se liší.</summary>
    static List<string> Zmenene(IReadOnlyDictionary<string, string> a, IReadOnlyDictionary<string, string> b) =>
        a.Keys.Where(k => a[k] != b[k]).OrderBy(k => k, StringComparer.Ordinal).ToList();

    static List<string> Ocekavane(GrafModulu g, params string[] zmenene)
    {
        var s = new SortedSet<string>(StringComparer.Ordinal);
        foreach (var z in zmenene) { s.Add(z); foreach (var d in g.Zavisle(z)) s.Add(d); }
        return s.ToList();
    }

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var graf = ModulySveta.Graf();

        T.Sekce("G-1: graf modulů M0–M7");
        T.Je(S(graf.Poradi.Select(m => m.Id)) == "M0,M1,M2,M3,M4,M5,M6,M7", "8 modulů, topologické pořadí M0…M7 (" + S(graf.Poradi.Select(m => m.Id)) + ")");
        T.Je(S(graf.Zavisle("M3")) == "M6,M7" && S(graf.Zavisle("M4")) == "M5,M6,M7" && S(graf.Zavisle("M0")) == "M1,M2,M3,M4,M5,M6,M7" && graf.Zavisle("M7").Count == 0,
            $"závislé: M3 → {S(graf.Zavisle("M3"))}, M4 → {S(graf.Zavisle("M4"))}");
        T.Je(S(graf.Predchudci("M6")) == "M0,M1,M2,M3,M4,M5" && S(graf.Predchudci("M4")) == "M0,M1,M2", $"předchůdci: M6 → {S(graf.Predchudci("M6"))}, M4 → {S(graf.Predchudci("M4"))}");
        T.Je(Hodi(() => new GrafModulu(new[] { new Umely("A", "B"), new Umely("B", "C"), new Umely("C", "A") })), "cyklus A → B → C → A odmítnut");
        T.Je(Hodi(() => new GrafModulu(new[] { new Umely("A", "X") })) && Hodi(() => new GrafModulu(new[] { new Umely("A"), new Umely("A") })), "neznámá závislost a duplicitní id odmítnuty");
        T.Je(S(new GrafModulu(new[] { new Umely("C", "A"), new Umely("B", "A"), new Umely("A") }).Poradi.Select(m => m.Id)) == "A,B,C", "pořadí nezávisí na pořadí registrace (ordinální)");

        T.Sekce("G-1: rozdělení parametrů světa a kopie");
        var pole = typeof(ParametrySveta).GetFields(BindingFlags.Public | BindingFlags.Instance).Select(f => f.Name).ToList();
        var prirazeno = RozdeleniParametru.Vse.SelectMany(kv => kv.Value).ToList();
        var chybi = pole.Except(prirazeno).ToList(); var navic = prirazeno.Except(pole).ToList();
        var dvakrat = prirazeno.GroupBy(x => x).Where(g => g.Count() > 1).Select(g => g.Key).ToList();
        T.Je(chybi.Count == 0 && navic.Count == 0 && dvakrat.Count == 0, $"každé z {pole.Count} polí ParametrySveta právě v jednom modulu (chybí {S(chybi)}; navíc {S(navic)}; dvakrát {S(dvakrat)})");
        var p0 = new ParametrySveta(); var kp = p0.Kopie();
        kp.StartBlok[0] = 1; kp.Podil[0] = 9; kp.Biomy[0].PrevyseniM = 99; kp.HorninyBiomu[0][0] = 1;
        T.Je(p0.StartBlok[0] == 14 && p0.Podil[0] == 0.35 && p0.Biomy[0].PrevyseniM == 3.0 && p0.HorninyBiomu[0][0] == 54, "Kopie je hluboká (pole, biomy, horniny)");
        var k2 = p0.Kopie();
        T.Je(RozdeleniParametru.Vse.All(kv => KanonickeParametry.Pole(k2, kv.Value) == KanonickeParametry.Pole(p0, kv.Value)), "kopie má stejné kanonické parametry");

        T.Sekce("G-1: manifest katalogů");
        var man = ManifestKatalogu.Spocti(data);
        var cesty = typeof(DataSveta).GetProperties().Where(pr => pr.PropertyType == typeof(string) && pr.Name != nameof(DataSveta.Koren))
            .Select(pr => ManifestKatalogu.Relativni(data.Koren, (string)pr.GetValue(data)!)).ToList();
        var souboryModulu = graf.Poradi.SelectMany(m => m.Soubory).ToHashSet();
        T.Je(cesty.All(man.Obsahuje), $"všech {cesty.Count} cest DataSveta je v manifestu ({man.Polozky.Count} souborů)");
        T.Je(cesty.All(souboryModulu.Contains), "každou cestu DataSveta čte aspoň jeden modul (chybí: " + S(cesty.Where(c => !souboryModulu.Contains(c))) + ")");
        T.Je(souboryModulu.All(man.Obsahuje), "soubory modulů jsou v manifestu");
        var bezModulu = man.Polozky.Select(x => x.Cesta).Where(c => !souboryModulu.Contains(c)).ToList();
        Console.WriteLine($"  manifest {man.Souhrn[..16]}, soubory bez modulu (jen klíč M7): {S(bezModulu)}");
        var sv3 = data.SouborySveta.Select(f => ManifestKatalogu.Relativni(data.Koren, f)).ToList();
        T.Je(souboryModulu.Count > sv3.Count && sv3.All(souboryModulu.Contains), $"klíče modulů pokrývají {souboryModulu.Count} souborů, SouborySveta jen {sv3.Count} ({S(sv3)})");
        T.Je(ManifestKatalogu.ZJson(man.ToJson()).Souhrn == man.Souhrn && ManifestKatalogu.ZJson(man.ToJson()).Rozdily(man).Count == 0, "manifest JSON tam a zpět");
        T.Je(ManifestKatalogu.Spocti(data).ToJson() == man.ToJson(), "manifest deterministický");
        string ulozeny = Path.Combine(data.Koren, ManifestKatalogu.NazevSouboru);
        var rozdUl = File.Exists(ulozeny) ? ManifestKatalogu.ZJson(File.ReadAllText(ulozeny)).Rozdily(man) : new[] { "(soubor chybí)" };
        T.Je(rozdUl.Count == 0, $"uložený data/{ManifestKatalogu.NazevSouboru} odpovídá datům (rozdíly: {S(rozdUl)}; obnovit: Willage.Gen.Nastroje manifest)");

        // kopie dat do dočasné složky: změna každého souboru → SHA, souhrn a klíče právě dotčených modulů
        string tmp = Path.Combine(Path.GetTempPath(), "willage-g1-data-" + Environment.ProcessId);
        if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
        foreach (var x in man.Polozky) { var c = Path.Combine(tmp, x.Cesta); Directory.CreateDirectory(Path.GetDirectoryName(c)!); File.Copy(Path.Combine(data.Koren, x.Cesta), c); }
        var dt = new DataSveta(tmp); var pt = new PipelineSveta(dt);
        var zakl = pt.Klice(new ParametrySveta());
        T.Je(S(zakl.Values) == S(new PipelineSveta(data).Klice(new ParametrySveta()).Values), "kopie dat → stejné klíče jako originál (klíče nezávisí na cestě)");
        int ok = 0; var spatne = new List<string>();
        foreach (var x in man.Polozky)
        {
            var c = Path.Combine(tmp, x.Cesta); var puv = File.ReadAllBytes(c);
            File.AppendAllText(c, "\n");   // bílý znak na konci: JSON i CSV zůstanou platné, mění se jen SHA
            var m2 = ManifestKatalogu.Spocti(dt);
            var zm = Zmenene(zakl, pt.Klice(new ParametrySveta()));
            var ctou = graf.Poradi.Where(m => m.Soubory.Contains(x.Cesta)).Select(m => m.Id).ToArray();
            var oc = Ocekavane(graf, ctou.Length > 0 ? ctou : new[] { "M7" });
            if (S(m2.Rozdily(man)) == x.Cesta && m2.Souhrn != man.Souhrn && S(zm) == S(oc)) ok++; else spatne.Add($"{x.Cesta}: {S(zm)} ≠ {S(oc)}");
            File.WriteAllBytes(c, puv);
        }
        T.Je(ok == man.Polozky.Count, $"změna každého z {man.Polozky.Count} souborů změní jeho SHA, souhrn a klíče právě modulů, které ho čtou (+ závislé) {S(spatne)}");
        var crlf = Path.Combine(tmp, "v1", "klima_v1.json"); var lf = File.ReadAllText(crlf);
        File.WriteAllText(crlf, lf.Replace("\n", "\r\n"));
        T.Je(ManifestKatalogu.Spocti(dt).Souhrn == man.Souhrn, "CRLF v textových datech (git autocrlf) nemění SHA");
        File.WriteAllText(crlf, lf);
        // hodnota v more_v1.json (parametry M2 se berou odtud, ne z ParametrySveta)
        var more = Path.Combine(tmp, "v1", "more_v1.json"); var mj = File.ReadAllText(more);
        var pm = ParametryMore.ZJson(mj);
        File.WriteAllText(more, System.Text.Json.JsonSerializer.Serialize(pm with { PodilMore = pm.PodilMore - 0.05 }));
        T.Je(S(Zmenene(zakl, pt.Klice(new ParametrySveta()))) == S(Ocekavane(graf, "M2")), "PodilMore v more_v1.json → klíče M2–M7, M0 a M1 beze změny");
        File.WriteAllText(more, mj);
        Directory.Delete(tmp, true);

        T.Sekce("G-1: izolace klíčů modulů (změna modulu N nezmění klíče před ním)");
        var pl = new PipelineSveta(data);
        var n0 = NastaveniModulu.ZDat(data);
        IReadOnlyDictionary<string, string> K(ParametrySveta p, NastaveniModulu? n = null) { pl.Nastaveni = n ?? n0; return pl.Klice(p); }
        var kz = K(new ParametrySveta());
        T.Je(S(kz.Values) == S(K(new ParametrySveta()).Values) && kz.Values.Distinct().Count() == 8, "stejné vstupy → stejné klíče, 8 různých klíčů");
        var zmeny = new (string modul, string popis, ParametrySveta p, NastaveniModulu n)[]
        {
            ("M0", "Seed 49 → 50", new ParametrySveta { Seed = 50 }, n0),
            ("M0", "KlimaKrok07 vypnuto", new ParametrySveta { KlimaKrok07 = false }, n0),
            ("M1", "Oktav 4 → 5", new ParametrySveta { Oktav = 5 }, n0),
            ("M3", "P82Podil 0,5 → 0,6", new ParametrySveta { P82Podil = 0.6 }, n0),
            ("M4", "eroze KrokuCasu 20 → 21", new ParametrySveta(), new NastaveniModulu { Eroze = n0.Eroze with { KrokuCasu = n0.Eroze.KrokuCasu + 1 }, Klima = n0.Klima, Voda = n0.Voda, PrusakJson = n0.PrusakJson }),
            ("M4", "eroze OdtokPodil (pole mimo klíč WGER)", new ParametrySveta(), new NastaveniModulu { Eroze = n0.Eroze with { OdtokPodil = n0.Eroze.OdtokPodil * 2 }, Klima = n0.Klima, Voda = n0.Voda, PrusakJson = n0.PrusakJson }),
            ("M5", "klima KontinentalitaM 20 000 → 1000", new ParametrySveta(), new NastaveniModulu { Eroze = n0.Eroze, Klima = n0.Klima with { KontinentalitaM = 1000 }, Voda = n0.Voda, PrusakJson = n0.PrusakJson }),
            ("M6", "voda FilmM 0,5 → 0,4", new ParametrySveta(), new NastaveniModulu { Eroze = n0.Eroze, Klima = n0.Klima, Voda = n0.Voda with { FilmM = 0.4 }, PrusakJson = n0.PrusakJson }),
        };
        foreach (var (modul, popis, p, n) in zmeny)
        {
            var zm = Zmenene(kz, K(p, n)); var oc = Ocekavane(graf, modul);
            T.Je(S(zm) == S(oc), $"{modul} {popis}: změněno {S(zm)} (čekáno {S(oc)})");
        }
        T.Je(Zmenene(kz, K(new ParametrySveta { PodilMore = 0.1 })).Count == 0, "PodilMore v ParametrySveta nic nemění (přepíše ho more_v1.json, jako dnes)");

        T.Sekce("G-1: pipeline = původní Sestav (otisky beze změny)");
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        var kat = KatalogMaterialu.ZeSouboru(data.KatalogMaterialu); var pv = n0.Voda;
        foreach (var (nazev, mk) in new (string, Func<ParametrySveta>)[] { ("výchozí", () => new ParametrySveta()), ("Krok06()", () => ParametrySveta.Krok06()), ("Krok5()", () => ParametrySveta.Krok5()) })
        {
            var sw = Stopwatch.StartNew(); var a = SestavPuvodni.Sestav(mk(), data, kes, 8); double ta = sw.Elapsed.TotalMilliseconds;
            sw.Restart(); var b = KonfiguraceSveta.Sestav(mk(), data, kes, 8); double tb = sw.Elapsed.TotalMilliseconds;
            string oa = a.Mapa is null ? "-" : SouborMapy.Otisk(a.Mapa), ob = b.Mapa is null ? "-" : SouborMapy.Otisk(b.Mapa);
            T.Je(oa == ob && (a.Mapa?.KlicKese ?? "") == (b.Mapa?.KlicKese ?? ""), $"{nazev}: otisk mapy {oa} = {ob}, klíč WGER stejný");
            if (nazev == "výchozí") T.Je(ob == TestyKrok06d.GoldenMapaVychozi, $"výchozí: golden mapa eroze {ob}");
            T.Je(a.Vodnici.SequenceEqual(b.Vodnici) && a.Oazy.SequenceEqual(b.Oazy) && a.VodniciBezKlimatu.SequenceEqual(b.VodniciBezKlimatu),
                $"{nazev}: vodníci {a.Vodnici.Count}, oázy {a.Oazy.Count}, vodníci bez klimatu {a.VodniciBezKlimatu.Count} shodní");
            T.Je((a.Klima is null) == (b.Klima is null) && (a.Napajeni is null) == (b.Napajeni is null) && (a.Napajeni is null || a.Napajeni.E.AsSpan().SequenceEqual(b.Napajeni!.E)) && a.ParametryKlimatu?.Kanonicky("mirne") == b.ParametryKlimatu?.Kanonicky("mirne") && (a.Hydrologie is null) == (b.Hydrologie is null), $"{nazev}: klima {(a.Klima is null ? "vypnuto" : "zapnuto")}, dobití hladiny 7c {(a.Napajeni is null ? "vypnuto" : "shodné")} v obou");
            bool sl = true; var r = new Random(7);
            for (int i = 0; i < 200; i++)
            {
                double x = 1792 + r.NextDouble() * 384, y = 1792 + r.NextDouble() * 384;
                if (!a.Geologie.Sloupec(x, y).AsSpan().SequenceEqual(b.Geologie.Sloupec(x, y)) || a.Geologie.Povrch(x, y) != b.Geologie.Povrch(x, y)) sl = false;
            }
            T.Je(sl, $"{nazev}: 200 sloupců geologie a povrch (s erozí) shodné");
            string va = OtiskVody.Blok(a.Voda(kat, pv, n0.PrusakJson).Blok(14, 14, 4, false)), vb = OtiskVody.Blok(b.Voda(kat, pv, n0.PrusakJson).Blok(14, 14, 4, false));
            T.Je(va == vb, $"{nazev}: otisk bloku vody 14,14 {va} = {vb}");
            Console.WriteLine(FormattableString.Invariant($"  {nazev}: původní {ta:F0} ms, pipeline {tb:F0} ms"));
        }
        T.Je(Segment(new PipelineSveta(data).Spust(ParametrySveta.Puvodni(), kes).Vystup<GeologieCs>("M3"), 2104, 2104) == "059d807ab04b7f00", "Puvodni(): segment geologie M3 = GDScript 059d807ab04b7f00");

        var vm1 = new PipelineSveta(data).Spust(new ParametrySveta(), kes).Vystup<VystupFunkceSveta>("M1");
        T.Je(!vm1.BezMore.IsValueCreated && vm1.Svet.More is null && vm1.Svet.Panve is null, "M1: funkce světa bez moře a pánví, staví se líně");
        T.Sekce("G-1: pipeline přepočítá jen dotčené moduly");
        var pp = new PipelineSveta(data) { Nastaveni = n0 };
        var r1 = pp.Spust(new ParametrySveta(), kes, 8);
        var r2 = pp.Spust(new ParametrySveta(), kes, 8);
        T.Je(r1.Prepocitane.Count == 8 && r2.Prepocitane.Count == 0 && ReferenceEquals(r1.Svet, r2.Svet), $"1. běh {S(r1.Prepocitane)}; 2. běh stejné vstupy: přepočteno {r2.Prepocitane.Count}");
        Console.WriteLine("  časy modulů (ms): " + string.Join(", ", r1.Moduly.Select(m => FormattableString.Invariant($"{m.Id} {m.Ms:F0}"))));
        pp.Nastaveni = new NastaveniModulu { Eroze = n0.Eroze, Klima = n0.Klima with { KontinentalitaM = 1000 }, Voda = n0.Voda, PrusakJson = n0.PrusakJson };
        var r3 = pp.Spust(new ParametrySveta(), kes, 8);
        T.Je(S(r3.Prepocitane) == "M5,M6,M7" && ReferenceEquals(r3.Vystup<VystupEroze>("M4"), r1.Vystup<VystupEroze>("M4")) && r3.Vystup<VystupPlanety>("M7").Souhrn.OtiskMapy == TestyKrok06d.GoldenMapaVychozi
            && r3.Vystup<VystupPlanety>("M7").Souhrn.OtiskKlimatu != r1.Vystup<VystupPlanety>("M7").Souhrn.OtiskKlimatu,
            $"změna klimatu: přepočteno {S(r3.Prepocitane)}, mapa eroze z paměti (golden), klima jiné");
        pp.Nastaveni = n0;
        var r4 = pp.Spust(new ParametrySveta { P82Podil = 0.6 }, kes, 8);
        T.Je(S(r4.Prepocitane) == "M3,M5,M6,M7" && ReferenceEquals(r4.Vystup<VystupEroze>("M4"), r1.Vystup<VystupEroze>("M4")),
            $"změna geologie po změně klimatu zpět: přepočteno {S(r4.Prepocitane)}");
        var r5 = pp.Spust(new ParametrySveta { P82Podil = 0.6 }, kes, 8);
        T.Je(r5.Prepocitane.Count == 0 && r5.Vystup<GeologieCs>("M3").Svet.Eroze is not null, "opakovaný běh: nic, geologie má erozi z M4");

        T.Sekce("G-1: determinismus 1 a 8 vláken");
        var s1 = new PipelineSveta(data) { Nastaveni = n0 }.Spust(new ParametrySveta(), kes, 1);
        var s8 = new PipelineSveta(data) { Nastaveni = n0 }.Spust(new ParametrySveta(), kes, 8);
        T.Je(S(s1.Klice.Values) == S(s8.Klice.Values) && s1.Vystup<VystupPlanety>("M7").Souhrn == s8.Vystup<VystupPlanety>("M7").Souhrn,
            $"klíče a souhrn stejné (klima {s8.Vystup<VystupPlanety>("M7").Souhrn.OtiskKlimatu}, vodníků {s8.Vystup<VystupPlanety>("M7").Souhrn.Vodniku})");
        Console.WriteLine("  klíče modulů (výchozí svět): " + string.Join(", ", s8.Moduly.Select(m => m.Id + " " + m.Klic[..12])));
    }

    static string Segment(GeologieCs g, double ox, double oy)
    {
        using var sha = System.Security.Cryptography.IncrementalHash.CreateHash(System.Security.Cryptography.HashAlgorithmName.SHA256);
        for (int ix = 0; ix < 32; ix++)
        for (int iy = 0; iy < 32; iy++)
            sha.AppendData(g.Geo.VyplnSloupec(ox + (ix + 0.5) * 0.25, oy + (iy + 0.5) * 0.25, 0.25, 128.0));
        return Convert.ToHexString(sha.GetHashAndReset())[..16].ToLowerInvariant();
    }
}
