using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Pipeline;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Schema;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>G-2: schéma parametrů M0–M7 (úplnost, výchozí = dnešní hodnoty, rozsahy, JSON tam a zpět) a SadaParametru jako vstup pipeline.</summary>
public static class TestyG2
{
    static string S(IEnumerable<string> s) => string.Join(",", s);
    static bool Hodi<TE>(Action a) where TE : Exception { try { a(); return false; } catch (TE) { return true; } }
    static List<string> Zmenene(IReadOnlyDictionary<string, string> a, IReadOnlyDictionary<string, string> b) =>
        a.Keys.Where(k => a[k] != b[k]).OrderBy(k => k, StringComparer.Ordinal).ToList();
    static readonly JsonSerializerOptions O = new() { IncludeFields = true };

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var graf = ModulySveta.Graf();
        var s = SchemaParametru.Sestav(data);

        T.Sekce("G-2: schéma parametrů – úplnost");
        var kod = SchemaParametru.Zdroje.SelectMany(z => SchemaParametru.Cleny(z.typ).Select(m => z.zdroj + "." + m.Name)).Append("prusak_v1.json.Tabulka").ToList();
        var ids = s.Parametry.Select(p => p.Id).ToList();
        T.Je(ids.Distinct().Count() == ids.Count && kod.Except(ids).Count() == 0 && ids.Except(kod).Count() == 0,
            $"každý z {kod.Count} parametrů kódu je ve schématu právě jednou (chybí {S(kod.Except(ids))}; navíc {S(ids.Except(kod))})");
        T.Je(s.Parametry.All(p => graf.Poradi.Any(m => m.Id == p.Modul)), "každý parametr má modul z grafu M0–M7");
        var mod = s.Parametry.GroupBy(p => p.Modul).ToDictionary(g => g.Key, g => g.Count());
        Console.WriteLine("  parametrů podle modulu: " + string.Join(", ", graf.Poradi.Select(m => $"{m.Id} {mod.GetValueOrDefault(m.Id)}")) + $" (celkem {s.Parametry.Count})");
        T.Je(RozdeleniParametru.Vse.All(kv => kv.Value.All(n => s["ParametrySveta." + n].Modul == kv.Key)) && s.Modulu("M4").All(p => p.Zdroj == "ParametryEroze")
            && RozdeleniParametru.KlimaProM6.All(n => s["ParametryKlimatu." + n].Modul == "M6") && s.Modulu("M5").All(p => p.Zdroj == "ParametryKlimatu") && !s.Modulu("M7").Any(),
            "vlastník = RozdeleniParametru (M0–M3), eroze M4, klima M5 (dobití hladiny 7c M6), voda a průsak M6, M7 nemá parametry");
        // ruční metadata: každý člen kódu právě v jedné skupině, nic navíc
        var meta = MetadataParametru.Skupiny.SelectMany(kv => kv.Value.SelectMany(g => g.nazvy.Select(n => kv.Key + "." + n))).ToList();
        T.Je(meta.Distinct().Count() == meta.Count && S(meta.OrderBy(x => x, StringComparer.Ordinal)) == S(kod.OrderBy(x => x, StringComparer.Ordinal)),
            $"metadata: každý parametr právě v jedné skupině (bez skupiny {S(kod.Except(meta))}; navíc {S(meta.Except(kod))}; dvakrát {S(meta.GroupBy(x => x).Where(g => g.Count() > 1).Select(g => g.Key))})");
        var klice = MetadataParametru.Rozsahy.Keys.Concat(MetadataParametru.Volby.Keys).Concat(MetadataParametru.JenCteni.Keys).ToList();
        T.Je(klice.All(s.Obsahuje), "rozsahy, volby a jen čtení míří na existující parametry (" + S(klice.Where(k => !s.Obsahuje(k))) + ")");

        T.Sekce("G-2: schéma – výchozí hodnoty = dnešní");
        // nezávisle na SadaParametru: syrový JSON souborů (klíče bez ohledu na velikost písmen) a nový objekt v C#
        var soubory = new (string zdroj, string soubor)[] { ("ParametrySveta", data.MoreV1), ("ParametryEroze", data.ErozeV1), ("ParametryKlimatu", data.KlimaV1), ("ParametryVody", data.VodaV1) };
        var spatne = new List<string>(); var zeSouboru = new List<string>(); var neznameKlice = new List<string>();
        var rozdilKod = new List<string>();
        foreach (var (zdroj, soubor) in soubory)
        {
            var raw = JsonNode.Parse(File.ReadAllText(soubor), documentOptions: new JsonDocumentOptions { CommentHandling = JsonCommentHandling.Skip })!.AsObject();
            var typ = SchemaParametru.Zdroje.Single(z => z.zdroj == zdroj).typ;
            object novy = Activator.CreateInstance(typ)!;
            foreach (var m in SchemaParametru.Cleny(typ))
            {
                var p = s[zdroj + "." + m.Name]; var t = SchemaParametru.TypClenu(m);
                var kodH = JsonSerializer.SerializeToNode(SchemaParametru.Hodnota(m, novy), t, O);
                var vSoub = raw.FirstOrDefault(kv => string.Equals(kv.Key, m.Name, StringComparison.OrdinalIgnoreCase)).Value;
                var ocek = vSoub is null ? kodH : JsonSerializer.SerializeToNode(vSoub.Deserialize(t, new JsonSerializerOptions { IncludeFields = true, PropertyNameCaseInsensitive = true }), t, O);
                if (vSoub is not null) zeSouboru.Add(p.Id);
                if (!JsonNode.DeepEquals(p.Vychozi, ocek)) spatne.Add(p.Id);
                if (!JsonNode.DeepEquals(p.VychoziKod, kodH)) spatne.Add(p.Id + "(kód)");
                if (!JsonNode.DeepEquals(p.Vychozi, p.VychoziKod)) rozdilKod.Add(p.Id);
            }
            neznameKlice.AddRange(raw.Select(kv => kv.Key).Where(k => k != "_popis" && !k.StartsWith("_") && !SchemaParametru.Cleny(typ).Any(m => string.Equals(m.Name, k, StringComparison.OrdinalIgnoreCase))).Select(k => Path.GetFileName(soubor) + ":" + k));
        }
        T.Je(spatne.Count == 0, $"výchozí = soubor (data/v1) nebo C#, VychoziKod = C#, pro všech {kod.Count - 1} parametrů ({S(spatne)})");
        Console.WriteLine($"  ze souborů {zeSouboru.Count} hodnot; soubor ≠ C#: {S(rozdilKod)}; klíče souborů mimo kód: {S(neznameKlice)}");
        T.Je(neznameKlice.Count == 0, "soubory data/v1 nemají klíče, které kód nečte (překlep by se tiše ignoroval)");
        T.Je(JsonNode.DeepEquals(s["prusak_v1.json.Tabulka"].Vychozi, JsonNode.Parse(File.ReadAllText(data.PrusakV1))), "tabulka průsaku = prusak_v1.json");
        T.Je(s.Parametry.Where(p => p.Soubor is not null && p.Soubor != "v1/prusak_v1.json").All(p => File.Exists(data.Cesta(p.Soubor!))), "datové soubory parametrů existují");
        T.Je(S(s["ParametrySveta.Klima"].Volby!) == S(SchemaParametru.IdPresetuKlimatu(data)) && s["ParametrySveta.Klima"].Volby!.Contains((string)s["ParametrySveta.Klima"].Vychozi!),
            $"Klima: volby z klima_presety.csv ({S(s["ParametrySveta.Klima"].Volby!)}), výchozí mezi nimi");

        T.Sekce("G-2: schéma – typy, rozsahy, jednotky, nápověda");
        var cisla = s.Parametry.Where(p => p.Typ is TypParametru.Cele or TypParametru.Desetinne).ToList();
        var mimo = cisla.Where(p => p.Min is null || p.Max is null || p.Min > p.Max || (double)p.Vychozi! < p.Min || (double)p.Vychozi! > p.Max).Select(p => $"{p.Id}={p.Vychozi}∉[{p.Min},{p.Max}]").ToList();
        T.Je(mimo.Count == 0, $"{cisla.Count} číselných parametrů: Min ≤ výchozí ≤ Max ({S(mimo)})");
        T.Je(cisla.All(p => p.Jednotka.Length > 0 && p.RozsahZdroj.Length > 0) && cisla.Where(p => p.Typ == TypParametru.Cele).All(p => p.Krok == 1), "číselné parametry mají jednotku (– = bezrozměrné), zdroj rozsahu, celá čísla krok 1");
        T.Je(s.Parametry.All(p => p.Skupina.Length > 0 && p.Napoveda == "" && p.TypKodu.Length > 0), "každý parametr má skupinu a typ; nápověda je prázdný slot (texty nejsou ve v1)");
        T.Je(s.Parametry.Where(p => p.Typ == TypParametru.Volba).All(p => p.Volby is { Length: > 0 }) && s.Parametry.Where(p => p.Typ != TypParametru.Volba).All(p => p.Volby is null), "volby právě u typu Volba");
        T.Je(s.Parametry.All(p => p.JenCteni == (p.Poznamka is not null && MetadataParametru.JenCteni.ContainsKey(p.Id))), "jen čtení má důvod v poznámce");
        Console.WriteLine("  typy: " + string.Join(", ", s.Parametry.GroupBy(p => p.Typ).Select(g => $"{g.Key} {g.Count()}")) +
            $"; jen čtení {s.Parametry.Count(p => p.JenCteni)}; rozsah z kódu {cisla.Count(p => p.RozsahZdroj != "odhad")}, odhad {cisla.Count(p => p.RozsahZdroj == "odhad")}");

        T.Sekce("G-2: JSON tam a zpět");
        string js = s.ToJson();
        var s2 = SchemaParametru.ZJson(js);
        T.Je(s2.ToJson() == js && s2.Parametry.Count == s.Parametry.Count && SchemaParametru.Sestav(data).ToJson() == js, "schéma JSON tam a zpět, deterministické");
        T.Je(Hodi<FormatException>(() => SchemaParametru.ZJson("{\"format\":\"jiny\"}")), "neznámý formát schématu odmítnut");
        string koren = Path.GetFullPath(Path.Combine(data.Koren, "..", ".."));
        string export = Path.Combine(koren, "docs", "sjednoceni", "reporty", "g2", "schema_parametru_v1.json");
        T.Je(File.Exists(export) && File.ReadAllText(export).Replace("\r\n", "\n") == js, "uložené docs/sjednoceni/reporty/g2/schema_parametru_v1.json je aktuální (obnovit: Willage.Gen.Nastroje schema <soubor>)");
        var sd = SadaParametru.ZDat(data);
        string jsd = sd.ToJson(s);
        var zKodu = SadaParametru.ZJson(jsd, s, SadaParametru.ZKodu());
        T.Je(zKodu.ToJson(s) == jsd, "sada JSON tam a zpět (načtená přes výchozí z kódu → všechny hodnoty v JSON)");
        T.Je(s.Parametry.All(p => JsonNode.DeepEquals(sd.Hodnota(p.Id), p.Vychozi)), "výchozí sada = výchozí hodnoty schématu");
        T.Je(Hodi<FormatException>(() => SadaParametru.ZJson("{\"format\":\"willage-sada-parametru-v1\",\"moduly\":{\"M1\":{\"ParametrySveta.PodilMore\":0.3}}}", s, sd))
            && Hodi<FormatException>(() => SadaParametru.ZJson("{\"format\":\"willage-sada-parametru-v1\",\"moduly\":{\"M2\":{\"ParametrySveta.Neni\":1}}}", s, sd))
            && Hodi<JsonException>(() => SadaParametru.ZJson("{\"format\":\"willage-sada-parametru-v1\",\"moduly\":{\"M0\":{\"ParametrySveta.Seed\":\"x\"}}}", s, sd)),
            "sada: parametr v cizím modulu, neznámý parametr a špatný typ odmítnuty");
        var cast = SadaParametru.ZJson("{\"format\":\"willage-sada-parametru-v1\",\"moduly\":{\"M2\":{\"ParametrySveta.PodilMore\":0.25},\"M6\":{\"ParametryKlimatu.HladinaSuchoM\":2.5,\"ParametryVody.FilmM\":0.4}}}", s, sd);
        var (cs, cn) = cast.Sestav();
        T.Je(cs.PodilMore == 0.25 && cn.Klima.HladinaSuchoM == 2.5 && cn.Voda.FilmM == 0.4 && cs.Oktav == new ParametrySveta().Oktav && cn.Eroze == sd.Sestav().nastaveni.Eroze,
            "částečná sada: změněné hodnoty, ostatní ze základu");
        T.Je(sd.Hodnota("ParametrySveta.PodilMore")!.GetValue<double>() == new ParametrySveta().PodilMore && sd.Hodnota("ParametryKlimatu.HladinaSuchoM")!.GetValue<double>() == NastaveniModulu.ZDat(data).Klima.HladinaSuchoM,
            "Sestav vrací kopie (základ se nezměnil)");

        T.Sekce("G-2: sada jako vstup pipeline");
        var pl = new PipelineSveta(data);
        var kz = pl.Klice(new ParametrySveta());
        IReadOnlyDictionary<string, string> K(SadaParametru x) { var (p, n) = x.Sestav(); var q = new PipelineSveta(data) { Nastaveni = n }; return q.Klice(p); }
        T.Je(S(K(sd).Values) == S(kz.Values), "výchozí sada → stejné klíče modulů jako pipeline bez sady");
        var kKodu = Zmenene(kz, K(SadaParametru.ZKodu()));
        Console.WriteLine($"  sada jen z kódu (bez data/v1) mění klíče: {S(kKodu)}");
        var oc2 = new SortedSet<string>(graf.Zavisle("M2").Append("M2"), StringComparer.Ordinal);
        T.Je(S(Zmenene(kz, K(SadaParametru.ZDat(data).Nastav("ParametrySveta.PodilMore", 0.25)))) == S(oc2), "moře přes sadu: PodilMore 0,35 → 0,25 mění klíče M2–M7");
        T.Je(S(Zmenene(kz, pl.Klice(new ParametrySveta { PodilMore = 0.25 }))) == S(oc2), "moře přes ParametrySveta: PodilMore 0,25 mění klíče M2–M7 (dřív ho přepsal more_v1.json)");
        T.Je(S(Zmenene(kz, K(SadaParametru.ZDat(data).Nastav("ParametryKlimatu.HladinaSuchoM", 2.5)))) == "M6,M7", "dobití hladiny 7c (HladinaSuchoM) mění jen klíče M6, M7");
        T.Je(S(Zmenene(kz, K(SadaParametru.ZDat(data).Nastav("ParametryKlimatu.HladinaMoreM", 50.0)))) == "M5,M6,M7", "hladina moře pro klima (ParametryKlimatu.HladinaMoreM) mění M5–M7");

        // moře opravdu dorazí do světa: jen M0–M2 (bez eroze)
        var g3 = new GrafModulu(graf.Poradi.Take(3));
        double Podil(ParametrySveta p) => new PipelineSveta(data, g3).Spust(p).Vystup<SvetFn>("M2").More!.Podil;
        double p0 = Podil(new ParametrySveta()), p1 = Podil(new ParametrySveta { PodilMore = 0.25 }), p2 = Podil(SadaParametru.ZDat(data).Nastav("ParametrySveta.PodilMore", 0.25).Sestav().svet);
        T.Je(p1 < p0 && p1 == p2 && Math.Abs(p1 - 0.25) < 0.08 && Math.Abs(p0 - 0.35) < 0.08, FormattableString.Invariant($"podíl moře M2: výchozí {p0:F3}, PodilMore 0,25 → {p1:F3} (sada {p2:F3})"));

        // dobití hladiny přes sadu: přepočte jen M6, M7 a svět nese nové parametry klimatu
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");
        var (ps, n0) = sd.Sestav();
        var pp = new PipelineSveta(data) { Nastaveni = n0 };
        var r1 = pp.Spust(ps, kes, 8);
        var zmena = SadaParametru.ZDat(data).Nastav("ParametryKlimatu.HladinaSuchoM", 2.5).Nastav("ParametryKlimatu.HladinaWPrah", n0.Klima.HladinaWPrah * 0.5);
        var (ps2, n2) = zmena.Sestav();
        pp.Nastaveni = n2;
        var r2 = pp.Spust(ps2, kes, 8);
        var c = r2.Vystup<VystupKlimatu>("M5"); var e = r2.Vystup<VystupEroze>("M4");
        var prima = c.Zapnuto ? NapajeniVody.Spocti(e.Mapa!, c.Mapa!, c.Hydrologie!, c.Vodnici, n2.Klima) : null;
        var nap = r2.Vystup<VystupVody>("M6").Napajeni;
        T.Je(S(r2.Prepocitane) == "M6,M7" && ReferenceEquals(c, r1.Vystup<VystupKlimatu>("M5")) && r2.Svet.ParametryKlimatu!.HladinaSuchoM == 2.5 && r2.Svet.ParametryKlimatu.HladinaWPrah == n2.Klima.HladinaWPrah
            && r2.Svet.Napajeni is not null && ReferenceEquals(r2.Svet.Napajeni, nap) && prima is not null && nap!.E.AsSpan().SequenceEqual(prima.E) && !nap.E.AsSpan().SequenceEqual(r1.Svet.Napajeni!.E),
            $"dobití hladiny přes sadu: přepočteno {S(r2.Prepocitane)}, klima M5 z paměti, svět má HladinaSuchoM 2,5 a dobití = přímý výpočet (jiné než výchozí)");
        pp.Nastaveni = n0;
        var r3 = pp.Spust(ps, kes, 8);
        T.Je(S(r3.Prepocitane) == "M6,M7" && r3.Vystup<VystupPlanety>("M7").Souhrn == r1.Vystup<VystupPlanety>("M7").Souhrn && r3.Vystup<VystupPlanety>("M7").Souhrn.OtiskMapy == TestyKrok06d.GoldenMapaVychozi,
            "zpět na výchozí sadu: souhrn = první běh, golden mapa eroze");
    }
}
