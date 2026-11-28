using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;
using Willage.Gen.Testy.V8;

namespace Willage.Gen.Testy;

/// <summary>V8: rozdílová zpráva GEO2 × GEO1 po kategoriích (<c>--jen=GEO2V8</c>, volitelně <c>--blok=ox,oy[,krokXy]</c> jen jeden blok).</summary>
public static class TestyGeo2V8
{
    public static List<(string Kategorie, double X, double Y)> Kategorie(SvetFn s)
    {
        var l = new List<(string, double, double)>
        {
            ("náhodné", 1024, 512), ("náhodné", 3000, 2000), ("náhodné", 0, 0), ("náhodné", 2048, 1024), ("náhodné", 512, 3072),
            ("šev mince x = 1920", 1856, 1024), ("šev mince x = 2048", 1984, 2560),
            ("hornatina / strmé", 1664, 1728), ("hornatina / strmé", 3904, 1344),
        };
        var ss = s.Sopky.Seznam;
        if (ss.Count > 0)
        {
            var q = ss[0];
            l.Add(("svah sopky", Math.Floor(q.X + 0.4 * q.R - 64), Math.Floor(q.Y - 64)));
            l.Add(("okraj sopky", Math.Floor(q.X + q.R - 96), Math.Floor(q.Y - 64)));
        }
        return l;
    }

    /// <summary>Regrese nalezená V8: sopka – běhy + raster == Bod ve všech buňkách sloupců přes povrch kuželu (pruh [zPovKuz − 0,5; zPovKuz + 0,5], vč. proužku 0,05 m nad kuželem).</summary>
    public static void RegreseSopka(string data)
    {
        T.Sekce("GEO2 V8: sopka – raster z běhů == Bod u povrchu kuželu (regrese zlomu zPovKuz)");
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d); var q = g.Svet.Sopky.Seznam[0];
        double ox = Math.Floor(q.X + 0.4 * q.R - 64), oy = Math.Floor(q.Y - 64);
        var (k, r) = Willage.Gen.Geo2.E84.KontextBlokuE84.Sestav(g.Geo, kat, Willage.Gen.Geo2.E84.SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), null, 1);
        T.Je(r.Ok, "kontext s volcano");
        if (!r.Ok) return;
        var rnd = new Random(88); long bunek = 0, ruzne = 0; var v = new Vzorek[512];
        for (int i = 0; i < 4000; i++)
        {
            double x = ox + rnd.NextDouble() * 128, y = oy + rnd.NextDouble() * 128;
            var (bi, br2) = g.Geo.Sopky.Nejblizsi(x, y); if (bi < 0) continue;
            double zk = q.VyskaOkoli + g.Svet.Sopky.Kuzel(bi, Math.Sqrt(br2)), zp = k.Povrch(x, y);
            // výška buňky 0,0625 m kolem zPovKuz: proužek 0,05 m nad kuželem pokryje aspoň jeden střed
            double z0 = Math.Max(0, Math.Floor((zk - 0.5) * 16) / 16);
            k.Sloupec(x, y, z0, 0.0625, v.AsSpan(0, 16));
            for (int j = 0; j < 16; j++)
            {
                double z = z0 + (j + 0.5) * 0.0625; if (z > zp) continue;
                bunek++; if (v[j].Material != k.Chronologie.Vzorek(x, y, z, zp).Material) ruzne++;
            }
        }
        Console.WriteLine($"  buněk {bunek:N0}, raster ≠ Bod {ruzne:N0}");
        T.Je(bunek > 10_000 && ruzne == 0, "sopka: raster z běhů == Bod u povrchu kuželu");
    }

    /// <summary>
    /// Regrese `SkarnJine` (blok 3904, 1344): 2 buňky, kde GEO1 dává skarn, GEO2 karbonát. Příčina není chyba GEO2: v q′ = π + η·u (kontrakt 2.5, R5) je za bočním okrajem granitové plochy
    /// ortorula, `hostitel_okoli` selže. Test: obě buňky GEO1 skarn / GEO2 karbonát, klasifikace SkarnHostitelOkoli, a vzorek bloku po 2 m nemá otevřenou buňku.
    /// </summary>
    public static void RegreseSkarnJine(string data)
    {
        T.Sekce("GEO2 V8: SkarnJine – okraj plochy cíle, hostitel_okoli v q′ (regrese)");
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        double ox = 3904, oy = 1344;
        var bunky = new[] { (X: 3942.625, Y: 1378.875, Z: 37.125), (X: 3944.125, Y: 1382.125, Z: 37.375) };
        var (k, r) = Willage.Gen.Geo2.E84.KontextBlokuE84.Sestav(g.Geo, kat, Willage.Gen.Geo2.E84.SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), null, Environment.ProcessorCount);
        T.Je(r.Ok, "kontext bloku (3904, 1344)");
        if (!r.Ok) return;
        var c = k.Chronologie; int iu = c.IndexUdalosti("skarn_kontakt"); var kp = (KontaktniPasmo)c.Udalosti[iu].Kontakt!; int skarn = kat.PodleKlice("skarn")!.Id;
        var v = new Vzorek[512];
        foreach (var b in bunky)
        {
            var m1 = g.Geo.VyplnSloupec(b.X, b.Y, 0.25, 128); k.Sloupec(b.X, b.Y, 0, 0.25, v);
            int iz = (int)Math.Floor(b.Z / 0.25);
            double zp = k.Povrch(b.X, b.Y); var st = c.BodPred(iu, b.X, b.Y, b.Z, zp);
            bool je = kp.Nejblizsi(b.X, b.Y, b.Z, out var bp);
            bool plati = kp.Plati(b.X, b.Y, b.Z, st, c, iu, zp, out bool odhad);
            Console.WriteLine($"  ({b.X}, {b.Y}, {b.Z}): GEO1 {kat.PodleId(m1[iz])?.Klic}, GEO2 {kat.PodleId(v[iz].Material)?.Klic}, D {bp.D:F3}, odhad {odhad}, pásmo platí {plati}");
            T.Je(m1[iz] == skarn && v[iz].Material != skarn, $"buňka ({b.X}, {b.Y}, {b.Z}): GEO1 skarn, GEO2 ne");
            T.Je(je && !odhad && bp.D < 0.625 && !plati, $"buňka ({b.X}, {b.Y}, {b.Z}): D < 0,625 m bez odhadu, pásmo neplatí (selhává hostitel_okoli)");
            T.Je(v[iz].Material == c.Vzorek(b.X, b.Y, b.Z, zp).Material, $"buňka ({b.X}, {b.Y}, {b.Z}): raster == Bod");
        }
        while (V8Blok.Otevrene.TryTake(out _)) { }
        var s = V8Blok.Porovnej(g, kat, d, ox, oy, 2.0, Environment.ProcessorCount);
        var pc = s.PodlePriciny();
        Console.WriteLine($"  vzorek 2 m: buněk {s.Bunek:N0}, různých {s.Ruznych:N0}, otevřených {V8Blok.Otevrene.Count}");
        T.Je(V8Blok.Otevrene.IsEmpty, "vzorek bloku (3904, 1344) po 2 m: 0 otevřených buněk");
    }

    public static void Spust(string data, double[]? jedenBlok, double krokXy, int vlaken, string? csv)
    {
        T.Sekce($"GEO2 V8: rozdíly GEO2 × GEO1 po kategoriích (bloky 128 m, sloupce po {krokXy} m, z po 0,25 m, {vlaken} vláken)");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        var bloky = jedenBlok is null ? Kategorie(g.Svet) : new List<(string, double, double)> { ("zadaný", jedenBlok[0], jedenBlok[1]) };
        var podle = new Dictionary<string, V8Soucty>(); var poradi = new List<string>();
        foreach (var (nazev, x, y) in bloky)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var s = V8Blok.Porovnej(g, kat, d, x, y, krokXy, vlaken);
            if (!podle.TryGetValue(nazev, out var cil)) { podle[nazev] = cil = new V8Soucty(); poradi.Add(nazev); }
            cil.Slouc(s);
            Console.WriteLine($"  blok ({x}, {y}) [{nazev}]: {s.Bunek:N0} buněk, různých {s.Ruznych:N0} ({100.0 * s.Ruznych / s.Bunek:F4} %), {sw.Elapsed.TotalSeconds:F1} s");
        }
        foreach (var o in V8Blok.Otevrene.OrderBy(o => o.X).ThenBy(o => o.Y).ThenBy(o => o.Z).Take(50)) Console.WriteLine($"  otevřená buňka: x {o.X:F3}, y {o.Y:F3}, z {o.Z:F3}, {o.Pricina}");
        var vysl = poradi.Select(n => (n, podle[n])).ToList();
        V8Zprava.Vypis(vysl, kat);
        if (csv is not null) V8Zprava.Csv(csv, vysl);
        var vse = new V8Soucty(); foreach (var (_, s) in vysl) vse.Slouc(s);
        T.Je(vse.Bunek > 0 && vse.PodleVerdiktu().Values.Sum() == vse.Ruznych, "součet verdiktů = všechny různé buňky");
    }
}
