using System.Text.Json;
using Willage.Gen.Jadro;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;
using Willage.Gen.Testy;

string data = Path.Combine(AppContext.BaseDirectory, "Data");
var kat = KatalogMaterialu.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
var pr = new Propustnost(kat);

// G-5: rychlé ladění jedné sady (--jen=G5); plný běh bez argumentu.
var jen = args.FirstOrDefault(a => a.StartsWith("--jen="))?[6..];
if (jen == "GEO2B")
{
    // blok 128 m: GEO2 × stará cesta a výkon (není v celé sadě, trvá déle); --blok=ox,oy volitelně
    var bo = args.FirstOrDefault(a => a.StartsWith("--blok="))?["--blok=".Length..].Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray() ?? new[] { 0.0, 0.0 };
    TestyGeo2K1b.Blok(data, bo[0], bo[1], Environment.ProcessorCount, bo.Length > 2 ? bo[2] : 1.0, bo.Length > 3 ? bo[3] : 0.5);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K3B")
{
    // blok 128 m: stará cesta × GEO2 před K3 × GEO2 K3, bitová shoda a výkon; --blok=ox,oy[,krokXy[,krokMrizky[,vlaken]]]
    var bo = args.FirstOrDefault(a => a.StartsWith("--blok="))?["--blok=".Length..].Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray() ?? new[] { 1024.0, 512.0 };
    TestyGeo2K3.Blok(data, bo[0], bo[1], bo.Length > 4 ? (int)bo[4] : Environment.ProcessorCount, bo.Length > 2 ? bo[2] : 0.25, bo.Length > 3 ? bo[3] : 0.5);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K5B")
{
    // blok 128 m: adaptivní × pevná mřížka hranic, výkon; --blok=ox,oy[,krokXy[,vlaken]]
    var bo = args.FirstOrDefault(a => a.StartsWith("--blok="))?["--blok=".Length..].Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray() ?? new[] { 1024.0, 512.0 };
    TestyGeo2K5.Blok(data, bo[0], bo[1], bo.Length > 3 ? (int)bo[3] : Environment.ProcessorCount, bo.Length > 2 ? bo[2] : 0.5);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K5S")
{
    var g5 = new Willage.Gen.Geologie.GeologieCs(new Willage.Gen.Svet.ParametrySveta(), Willage.Gen.Data.DataSveta.Najdi(AppContext.BaseDirectory));
    foreach (var b in TestyGeo2K5.StrmeBloky(g5.Svet, 10)) Console.WriteLine($"{b.X},{b.Y}: {b.N}");
    return 0;
}
if (jen == "GEO2V8R")
{
    TestyGeo2V8.RegreseSopka(data);
TestyGeo2V8.RegreseSkarnJine(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2V8L")
{
    var bo = args.First(a => a.StartsWith("--blok="))["--blok=".Length..].Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray();
    Willage.Gen.Testy.V8.V8Ladeni.Sloupec(data, bo[0], bo[1], bo[2], bo[3]);
    return 0;
}
if (jen == "GEO2V8")
{
    // V8: rozdíly GEO2 × GEO1 po kategoriích; --seedy=49,7,100 (výchozí 49); --blok=ox,oy[,krokXy[,vlaken]] jen jeden blok; --csv=cesta nebo adresář
    string? A(string k) => args.FirstOrDefault(a => a.StartsWith(k))?[k.Length..];
    var bo = A("--blok=")?.Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray();
    var seedy = (A("--seedy=") ?? A("--seed="))?.Split(',').Select(long.Parse).ToArray();
    TestyGeo2V8.Spust(data, bo is { Length: >= 2 } ? bo : null, bo is { Length: > 2 } ? bo[2] : 0.25, bo is { Length: > 3 } ? (int)bo[3] : Environment.ProcessorCount, A("--csv="), seedy);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K6")
{
    TestyGeo2K6.Spust(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K5")
{
    TestyGeo2K5.Spust(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K4B")
{
    // blok 128 m: K3 (Bod po buňkách) × K4 (běhy + raster), rozdíly a výkon; --blok=ox,oy[,krokXy[,vlaken[,krokZ]]]
    var bo = args.FirstOrDefault(a => a.StartsWith("--blok="))?["--blok=".Length..].Split(',').Select(v => double.Parse(v, System.Globalization.CultureInfo.InvariantCulture)).ToArray() ?? new[] { 1024.0, 512.0 };
    TestyGeo2K4.Blok(data, bo[0], bo[1], bo.Length > 3 ? (int)bo[3] : Environment.ProcessorCount, bo.Length > 2 ? bo[2] : 0.25, bo.Length > 4 ? bo[4] : 0.25);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K4")
{
    TestyGeo2K4.Spust(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2K3")
{
    TestyGeo2K3.Spust(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen == "GEO2")
{
    TestyGeo2K1.Spust(data);
    TestyGeo2K1b.Spust(data);
    TestyGeo2K2.Spust(data);
    TestyGeo2K3.Spust(data);
    TestyGeo2K4.Spust(data);
    TestyGeo2K5.Spust(data);
    TestyGeo2K6.Spust(data);
    TestyGeo2V8.RegreseSopka(data);
TestyGeo2V8.RegreseSkarnJine(data);
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}
if (jen is "G5" or "G6" or "G7")
{
    if (jen == "G5") TestyG5.Spust(); else if (jen == "G6") TestyG6.Spust(); else TestyG7.Spust();
    Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
    return T.Chyb == 0 ? 0 : 1;
}

T.Sekce("hash: golden vectors Willage_Dev (zrcadlo HashInt3)");
using (var g = JsonDocument.Parse(File.ReadAllText(Path.Combine(data, "geology-hash-golden-v1.json"))))
{
    foreach (var v in g.RootElement.GetProperty("vectors").EnumerateArray())
    {
        uint seed = Convert.ToUInt32(v.GetProperty("seed").GetString(), 16), exp = Convert.ToUInt32(v.GetProperty("hash").GetString(), 16);
        T.Je(GeologyHash.HashInt3(v.GetProperty("x").GetInt32(), v.GetProperty("y").GetInt32(), v.GetProperty("z").GetInt32(), seed) == exp, "HashInt3 " + v);
    }
    foreach (var v in g.RootElement.GetProperty("deriveVectors").EnumerateArray())
        T.Je(GeologyHash.DeriveSeed(v.GetProperty("seed").GetUInt32(), v.GetProperty("salt").GetInt32()) == Convert.ToUInt32(v.GetProperty("hash").GetString(), 16), "DeriveSeed");
    foreach (var v in g.RootElement.GetProperty("hashStringVectors").EnumerateArray())
        T.Je(GeologyHash.HashString(v.GetProperty("text").GetString()) == Convert.ToUInt32(v.GetProperty("hash").GetString(), 16), "HashString");
}

T.Sekce("katalog a propustnost 1.8.1 (X = K × 0,0625 m² × 1000)");
T.Je(kat.Pocet == 75, $"katalog 75 záznamů ({kat.Pocet})");
T.Blizko(pr.X(3), 0.00625, 1e-12, "písek K 1e-4 → 0,00625 l/s");
T.Blizko(pr.X(1), 0.000625, 1e-12, "tráva K 1e-5 → 0,000625 l/s");
T.Je(pr.Rozhrani(3, 1) == pr.X(1), "rozhraní = minimum");
T.Je(pr.Teleso(3) && pr.Teleso(5) && pr.Teleso(44) && !pr.Teleso(6) && !pr.Teleso(4) && !pr.Teleso(12), "těleso: písek, vápence ano; žula, jíly ne");
T.Je(double.IsPositiveInfinity(pr.X(0)), "vzduch = otevřená stěna");

T.Sekce("výkon pramene, příklady 1.8");
var kat2 = new KatalogMaterialu("""{"materials":[{"id":6,"key":"granite","geology":{"permeabilityMs":1e-12}},{"id":99,"key":"x","geology":{"permeabilityMs":0.016}}]}""");
var pr2 = new Propustnost(kat2);
T.Blizko(pr2.X(99), 1.0, 1e-12, "buňka 1 l/s");
T.Blizko(VykonPramene.Spocti(10, new[] { 6, 6, 6, 6, 6, 99 }, pr2, false, 0).Vykon, 1.0, 1e-6, "žula + jedna buňka 1 l/s → 1 l/s");
T.Je(VykonPramene.Spocti(10, new[] { 0, 6, 6, 6, 6, 99 }, pr2, false, 0).Vykon == 10, "odkopáno → jmenovitý 10 l/s");
T.Je(VykonPramene.Spocti(10, new[] { 6, 6, 6, 6, 6, 6 }, pr2, false, 0).Vykon < 1e-9, "ucpáno žulou → ~0");
var tl = VykonPramene.Spocti(10, new[] { 6, 6, 6, 6, 6, 99 }, pr2, true, 10);
T.Blizko(tl.Vykon, 10, 1e-6, "tlakový: strop 10 m → spád 10 → 10 l/s"); T.Blizko(tl.TlakovaVyskaM, 2.25, 1e-9, "Ht 2,25 m");
T.Blizko(VykonPramene.Spocti(10, new[] { 6, 6, 6, 6, 6, 99 }, pr2, true, 0.5).Vykon, 3.0, 1e-9, "tlakový: strop 0,5 m → spád 3 → 3 l/s");

T.Sekce("profil sloupce (syntetický)");
var syn = new SyntetickaGeologie { Pov = (x, y) => 23.0 };
var prof = ProfilSloupce.Spocti(syn.Sloupec(0, 0), 23.0, 18.0, pr, 0.5);
T.Je(prof.Nasyceno == new Interval(14, 18), $"volná hladina 14–18 ({prof.Nasyceno})");
T.Je(prof.Zavesena.Count == 1 && prof.Zavesena[0] == new Interval(21, 21.5), $"zavěšená 21–21,5 ({string.Join(",", prof.Zavesena)})");
T.Je(prof.Sevrene.Count == 1 && prof.Sevrene[0] == new SevrenaVrstva(10, 12, 52), $"sevřená pískovec 10–12 ({string.Join(",", prof.Sevrene)})");
var prof2 = ProfilSloupce.Spocti(syn.Sloupec(0, 0), 23.0, 13.0, pr, 0.5);
T.Je(prof2.HladinaVTesneni && prof2.Nasyceno is null, "hladina v jílu → bez volné vody");

T.Sekce("hladina: spojitost a nezávislost na bloku (syntetický povrch)");
var p = new ParametryVody();
var gA = new SyntetickaGeologie(); var gB = new SyntetickaGeologie();
var fA = new PodzemniVodaFn(gA, kat, p); var fB = new PodzemniVodaFn(gB, kat, p);
fA.Blok(0, 0, 2, false); var bB = fB.Blok(1, 0, 2, false);
int neshod = 0; double maxSkok = 0;
for (double y = 0.5; y < 128; y += 1)
{
    if (fA.Hladina.Hladina(128, y) != fB.Hladina.Hladina(128, y)) neshod++;
    maxSkok = Math.Max(maxSkok, Math.Abs(fA.Hladina.Hladina(128 - 1e-6, y) - fB.Hladina.Hladina(128 + 1e-6, y)));
}
T.Je(neshod == 0, $"šev x = 128 m: {neshod} neshod mezi instancemi");
T.Je(maxSkok < 1e-4, $"skok přes šev {maxSkok:E2} m");
int nad = 0; for (int k = 0; k < bB.L.Length; k++) if (bB.L[k] > bB.Povrch[k]) nad++;
T.Je(nad == 0, "L ≤ povrch");
var sA = fA.Prameny.VOblasti(128, 0, 256, 128); var sB = fB.Prameny.VOblasti(128, 0, 256, 128);
T.Je(sA.SequenceEqual(sB), $"prameny bloku nezávislé na pořadí výpočtu ({sA.Count} vs {sB.Count})");

TestyKrok05.Spust(kat, pr);
TestyKrok06.Spust();
TestyKrok06b.Spust();
TestyKrok06c.Spust();
TestyKrok06d.Spust();
TestyKrok06e.Spust();
TestyKrok06f.Spust();
TestyKrok06g.Spust();
TestyKrok07.Spust(kat);
TestyKrok07c.Spust(kat);
TestyPrusak.Spust();
TestyPrusakPobrezi.Spust();
TestyPrusakKras.Spust();
TestyG1.Spust();
TestyG2.Spust();
TestyG3.Spust();
TestyG4.Spust();
TestyG5.Spust();
TestyG6.Spust();
TestyG7.Spust();
TestyGeo2K1.Spust(data);
TestyGeo2K1b.Spust(data);
TestyGeo2K2.Spust(data);
TestyGeo2K3.Spust(data);
TestyGeo2K4.Spust(data);
TestyGeo2K5.Spust(data);
TestyGeo2K6.Spust(data);
TestyGeo2V8.RegreseSopka(data);
TestyGeo2V8.RegreseSkarnJine(data);

Console.WriteLine($"OK {T.Ok}, chyb {T.Chyb}");
return T.Chyb == 0 ? 0 : 1;
