using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Jadro;
using Willage.Gen.Katalogy;
using Willage.Gen.Pipeline;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Planeta;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>G-3: fasáda Willage.Gen.Api (otisky přes fasádu, WPLN, potvrzení, dotazy, katalogy, zástupné části) a sladění s Dev Geology.Core G0.</summary>
public static class TestyG3
{
    static string S(IEnumerable<string> s) => string.Join(",", s);
    static bool Hodi<TE>(Action a) where TE : Exception { try { a(); return false; } catch (TE) { return true; } }

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        var tmp = Path.Combine(Path.GetTempPath(), "willage-g3-" + Environment.ProcessId);
        Directory.CreateDirectory(tmp);

        T.Sekce("G-3: zástupné moduly v grafu");
        var zakl = ModulySveta.Graf(); var se = ModulySveta.GrafSeZastupnymi();
        T.Je(S(se.Poradi.Select(m => m.Id)) == "M0,M1,M2,M3,M4,M5,M6,M6d,M7,M8,M9", "graf se zástupnými: " + S(se.Poradi.Select(m => m.Id)));
        T.Je(se.Poradi.OfType<ZastupnyModul>().Select(m => m.Id).SequenceEqual(new[] { "M6d", "M8", "M9" }) && se.Poradi.OfType<ZastupnyModul>().All(m => m.Nazev.Contains("zástupný") && m.VerzeAlgoritmu == 0 && m.Soubory.Count == 0),
            "zástupné M6d (7d), M8, M9: označené „zástupný“, verze 0, bez souborů");
        var zast = se.Poradi.OfType<ZastupnyModul>().Select(m => m.Id).ToHashSet();
        T.Je(zast.All(z => se.Zavisle(z).All(zast.Contains)), "žádný modul M0–M7 nezávisí na zástupném");
        var k8 = new PipelineSveta(data).Klice(new ParametrySveta()); var k11 = new PipelineSveta(data, se).Klice(new ParametrySveta());
        T.Je(k8.All(kv => k11[kv.Key] == kv.Value) && k11.Count == 11, "klíče M0–M7 se zástupnými = bez nich");

        T.Sekce("G-3: fasáda – moduly a parametry");
        var g = new GeneratorSveta(data, kes);
        var sez = g.Moduly.Seznam();
        T.Je(sez.Count == 11 && sez.Where(m => !m.Zastupny).All(m => m.Stav == StavModuluDto.Ceka) && sez.Where(m => m.Zastupny).All(m => m.Stav == StavModuluDto.Zastupny && m.Popis!.Length > 0),
            "před generací: 8 modulů čeká, 3 zástupné");
        T.Je(sez.Where(m => !m.Zastupny).All(m => m.Klic == k8[m.Id]), "klíče fasády = pipeline bez sady");
        int nPar = sez.Sum(m => g.Moduly.Parametry(m.Id).Count);
        T.Je(nPar == g.Stav.Schema.Parametry.Count && g.Moduly.Parametry("M2").Any(p => p.Id == "ParametrySveta.PodilMore" && p.Hodnota == p.Vychozi && p.Jednotka == "–"),
            $"parametry modulů = schéma G-2 ({nPar}), hodnota = výchozí");
        var nap = g.Moduly.Napoveda("ParametrySveta.PodilMore");
        T.Je(nap.Zastupny && nap.Text == "", "nápověda: zástupná, prázdný text");

        T.Sekce("G-3: otisky přes fasádu = CLI (9d4f2b8)");
        var r1 = g.Sluzba.Generuj();
        var o = g.Sluzba.Otisky();
        T.Je(o.Mapa == TestyKrok06d.GoldenMapaVychozi && o.Klima == "cb11da8d141a2a5e" && o.Vodniku == 86 && o.VodaBlok == "377a8210f82c856a",
            $"klima zap: mapa {o.Mapa}, klima {o.Klima}, vodníků {o.Vodniku}, voda 14,14 {o.VodaBlok}");
        T.Je(r1.Moduly.Where(m => !m.Zastupny).All(m => m.Stav is StavModuluDto.Spocitano or StavModuluDto.ZPameti) && r1.Souhrn.OtiskMapy == o.Mapa, "po generaci: moduly spočtené, souhrn = otisky");
        var r2 = g.Moduly.Prepocitej();
        T.Je(r2.Moduly.Where(m => !m.Zastupny).All(m => m.Stav == StavModuluDto.ZPameti), "opakovaný přepočet: vše z paměti");
        var gv = new GeneratorSveta(data, kes);
        var zm = gv.Moduly.Nastav("ParametrySveta.KlimaKrok07", "false");
        gv.Sluzba.Generuj(); var ov = gv.Sluzba.Otisky();
        T.Je(zm.Prijato && S(zm.Neplatne) == "M0,M1,M2,M3,M4,M5,M6,M6d,M7,M8,M9" && ov.Vodniku == 92 && ov.VodaBlok == "8e239a68c6d01be0" && ov.Klima is null && ov.Mapa == TestyKrok06d.GoldenMapaVychozi,
            $"klima vyp přes fasádu: vodníků {ov.Vodniku}, voda 14,14 {ov.VodaBlok}");

        T.Sekce("G-3: nastavení parametrů a potvrzení");
        var gz = new GeneratorSveta(data, kes);
        var z1 = gz.Moduly.Nastav("ParametryKlimatu.HladinaSuchoM", "2.5");
        T.Je(z1.Prijato && S(z1.Neplatne) == "M6,M6d,M7,M8,M9", "HladinaSuchoM → neplatné M6, M6d, M7, M8, M9: " + S(z1.Neplatne));
        T.Je(!gz.Moduly.Nastav("ParametrySveta.Podil", "[0.1]").Prijato && !gz.Moduly.Nastav("Neni.Nic", "1").Prijato && !gz.Moduly.Nastav("ParametrySveta.Seed", "\"x\"").Prijato,
            "odmítnuto: jen čtení, neznámý parametr, špatný typ");
        var z2 = gz.Moduly.Vychozi();
        T.Je(z2.Prijato && S(z2.Neplatne) == "M6,M6d,M7,M8,M9" && gz.Moduly.Seznam().Where(m => !m.Zastupny).All(m => m.Klic == k8[m.Id]), "Vychozi vrátí klíče");
        var pi = gz.Sluzba.PotvrdPlanetu();
        T.Je(pi.Potvrzena && !gz.Moduly.Nastav("ParametrySveta.Oktav", "5").Prijato && !gz.Moduly.Vychozi().Prijato, "po potvrzení jsou parametry zamčené");

        T.Sekce("G-3: soubor planety WPLN");
        string f1 = Path.Combine(tmp, "a.wpln"), f2 = Path.Combine(tmp, "b.wpln");
        var gs = new GeneratorSveta(data, kes);
        gs.Moduly.Nastav("ParametrySveta.PodilMore", "0.3"); gs.Moduly.Nastav("ParametryVody.FilmM", "0.4");
        var ui = gs.Sluzba.Uloz(f1);
        var gn = new GeneratorSveta(data, kes);
        var ni = gn.Sluzba.Nacti(f1);
        gn.Sluzba.Uloz(f2);
        T.Je(File.ReadAllBytes(f1).AsSpan().SequenceEqual(File.ReadAllBytes(f2)), $"uložit → načíst → uložit: bitově stejné ({new FileInfo(f1).Length} B)");
        T.Je(ni.RozdilyDat.Count == 0 && ni.NeplatneModuly.Count == 0 && S(gn.Moduly.Seznam().Select(m => m.Klic)) == S(gs.Moduly.Seznam().Select(m => m.Klic)) && ni.Seed == 49 && ni.GenVer == "V1.0",
            "načtená planeta: stejné klíče, data beze změny, seed 49, gen V1.0");
        var pl = SouborPlanety.Nacti(f1);
        T.Je(SouborPlanety.Kanonicky(SouborPlanety.ZBajtu(SouborPlanety.Bajty(pl))) == SouborPlanety.Kanonicky(pl) && pl.Upravy.Count == 0 && pl.Klice.Count == 11 && !pl.Potvrzena
            && pl.ManifestSouhrn == ManifestKatalogu.Spocti(data).Souhrn, "WPLN obsah: tam a zpět, 11 klíčů, 0 úprav (U-1 zástupné), manifest = data");
        T.Je(gn.Moduly.Parametry("M2").Single(p => p.Id == "ParametrySveta.PodilMore").Hodnota == "0.3" && gn.Moduly.Parametry("M6").Single(p => p.Id == "ParametryVody.FilmM").Hodnota == "0.4", "načtená sada: PodilMore 0,3, FilmM 0,4");
        gs.Sluzba.PotvrdPlanetu(); gs.Sluzba.Uloz(f2);
        var gp = new GeneratorSveta(data, kes);
        T.Je(gp.Sluzba.Nacti(f2).Potvrzena && !gp.Moduly.Nastav("ParametrySveta.Oktav", "5").Prijato, "potvrzená planeta se načte zamčená");
        var spatna = Path.Combine(tmp, "spatna.wpln");
        File.WriteAllBytes(spatna, SouborMapy_Spatny());
        T.Je(Hodi<InvalidDataException>(() => SouborPlanety.Nacti(spatna)), "soubor s jinou magií odmítnut");
        // změněný manifest: kopie dat, jeden soubor jinak
        var man = ManifestKatalogu.Spocti(data);
        string dk = Path.Combine(tmp, "data");
        foreach (var x in man.Polozky) { var c = Path.Combine(dk, x.Cesta); Directory.CreateDirectory(Path.GetDirectoryName(c)!); File.Copy(Path.Combine(data.Koren, x.Cesta), c); }
        File.Copy(Path.Combine(data.Koren, ManifestKatalogu.NazevSouboru), Path.Combine(dk, ManifestKatalogu.NazevSouboru), true);
        File.AppendAllText(Path.Combine(dk, "v1", "klima_v1.json"), "\n");
        var gd = new GeneratorSveta(new DataSveta(dk), kes);
        var di = gd.Sluzba.Nacti(f1);
        T.Je(S(di.RozdilyDat) == "v1/klima_v1.json" && S(di.NeplatneModuly) == "M5,M6,M6d,M7,M8,M9", $"změněný manifest se pozná: rozdíly {S(di.RozdilyDat)}, neplatné {S(di.NeplatneModuly)}");
        var kk = gd.Katalogy.Kontrola();
        T.Je(!kk.Aktualni && S(kk.Rozdily) == "v1/klima_v1.json" && S(kk.DotceneModuly) == "M5,M6,M6d,M7,M8,M9", "IKatalogy.Kontrola: klima_v1.json → M5, M6, … (uložený manifest se liší)");

        T.Sekce("G-3: katalogy a dotazy");
        var md = g.Katalogy.Manifest();
        T.Je(md.Souhrn == man.Souhrn && md.Polozky.Count == man.Polozky.Count && g.Katalogy.Kontrola().Aktualni, $"manifest přes fasádu = G-1 ({md.Polozky.Count} souborů), aktuální");
        T.Je(S(g.Katalogy.DotceneModuly("v1/eroze_v1.json")) == "M4,M5,M6,M6d,M7,M8,M9" && S(g.Katalogy.DotceneModuly("v1/voda_v1.json")) == "M6,M6d,M7,M8,M9", "dotčené moduly souboru (+ závislé)");
        T.Je(g.Katalogy.NavrhVerze().Zastupny, "návrh verze katalogu: zástupné");
        var svet = g.Stav.Hotovo().Svet;
        var bod = SouradniceQ16.ZMetru(1984.25, 1990.5);
        var sl = g.Dotazy.Sloupec(bod);
        T.Je(sl.Materialy.AsSpan().SequenceEqual(svet.Geologie.Sloupec(1984.25, 1990.5)) && sl.PovrchM == svet.Geologie.Povrch(1984.25, 1990.5), $"Sloupec = GeologieCs ({sl.Materialy.Length} buněk, povrch {sl.PovrchM:F2} m)");
        var bd = g.Dotazy.Bod(bod);
        T.Je(bd.Biom is not null && bd.TeplotaC == svet.Klima!.Teplota(1984.25, 1990.5) && bd.PovrchM == sl.PovrchM, $"Bod: {bd.PovrchM:F1} m, {bd.TeplotaC:F1} °C, {bd.Biom}");
        var rz = g.Dotazy.Rez(SouradniceQ16.ZMetru(1792, 1984), SouradniceQ16.ZMetru(2176, 1984), 2.0);
        T.Je(rz.PovrchM.Length == 193 && rz.PovrchM[0] == svet.Geologie.Povrch(1792, 1984) && rz.PovrchM[^1] == svet.Geologie.Povrch(2176, 1984), "Rez 384 m po 2 m: 193 vzorků, konce = povrch");
        var mv = g.Dotazy.Mapa(VrstvaMapyDto.Vyska); var mt = g.Dotazy.Mapa(VrstvaMapyDto.Teplota); var mb = g.Dotazy.Mapa(VrstvaMapyDto.Biom);
        T.Je(mv.Nx == svet.Mapa!.T.Nx && mv.Hodnoty.AsSpan().SequenceEqual(svet.Mapa.H) && !ReferenceEquals(mv.Hodnoty, svet.Mapa.H) && mt.Hodnoty.Length == mt.Nx * mt.Ny && mb.Hodnoty.All(x => x >= 0 && x < 11),
            $"Mapa: výška {mv.Nx}×{mv.Ny} po {mv.KrokM} m (kopie), teplota {mt.Nx}×{mt.Ny}, biom 0–10");

        T.Sekce("G-3: zástupné části fasády");
        var po = g.Moduly.PrepocitejOblast("M6", new OblastQ16(SouradniceQ16.ZMetru(0, 0), SouradniceQ16.ZMetru(128, 128)));
        T.Je(po.Zastupny && po.Poznamka.Contains("zástupné") && po.Prepocitane.Count == 0, "U-2 přepočet oblasti: zástupné (nic neplatné → nic se nepřepočetlo)");
        var pu = g.Upravy.Pridej(new UpravaRegionuDto("zvedni", "M2", new OblastQ16(default, SouradniceQ16.ZMetru(64, 64)), "{}"));
        T.Je(pu.Zastupny && g.Upravy.Seznam().Count == 0, "U-1 úpravy s regiony: zástupné, nic se neuloží");
        T.Je(g.Vizual.BlokyOkna(default).Count == 0 && g.Vizual.VariantyModelu().Count == 6, "vizuální data (okno 2): zástupné");

        T.Sekce("G-3: sladění s Willage_Dev Geology.Core G0 (29bffc0)");
        // golden vektory z Dev tests/Willage.World.Geology.Core.Tests/Fixtures/geology-hash-golden-v1.json
        var vek = new (int x, int y, int z, uint seed, uint hash)[]
        {
            (0, 0, 0, 0x00000001, 0x4D234C08), (1, 2, 3, 0x0000601D, 0xE7E0506A), (-1, 5, 9, 0x0000002A, 0x4F2C2C38),
            (100, -200, 7, 0xDEADBEEF, 0xD3835B03), (24605, 0, 0, 0x00000000, 0xCBF974C2), (17, 19, 23, 0x13572468, 0x5E0E7806),
        };
        T.Je(vek.All(v => GeologyHash.HashInt3(v.x, v.y, v.z, v.seed) == v.hash) && GeologyHash.DeriveSeed(99, 7) == 0x4C95CAD5 && GeologyHash.HashString("ev_sed_0001") == 0x3E0E4409,
            "GeologyHash = golden vektory Dev (HashInt3 ×6, DeriveSeed, HashString)");
        var pe = ParametryEroze.ZJson(File.ReadAllText(data.ErozeV1));
        T.Je(GeologyGridConstants.DefaultPlanetPeriodXMillimetres == 245 * 128_000 && GeologyGridConstants.DefaultPlanetPeriodYMillimetres == 122 * 128_000
            && pe.PlanetaXM * 1000 == GeologyGridConstants.DefaultPlanetPeriodXMillimetres && pe.PlanetaYM * 1000 == GeologyGridConstants.DefaultPlanetPeriodYMillimetres,
            $"perioda planety = Dev PlanetTorus.Default (245 × 122 sloupců = {pe.PlanetaXM} × {pe.PlanetaYM} m)");
        T.Je(SouradniceQ16.JednotekNaMetr == Q16.UnitsPerMetre && SouradniceQ16.ZMetru(1.5, -0.25) == new SouradniceQ16(98304, -16384) && SouradniceQ16.ZMetru(1984.25, 7).XM == 1984.25,
            "SouradniceQ16 = FxQ16 (65 536/m), převod tam a zpět");

        Directory.Delete(tmp, true);
    }

    static byte[] SouborMapy_Spatny()
    {
        using var ms = new MemoryStream();
        using (var z = new System.IO.Compression.DeflateStream(ms, System.IO.Compression.CompressionLevel.Optimal, true)) z.Write("WGER\u0001\0\0\0"u8);
        return ms.ToArray();
    }
}
