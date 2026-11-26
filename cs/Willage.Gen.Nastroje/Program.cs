using Willage.Gen.Data;
using Willage.Gen.Nastroje;

var data = DataSveta.Najdi(AppContext.BaseDirectory);
args = ErozeNastroj.Volby(args);
ErozeNastroj.D = data;
string cmd = args.Length > 0 ? args[0] : "";
return cmd switch
{
    "vyska" => PorovnejVysku.Spust(args[1], data) == 0 ? 0 : 1,
    "det3" => Det3(args, data),
    "voda" => Voda(args, data),
    "sevy" => Sevy(args, data),
    "rez" => Rez(args, data),
    "sopka" => Sopka(data),
    "pobrezi" => args[1] switch
    {
        "tabulka" => PobrezniNastroj.Tabulka(data),
        "brehy" => PobrezniNastroj.Brehy(args, data),
        "vliv" => PobrezniNastroj.Vliv(args, data),
        _ => Napoveda(),
    },
    "prusak" => PrusakSimulace.Spust(data, args.Length > 1 ? args[1] : "vystup-prusak"),
    "prameny" => Prameny(data),
    "manifest" => Manifest(args, data),
    "moduly" => Moduly(data),
    "schema" => Schema(args, data),
    "api" => Api(args, data),
    "nahled" => Nahled(args, data),
    "cas" => Cas(args, data),
    "par" => Paralelne.Spust(data, args.Contains("--puvodni"), args.Skip(1).Where(s => int.TryParse(s, out _)).Select(int.Parse).DefaultIfEmpty(1).ToArray()) == 0 ? 0 : 1,
    "klima" => args[1] switch
    {
        "mapa" => KlimaNastroj.Mapa(args, data),
        "otisky" => KlimaNastroj.Otisky(args, data),
        "prameny" => KlimaNastroj.Prameny(args, data),
        _ => Napoveda(),
    },
    "eroze" => args[1] switch
    {
        "svetmax" => ErozeNastroj.SvetMax(data),
        "mapa" => ErozeNastroj.Mapa(args, data),
        "otisky" => ErozeNastroj.Otisky(args, data),
        "detail" => ErozeNastroj.Detail(args, data),
        "prameny" => ErozeNastroj.PramenyDiag(args, data),
        "interp" => ErozeNastroj.InterpMer(args, data),
        "vse" => ErozeNastroj.Vse(args, data),
        "rez" => ErozeNastroj.Rez(args, data),
        _ => Napoveda(),
    },
    _ => Napoveda(),
};

static int Napoveda() { Console.WriteLine("použití: vyska <bin>"); return 2; }

/// G-1: manifest katalogů – „manifest“ zapíše data/manifest_katalogu_v1.json, „manifest --kontrola“ jen porovná.
static int Manifest(string[] a, Willage.Gen.Data.DataSveta d)
{
    var m = Willage.Gen.Katalogy.ManifestKatalogu.Spocti(d);
    string f = Path.Combine(d.Koren, Willage.Gen.Katalogy.ManifestKatalogu.NazevSouboru);
    if (a.Contains("--kontrola"))
    {
        var r = File.Exists(f) ? Willage.Gen.Katalogy.ManifestKatalogu.ZJson(File.ReadAllText(f)).Rozdily(m) : new[] { "(chybí " + f + ")" };
        Console.WriteLine(r.Count == 0 ? $"manifest aktuální: {m.Polozky.Count} souborů, souhrn {m.Souhrn}" : "rozdíly: " + string.Join(", ", r));
        return r.Count == 0 ? 0 : 1;
    }
    m.Uloz(d.Koren);
    Console.WriteLine($"manifest {f}: {m.Polozky.Count} souborů, souhrn {m.Souhrn}");
    return 0;
}

/// G-1: graf modulů a klíče výchozího světa (bez výpočtu).
static int Moduly(Willage.Gen.Data.DataSveta d)
{
    var pl = new Willage.Gen.Pipeline.PipelineSveta(d);
    var k = pl.Klice(new Willage.Gen.Svet.ParametrySveta());
    foreach (var m in pl.Graf.Poradi)
        Console.WriteLine($"{m.Id} {m.Nazev,-18} v{m.VerzeAlgoritmu} ← [{string.Join(",", m.Zavislosti)}] soubory [{string.Join(", ", m.Soubory)}] klíč {k[m.Id][..16]}");
    return 0;
}

/// G-2: schéma parametrů – „schema [soubor.json]“ zapíše JSON (bez souboru jen souhrn); „schema --kontrola soubor.json“ porovná.
static int Schema(string[] a, Willage.Gen.Data.DataSveta d)
{
    var s = Willage.Gen.Schema.SchemaParametru.Sestav(d);
    string json = s.ToJson();
    foreach (var g in s.Parametry.GroupBy(p => p.Modul).OrderBy(g => g.Key))
        Console.WriteLine($"{g.Key}: {g.Count()} parametrů, skupiny {string.Join(", ", g.Select(p => p.Skupina).Distinct())}");
    Console.WriteLine($"celkem {s.Parametry.Count}, jen čtení {s.Parametry.Count(p => p.JenCteni)}, SHA256 {Willage.Gen.Katalogy.ManifestKatalogu.Sha(System.Text.Encoding.UTF8.GetBytes(json))[..16]}");
    var f = a.Skip(1).FirstOrDefault(x => !x.StartsWith("--"));
    if (f is null) return 0;
    if (a.Contains("--kontrola")) { bool ok = File.Exists(f) && File.ReadAllText(f).Replace("\r\n", "\n") == json; Console.WriteLine(ok ? "schéma aktuální" : "schéma se liší: " + f); return ok ? 0 : 1; }
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(f))!);
    File.WriteAllText(f, json);
    Console.WriteLine("zapsáno " + f);
    return 0;
}

/// G-3: přes fasádu – „api otisky [kes]“ (porovnat s „klima otisky“), „api moduly“, „api uloz soubor.wpln [kes]“, „api nacti soubor.wpln“.
static int Api(string[] a, Willage.Gen.Data.DataSveta d)
{
    string sub = a.Length > 1 ? a[1] : "otisky";
    string? kes = sub is "uloz" ? (a.Length > 3 ? a[3] : null) : (a.Length > 2 ? a[2] : null);
    var g = new Willage.Gen.Api.GeneratorSveta(d, kes);
    switch (sub)
    {
        case "moduly":
            foreach (var m in g.Moduly.Seznam()) Console.WriteLine($"{m.Id,-4} {m.Nazev,-30} v{m.Verze} {m.Stav,-9} parametrů {g.Moduly.Parametry(m.Id).Count,3} klíč {m.Klic[..16]}");
            return 0;
        case "otisky":
            var r = g.Sluzba.Generuj();
            var o = g.Sluzba.Otisky();
            Console.WriteLine($"api: mapa {o.Mapa}, vodníků {o.Vodniku}, voda {o.BlokX},{o.BlokY} {o.VodaBlok} ({o.Pramenu} pramenů), klima {o.Klima}, {r.Ms:F0} ms");
            return 0;
        case "uloz":
            g.Sluzba.Generuj();
            var i = g.Sluzba.Uloz(a[2]);
            Console.WriteLine($"uloženo {a[2]}: {new FileInfo(a[2]).Length} B, seed {i.Seed}, manifest {i.ManifestSouhrn[..16]}");
            return 0;
        case "nacti":
            var n = g.Sluzba.Nacti(a[2]);
            Console.WriteLine($"načteno {a[2]}: gen {n.GenVer}, seed {n.Seed}, potvrzena {n.Potvrzena}, rozdíly dat [{string.Join(", ", n.RozdilyDat)}], neplatné moduly [{string.Join(", ", n.NeplatneModuly)}]");
            return 0;
        default: return Napoveda();
    }
}

/// G-6: náhledy M1–M3 přes fasádu – „nahled porovnej-rez rez_opravy.bin [kes]“ porovná řez M3 s výstupem nástroje „rez“ bajt po bajtu,
/// „nahled otisky [kes]“ vypíše SHA (16 hex) všech vrstev náhledu 256×256 (M6 128×128) (pro porovnání mezi větvemi / s Godot náhledem).
/// G-7: „nahled porovnej-rez-vody bin x0 y0 ux uy [kes]“ – řez M6 proti „eroze rez“; „nahled planeta [kes]“ – čísla M4–M6 a tabulka pásem.
static int Nahled(string[] a, Willage.Gen.Data.DataSveta d)
{
    string sub = a.Length > 1 ? a[1] : "otisky";
    string? kes = sub == "porovnej-rez" ? (a.Length > 3 ? a[3] : null) : sub == "porovnej-rez-vody" ? (a.Length > 7 ? a[7] : null) : (a.Length > 2 ? a[2] : null);
    var g = new Willage.Gen.Api.GeneratorSveta(d, kes);
    g.Sluzba.Generuj();
    var C = System.Globalization.CultureInfo.InvariantCulture;
    if (sub == "porovnej-rez-vody")
    {
        // G-7: nahled porovnej-rez-vody <eroze_rez.bin> <x0> <y0> <ux> <uy> [kes] – řez M6 proti nástroji „eroze rez“ (materiály, povrch, surová hladina)
        double x0 = double.Parse(a[3], C), y0 = double.Parse(a[4], C), ux = double.Parse(a[5], C), uy = double.Parse(a[6], C);
        double nrm = Math.Sqrt(ux * ux + uy * uy); ux /= nrm; uy /= nrm;
        using var r = new BinaryReader(File.OpenRead(a[2]));
        int nx = r.ReadInt32(), nz = r.ReadInt32(); double krok = r.ReadDouble();
        var rez = g.Nahledy.Rez("M6", Willage.Gen.Api.Dto.SouradniceQ16.ZMetru(x0, y0), Willage.Gen.Api.Dto.SouradniceQ16.ZMetru(x0 + nx * krok * ux, y0 + nx * krok * uy), krok);
        int bunek = 0, povrch = 0, hladina = 0; double maxPov = 0, maxHl = 0;
        if (rez.Nx != nx) Console.WriteLine($"počet vzorků se liší: nástroj {nx}, náhled {rez.Nx}");
        for (int i = 0; i < Math.Min(nx, rez.Nx); i++)
        {
            double pv = r.ReadDouble(), hl = r.ReadDouble(); r.ReadDouble();
            var sl = r.ReadBytes(nz);
            if (BitConverter.DoubleToInt64Bits(pv) != BitConverter.DoubleToInt64Bits(rez.PovrchM[i])) { povrch++; maxPov = Math.Max(maxPov, Math.Abs(pv - rez.PovrchM[i])); }
            double h2 = rez.HladinaPodzemniM![i];
            if (BitConverter.DoubleToInt64Bits(hl) != BitConverter.DoubleToInt64Bits(h2)) { hladina++; if (!double.IsNaN(hl) && !double.IsNaN(h2)) maxHl = Math.Max(maxHl, Math.Abs(hl - h2)); }
            for (int k = 0; k < nz; k++) if (sl[k] != rez.Material(i, k)) bunek++;
        }
        Console.WriteLine(FormattableString.Invariant($"řez M6 od ({x0}, {y0}) směr ({ux:F3}, {uy:F3}): {nx}×{nz} buněk, rozdílných buněk {bunek}, povrchů {povrch} (max {maxPov:G3} m), hladin {hladina} (max {maxHl:G3} m); pramenů u řezu {rez.Body!.Count}; náhled {rez.Ms:F0} ms"));
        // řady M5 (teplota, srážky, w, biom) a M4 (eroze) proti CSV nástroje (přesnost výpisu: F3, F2, F4, F3)
        int rad = 0; var csv = File.ReadAllLines(Path.ChangeExtension(a[2], ".csv")).Skip(1).Select(l => l.Split(',')).ToArray();
        var r5 = g.Nahledy.Rez("M5", rez.Od, rez.Do, krok); var r4 = g.Nahledy.Rez("M4", rez.Od, rez.Do, krok);
        for (int i = 0; i < Math.Min(csv.Length, r5.Nx); i++)
        {
            double P(int c) => double.Parse(csv[i][c], C);
            if (Math.Abs(P(7) - r5.Rady!["teplota_c"][i]) > 6e-4 || Math.Abs(P(8) - r5.Rady["srazky_mm"][i]) > 6e-3 || Math.Abs(P(9) - r5.Rady["w"][i]) > 6e-5
                || (int)P(10) != (int)r5.Rady["biom"][i] || Math.Abs(P(12) - r4.Rady!["eroze_m"][i]) > 6e-4) rad++;
        }
        Console.WriteLine($"řady M5 / M4 proti CSV nástroje: rozdílných vzorků {rad} z {csv.Length} (M5 {r5.Ms:F0} ms, M4 {r4.Ms:F0} ms)");
        return bunek + povrch + hladina + rad == 0 ? 0 : 1;
    }
    if (sub == "planeta")
    {
        // G-7: souhrnná čísla M4–M6 (porovnat s „klima mapa“) a tabulka pásem
        foreach (var (m, v) in new[] { ("M4", Willage.Gen.Api.Dto.VrstvaNahleduDto.PosunEroze), ("M5", Willage.Gen.Api.Dto.VrstvaNahleduDto.BiomKlimatu), ("M6", Willage.Gen.Api.Dto.VrstvaNahleduDto.Hladina) })
        {
            var n = g.Nahledy.Mapa(m, v, m == "M6" ? 128 : 256);
            Console.WriteLine($"{m} {n.Popis}\n   " + string.Join(", ", n.Cisla.Select(c => FormattableString.Invariant($"{c.Key} {c.Value:0.###}"))) + $" · bodů {n.Body?.Count ?? 0} · {n.Ms:F0} ms");
        }
        foreach (var p in g.Nahledy.TabulkaPasem())
            Console.WriteLine(FormattableString.Invariant($"pásmo {p.Nazev,-9} podíl {p.Podil:0.##} T {p.TOdC}→{p.TDoC} K {p.SrazkyK} vítr {p.Vitr:+0;-0} u {p.UOd:0.###}…{p.UDo:0.###} pevnina {100 * p.PodilPevniny:F1} % T {p.TPrumerC:F1} P {p.PPrumerMm:F0} w {p.WPrumer:F2} hlavní {p.HlavniBiom} {100 * p.PodilHlavnihoBiomu:F1} %"));
        return 0;
    }
    if (sub == "porovnej-rez")
    {
        using var r = new BinaryReader(File.OpenRead(a[2]));
        int nx = r.ReadInt32(), nz = r.ReadInt32(); double x0 = r.ReadDouble(), y = r.ReadDouble();
        var rez = g.Nahledy.Rez("M3", Willage.Gen.Api.Dto.SouradniceQ16.ZMetru(x0, y), Willage.Gen.Api.Dto.SouradniceQ16.ZMetru(x0 + nx * 0.25, y), 0.25);
        int bunek = 0, povrch = 0;
        for (int i = 0; i < nx; i++)
        {
            double pv = r.ReadDouble(); r.ReadDouble();
            var sl = r.ReadBytes(nz);
            if (BitConverter.DoubleToInt64Bits(pv) != BitConverter.DoubleToInt64Bits(rez.PovrchM[i])) povrch++;
            for (int k = 0; k < nz; k++) if (sl[k] != rez.Material(i, k)) bunek++;
        }
        Console.WriteLine($"řez M3 x {x0}…{x0 + nx * 0.25}, y {y}: {nx}×{nz} buněk, rozdílných buněk {bunek}, rozdílných povrchů {povrch} (náhled {rez.Ms:F0} ms)");
        return bunek + povrch == 0 ? 0 : 1;
    }
    foreach (var m in g.Nahledy.Moduly())
        foreach (var v in g.Nahledy.Vrstvy(m))
        {
            var n = g.Nahledy.Mapa(m, v, m == "M6" ? 128 : 256);
            var b = new byte[n.Hodnoty.Length * 4]; Buffer.BlockCopy(n.Hodnoty, 0, b, 0, b.Length);
            Console.WriteLine($"{m}.{v,-16} {Willage.Gen.Katalogy.ManifestKatalogu.Sha(b)[..16]}  min {n.Cisla["min"]:F2} max {n.Cisla["max"]:F2}  {n.Ms:F0} ms");
        }
    return 0;
}

static int Det3(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var p = opravy ? new Willage.Gen.Svet.ParametrySveta() : Willage.Gen.Svet.ParametrySveta.Puvodni();
    if (a.Contains("--presny")) p.UtvaryKlicGd = false;
    if (a.Contains("--klic-gd")) p.UtvaryKlicGd = true;
    var (o, n, ms) = OtiskKrok3.Spocti(p, d);
    Console.WriteLine($"det3 {(opravy ? "opravy" : "puvodni")} klíč {(p.UtvaryKlicGd ? "gd" : "přesný")}: {o} {n} buněk, {ms:F0} ms");
    return 0;
}

static int Voda(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var (o, n, init, ms) = VodaBlok.Spust(opravy, d);
    Console.WriteLine($"voda {(opravy ? "opravy" : "puvodni")} blok 14,14: {o}, pramenů {n}, init {init:F0} ms, blok {ms:F0} ms");
    return 0;
}

static int Sevy(string[] a, Willage.Gen.Data.DataSveta d)
{
    string o = a.Length > 1 ? a[1] : "vystup";
    SevyMince.Spust(d, o);
    return 0;
}

static int Rez(string[] a, Willage.Gen.Data.DataSveta d)
{
    // rez <výstupní složka> [xs] [y] [pul]
    string o = a[1];
    double xs = a.Length > 2 ? double.Parse(a[2], System.Globalization.CultureInfo.InvariantCulture) : 2048.0;
    double y = a.Length > 3 ? double.Parse(a[3], System.Globalization.CultureInfo.InvariantCulture) : 1984.0;
    double pul = a.Length > 4 ? double.Parse(a[4], System.Globalization.CultureInfo.InvariantCulture) : 48.0;
    SevyMince.Rez(d, Path.Combine(o, "rez_puvodni.bin"), false, xs, y, pul);
    SevyMince.Rez(d, Path.Combine(o, "rez_opravy.bin"), true, xs, y, pul);
    return 0;
}

static int Sopka(Willage.Gen.Data.DataSveta d) { SopkaVoda.Spust(d); return 0; }

static int Prameny(Willage.Gen.Data.DataSveta d) { HustotaPramenu.Spust(d); return 0; }

static int Cas(string[] a, Willage.Gen.Data.DataSveta d) { Casy.Spust(d, a.Contains("--opravy"), a.Contains("--blok")); return 0; }
