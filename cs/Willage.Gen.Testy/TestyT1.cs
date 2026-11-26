using System.Diagnostics;
using Willage.Gen.Data;
using Willage.Gen.Katalogy;
using Willage.Gen.Pipeline;
using Willage.Gen.Svet;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Gen.Testy;

/// <summary>T-1: VPMG z připnutého Willage_Dev mimo proces + fasáda materiálů (katalog vzhledu, receptury, schéma operací).</summary>
public static class TestyT1
{
    static string S<X>(IEnumerable<X> x) => string.Join(",", x);

    static uint Fnv(byte[] b) { uint h = 0x811C9DC5; foreach (var x in b) { h ^= x; h = unchecked(h * 0x01000193); } return h; }

    public static void Spust()
    {
        T.Sekce("T-1: VPMG z připnutého Dev (nástroj mimo proces), katalog vzhledu, receptury, schéma operací");
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        using var api = new MaterialyApi(data.Koren);
        var pin = api.Pin;
        var man = ManifestKatalogu.Spocti(data);

        // pin a zrcadlo
        T.Je(pin.Commit == "34764880fa2b0f1c580558403f9ea40a29f6a1c8" && api.Schema.DevCommit == pin.Commit, $"pin Dev {pin.Commit[..7]} = schéma operací ({api.Schema.DevCommit[..7]})");
        T.Je(man.ShaSouboru(pin.ZrcadloCesta) == pin.ZrcadloSha, "SHA zrcadla = manifest");
        T.Je(pin.GoldenChecksum == 1756279408u && pin.GoldenMaterial == 52 && pin.GoldenSeed == 0xC0FFEE00u && pin.GoldenRozliseni == 64, "golden v pinu = Dev (52, 0xC0FFEE00, 64 → 1756279408)");

        // katalog vzhledu
        var k = api.Katalog;
        T.Je(k.Materialy.Count == 75 && k.Materialy.Select(m => m.Id).Distinct().Count() == 75, $"katalog vzhledu: 75 materiálů ({k.Materialy.Count})");
        T.Je(k.Materialy.All(m => m.Profily.ContainsKey("default")), "každý materiál má profil default");
        T.Je(k.Materialy.All(m => m.Fyzika.Count >= 8 && m.Fyzika.Any(f => f.Nazev == "porosityPermille")), "fyzika (geology) jen ke čtení u každého materiálu");
        var m52 = k.Material(52)!;
        Console.WriteLine($"  materiál 52 {m52.Key} „{m52.Nazev}“, {m52.Profily["default"]}, skupin {k.Skupiny.Count}: {S(k.Skupiny)}");

        // schéma operací
        var sch = api.Schema;
        T.Je(sch.Spustitelne.Count == 2 && sch.Zastupne.Count == 7, $"schéma: 2 spustitelné + 7 zástupných ({sch.Spustitelne.Count} + {sch.Zastupne.Count})");
        T.Je(sch.Profil.Select(p => p.Nazev).SequenceEqual(new[] { "style", "baseColor", "grainScalePermille", "layerDensityPermille", "irregularityPermille" }), "parametry profilu = MaterialVisualProfile Dev");

        // receptury – formát a validace (bez nástroje)
        var r52 = RecepturyVpmg.Vychozi(52);
        T.Je(RecepturyVpmg.DoJson(RecepturyVpmg.ZJson(RecepturyVpmg.DoJson(r52))) == RecepturyVpmg.DoJson(r52), "receptura JSON tam a zpět");
        T.Je(RecepturyVpmg.Validuj(r52, sch, k).Count == 0, "výchozí receptura je platná");
        var spatna = r52 with { Resolution = 4, Kroky = r52.Kroky.Append(new KrokVpmgDto("s3", "perlin", true, new Dictionary<string, string>()))
            .Append(new KrokVpmgDto("s4", "roots", true, new Dictionary<string, string>())).Append(new KrokVpmgDto("s1", "hash_grain", true, new Dictionary<string, string> { ["x"] = "1" })).ToList() };
        var ch = RecepturyVpmg.Validuj(spatna, sch, k);
        T.Je(ch.Count == 5, $"validace: rozlišení, neznámá, zástupná, duplicitní id, neznámý parametr ({ch.Count}: {S(ch)})");
        T.Je(RecepturyVpmg.Validuj(r52 with { MaterialId = 200 }, sch, k).Count == 1 && RecepturyVpmg.Validuj(r52 with { VisualProfile = "mokry" }, sch, k).Count == 1, "validace: chybějící materiál / profil");

        // bez nástroje → zástupné
        Environment.SetEnvironmentVariable("WILLAGE_VPMG_NASTROJ", null);
        string tmpZrc = Path.Combine(Path.GetTempPath(), "willage-t1-zrcadlo.json"); File.Copy(k.Cesta, tmpZrc, true);
        using (var bez = new ZdrojVpmgProces(tmpZrc))
        {
            var z = bez.Spust(r52, 1);
            T.Je(!bez.Dostupny && z.Zastupna && !z.Ok && z.Rgba.Length == 64 * 64 * 4 && bez.Popis.StartsWith("zástupné"), "bez nástroje: Dostupny=false, zástupná textura s popisem");
        }

        // nástroj
        var zdroj = (ZdrojVpmgProces)api.Zdroj;
        T.Je(zdroj.Dostupny, "nástroj VPMG nalezen: " + zdroj.Popis);
        if (!zdroj.Dostupny) return;
        var sw = Stopwatch.StartNew();
        var info = zdroj.Info();
        Console.WriteLine($"  nástroj: Dev {info.DevCommit[..7]}, runtime {info.Runtime}, katalog {Path.GetFileName(info.Katalog)}, operace {S(info.Operace)}, studený start {zdroj.MsStartu:F0} ms");
        T.Je(info.DevCommit == pin.Commit, "commit nástroje (csproj WillageDevCommit) = dev_pin.json");
        T.Je(info.Materialu == 75 && info.Katalog == k.Cesta, "nástroj čte zrcadlo klienta (75 materiálů, loader Dev)");
        T.Je(S(info.Operace) == S(sch.Spustitelne.Select(o => o.Type).OrderBy(x => x, StringComparer.Ordinal)), $"spustitelné operace schématu = registr Dev ({S(info.Operace)})");
        T.Je(sch.Zastupne.All(o => !info.Operace.Contains(o.Type)), "zástupné operace v registru Dev nejsou");

        var kz = zdroj.KontrolaZrcadla(k.Cesta);
        T.Je(kz.BajtyBezKonce && kz.Zaznamy && kz.Pocet == 75 && kz.PocetDev == 75, $"zrcadlo = katalog Dev v pinu (bajty bez konce, záznamy 75/75; {kz.Rozdil})");

        var (oc, sp) = zdroj.Golden();
        T.Je(oc == 1756279408u && sp == oc, $"golden Dev přes nástroj: {sp} = {oc}");
        var g = zdroj.Spust(RecepturyVpmg.Vychozi(52), 0xC0FFEE00u);
        T.Je(g.Ok && g.Checksum == 1756279408u && g.Sirka == 64 && g.Rgba.Length == 16384, $"golden přes fasádu (receptura z klienta, katalog = zrcadlo): {g.Checksum}");
        T.Je(Fnv(g.Rgba) == g.Checksum, "RGBA přenesené přes proces = checksum Dev (FNV nad bajty)");
        Console.WriteLine($"  textura 64 px: nástroj {g.MsNastroj:F2} ms, celkem s přenosem {g.MsCelkem:F2} ms");

        var g2 = zdroj.Spust(RecepturyVpmg.Vychozi(52), 0xC0FFEE00u);
        T.Je(g2.Rgba.AsSpan().SequenceEqual(g.Rgba), "stejný vstup = stejné bajty");
        T.Je(zdroj.Spust(r52, 1).Checksum != zdroj.Spust(r52, 2).Checksum, "jiný seed = jiný checksum");
        T.Je(zdroj.Spust(r52 with { Kroky = new[] { r52.Kroky[0] with { Enabled = true }, r52.Kroky[1] with { Enabled = false } } }, 0xC0FFEE00u).Checksum != g.Checksum, "vypnutý krok hash_grain změní výstup");

        // receptura JSON = VpmgRecipeJson Dev bajt po bajtu
        var rnd = new Random(7); int shod = 0, celkem = 0;
        foreach (var r in new[] { r52, RecepturyVpmg.Vychozi(3, 128), r52 with { VisualProfile = "default", Kroky = new[] { new KrokVpmgDto("a", "base_fill", false, new Dictionary<string, string> { ["layer"] = "albedo", ["zz"] = "ž" }) } } }
            .Concat(Enumerable.Range(0, 5).Select(i => new RecepturaVpmgDto(1, (byte)rnd.Next(75), "default", 8 << rnd.Next(5),
                Enumerable.Range(0, rnd.Next(1, 4)).Select(j => new KrokVpmgDto("k" + j, j % 2 == 0 ? "base_fill" : "hash_grain", rnd.Next(2) == 0, new Dictionary<string, string> { ["layer"] = "l" + rnd.Next(3) })).ToList()))))
        {
            celkem++; var j = RecepturyVpmg.DoJson(r);
            if (zdroj.Kanon(j) == j) shod++; else Console.WriteLine("  rozdíl:\n" + j + "\n≠\n" + zdroj.Kanon(j));
        }
        T.Je(shod == celkem, $"receptura fasády = VpmgRecipeJson.ToJson Dev bajt po bajtu ({shod}/{celkem})");

        // návrh profilu jen v paměti
        var (cr, cg, cb) = KatalogVzhledu.Barva(m52.Profily["default"].BaseColor);
        var n0 = zdroj.Spust(r52, 0xC0FFEE00u, new NavrhProfiluDto(GrainScalePermille: 0));
        bool vse = true; for (int i = 0; i < n0.Rgba.Length; i += 4) vse &= n0.Rgba[i] == cr && n0.Rgba[i + 1] == cg && n0.Rgba[i + 2] == cb && n0.Rgba[i + 3] == 255;
        T.Je(vse, $"návrh grain 0 → celá plocha baseColor {m52.Profily["default"].BaseColor}");
        var n1 = zdroj.Spust(r52, 0xC0FFEE00u, new NavrhProfiluDto(BaseColor: "#102030", GrainScalePermille: 0));
        T.Je(n1.Rgba[0] == 0x10 && n1.Rgba[1] == 0x20 && n1.Rgba[2] == 0x30 && n1.Rgba[^4] == 0x10, "návrh baseColor #102030 se projeví");
        T.Je(zdroj.Spust(r52, 0xC0FFEE00u).Checksum == 1756279408u, "po návrhu bez návrhu znovu golden (katalog se nezměnil)");
        T.Je(zdroj.Spust(r52, 0xC0FFEE00u, new NavrhProfiluDto(LayerDensityPermille: 900, IrregularityPermille: 900, Style: "watercolor")).Checksum == 1756279408u,
            "v0: layerDensity / irregularity / style výstup nemění (žádná operace je nečte – negativní nález)");
        T.Je(File.ReadAllText(k.Cesta) == File.ReadAllText(tmpZrc), "zrcadlo katalogu na disku beze změny");

        // chyba operace nezabije proces
        var chyb = zdroj.Spust(r52 with { Kroky = new[] { new KrokVpmgDto("x", "perlin", true, new Dictionary<string, string>()) } }, 1);
        T.Je(!chyb.Ok && chyb.Chyba!.Contains("Unknown VPMG step type") && zdroj.Spust(r52, 0xC0FFEE00u).Checksum == 1756279408u, "neznámá operace → chyba z registru Dev, proces běží dál: " + chyb.Chyba);

        // všechny materiály, větší rozlišení
        var swv = Stopwatch.StartNew(); var sumy = new HashSet<uint>(); int okm = 0;
        foreach (var m in k.Materialy) { var t = zdroj.Spust(RecepturyVpmg.Vychozi(m.Id), 49); if (t.Ok) okm++; sumy.Add(t.Checksum); }
        T.Je(okm == 75, $"všech 75 materiálů 64 px OK ({okm}), různých checksumů {sumy.Count}, {swv.Elapsed.TotalMilliseconds:F0} ms");
        Console.WriteLine($"  75 materiálů 64 px: {swv.Elapsed.TotalMilliseconds:F0} ms, různých checksumů {sumy.Count}");
        var t256 = zdroj.Spust(RecepturyVpmg.Vychozi(52, 256), 49);
        Console.WriteLine($"  256 px: nástroj {t256.MsNastroj:F1} ms, celkem s přenosem {t256.MsCelkem:F1} ms");
        T.Je(t256.Ok && t256.Rgba.Length == 256 * 256 * 4, $"256 px: nástroj {t256.MsNastroj:F1} ms, celkem {t256.MsCelkem:F1} ms");

        // klíče světa: soubory data/vpmg nemění klíč žádného modulu
        string tmp = Path.Combine(Path.GetTempPath(), "willage-t1-data-" + Environment.ProcessId);
        if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
        foreach (var x in man.Polozky.Where(x => !x.Cesta.StartsWith("vpmg/", StringComparison.Ordinal)))
        { var c = Path.Combine(tmp, x.Cesta); Directory.CreateDirectory(Path.GetDirectoryName(c)!); File.Copy(Path.Combine(data.Koren, x.Cesta), c); }
        var bezVpmg = new PipelineSveta(new DataSveta(tmp)).Klice(new ParametrySveta());
        var sVpmg = new PipelineSveta(data).Klice(new ParametrySveta());
        var lisi = sVpmg.Where(kv => bezVpmg[kv.Key] != kv.Value).Select(kv => kv.Key).ToList();
        T.Je(lisi.SequenceEqual(new[] { "M7" }), $"data/vpmg/* nemění klíče M0–M6; mění jen M7 (souhrn manifestu, návrh G-1) – liší se: {S(lisi)}");
        Directory.Delete(tmp, true);
        Console.WriteLine($"  T-1 nástrojová část {sw.Elapsed.TotalMilliseconds:F0} ms");
    }
}
