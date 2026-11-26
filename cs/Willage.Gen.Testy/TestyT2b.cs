using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Willage.Gen.Data;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Gen.Testy;

/// <summary>T-2b / T-2c: Dev VPMG ops v1 s opravou (42e7475): schéma z deskriptorů Dev, receptury v1 vzorku, goldeny přes nástroj i fasádu, paleta, barvy.</summary>
public static class TestyT2b
{
    static string S<X>(IEnumerable<X> x) => string.Join(",", x);

    /// <summary>Goldeny od Willage-backendu (zpráva 22:48) – nezávislá kontrola fixture Dev.</summary>
    static readonly Dictionary<string, uint> Ocekavane = new()
    {
        ["recipe-grass-v1.json"] = 756991887u, ["recipe-topsoil-v1.json"] = 2725408357u, ["recipe-gravel-sand-v1.json"] = 3628591702u,
        ["recipe-cave-limestone-v1.json"] = 2752359023u, ["recipe-granite-v1.json"] = 917430836u,
        ["recipe-op-smooth-noise-v1.json"] = 2914983316u, ["recipe-op-palette-map-v1.json"] = 2821145053u, ["recipe-op-strata-v1.json"] = 2813106466u,
        ["recipe-op-warp-v1.json"] = 887461636u, ["recipe-op-grass-tufts-v1.json"] = 2214710167u,
    };

    /// <summary>Podíl pixelů dál než <paramref name="mez"/> (max |ΔRGB|) od nejbližší barvy palety (kontrola „žádné žluté / modré“ z T-2b).</summary>
    static double MimoPaletu(byte[] rgba, IReadOnlyList<string> paleta, int mez)
    {
        var pal = paleta.Select(KatalogVzhledu.Barva).ToList(); int mimo = 0, n = rgba.Length / 4;
        for (int i = 0; i < rgba.Length; i += 4)
        {
            int best = pal.Min(c => Math.Max(Math.Abs(rgba[i] - c.R), Math.Max(Math.Abs(rgba[i + 1] - c.G), Math.Abs(rgba[i + 2] - c.B))));
            if (best > mez) mimo++;
        }
        return (double)mimo / n;
    }

    static void DescribeOps(string devKoren, JsonNode soubor)
    {
        var psi = new System.Diagnostics.ProcessStartInfo("dotnet") { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false };
        foreach (var a in new[] { "run", "-c", "Release", "--project", Path.Combine(devKoren, "tools", "VpmgPreview"), "--", "--describe-ops" }) psi.ArgumentList.Add(a);
        using var pr = System.Diagnostics.Process.Start(psi)!;
        string vystup = pr.StandardOutput.ReadToEnd(); pr.WaitForExit();
        int z = vystup.IndexOf('['); if (pr.ExitCode != 0 || z < 0) { T.Je(false, "VpmgPreview --describe-ops selhal: " + pr.StandardError.ReadToEnd()); return; }
        var desk = JsonNode.Parse(vystup[z..])!.AsArray();
        int shod = 0, celkem = 0; var roz = new List<string>();
        foreach (var d in desk)
        {
            string type = (string)d!["TypeId"]!; var par = d["Parameters"]!.AsArray();
            var naso = soubor["operace"]!.AsArray().FirstOrDefault(o => (string)o!["type"]! == type);
            if (naso is null) { roz.Add("chybí " + type); continue; }
            if (par.Count == 0 && naso["aliasOf"] != null) continue; // alias: Dev nemá parametry, my bereme cílovou operaci
            foreach (var p in par)
            {
                celkem++;
                var q = naso["params"]!.AsArray().FirstOrDefault(x => (string)x!["nazev"]! == (string)p!["Name"]!);
                bool ok = q != null && (int?)q["min"] == (int?)p!["Min"] && (int?)q["max"] == (int?)p["Max"] && ((string?)p["DefaultLiteral"] ?? "") == (string)q["vychozi"]!
                    && (string?)p["ProfileField"] == (string?)q["zProfilu"]?[0];
                if (ok) shod++; else roz.Add(type + "." + (string)p!["Name"]!);
            }
        }
        T.Je(desk.Count == soubor["operace"]!.AsArray().Count && shod == celkem && roz.Count == 0,
            $"operace_dev_v1.json = VpmgPreview --describe-ops ({desk.Count} operací, {shod}/{celkem} parametrů){(roz.Count > 0 ? ": " + S(roz) : "")}");
    }

    public static void Spust()
    {
        T.Sekce("T-2b/T-2c: Dev VPMG ops v1 (oprava 42e7475) – schéma z deskriptorů Dev, receptury v1 vzorku, goldeny, paleta, barvy");
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        using var api = new MaterialyApi(data.Koren);
        var sch = api.Schema; var kn = api.Receptury; var k = api.Katalog;
        string devKoren = Path.GetFullPath(Path.Combine(data.Koren, "..", "..", ".willage-dev", api.Pin.Commit));

        // schéma: generované z Dev + překryv
        T.Je(sch.Nesoulad.Count == 0, "překryv operací souhlasí s Dev (žádný parametr / operace navíc): " + S(sch.Nesoulad));
        var v1 = new[] { "smooth_noise", "value_noise", "palette_map", "color_variation", "strata", "warp", "irregularity", "grass_tufts" };
        T.Je(v1.All(t => sch.Operace(t) is { Zastupna: false }), "operace v1 v konfigurátoru (spustitelné): " + S(v1));
        T.Je(sch.Operace("value_noise")!.AliasOf == "smooth_noise" && sch.Operace("color_variation")!.AliasOf == "palette_map" && sch.Operace("irregularity")!.AliasOf == "warp", "aliasy z Dev (_inner): value_noise→smooth_noise, color_variation→palette_map, irregularity→warp");
        var sn = sch.Operace("smooth_noise")!;
        T.Je(S(sn.Params.Select(p => p.Nazev + "=" + p.Vychozi)) == "scalePermille=,octaves=3,amplitudePermille=120" && sn.Params[0].VychoziDev.Contains("grainScalePermille") && sn.Params[1].Min == 1 && sn.Params[1].Max == 6 && sn.Params[0].Max == 2000,
            "smooth_noise: scalePermille (výchozí = profil grain, 1..2000), octaves 3 (1..6), amplitude 120 – z deskriptorů Dev");
        T.Je(S(sch.Operace("palette_map")!.Params.Select(p => p.Nazev + "=" + p.Vychozi)) == "scalePermille=280,jitterPermille=90", "palette_map: scale 280, jitter 90");
        T.Je(S(sch.Operace("strata")!.Params.Select(p => p.Nazev)) == "bandMinPx,bandJitterPermille" && S(sch.Operace("strata")!.CtiProfil) == "baseColor,irregularityPermille,layerDensityPermille,palette", "strata: bandMinPx, bandJitterPermille; čte paletu, layerDensity, irregularity");
        T.Je(S(sch.Operace("warp")!.Params.Select(p => p.Nazev)) == "strengthPermille,cellPx" && S(sch.Operace("grass_tufts")!.Params.Select(p => p.Nazev + "=" + p.Vychozi)) == "densityPermille=550,bladeLengthPermille=180,hueJitterPermille=120",
            "warp: strength, cellPx; grass_tufts: 550 / 180 / 120");
        T.Je(sch.Spustitelne.SelectMany(o => o.Params).All(p => !p.BezPrekryvu), "každý parametr Dev má klientský popis (žádný obecný editor)");

        // receptury v1 vzorku (N8)
        T.Je(S(kn.Zaznamy.Select(z => z.MaterialId)) == S(api.Vzorek.Materialy.Select(m => m.Id)) && kn.DevCommit == api.Pin.Commit, "receptury v1 = vzorek 1,2,3,5,6; index z pinu Dev");
        T.Je(kn.Zaznamy.All(z => z.Soubor == $"{z.MaterialId}.json" && kn.ShaSouboru(z) == z.Sha256), "receptury/<materialId>.json, SHA = index");
        if (Directory.Exists(devKoren))
            T.Je(kn.Zaznamy.All(z => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(devKoren, z.ZdrojDev)))).ToLowerInvariant() == z.Sha256),
                "kopie receptur = fixture Dev v pinu bajt po bajtu");
        else T.Je(false, "připnutý Dev chybí: " + devKoren);
        T.Je(kn.Zaznamy.All(z => RecepturyVpmg.Validuj(z.Receptura, sch, k).Count == 0), "receptury v1 platné proti schématu z Dev: " + S(kn.Zaznamy.SelectMany(z => RecepturyVpmg.Validuj(z.Receptura, sch, k))));
        T.Je(kn.Zaznamy.All(z => Ocekavane[Path.GetFileName(z.ZdrojDev)] == z.GoldenChecksum), "golden v indexu = goldeny backendu");
        T.Je(RecepturyVpmg.DoJson(kn.Vychozi(52)) == RecepturyVpmg.DoJson(RecepturyVpmg.Vychozi(52)), "materiál bez receptury v1 → výchozí v0");

        // paleta
        T.Je(api.Vzorek.Materialy.All(m => k.Material(m.Id)!.Profily["default"].Palette is { Count: >= 4 }) && k.Material(52)!.Profily["default"].Palette is null,
            "palette: 5 materiálů vzorku ji má (4–5 barev), 52 ne: " + S(api.Vzorek.Materialy.Select(m => k.Material(m.Id)!.Profily["default"].Palette!.Count)));

        // stav editoru s knihovnou
        var st = new StavEditoru(k, sch, api.Vzorek, receptury: kn);
        T.Je(RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(kn.Zaznam(1)!.Receptura) && st.ZdrojReceptury!.Soubor == "1.json", "stav: tráva → receptura v1 z receptury/1.json");
        st.VyberMaterial(6);
        T.Je(RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(kn.Zaznam(6)!.Receptura) && st.Receptura.Kroky.Count == 6, "výběr 6 žula → její receptura v1 (6 kroků)");
        T.Je(st.PridejKrok("smooth_noise") == null && st.Receptura.Kroky[^1].Params is var pn && !pn.ContainsKey("scalePermille") && pn["octaves"] == "3" && pn["amplitudePermille"] == "120",
            "přidaný smooth_noise: octaves 3, amplitude 120, scalePermille nevyplněno (= profil, jako Dev)");
        int ix = st.Receptura.Kroky.Count - 1;
        T.Je(st.NastavParametrKroku(ix, "octaves", "9") != null && st.NastavParametrKroku(ix, "scalePermille", "300") == null && st.Receptura.Kroky[ix].Params["scalePermille"] == "300"
             && st.NastavParametrKroku(ix, "scalePermille", "") == null && !st.Receptura.Kroky[ix].Params.ContainsKey("scalePermille"), "octaves 9 mimo 1..8 odmítnuto; prázdná hodnota = výchozí Dev (klíč odebrán)");
        st.VychoziReceptura();
        T.Je(RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(kn.Zaznam(6)!.Receptura), "„Výchozí receptura“ = v1 materiálu");
        T.Je(st.NastavNavrh("palette", "#112233, #zz0000") != null && st.NastavNavrh("palette", "#112233, #445566") == null && S(st.Navrh.Palette!) == "#112233,#445566"
             && st.NastavNavrh("palette", st.ProfilKatalogu.PaletaText) == null && st.Navrh.Palette is null, "návrh palety: špatná barva odmítnuta, platná projde, = katalog → zrušen");

        // nástroj + fasáda
        var z = (ZdrojVpmgProces)api.Zdroj;
        if (!z.Dostupny) { T.Je(false, "nástroj VPMG chybí: " + z.Popis); return; }
        var info = z.Info();
        T.Je(info.DevCommit == api.Pin.Commit && S(info.Operace) == S(sch.Spustitelne.Select(o => o.Type).OrderBy(x => x, StringComparer.Ordinal)), $"registr Dev {info.DevCommit[..7]} = spustitelné operace schématu ({info.Operace.Count})");
        var ziva = JsonNode.Parse(z.ParametryDevJson())!; var soubor = JsonNode.Parse(File.ReadAllText(Path.Combine(api.KorenDat, "vpmg", "operace_dev_v1.json")))!;
        T.Je(JsonNode.DeepEquals(ziva, soubor), "operace_dev_v1.json = živý rozbor Dev nástrojem (generovaný soubor aktuální)");
        var g = z.Goldeny();
        T.Je(g.Count == 10 && g.All(x => x.Ocekavany == x.Spocteny && Ocekavane[x.Soubor] == x.Ocekavany), "goldeny v1 přes nástroj 10/10: " + S(g.Select(x => $"{x.Soubor.Replace("recipe-", "").Replace("-v1.json", "")}={x.Spocteny}")));
        var (oc, sp) = z.Golden();
        T.Je(oc == 1756279408u && sp == oc && z.Spust(RecepturyVpmg.Vychozi(52), 0xC0FFEE00u).Checksum == 1756279408u, "legacy golden 52 = 1756279408 (nástroj i fasáda)");
        var fas = kn.Zaznamy.Select(r => (r.MaterialId, Ch: z.Spust(r.Receptura, r.GoldenSeed).Checksum, r.GoldenChecksum)).ToList();
        T.Je(fas.All(x => x.Ch == x.GoldenChecksum), "goldeny 5 materiálů přes fasádu (receptury/ + zrcadlo): " + S(fas.Select(x => $"{x.MaterialId}={x.Ch}")));
        if (Directory.Exists(devKoren))
        {
            var opy = Ocekavane.Keys.Where(f => f.StartsWith("recipe-op-")).Select(f => (f, Ch: z.Spust(RecepturyVpmg.ZJson(File.ReadAllText(Path.Combine(devKoren, "tests/Willage.World.Vpmg.Tests/Fixtures/recipes", f))), 0xC0FFEE00u).Checksum)).ToList();
            T.Je(opy.All(x => x.Ch == Ocekavane[x.f]), "goldeny 5 operací přes fasádu (receptura Dev → DTO → JSON fasády → nástroj): " + S(opy.Select(x => x.Ch)));
        }
        var r6 = kn.Zaznam(6)!.Receptura;
        uint c0 = z.Spust(r6, 0xC0FFEE00u).Checksum;
        T.Je(z.Spust(r6, 0xC0FFEE00u, new NavrhProfiluDto(Palette: new[] { "#112233", "#445566" })).Checksum != c0 && z.Spust(r6, 0xC0FFEE00u).Checksum == c0, "návrh palety změní žulu, bez návrhu zase golden");
        bool ld = z.Spust(r6, 0xC0FFEE00u, new NavrhProfiluDto(LayerDensityPermille: 900)).Checksum != c0, ir = z.Spust(r6, 0xC0FFEE00u, new NavrhProfiluDto(IrregularityPermille: 900)).Checksum != c0;
        T.Je(ld && ir, "T-2c: receptura žuly bez natvrdo zadaného bandMinPx / warp → layerDensity i irregularity profilu se projeví");
        var r6p = r6 with { Kroky = r6.Kroky.Select(x => x.Type is "strata" or "warp" ? x with { Params = new Dictionary<string, string>() } : x).ToList() };
        uint cp = z.Spust(r6p, 0xC0FFEE00u).Checksum;
        T.Je(z.Spust(r6p, 0xC0FFEE00u, new NavrhProfiluDto(LayerDensityPermille: 900)).Checksum != cp && z.Spust(r6p, 0xC0FFEE00u, new NavrhProfiluDto(IrregularityPermille: 900)).Checksum != cp,
            "strata / warp bez parametrů: layerDensity i irregularity profilu výstup mění (výchozí Dev z profilu)");
        T.Je(z.Spust(r6, 0xC0FFEE00u, new NavrhProfiluDto(Style: "watercolor")).Checksum == c0, "style dál nečte žádná operace (negativní nález)");
        uint sA = z.Spust(r6, 1).Checksum;
        var r6b = r6 with { Kroky = r6.Kroky.Select(x => x.Id == "s4" ? x with { Id = "s4b" } : x).ToList() };
        T.Je(z.Spust(r6b, 1).Checksum != sA, "seed kroku = DeriveSeed(seed, HashString(step.Id)): přejmenování kroku změní výstup");
        // T-2c: barvy v paletě (oprava SmoothStep / strata) – podíl pixelů dál než 48 od nejbližší barvy palety
        foreach (var r in kn.Zaznamy)
        {
            var t = z.Spust(r.Receptura, r.GoldenSeed); var pal = k.Material(r.MaterialId)!.Profily["default"].Palette!;
            double mimo = MimoPaletu(t.Rgba, pal, 48);
            int cist = 0; for (int i = 0; i < t.Rgba.Length; i += 4) if ((t.Rgba[i] == 255 && t.Rgba[i + 1] == 255 && t.Rgba[i + 2] == 0) || (t.Rgba[i] == 0 && t.Rgba[i + 1] == 0 && t.Rgba[i + 2] == 255)) cist++;
            Console.WriteLine($"  barvy {r.MaterialId}: mimo paletu (>48) {mimo:P1}, čistě žlutých / modrých {cist}");
            T.Je(cist == 0 && mimo < 0.05, $"barvy {r.MaterialId} {k.Material(r.MaterialId)!.Key}: žádné čistě žluté / modré ({cist}), mimo paletu {mimo:P1} < 5 %");
        }

        // T-2c: generovaný soubor = výstup VpmgPreview --describe-ops z pinu Dev (stejné parametry, rozsahy, výchozí hodnoty)
        if (Directory.Exists(devKoren)) DescribeOps(devKoren, soubor);
        foreach (var r in kn.Zaznamy) { var t = z.Spust(r.Receptura, r.GoldenSeed); Console.WriteLine($"  {r.MaterialId} {k.Material(r.MaterialId)!.Key}: {t.Checksum} ({t.MsNastroj:F2} ms nástroj, {t.MsCelkem:F2} ms celkem)"); }
    }
}
