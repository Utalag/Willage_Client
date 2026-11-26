using System.Security.Cryptography;
using System.Text.Json;
using Willage.Gen.Data;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Gen.Testy;

/// <summary>T-2d: Dev 36ac11f – base_texture nad ručními dlaždicemi (baseTile), receptury v2 vzorku, goldeny v2 přes nástroj i fasádu, variace seedu.</summary>
public static class TestyT2d
{
    static string S<X>(IEnumerable<X> x) => string.Join(",", x);

    /// <summary>Goldeny v2 od Willage-backendu (zpráva 23:43, seed 0xC0FFEE00, 64 px) – nezávislá kontrola fixture Dev.</summary>
    static readonly Dictionary<string, uint> V2 = new()
    {
        ["recipe-grass-v2.json"] = 3708330389u, ["recipe-topsoil-v2.json"] = 4232278201u, ["recipe-gravel-sand-v2.json"] = 589438081u,
        ["recipe-cave-limestone-v2.json"] = 1867729526u, ["recipe-granite-v2.json"] = 453757041u,
    };

    public static void Spust()
    {
        T.Sekce("T-2d: Dev 36ac11f – base_texture + dlaždice baseTile, receptury v2 vzorku, goldeny v2, variace seedu");
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        using var api = new MaterialyApi(data.Koren);
        var sch = api.Schema; var kn = api.Receptury; var k = api.Katalog;
        string devKoren = Path.GetFullPath(Path.Combine(data.Koren, "..", "..", ".willage-dev", api.Pin.Commit));

        // schéma: base_texture z deskriptorů Dev + český překryv
        var bt = sch.Operace("base_texture");
        T.Je(bt is { Zastupna: false } && S(bt.Params.Select(p => p.Nazev + "=" + p.Vychozi)) == "layer=albedo,scalePermille=1000,offsetEnabled=true,tintPermille=0,rotate90=false"
             && bt.Params.All(p => !p.BezPrekryvu) && bt.Nazev == "Podkladová dlaždice", "base_texture: layer, scale 1000, offset true, tint 0, rotate90 false – z Dev, český překryv");
        T.Je(bt!.Params.Single(p => p.Nazev == "offsetEnabled").Druh == DruhParametruVpmg.Prepinac && bt.Params.Single(p => p.Nazev == "scalePermille") is { Min: 250, Max: 4000 },
            "bool parametry Dev → přepínač, scalePermille 250..4000");
        T.Je(sch.Operace("tile_sample")!.AliasOf == "base_texture" && sch.Operace("palette_map")!.Params.Any(p => p.Nazev == "mixPermille" && p.Min == 0 && p.Max == 1000),
            "alias tile_sample → base_texture; palette_map.mixPermille 0..1000");
        T.Je(sch.Nesoulad.Count == 0, "překryv ↔ Dev bez nesouladu: " + S(sch.Nesoulad));

        // receptury v2 vzorku (N8)
        T.Je(S(kn.Zaznamy.Select(z => z.MaterialId)) == "1,2,3,5,6" && kn.DevCommit == api.Pin.Commit && kn.Zaznamy.All(z => z.ZdrojDev.EndsWith("-v2.json")),
            "receptury vzorku 1,2,3,5,6 = v2 z pinu Dev");
        T.Je(kn.Zaznamy.All(z => z.Soubor == $"{z.MaterialId}.json" && kn.ShaSouboru(z) == z.Sha256), "receptury/<materialId>.json, SHA = index");
        if (!Directory.Exists(devKoren)) { T.Je(false, "připnutý Dev chybí: " + devKoren); return; }
        T.Je(kn.Zaznamy.All(z => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(devKoren, z.ZdrojDev)))).ToLowerInvariant() == z.Sha256),
            "kopie receptur v2 = fixture Dev v pinu bajt po bajtu");
        T.Je(kn.Zaznamy.All(z => V2[Path.GetFileName(z.ZdrojDev)] == z.GoldenChecksum), "golden v indexu = goldeny v2 backendu");
        T.Je(kn.Zaznamy.All(z => z.Receptura.Kroky[0].Type == "base_texture" && z.Receptura.Kroky.Any(x => x.Type == "palette_map" && x.Params["mixPermille"] == "200")),
            "receptury v2: první krok base_texture, palette_map mix 200 ‰");
        T.Je(kn.Zaznamy.All(z => RecepturyVpmg.Validuj(z.Receptura, sch, k).Count == 0), "receptury v2 platné proti schématu: " + S(kn.Zaznamy.SelectMany(z => RecepturyVpmg.Validuj(z.Receptura, sch, k))));

        // dlaždice: katalog (zrcadlo) baseTile = dlaždice klienta data/vpmg/zaklady = soubory Dev Data/tiles
        var zak = api.Zaklady;
        var prof = api.Vzorek.Materialy.Select(m => (m.Id, Bt: k.Material(m.Id)!.Profily["default"].BaseTile)).ToList();
        T.Je(prof.All(p => p.Bt is { Format: "rgba8", WidthPx: 128, HeightPx: 128 }) && k.Material(52)!.Profily["default"].BaseTile is null, "baseTile 128×128 rgba8 u 5 materiálů vzorku, 52 bez dlaždice");
        T.Je(prof.All(p => zak.PodleSha(p.Bt!.Sha256) is { } z && z.MaterialId == p.Id), "SHA baseTile = dlaždice klienta data/vpmg/zaklady (5/5)");
        T.Je(prof.All(p => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(devKoren, "src/Modules/World/Willage.World.Materials/Data", p.Bt!.Asset)))).ToLowerInvariant() == p.Bt.Sha256),
            "soubory Dev Data/tiles/*.rgba8 = SHA baseTile (5/5)");
        T.Je(zak.Dlazdice.All(z => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(z.Cesta))).ToLowerInvariant() == z.PngSha256), "PNG v data/vpmg/zaklady = pngSha256 manifestu (bez převodu konců řádků)");

        // nástroj + fasáda
        var zd = (ZdrojVpmgProces)api.Zdroj;
        if (!zd.Dostupny) { T.Je(false, "nástroj VPMG chybí: " + zd.Popis); return; }
        var g = zd.Goldeny();
        var g2 = g.Where(x => x.Soubor.EndsWith("-v2.json")).ToList();
        T.Je(g2.Count == 5 && g2.All(x => x.Ocekavany == x.Spocteny && V2[x.Soubor] == x.Ocekavany), "goldeny v2 přes nástroj 5/5: " + S(g2.Select(x => x.Spocteny)));
        T.Je(g.Count == 15 && g.All(x => x.Ocekavany == x.Spocteny), $"všechny goldeny receptur Dev přes nástroj ({g.Count(x => x.Ocekavany == x.Spocteny)}/{g.Count})");
        var fas = kn.Zaznamy.Select(r => (r.MaterialId, Ch: zd.Spust(r.Receptura, r.GoldenSeed).Checksum, r.GoldenChecksum)).ToList();
        T.Je(fas.All(x => x.Ch == x.GoldenChecksum), "goldeny v2 5 materiálů přes fasádu (receptury/ + zrcadlo + dlaždice Dev): " + S(fas.Select(x => $"{x.MaterialId}={x.Ch}")));
        T.Je(zd.Golden() is (1756279408u, 1756279408u), "legacy golden 52 = 1756279408");

        // návrh profilu nesmí ztratit baseTile; base_texture sám = dlaždice (posun)
        var r1 = kn.Zaznam(1)!.Receptura;
        var tn = zd.Spust(r1, 0xC0FFEE00u, new NavrhProfiluDto(Palette: new[] { "#112233", "#445566", "#778899" }));
        T.Je(tn.Ok && tn.Checksum != fas[0].Ch, "návrh palety nad receptou v2 (base_texture) projde a výstup změní – baseTile zůstává (" + (tn.Chyba ?? "ok") + ")");
        var jen = r1 with { Resolution = 128, Kroky = r1.Kroky.Take(1).Select(x => x with { Params = new Dictionary<string, string>(x.Params) { ["tintPermille"] = "0" } }).ToList() };
        var t0 = zd.Spust(jen, 0xC0FFEE00u);
        var dl = ZakladRgba(zak.Dlazdice.Single(x => x.MaterialId == 1).Cesta, prof[0].Bt!.Sha256, devKoren);
        T.Je(t0.Ok && JePosunem(t0.Rgba, dl, 128), "base_texture bez tintu, 128 px = dlaždice jen toroidálně posunutá");

        // přepínač offsetEnabled přes stav editoru (stejná cesta jako okno)
        var st = new StavEditoru(k, sch, api.Vzorek, receptury: kn);
        T.Je(st.NastavParametrKroku(0, "offsetEnabled", "ano") != null && st.NastavParametrKroku(0, "offsetEnabled", "false") == null, "offsetEnabled: 'ano' odmítnuto, 'false' přijato");
        var tOff = zd.Spust(st.Receptura, 0xC0FFEE00u);
        Console.WriteLine($"  offset false: {tOff.Checksum} vs golden {fas[0].Ch}; json {RecepturyVpmg.DoJson(st.Receptura)[..200]}");
        T.Je(tOff.Ok && tOff.Checksum != fas[0].Ch, "offsetEnabled false → jiný výstup než golden (fasáda)");

        // variace seedu (editor: seed + i·7919): liší se, ale hlavně posunem – tint je pevný v receptuře
        foreach (var r in kn.Zaznamy)
        {
            var rr = r.Receptura with { Resolution = 128 };
            var tx = Enumerable.Range(1, 4).Select(i => zd.Spust(rr, unchecked(0xC0FFEE00u + (uint)i * 7919u))).ToList();
            var prumery = tx.Select(t => Prumer(t.Rgba)).ToList();
            double rozptyl = prumery.Max(p => prumery.Max(q => Math.Abs(p - q)));
            Console.WriteLine($"  variace {r.MaterialId}: {S(tx.Select(t => t.Checksum))}; rozdíl průměrného jasu mezi seedy {rozptyl:F1}");
            T.Je(tx.Select(t => t.Checksum).Distinct().Count() == 4 && rozptyl < 6, $"variace {r.MaterialId}: 4 různé výstupy, průměrný jas se liší < 6 (tint pevný)");
        }
    }

    static double Prumer(byte[] rgba) { long s = 0; for (int i = 0; i < rgba.Length; i += 4) s += rgba[i] + rgba[i + 1] + rgba[i + 2]; return s / (rgba.Length / 4 * 3.0); }

    /// <summary>RGBA8 dlaždice: soubor Dev Data/tiles (SHA ověřené v testu výš).</summary>
    static byte[] ZakladRgba(string png, string sha, string devKoren)
    {
        var p = Directory.GetFiles(Path.Combine(devKoren, "src/Modules/World/Willage.World.Materials/Data/tiles"), "*.rgba8")
            .First(f => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(f))).ToLowerInvariant() == sha);
        return File.ReadAllBytes(p);
    }

    static bool JePosunem(byte[] a, byte[] b, int n)
    {
        for (int oy = 0; oy < n; oy++)
            for (int ox = 0; ox < n; ox++)
            {
                bool ok = true;
                for (int y = 0; y < n && ok; y++)
                    for (int x = 0; x < n; x++)
                    {
                        int i = (y * n + x) * 4, j = (((y + oy) % n) * n + (x + ox) % n) * 4;
                        if (a[i] != b[j] || a[i + 1] != b[j + 1] || a[i + 2] != b[j + 2]) { ok = false; break; }
                    }
                if (ok) return true;
            }
        return false;
    }
}
