using System.Text.Json;
using Willage.Gen.Geo2;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K1 (kontrakt docs/sjednoceni/06-geologie-geo2.md): chronologie (stáří, id), pravidla zásahu 2.2–2.4, pravidlo cíle 2.3,
/// katalog kap. 8, příklad 2.7, V1 bez zlomu na syntetických tvarech, nezávislost na pořadí v datech, determinismus ve vláknech.
/// Syntetické tvary ověřují pravidla, ne geologickou geometrii (ta je K1b / K4).
/// </summary>
public static class TestyGeo2K1
{
    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        Katalog(kat);
        Priklad27(kat, data);
        Validace(kat);
        V1(kat);
        Prazdno(kat);
        PoradiADeterminismus(kat);
    }

    // ---------- syntetické tvary ----------
    private sealed class Koule : ITvarSMaterialem
    {
        public double X, Y, Z, R; public int Mat;
        public bool Obsahuje(double x, double y, double z, out uint i) { i = 1; double dx = x - X, dy = y - Y, dz = z - Z; return dx * dx + dy * dy + dz * dz <= R * R; }
        public int Material(double x, double y, double z, uint i) => Mat;
    }
    private sealed class Deska : ITvar
    {
        public double X0, H;
        public bool Obsahuje(double x, double y, double z, out uint i) { i = 7; return Math.Abs(x - X0) <= H; }
    }
    private sealed class Vrstvy : ITvarZasobniku
    {
        public List<(double doZ, int mat)> V = new();
        public bool Vrstva(double x, double y, double z, out int m, out short v)
        {
            for (int i = 0; i < V.Count; i++) if (z < V[i].doZ) { m = V[i].mat; v = (short)i; return true; }
            m = V[^1].mat; v = (short)(V.Count - 1); return true;
        }
    }
    /// <summary>Miniaturní kontakt 2.5 kolem koule cíle: vně, d ≤ šířka, hostitel_okoli čtený prefixem v q′ = π(q) + η·u.</summary>
    private sealed class KontaktKoule : IKontaktniPasmo
    {
        public Koule Cil = null!; public double W, Eta; public HashSet<int> Hostitel = new();
        public bool Plati(double x, double y, double z, in StavBodu s, PrefixVyhodnoceni pred)
        {
            double dx = x - Cil.X, dy = y - Cil.Y, dz = z - Cil.Z, r = Math.Sqrt(dx * dx + dy * dy + dz * dz);
            double d = r - Cil.R;
            if (d <= 0 || d > W || r < 1e-9) return false;
            double k = (Cil.R - Eta) / r;
            var q = pred(Cil.X + dx * k, Cil.Y + dy * k, Cil.Z + dz * k);
            return q.Typ == TypProstoru.Pevne && Hostitel.Contains(q.Material);
        }
    }

    private sealed class Tovarna : ITovarnaTvaru
    {
        private readonly KatalogGeo2 _k; private readonly bool _kontakt;
        private readonly Dictionary<string, Koule> _koule = new();
        public Tovarna(KatalogGeo2 k, bool kontakt = true) { _k = k; _kontakt = kontakt; }
        private int Id(string klic) => _k.PodleKlice(klic)!.Id;
        public object? Vytvor(UdalostData u)
        {
            var t = u.Tvar;
            switch (u.TvarDruh)
            {
                case "test_vrstvy":
                    var v = new Vrstvy();
                    foreach (var e in t.GetProperty("vrstvy").EnumerateArray()) v.V.Add((e.GetProperty("do_z").GetDouble(), Id(e.GetProperty("material").GetString()!)));
                    return v;
                case "test_koule":
                    var s = t.GetProperty("stred");
                    var kk = new Koule { X = s[0].GetDouble(), Y = s[1].GetDouble(), Z = s[2].GetDouble(), R = t.GetProperty("r").GetDouble(),
                        Mat = t.TryGetProperty("material", out var m) ? Id(m.GetString()!) : 0 };
                    _koule[u.Id] = kk; return kk;
                case "test_deska":
                    return new Deska { X0 = t.GetProperty("x0").GetDouble(), H = t.GetProperty("polotloustka").GetDouble() };
                // příklad 2.7: geometrie není předmětem K1, stačí tvar, který nic neobsahuje (a zásobník / tvar s materiálem)
                case "zasobnik": return new Vrstvy { V = { (1e9, Id("granite")) } };
                case "sopka_nitro": return new Koule { R = -1, Mat = Id("granite") };
                case "elipsoid" or "deska" or "kapsle_retez" or "pod_dnem" or "rovina_zlomu": return new Koule { R = -1 };
                default: return null;
            }
        }
        public IKontaktniPasmo? Kontakt(UdalostData u)
        {
            if (!_kontakt) return null;
            var ko = u.Pravidla.GetProperty("kontakt");
            var cil = ko.GetProperty("cil");
            var host = new HashSet<int>();
            if (ko.TryGetProperty("hostitel_okoli", out var ho) && ho.TryGetProperty("materialy", out var hm))
                foreach (var e in hm.EnumerateArray()) host.Add(Id(e.GetString()!));
            Koule? c = null;
            if (cil.TryGetProperty("udalosti", out var cu)) foreach (var e in cu.EnumerateArray()) if (_koule.TryGetValue(e.GetString()!, out var x)) c = x;
            return new KontaktKoule { Cil = c ?? new Koule { R = -1 }, W = ko.GetProperty("sirka_m").GetDouble(),
                Eta = ho.ValueKind == JsonValueKind.Object && ho.TryGetProperty("hloubka_vzorku_m", out var h) ? h.GetDouble() : 0.125, Hostitel = host };
        }
    }

    private static VysledekKompilace K(string pole, KatalogGeo2 kat, bool kontakt = true, IEnumerable<string>? nikdy = null) =>
        KompilatorChronologie.Kompiluj(UdalostiJson.NactiPole(pole, nikdy), kat, new Tovarna(kat, kontakt));

    // ---------- katalog (kap. 8) ----------
    private static void Katalog(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1: katalog (kap. 8)");
        T.Je(kat.Materialy.Count == 75 && !kat.Zprava.MaChyby, $"skutečný katalog 75 hornin bez chyb ({kat.Materialy.Count}; {kat.Zprava})");
        T.Je(KatalogGeo2.ZeSouboru(Path.Combine(AppContext.BaseDirectory, "Data", "materials-catalog-v1.json")).Otisk == kat.Otisk, "otisk katalogu je stabilní");
        T.Je(kat.IdSkupiny("vapenec").Contains(5) && kat.IdSkupiny("vapenec").Contains(44), "skupina vapenec obsahuje cave_limestone i deep_limestone");

        string Kat(string extra) => """
          {"schemaVersion":1,"materials":[
          {"id":0,"key":"air","idStatus":"active","geology":{"skupina":"krystal"}},
          {"id":5,"key":"cave_limestone","idStatus":"active","geology":{"skupina":"vapenec"}},
          {"id":6,"key":"granite","idStatus":"active","geology":{"skupina":"krystal"}},
          {"id":42,"key":"skarn","idStatus":"active","geology":{"skupina":"krystal"}},
          {"id":2,"key":"topsoil","idStatus":"active","geology":{"skupina":"hlina"}}EXTRA]}
          """.Replace("EXTRA", extra);
        var a = new KatalogGeo2(Kat(""",{"id":90,"key":"old_lime","idStatus":"retired","replacedBy":5,"geology":{"skupina":"vapenec"}}"""));
        T.Je(!a.Zprava.MaChyby && a.Aktivni(90)?.Id == 5, "vyřazená s náhradou → aktivní náhrada");
        var b = new KatalogGeo2(Kat(""",{"id":91,"key":"gone","idStatus":"retired","geology":{"skupina":"vapenec"}}"""));
        T.Je(b.Zprava.Obsahuje("KAT_VYRAZENA_BEZ_NAHRADY"), "vyřazená bez náhrady = chyba katalogu");
        var c = new KatalogGeo2(Kat(""",{"id":92,"key":"c1","idStatus":"retired","replacedBy":93},{"id":93,"key":"c2","idStatus":"retired","replacedBy":92}"""));
        T.Je(c.Zprava.Obsahuje("KAT_NAHRADA_NEVEDE_K_AKTIVNI"), "cyklus náhrad = chyba katalogu");
        T.Je(a.Otisk != new KatalogGeo2(Kat(""",{"id":90,"key":"old_lime","idStatus":"retired","replacedBy":6,"geology":{"skupina":"vapenec"}}""")).Otisk,
            "jiná náhrada = jiný otisk katalogu");
        T.Je(new KatalogGeo2(Kat("")).MaxId == 42, "max id podle katalogu, ne pevné");

        const string ud = """
          [{"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":100,"material":"cave_limestone"}]}},
          {"id":"t","stari":1,"operace":"Vnikni","tvar":{"druh":"test_koule","stred":[0,0,0],"r":1},
           "pravidla":{"nahrazuje":{"materialy":["XX"]}},"vysledek":{"material":"granite"}}]
          """;
        var rA = K(ud.Replace("XX", "old_lime"), a);
        T.Je(rA.Ok && rA.Zprava.Obsahuje("MATERIAL_PRESMEROVAN"), "odkaz na vyřazenou s náhradou: varování a přesměrování");
        T.Je(K(ud.Replace("XX", "gone"), b).Zprava.Obsahuje("MATERIAL_VYRAZENY_BEZ_NAHRADY"), "odkaz na vyřazenou bez náhrady = chyba");
        // nová hornina ve skupině spadne pod pravidla automaticky
        var nov = new KatalogGeo2(Kat(""",{"id":95,"key":"new_dolomite","idStatus":"active","geology":{"skupina":"vapenec"}}"""));
        var rS = K(ud.Replace("\"materialy\":[\"XX\"]", "\"skupiny\":[\"vapenec\"]").Replace("\"cave_limestone\"}]", "\"new_dolomite\"}]"), nov);
        T.Je(rS.Ok && rS.Chronologie!.Bod(0, 0, 0, 100).Material == 6, "nová hornina ve skupině vapenec: těleso ji nahradí bez úpravy událostí");
    }

    // ---------- příklad 2.7 ----------
    private static void Priklad27(KatalogGeo2 kat, string data)
    {
        T.Sekce("GEO2 K1: příklad 2.7 z kontraktu (12 událostí)");
        var sada = UdalostiJson.Nacti(File.ReadAllText(Path.Combine(data, "geo2", "udalosti_priklad_06_2_7.json")));
        T.Je(sada.Udalosti.Count == 12 && !sada.Zprava.MaChyby, $"načteno 12 událostí ({sada.Zprava})");
        T.Je(sada.Konfigurace == new KonfiguraceGeo2(0.125, 0.125, 0.125, 0.125), "konfigurace: 4 samostatné parametry 0,125 m");
        var r = KompilatorChronologie.Kompiluj(sada, kat, new Tovarna(kat));
        T.Je(r.Ok, "příklad se zkompiluje: " + string.Join("; ", r.Zprava.Chyby));
        if (r.Ok)
        {
            var ids = r.Chronologie!.Udalosti.Select(u => u.Id).ToArray();
            T.Je(ids.SequenceEqual(new[] { "zasobnik", "skarn_kontakt", "cocka_pegmatit", "zila_kremen", "solny_dom", "komin_kimberlit", "kras", "sopka", "vyplen_jeskyne" }),
                "9 aktivních v pořadí stáří: " + string.Join(",", ids));
            T.Je(r.Zprava.Obsahuje("ODKAZ_NEAKTIVNI"), "odkaz na neaktivní granitoid_intruze se vypustí s varováním");
            var skarn = r.Chronologie.Udalosti[1];
            T.Je(skarn.Nahrazuje!.Plati(kat.PodleKlice("cave_limestone")!.Id) && !skarn.Nahrazuje.Plati(kat.PodleKlice("amphibolite")!.Id),
                "O1: skarn jen v karbonátech, amfibolit ne");
        }
        var bez = KompilatorChronologie.Kompiluj(sada, kat, new Tovarna(kat, kontakt: false));
        T.Je(!bez.Ok && bez.Zprava.Obsahuje("KONTAKT_K1B"), "bez implementace kontaktu: chyba KONTAKT_K1B (K1b)");
    }

    // ---------- validace 2.4 ----------
    private const string Z0 = """{"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":10,"material":"granite"},{"do_z":100,"material":"cave_limestone"}]}}""";
    private const string KOULE = "\"tvar\":{\"druh\":\"test_koule\",\"stred\":[0,0,20],\"r\":2}";

    private static void Ma(KatalogGeo2 kat, string kod, string udalosti, string co)
    {
        var r = K("[" + Z0 + "," + udalosti.Replace("KOULE", KOULE) + "]", kat);
        T.Je(!r.Ok && r.Zprava.Obsahuje(kod), $"{co}: očekáváno {kod}, je {(r.Ok ? "OK" : string.Join("; ", r.Zprava.Chyby.Select(h => h.Kod)))}");
    }

    private static void Validace(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1: validace (1.3, 2.4)");
        var ok = K("[" + Z0 + "]", kat);
        T.Je(ok.Ok, "jen zásobník: OK " + ok.Zprava);
        Ma(kat, "STARI_SHODNE", """{"id":"a","stari":0,"operace":"Vnikni",KOULE,"vysledek":{"material":"granite"}}""", "shodné stáří");
        Ma(kat, "DEFORMACE_AZ_D", """{"id":"f","stari":5,"operace":"Deformuj","tvar":{"druh":"rovina_zlomu"}}""", "aktivní deformace");
        T.Je(K("[" + Z0 + """,{"id":"f","stari":5,"operace":"Deformuj","aktivni":false,"tvar":{"druh":"rovina_zlomu"}}]""", kat).Ok, "neaktivní deformace v datech smí být");
        Ma(kat, "ULOZ_POCET", """{"id":"z2","stari":3,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":1,"material":"granite"}]}}""", "dvě Uloz");
        T.Je(K("""[{"id":"a","stari":0,"operace":"Vnikni",KOULE,"vysledek":{"material":"granite"}},{"id":"z","stari":1,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":1,"material":"granite"}]}}]""".Replace("KOULE", KOULE), kat)
            .Zprava.Obsahuje("ULOZ_NENI_PRVNI"), "Uloz není nejstarší → ULOZ_NENI_PRVNI");
        Ma(kat, "PRAVIDLO_ZAKAZANO", """{"id":"v","stari":5,"operace":"Vypln",KOULE,"pravidla":{"nahrazuje":"*","prostor":["DutinaKras"]},"vysledek":{"material":"clay_deposit"}}""", "Vypln s nahrazuje");
        Ma(kat, "PRAVIDLO_ZAKAZANO", """{"id":"o","stari":5,"operace":"Odstran",KOULE,"pravidla":{"nahrazuje":"*","prostor":["DutinaKras"],"hloubka":{"min_m":2}},"vysledek":{"prostor":"DutinaKras"}}""", "Odstran s prostor");
        Ma(kat, "PRAVIDLO_ZAKAZANO", """{"id":"t","stari":5,"operace":"Transformuj","tvar":{"druh":"oblast"},"pravidla":{"nahrazuje":{"materialy":["granite"]},"prostor":["DutinaKras"]},"vysledek":{"mapa":{"granite":"skarn"}}}""", "Transformuj s prostor");
        Ma(kat, "NAHRAZUJE_POVINNE", """{"id":"o","stari":5,"operace":"Odstran",KOULE,"pravidla":{"hloubka":{"min_m":2}},"vysledek":{"prostor":"DutinaKras"}}""", "Odstran bez nahrazuje");
        Ma(kat, "NAHRAZUJE_POVINNE", """{"id":"t","stari":5,"operace":"Transformuj","tvar":{"druh":"oblast"},"vysledek":{"mapa":{"granite":"skarn"}}}""", "Transformuj bez nahrazuje");
        Ma(kat, "PROSTOR_POVINNY", """{"id":"v","stari":5,"operace":"Vypln",KOULE,"vysledek":{"material":"clay_deposit"}}""", "Vypln bez prostor");
        Ma(kat, "HLOUBKA_POVINNA", """{"id":"o","stari":5,"operace":"Odstran",KOULE,"pravidla":{"nahrazuje":"*"},"vysledek":{"prostor":"DutinaKras"}}""", "Odstran bez hloubka.min_m");
        Ma(kat, "VYSLEDEK_PROSTOR", """{"id":"o","stari":5,"operace":"Odstran",KOULE,"pravidla":{"nahrazuje":"*","hloubka":{"min_m":2}},"vysledek":{"prostor":"NadPovrchem"}}""", "Odstran s vysledek.prostor NadPovrchem");
        Ma(kat, "PROSTOR_ZAKAZANY", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"prostor":["NadPovrchem"]},"vysledek":{"material":"granite"}}""", "prostor NadPovrchem");
        Ma(kat, "PROSTOR_ZAKAZANY", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"prostor":["Vykopano"]},"vysledek":{"material":"granite"}}""", "prostor Vykopano");
        Ma(kat, "PROSTOR_NEZNAMY", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"prostor":["Jeskyne"]},"vysledek":{"material":"granite"}}""", "neznámý typ prostoru");
        Ma(kat, "ODKAZ_NENI_STARSI", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"zdroje":{"telesa":["b"]}},"vysledek":{"material":"granite"}},{"id":"b","stari":6,"operace":"Vnikni",KOULE,"vysledek":{"material":"granite"}}""", "zdroje.telesa na mladší");
        Ma(kat, "ODKAZ_NEZNAMY", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"zdroje":{"telesa":["nic"]}},"vysledek":{"material":"granite"}}""", "zdroje.telesa na neexistující");
        Ma(kat, "MAPA_NESEDI", """{"id":"t","stari":5,"operace":"Transformuj","tvar":{"druh":"oblast"},"pravidla":{"nahrazuje":{"materialy":["granite","cave_limestone"]}},"vysledek":{"mapa":{"granite":"skarn"}}}""", "nahrazuje ≠ klíče mapa");
        Ma(kat, "MATERIAL_NEZNAMY", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"vysledek":{"material":"unobtainium"}}""", "neznámý materiál");
        Ma(kat, "SKUPINA_NEZNAMA", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"nahrazuje":{"skupiny":["kouzelna"]}},"vysledek":{"material":"granite"}}""", "neznámá skupina");
        Ma(kat, "NEZNAMY_KLIC", """{"id":"a","stari":5,"operace":"Vnikni",KOULE,"pravidla":{"nahrazue":"*"},"vysledek":{"material":"granite"}}""", "překlep v klíči pravidel");
        Ma(kat, "ID_DUPLICITNI", """{"id":"z","stari":5,"operace":"Vnikni",KOULE,"vysledek":{"material":"granite"}}""", "duplicitní id");
        Ma(kat, "VYSLEDEK_MATERIAL", """{"id":"a","stari":5,"operace":"Vnikni",KOULE}""", "Vnikni bez výsledku");
        Ma(kat, "OPERACE_NEZNAMA", """{"id":"a","stari":5,"operace":"Prohod",KOULE}""", "neznámá operace");
        Ma(kat, "TVAR_NEZNAMY", """{"id":"a","stari":5,"operace":"Vnikni","tvar":{"druh":"hvezda"},"vysledek":{"material":"granite"}}""", "neznámý tvar");
        // O2: tenké těleso není chyba
        T.Je(K("[" + Z0 + """,{"id":"a","stari":5,"operace":"Vnikni","tvar":{"druh":"test_deska","x0":0,"polotloustka":0.001},"vysledek":{"material":"quartzite"}}]""", kat).Ok,
            "O2: těleso tlusté 2 mm projde validací");
    }

    // ---------- V1 bez zlomu ----------
    private const string V1Data = """
    [ {"id":"sedimentace","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":0,"material":"granite"},{"do_z":30,"material":"cave_limestone"},{"do_z":100,"material":"topsoil"}]}},
      {"id":"intruze","stari":10,"operace":"Vnikni","tvar":{"druh":"test_koule","stred":[0,0,10],"r":5},
       "pravidla":{"nahrazuje":{"skupiny":["vapenec"]}},"vysledek":{"material":"granite"}},
      {"id":"skarn","stari":20,"operace":"Transformuj","tvar":{"druh":"kontakt"},
       "pravidla":{"nahrazuje":{"materialy":["cave_limestone"]},
                   "kontakt":{"cil":{"udalosti":["intruze"]},"strana":"vne","sirka_m":1.5,"hostitel_okoli":{"materialy":["granite"],"hloubka_vzorku_m":0.125}}},
       "vysledek":{"mapa":{"cave_limestone":"skarn"}}},
      {"id":"zila","stari":30,"operace":"Vnikni","tvar":{"druh":"test_deska","x0":0,"polotloustka":0.2},
       "pravidla":{"nahrazuje":{"skupiny":["krystal","vapenec"]},"zdroje":{"vrstvy":true,"telesa":["intruze"],"transformace":true}},
       "vysledek":{"material":"quartzite"}},
      {"id":"metamorfoza","stari":40,"operace":"Transformuj","tvar":{"druh":"oblast"},
       "pravidla":{"nahrazuje":{"materialy":["skarn","cave_limestone"]},"hloubka":{"min_m":95}},"vysledek":{"mapa":{"skarn":"amphibolite","cave_limestone":"amphibolite"}}}
    ]
    """;

    private static void V1(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1: V1 bez zlomu (sedimentace → intruze → skarn → žíla), syntetické tvary");
        int Id(string k) => kat.PodleKlice(k)!.Id;
        var r = K(V1Data, kat, nikdy: new[] { "topsoil" });
        T.Je(r.Ok, "V1 se zkompiluje: " + string.Join("; ", r.Zprava.Chyby));
        if (!r.Ok) return;
        var c = r.Chronologie!; const double P = 100;
        int iInt = c.IndexUdalosti("intruze"), iSk = c.IndexUdalosti("skarn"), iZ = c.IndexUdalosti("zila"), iSed = c.IndexUdalosti("sedimentace");

        var vapenec = c.Bod(20, 0, 10, P);
        T.Je(vapenec.Material == Id("cave_limestone") && vapenec.GeoUdalost == iSed && vapenec.Vrstva == 1, "daleko: vápenec z vrstvy 1");
        var g = c.Bod(2, 3, 10, P);
        T.Je(g.Material == Id("granite") && g.GeoUdalost == iInt && g.GeoInstance == 1, "uvnitř intruze: granit, původ intruze");
        var sk2 = c.Bod(1, 5.4, 10, P);
        T.Je(sk2.Material == Id("skarn") && sk2.GeoUdalost == iSed && sk2.MaterialPuvodu == Id("cave_limestone") && sk2.PosledniTransformace == iSk && sk2.PocetTransformaci == 1,
            $"pásmo vně intruze: skarn, geometricky vrstva vápence, transformace skarn ({sk2})");
        var mimoPasmo = c.Bod(1, 7.5, 10, P);
        T.Je(mimoPasmo.Material == Id("cave_limestone"), "za šířkou 1,5 m: vápenec");
        var zilaVeSkarnu = c.Bod(0.1, 5.4, 10, P);
        T.Je(zilaVeSkarnu.Material == Id("quartzite") && zilaVeSkarnu.GeoUdalost == iZ && zilaVeSkarnu.PocetTransformaci == 0,
            "žíla v pásmu skarnu zůstane křemen (mladší než skarn)");
        T.Je(c.Bod(0.1, 2, 10, P).Material == Id("quartzite"), "žíla prochází starší intruzí (zdroje.telesa)");
        T.Je(c.Bod(0.1, 9, 10, P).Material == Id("quartzite"), "žíla ve vápenci");
        T.Je(c.Bod(0.1, 9, 50, P).Material == Id("topsoil"), "žíla nesmí do ornice (nikdy)");
        T.Je(c.Bod(0.1, 0, 120, P).Typ == TypProstoru.NadPovrchem, "nad povrchem: NadPovrchem");
        var pod = c.Bod(3, 0, -1, P);
        T.Je(pod.Material == Id("granite") && pod.GeoUdalost == iSed && pod.Vrstva == 0, "pod vápencem granit vrstvy 0, ne intruze");

        // metamorfóza (stáří 40, hloubka ≥ 95 m, výchozí zdroje.transformace = false): vápenec přemění, skarn ne (1.5)
        int iMet = c.IndexUdalosti("metamorfoza");
        var hlubokyVap = c.Bod(20, 0, 3, P);
        T.Je(hlubokyVap.Material == Id("amphibolite") && hlubokyVap.PosledniTransformace == iMet && hlubokyVap.MaterialPuvodu == Id("cave_limestone"),
            "metamorfóza v hloubce přemění vápenec, původ zůstane vrstva vápence");
        var hlubokySkarn = c.Bod(1, 0, 4, P);
        T.Je(hlubokySkarn.Material == Id("skarn") && hlubokySkarn.PocetTransformaci == 1, $"zdroje.transformace = false: skarn v hloubce zůstane ({hlubokySkarn})");
        T.Je(c.Bod(20, 0, 10, P).Material == Id("cave_limestone"), "nad hloubkou 95 m metamorfóza nepůsobí");

        // vypnutí mladší události nezmění body, kde zasahovala jen starší
        var bezZily = K(V1Data.Replace("{\"id\":\"zila\",\"stari\":30,", "{\"id\":\"zila\",\"stari\":30,\"aktivni\":false,"), kat, nikdy: new[] { "topsoil" }).Chronologie!;
        int rozdil = 0, neurceno = 0;
        for (double x = -9; x <= 9; x += 0.7) for (double y = -9; y <= 9; y += 0.7) for (double z = -3; z <= 32; z += 0.9)
        {
            var a = c.Bod(x, y, z, P); var b = bezZily.Bod(x, y, z, P);
            if (a.Typ == TypProstoru.Neurceno) neurceno++;
            if (a.GeoUdalost != iZ && (a.Material != b.Material || a.PocetTransformaci != b.PocetTransformaci)) rozdil++;
        }
        T.Je(rozdil == 0, $"vypnutí žíly nezmění body mimo žílu ({rozdil})");
        T.Je(neurceno == 0, "žádný bod pod povrchem Neurceno");
    }

    // ---------- prázdno: pravidlo cíle 2.3 ----------
    private static void Prazdno(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1: pravidlo cíle 2.3 (materiál → nahrazuje + zdroje, prázdno → jen prostor)");
        int Id(string k) => kat.PodleKlice(k)!.Id;
        string D(string dalsi) => """
        [ {"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":100,"material":"cave_limestone"}]}},
          {"id":"kras","stari":10,"operace":"Odstran","tvar":{"druh":"test_koule","stred":[0,0,50],"r":3},
           "pravidla":{"nahrazuje":{"skupiny":["vapenec"]},"hloubka":{"min_m":2}},"vysledek":{"prostor":"DutinaKras"}}DALSI ]
        """.Replace("DALSI", dalsi);
        var c = K(D(""), kat).Chronologie!;
        var d = c.Bod(0, 0, 50, 100);
        T.Je(d.Typ == TypProstoru.DutinaKras && d.Material == 0 && d.GeoUdalost == 1, "Odstran: krasová dutina, materiál 0");
        T.Je(K(D("").Replace("\"min_m\":2", "\"min_m\":60"), kat).Chronologie!.Bod(0, 0, 50, 100).Typ == TypProstoru.Pevne, "hloubka.min_m 60: dutina 50 m pod povrchem nevznikne");

        const string telo = ",{\"id\":\"teleso\",\"stari\":20,\"operace\":\"Vnikni\",\"tvar\":{\"druh\":\"test_koule\",\"stred\":[0,0,50],\"r\":10},\"pravidla\":{PRAV},\"vysledek\":{\"material\":\"granite\"}}";
        var bez = K(D(telo.Replace("PRAV", "\"nahrazuje\":\"*\"")), kat).Chronologie!;
        T.Je(bez.Bod(0, 0, 50, 100).Typ == TypProstoru.DutinaKras && bez.Bod(0, 0, 57, 100).Material == Id("granite"),
            "Vnikni bez prostor: dutinu nechá (výchozí), horninu kolem nahradí");
        var sp = K(D(telo.Replace("PRAV", "\"nahrazuje\":{\"materialy\":[\"granite\"]},\"prostor\":[\"DutinaKras\"]")), kat).Chronologie!;
        T.Je(sp.Bod(0, 0, 50, 100).Material == Id("granite") && sp.Bod(0, 0, 50, 100).Typ == TypProstoru.Pevne,
            "Vnikni s prostor DutinaKras vyplní dutinu, i když nahrazuje vápenec nepovoluje (nahrazuje se pro prázdno nečte)");
        T.Je(sp.Bod(0, 0, 57, 100).Material == Id("cave_limestone"), "…a pro materiál platí nahrazuje (vápenec nenahradí)");

        const string vypln = ",{\"id\":\"vypln\",\"stari\":30,\"operace\":\"Vypln\",\"tvar\":{\"druh\":\"test_koule\",\"stred\":[0,0,50],\"r\":10},\"pravidla\":{\"prostor\":[\"DutinaKras\"]},\"vysledek\":{\"material\":\"clay_deposit\"}}";
        var vy = K(D(vypln), kat).Chronologie!;
        var vb = vy.Bod(0, 0, 50, 100);
        T.Je(vb.Material == Id("clay_deposit") && vb.GeoOperace == Operace.Vypln, "Vypln vyplní krasovou dutinu");
        T.Je(vy.Bod(0, 0, 57, 100).Material == Id("cave_limestone"), "Vypln nezasáhne pevnou horninu");
        // těleso nesmí do tělesa se zdroje.telesa = zadna
        const string dve = ",{\"id\":\"a\",\"stari\":20,\"operace\":\"Vnikni\",\"tvar\":{\"druh\":\"test_koule\",\"stred\":[20,0,50],\"r\":3},\"vysledek\":{\"material\":\"granite\"}},{\"id\":\"b\",\"stari\":25,\"operace\":\"Vnikni\",\"tvar\":{\"druh\":\"test_koule\",\"stred\":[20,0,50],\"r\":5},\"vysledek\":{\"material\":\"kimberlite\"}}";
        var tt = K(D(dve), kat).Chronologie!;
        T.Je(tt.Bod(20, 0, 50, 100).Material == Id("granite") && tt.Bod(24, 0, 50, 100).Material == Id("kimberlite"),
            "zdroje.telesa výchozí \"zadna\": mladší těleso neprorazí starší, okolní vrstvy ano");
        var st = K(D(dve.Replace("\"r\":5},\"vysledek\"", "\"r\":5},\"pravidla\":{\"zdroje\":{\"telesa\":\"starsi\"}},\"vysledek\"")), kat).Chronologie!;
        T.Je(st.Bod(20, 0, 50, 100).Material == Id("kimberlite"), "zdroje.telesa \"starsi\": prorazí");
    }

    // ---------- pořadí v datech, determinismus ----------
    private static void PoradiADeterminismus(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1: pořadí v datech nemá význam, determinismus ve vláknech");
        var c = K(V1Data, kat, nikdy: new[] { "topsoil" }).Chronologie!;
        using var doc = JsonDocument.Parse(V1Data);
        var prvky = doc.RootElement.EnumerateArray().Select(e => e.GetRawText()).Reverse().ToArray();
        var obr = K("[" + string.Join(",", prvky) + "]", kat, nikdy: new[] { "topsoil" }).Chronologie!;
        var body = new List<(double, double, double)>();
        for (double x = -8; x <= 8; x += 0.37) for (double y = -8; y <= 8; y += 0.41) for (double z = -2; z <= 31; z += 1.3) body.Add((x, y, z));
        int neshod = body.Count(b => c.Bod(b.Item1, b.Item2, b.Item3, 100) != obr.Bod(b.Item1, b.Item2, b.Item3, 100));
        T.Je(neshod == 0, $"obrácené pořadí v souboru: {neshod} neshod z {body.Count}");
        var seriove = body.Select(b => c.Bod(b.Item1, b.Item2, b.Item3, 100)).ToArray();
        var paralelne = new StavBodu[body.Count];
        Parallel.For(0, body.Count, new ParallelOptions { MaxDegreeOfParallelism = 8 }, i => paralelne[i] = c.Bod(body[i].Item1, body[i].Item2, body[i].Item3, 100));
        T.Je(seriove.SequenceEqual(paralelne), "8 vláken = sériově");
        var hist = seriove.GroupBy(s => s.Material).ToDictionary(g => g.Key, g => g.Count());
        T.Je(hist.Count >= 4, $"vzorek obsahuje ≥ 4 materiály ({hist.Count})");
    }
}
