using System.Collections.Concurrent;
using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Fronta;
using Willage.Gen.Api.Vizual;
using Willage.Gen.Data;
using Willage.Gen.Pipeline;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Svet;
using Willage.Gen.Planeta;
using Willage.Gen.Jadro;
using Willage.Gen.Katalogy;

namespace Willage.Gen.Testy;

/// <summary>G-4 (část bez Godotu): fronta práce, průběh a zrušení pipeline, barvy vrstev. Godot část: nastroje/testy/JadroTest.tscn.</summary>
public static class TestyG4
{
    static string S(IEnumerable<string> s) => string.Join(",", s);

    /// <summary>Dispečer do vlastní fronty (jako CallDeferred): akce se provedou až v Pump na „hlavním“ vlákně testu.</summary>
    sealed class Dispecer
    {
        readonly BlockingCollection<Action> _q = new();
        public void Posli(Action a) => _q.Add(a);
        public bool Pump(int ms) { if (!_q.TryTake(out var a, ms)) return false; a(); return true; }
    }

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");

        T.Sekce("G-4: fronta práce (jedno vlákno, pořadí, chyby, zrušení)");
        var d = new Dispecer(); int hlavni = Environment.CurrentManagedThreadId;
        using (var f = new FrontaPrace(d.Posli, "test"))
        {
            var konce = new List<string>(); var vlakna = new ConcurrentBag<int>(); var vlaknaKonce = new List<int>();
            var start = new ManualResetEventSlim(false);
            var sw = System.Diagnostics.Stopwatch.StartNew();
            long u1 = f.Zarad("a", _ => { start.Wait(); vlakna.Add(Environment.CurrentManagedThreadId); return 1; }, (id, k, v, e) => { konce.Add($"a:{k}:{v}"); vlaknaKonce.Add(Environment.CurrentManagedThreadId); });
            double zarad = sw.Elapsed.TotalMilliseconds;
            f.Zarad("b", _ => { vlakna.Add(Environment.CurrentManagedThreadId); throw new InvalidOperationException("bum"); }, (id, k, v, e) => konce.Add($"b:{k}:{e?.Message}"));
            f.Zarad("c", _ => { vlakna.Add(Environment.CurrentManagedThreadId); return "x"; }, (id, k, v, e) => { konce.Add($"c:{k}:{v}"); vlaknaKonce.Add(Environment.CurrentManagedThreadId); });
            T.Je(f.Cekajicich == 3 && zarad < 5, $"Zarad nic nepočítá ({zarad:F3} ms), čeká 3");
            start.Set();
            for (int i = 0; i < 3; i++) d.Pump(5000);
            T.Je(S(konce) == "a:Hotovo:1,b:Chyba:bum,c:Hotovo:x" && f.Cekajicich == 0, "pořadí, výjimka → Chyba, další úloha běží: " + S(konce));
            T.Je(vlakna.Distinct().Count() == 1 && vlakna.First() == f.IdVlakna && f.IdVlakna != hlavni && vlaknaKonce.All(t => t == hlavni), "práce na jednom vlákně fronty, konce přes dispečer na hlavním");
            // zrušení: běžící (čeká na token) i čekající
            konce.Clear(); var bezi = new ManualResetEventSlim(false);
            f.Zarad("dlouha", ct => { bezi.Set(); ct.WaitHandle.WaitOne(10000); ct.ThrowIfCancellationRequested(); return 0; }, (id, k, v, e) => konce.Add($"dlouha:{k}"));
            f.Zarad("cekajici", _ => 0, (id, k, v, e) => konce.Add($"cekajici:{k}"));
            bezi.Wait(5000);
            T.Je(f.Bezi == "dlouha" && f.Cekajicich == 2, "běží dlouhá, čeká 1");
            f.ZrusVse();
            for (int i = 0; i < 2; i++) d.Pump(5000);
            T.Je(S(konce) == "dlouha:Zruseno,cekajici:Zruseno", "ZrusVse zruší běžící i čekající: " + S(konce));
            konce.Clear();
            f.Zarad("po", _ => 5, (id, k, v, e) => konce.Add($"po:{k}:{v}")); d.Pump(5000);
            T.Je(S(konce) == "po:Hotovo:5", "po zrušení fronta funguje dál");
            int prubehu = 0;
            f.Zarad("prubeh", _ => { for (int i = 0; i < 4; i++) f.Dorucit(() => prubehu++); return 0; }, (id, k, v, e) => konce.Add("prubeh"));
            for (int i = 0; i < 5; i++) d.Pump(5000);
            T.Je(prubehu == 4 && konce[^1] == "prubeh", "průběh přes Dorucit dorazí před koncem úlohy");
        }

        T.Sekce("G-4: průběh a zrušení pipeline");
        var g = new GeneratorSveta(data, kes);
        var st = new List<ModulDto>();
        var r1 = g.Sluzba.Generuj(new Prubeh(st.Add), CancellationToken.None);
        T.Je(S(st.Select(m => m.Id)) == "M0,M1,M2,M3,M4,M5,M6,M6d,M7,M8,M9" && st.Where(m => m.Zastupny).All(m => m.Stav == StavModuluDto.Zastupny) && r1.Souhrn.OtiskMapy == TestyKrok06d.GoldenMapaVychozi,
            "průběh po každém z 11 modulů v pořadí, zástupné označené, golden mapa");
        st.Clear();
        g.Moduly.Nastav("ParametryKlimatu.KontinentalitaM", "1000");
        using var cts = new CancellationTokenSource();
        bool zrus = false;
        try { g.Sluzba.Generuj(new Prubeh(m => { st.Add(m); if (m.Id == "M5") cts.Cancel(); }), cts.Token); }
        catch (OperationCanceledException) { zrus = true; }
        T.Je(zrus && S(st.Select(m => m.Id)) == "M0,M1,M2,M3,M4,M5", "zrušení po M5 → OperationCanceledException před M6: " + S(st.Select(m => m.Id + ":" + m.Stav)));
        st.Clear();
        var r2 = g.Sluzba.Generuj(new Prubeh(st.Add), CancellationToken.None);
        T.Je(st.Single(m => m.Id == "M5").Stav == StavModuluDto.ZPameti && st.Single(m => m.Id == "M6").Stav == StavModuluDto.Spocitano && r2.Souhrn.OtiskKlimatu != r1.Souhrn.OtiskKlimatu,
            "po zrušení: M5 z paměti (hotový před zrušením), M6 a dál se dopočítá");
        var pz = new PipelineSveta(data);
        bool hned = false; using (var c0 = new CancellationTokenSource()) { c0.Cancel(); try { pz.Spust(new ParametrySveta(), kes, 8, null, c0.Token); } catch (OperationCanceledException) { hned = true; } }
        T.Je(hned, "zrušený token před startem → nic se nespočítá");

        Review(data, kes);

        T.Sekce("G-4: barvy vrstev (RGBA bez Godotu)");
        g.Moduly.Vychozi(); g.Sluzba.Generuj();
        var mv = g.Dotazy.Mapa(VrstvaMapyDto.Vyska); var mb = g.Dotazy.Mapa(VrstvaMapyDto.Biom);
        var a1 = BarvyVrstev.Rgba(mv); var a2 = BarvyVrstev.Rgba(g.Dotazy.Mapa(VrstvaMapyDto.Vyska));
        T.Je(a1.Length == mv.Nx * mv.Ny * 4 && a1.AsSpan().SequenceEqual(a2) && Enumerable.Range(0, mv.Nx * mv.Ny).All(i => a1[4 * i + 3] == 255), $"výška {mv.Nx}×{mv.Ny}: RGBA deterministické, alfa 255");
        var z4 = BarvyVrstev.Zmensi(mv, 4);
        T.Je(z4.Nx == mv.Nx / 4 && z4.Ny == mv.Ny / 4 && z4.KrokM == mv.KrokM * 4 && Math.Abs(z4.Hodnoty[0] - (mv.Hodnoty[0] + mv.Hodnoty[1] + mv.Hodnoty[mv.Nx] + mv.Hodnoty[mv.Nx + 1] + mv.Hodnoty[2] + mv.Hodnoty[3] + mv.Hodnoty[mv.Nx + 2] + mv.Hodnoty[mv.Nx + 3]
            + mv.Hodnoty[2 * mv.Nx] + mv.Hodnoty[2 * mv.Nx + 1] + mv.Hodnoty[2 * mv.Nx + 2] + mv.Hodnoty[2 * mv.Nx + 3] + mv.Hodnoty[3 * mv.Nx] + mv.Hodnoty[3 * mv.Nx + 1] + mv.Hodnoty[3 * mv.Nx + 2] + mv.Hodnoty[3 * mv.Nx + 3]) / 16) < 1e-3,
            $"zmenšení 4×: {z4.Nx}×{z4.Ny} po {z4.KrokM} m, průměr bloku");
        var rb = BarvyVrstev.Rgba(BarvyVrstev.Zmensi(mb, 4));
        var barvy = Enumerable.Range(0, rb.Length / 4).Select(i => (rb[4 * i], rb[4 * i + 1], rb[4 * i + 2])).Distinct().ToList();
        T.Je(barvy.All(c => BarvyVrstev.PaletaBiomu.Contains(c)) && barvy.Count >= 3, $"biom: jen barvy palety ({barvy.Count} různých), zmenšení bere vzorek (ne průměr)");
    }


    /// <summary>Připomínky Willage-backendu k fasádě G-3 (body 1, 3, 4, 5, 7).</summary>
    static void Review(DataSveta data, string kes)
    {
        T.Sekce("G-3 review: totožnost planety, seed, kompatibilita, katalog");
        var tmp = Path.Combine(Path.GetTempPath(), "willage-g3r-" + Environment.ProcessId); Directory.CreateDirectory(tmp);
        var g = new GeneratorSveta(data, kes);
        string f1 = Path.Combine(tmp, "a.wpln");
        var i1 = g.Sluzba.Uloz(f1);
        var p = SouborPlanety.Nacti(f1);
        T.Je(i1.OtiskPlanety == SouborPlanety.Otisk(p) && SouborPlanety.Otisk(SouborPlanety.ZBajtu(SouborPlanety.Bajty(p))) == i1.OtiskPlanety && i1.OtiskPlanety.Length == 64,
            $"otisk planety = SHA kanonického obsahu, stejný po uložení a načtení ({i1.OtiskPlanety[..16]})");
        T.Je(SouborPlanety.Otisk(p with { Potvrzena = true }) != i1.OtiskPlanety && SouborPlanety.Otisk(p with { Upravy = new[] { new UpravaRegionu("zvedni", "M2", 0, 0, 65536, 65536, "{}") } }) != i1.OtiskPlanety,
            "otisk se změní s potvrzením i s úpravou regionu (Q16)");
        var ex = System.Text.Json.Nodes.JsonNode.Parse(PlanetaJson.Export(p))!;
        T.Je((string?)ex["format"] == PlanetaJson.Format && (bool)ex["zastupny"]! && (string?)ex["otisk"] == i1.OtiskPlanety && (long)ex["seed"]! == 49, "zástupný JSON export planety: formát, otisk, seed");
        // seed 64 bit
        var gs = new GeneratorSveta(data, kes);
        long velky = (1L << 40) + 5;
        gs.Moduly.Nastav("ParametrySveta.Seed", velky.ToString());
        string f2 = Path.Combine(tmp, "b.wpln"); gs.Sluzba.Uloz(f2);
        var gn = new GeneratorSveta(data, kes); var ni = gn.Sluzba.Nacti(f2);
        T.Je(ni.Seed == velky && SouborPlanety.Nacti(f2).Seed == velky && SeedSveta.Hash32(49) == 49u && SeedSveta.Hash32(velky) == 5u && SeedSveta.Hash32(-1) == uint.MaxValue,
            $"seed 2⁴⁰+5 se ve WPLN nezkrátí; 32bit seed jen přes SeedSveta.Hash32 ({SeedSveta.Hash32(velky)})");
        // kompatibilita
        T.Je(KompatibilitaPlanety.Urci(p) == UrovenKompatibility.Plna && KompatibilitaPlanety.Urci(p with { GenVer = "V0.9" }) == UrovenKompatibility.Nepodporovana && ni.Kompatibilita == "Plna",
            "kompatibilita: V1.0 Plna, neznámá V0.9 Nepodporovana");
        string f3 = Path.Combine(tmp, "c.wpln"); SouborPlanety.Uloz(f3, p with { GenVer = "V0.9" });
        bool odm = false; try { new GeneratorSveta(data, kes).Sluzba.Nacti(f3); } catch (InvalidDataException) { odm = true; }
        var b = SouborPlanety.Bajty(p); byte[] v2;
        using (var ms = new MemoryStream())
        {
            using (var z = new System.IO.Compression.DeflateStream(new MemoryStream(b), System.IO.Compression.CompressionMode.Decompress)) z.CopyTo(ms);
            var raw = ms.ToArray(); raw[4] = 2;   // verze formátu 2
            using var o = new MemoryStream();
            using (var z = new System.IO.Compression.DeflateStream(o, System.IO.Compression.CompressionLevel.Optimal, true)) z.Write(raw);
            v2 = o.ToArray();
        }
        bool odm2 = false; try { SouborPlanety.ZBajtu(v2); } catch (InvalidDataException) { odm2 = true; }
        T.Je(odm && odm2, "neznámá gen_ver i novější formát WPLN (2) odmítnuty");
        // katalog materiálů připnutý v manifestu fasády
        var md = g.Katalogy.Manifest();
        T.Je(md.KatalogMaterialu.Cesta == "v1/materials-catalog-v1.json" && md.KatalogMaterialu.SchemaVersion == 1 && md.KatalogMaterialu.Sha256 == ManifestKatalogu.Spocti(data).ShaSouboru("v1/materials-catalog-v1.json"),
            $"katalog materiálů připnutý: schemaVersion {md.KatalogMaterialu.SchemaVersion}, SHA {md.KatalogMaterialu.Sha256[..16]}");
        Directory.Delete(tmp, true);
    }

    sealed class Prubeh : IProgress<ModulDto>
    {
        readonly Action<ModulDto> _a; public Prubeh(Action<ModulDto> a) => _a = a;
        public void Report(ModulDto m) => _a(m);
    }
}
