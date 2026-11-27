using System.Diagnostics;
using System.Text.Json;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K1b: kontaktní pásmo 2.5 na syntetických plochách (rovina vodorovná / šikmá, koule), modulace, strana,
/// hostitel_okoli prefixem, validace ploch; adaptéry staré cesty (VrstvySloupce, E84, sopky) a chyba d̃ na skutečných hranicích.
/// Srovnání celého bloku 128 m se starou cestou je zvlášť (<c>--jen=GEO2B</c>, <see cref="Blok"/>).
/// </summary>
public static class TestyGeo2K1b
{
    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        Rovina(kat);
        Modulace(kat);
        Strana(kat);
        Hostitel(kat);
        Telesa(kat);
        Validace(kat);
        Vlakna(kat);
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        Adaptery(kat, d);
        ChybaVzdalenosti(kat, d);
    }

    // ---------- syntetická rovina hranice: granit pod z = z0 + sx·x + sy·y, nahoře vápenec ----------
    private sealed class Rovina2 : ITvarZasobnikuSHranicemi
    {
        public double Z0 = 10, Sx, Sy; public int Dole, Nahore;
        public double H(double x, double y) => Z0 + Sx * x + Sy * y;
        public bool Vrstva(double x, double y, double z, out int m, out short v)
        { bool d = z < H(x, y); m = d ? Dole : Nahore; v = (short)(d ? 0 : 1); return true; }
        public IReadOnlyList<IntervalVrstvy> Sloupec(double x, double y) => new[] { new IntervalVrstvy(Dole, -1e9, H(x, y)), new IntervalVrstvy(Nahore, H(x, y), 1e9) };
    }
    private sealed class Polprostor : ITvar
    {
        public double XMax;
        public bool Obsahuje(double x, double y, double z, out uint i) { i = 3; return x < XMax; }
    }
    private sealed class Deska : ITvar { public bool Obsahuje(double x, double y, double z, out uint i) { i = 1; return false; } }

    private sealed class Tovarna : ITovarnaTvaru
    {
        private readonly KatalogGeo2 _k;
        public Tovarna(KatalogGeo2 k) => _k = k;
        private int Id(string s) => _k.PodleKlice(s)!.Id;
        public object? Vytvor(UdalostData u)
        {
            var t = u.Tvar;
            double D(string k, double v = 0) => t.TryGetProperty(k, out var e) ? e.GetDouble() : v;
            switch (u.TvarDruh)
            {
                case "rovina": return new Rovina2 { Z0 = D("z0", 10), Sx = D("sx"), Sy = D("sy"), Dole = Id("granite"), Nahore = Id("cave_limestone") };
                case "polprostor": return new Polprostor { XMax = D("x_max") };
                case "deska_bez_vzdalenosti": return new Deska();
                case "koule":
                    var s = t.GetProperty("stred");
                    return new TestyGeo2K1.Koule { X = s[0].GetDouble(), Y = s[1].GetDouble(), Z = s[2].GetDouble(), R = D("r"),
                        Mat = t.TryGetProperty("material", out var m) ? Id(m.GetString()!) : 0 };
                default: return null;
            }
        }
    }

    private const double P = 1000; // povrch syntetických testů
    private static VysledekKompilace K(string udalosti, KatalogGeo2 kat, string konfigurace = "") =>
        KompilatorChronologie.Kompiluj(UdalostiJson.Nacti(
            "{\"schema\":\"willage.udalosti.v2\",\"verze\":3" + konfigurace + ",\"udalosti\":[" + udalosti + "]}"), kat, new Tovarna(kat));

    private static string Uloz(double sx = 0, double sy = 0) =>
        "{\"id\":\"zasobnik\",\"stari\":0,\"operace\":\"Uloz\",\"tvar\":{\"druh\":\"rovina\",\"z0\":10,\"sx\":" + F(sx) + ",\"sy\":" + F(sy) + "}}";
    private static string F(double v) => v.ToString(System.Globalization.CultureInfo.InvariantCulture);

    private static string Skarn(string extra = "", string strana = "vne", string nahr = "[\"cave_limestone\"]", string mapa = "{\"cave_limestone\":\"skarn\"}",
        string host = "[\"granite\"]", int stari = 20, string cil = "\"vrstvy\":[\"granite\"]") =>
        "{\"id\":\"skarn\",\"stari\":" + stari + ",\"operace\":\"Transformuj\",\"tvar\":{\"druh\":\"kontakt\"},\"pravidla\":{\"nahrazuje\":{\"materialy\":" + nahr + "}," +
        "\"zdroje\":{\"vrstvy\":true,\"telesa\":\"zadna\",\"transformace\":false}," +
        "\"kontakt\":{\"cil\":{" + cil + "},\"strana\":\"" + strana + "\",\"sirka_m\":1.5" + extra + ",\"hostitel_okoli\":{\"materialy\":" + host + ",\"hloubka_vzorku_m\":0.125}}}," +
        "\"vysledek\":{\"mapa\":" + mapa + "}}";

    private static KontaktniPasmo Pasmo(ChronologieGeo2 c, string id) => (KontaktniPasmo)c.Udalosti[c.IndexUdalosti(id)].Kontakt!;

    private static void Rovina(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: kontakt na rovinu vrstev (d̃ eukleidovsky, ne svisle)");
        int skarn = kat.PodleKlice("skarn")!.Id, vap = kat.PodleKlice("cave_limestone")!.Id, gr = kat.PodleKlice("granite")!.Id;
        var r = K(Uloz() + "," + Skarn(), kat);
        T.Je(r.Ok, $"vodorovná hranice se zkompiluje ({r.Zprava})");
        var c = r.Chronologie!;
        T.Je(c.Bod(0.3, 0.7, 11.4, P).Material == skarn && c.Bod(0.3, 0.7, 11.6, P).Material == vap, "vodorovně: 1,4 m nad granitem skarn, 1,6 m ne");
        T.Je(c.Bod(0.3, 0.7, 9.0, P).Material == gr, "granit (cíl, strana vne) se nemění");
        var b = c.BodPred(1, 0.3, 0.7, 11.4, P);
        T.Je(b.Material == vap && c.Bod(0.3, 0.7, 11.4, P).MaterialPuvodu == vap && c.Bod(0.3, 0.7, 11.4, P).PosledniTransformace == 1,
            "skarn geometricky zůstává vrstvou vápence (původ vápenec, poslední transformace skarn)");

        var rs = K(Uloz(0.5, -0.25) + "," + Skarn(), kat);
        var cs = rs.Chronologie!; var pas = Pasmo(cs, "skarn");
        double n = Math.Sqrt(1 + 0.5 * 0.5 + 0.25 * 0.25), maxE = 0; var rnd = new Random(7);
        for (int i = 0; i < 400; i++)
        {
            double x = rnd.NextDouble() * 20 - 10, y = rnd.NextDouble() * 20 - 10, dz = rnd.NextDouble() * 1.8 + 0.05;
            double z = 10 + 0.5 * x - 0.25 * y + dz;
            if (!pas.Nejblizsi(x, y, z, out var bp)) { maxE = 1e9; break; }
            maxE = Math.Max(maxE, Math.Abs(bp.D - dz / n));
        }
        T.Je(maxE < 1e-9, $"šikmá rovina: |d̃ − d| < 1e-9 (max {maxE:E1}) – trojúhelníky rovinu vystihnou přesně");
        // svisle 1,6 m, eukleidovsky 1,6/1,146 = 1,397 m → skarn (stará cesta měřila svisle: ne)
        double x0 = 0.3, y0 = 0.2, z0 = 10 + 0.5 * x0 - 0.25 * y0 + 1.6;
        T.Je(cs.Bod(x0, y0, z0, P).Material == skarn, "šikmá: svisle 1,6 m, kolmo 1,40 m → skarn (měří se kolmo k ploše)");
        T.Je(cs.Bod(x0, y0, 10 + 0.5 * x0 - 0.25 * y0 + 1.75, P).Material == vap, "šikmá: kolmo 1,53 m → bez skarnu");
        T.Je(Math.Abs(pas.RMaxM - (1.5 + 0.125)) < 1e-12, $"R_max = w₀(1 + a) + e_k = 1,625 m pro a = 0 ({pas.RMaxM})");
    }

    private static void Modulace(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: modulace šířky w = w₀(1 + a·N(f·q))");
        int skarn = kat.PodleKlice("skarn")!.Id;
        var c = K(Uloz() + "," + Skarn(",\"modulace\":{\"amp_rel\":0.5,\"frekvence_1_m\":0.5}"), kat).Chronologie!;
        var pas = Pasmo(c, "skarn");
        T.Je(Math.Abs(pas.RMaxM - (1.5 * 1.5 + 0.125)) < 1e-12, $"R_max = 1,5 · 1,5 + 0,125 = 2,375 m ({pas.RMaxM})");
        var rnd = new Random(11); int vzdy = 0, nikdy = 0, mezi = 0, meziAno = 0, n = 3000; double wMin = 9, wMax = 0;
        for (int i = 0; i < n; i++)
        {
            double x = rnd.NextDouble() * 60 - 30, y = rnd.NextDouble() * 60 - 30, d = rnd.NextDouble() * 3.0 + 0.01, z = 10 + d;
            bool s = c.Bod(x, y, z, P).Material == skarn; double w = pas.Sirka(x, y, z);
            wMin = Math.Min(wMin, w); wMax = Math.Max(wMax, w);
            if (d <= 0.75) vzdy += s ? 0 : 1;
            else if (d > 2.25) nikdy += s ? 1 : 0;
            else { mezi++; if (s) meziAno++; }
            if (s != (d <= w)) { vzdy += 1000; break; }
        }
        T.Je(vzdy == 0 && nikdy == 0, $"d ≤ w₀(1−a) vždy skarn, d > w₀(1+a) nikdy, jinak přesně d ≤ w(q) (chyb {vzdy}/{nikdy})");
        T.Je(meziAno > 0 && meziAno < mezi && wMin >= 0.75 - 1e-12 && wMax <= 2.25 + 1e-12 && wMax - wMin > 0.5,
            $"šířka se mění s polohou: w ∈ [{wMin:F2}, {wMax:F2}] m, v mezipásmu skarn {meziAno}/{mezi}");
        var c2 = K(Uloz() + "," + Skarn(",\"modulace\":{\"amp_rel\":0.5,\"frekvence_1_m\":0.5}"), kat).Chronologie!;
        T.Je(Pasmo(c2, "skarn").Sirka(3.3, 4.4, 11) == pas.Sirka(3.3, 4.4, 11), "seed šumu z id události: stejná data = stejná šířka");
    }

    private static void Strana(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: strana vne / uvnitr / obe");
        int vap = kat.PodleKlice("cave_limestone")!.Id, gr = kat.PodleKlice("granite")!.Id, og = kat.PodleKlice("orthogneiss")!.Id, sk = kat.PodleKlice("skarn")!.Id;
        var u = K(Uloz() + "," + Skarn(strana: "uvnitr", nahr: "[\"granite\"]", mapa: "{\"granite\":\"orthogneiss\"}", host: "[\"cave_limestone\"]"), kat);
        T.Je(u.Ok, $"uvnitr se zkompiluje ({u.Zprava})");
        var c = u.Chronologie!;
        T.Je(c.Bod(1, 1, 8.8, P).Material == og && c.Bod(1, 1, 8.3, P).Material == gr && c.Bod(1, 1, 10.5, P).Material == vap,
            "uvnitr: granit 1,2 m pod hranicí přeměněn, 1,7 m ne, vápenec beze změny");
        var o = K(Uloz() + "," + Skarn(strana: "obe", nahr: "[\"granite\",\"cave_limestone\"]", mapa: "{\"granite\":\"orthogneiss\",\"cave_limestone\":\"skarn\"}",
            host: "[\"granite\",\"cave_limestone\"]"), kat).Chronologie!;
        T.Je(o.Bod(1, 1, 8.8, P).Material == og && o.Bod(1, 1, 11.2, P).Material == sk && o.Bod(1, 1, 12, P).Material == vap, "obe: obě strany v pásmu");
    }

    private static void Hostitel(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: hostitel_okoli prefixem (stav těsně před kontaktem)");
        int vap = kat.PodleKlice("cave_limestone")!.Id, sk = kat.PodleKlice("skarn")!.Id, og = kat.PodleKlice("orthogneiss")!.Id;
        string meta(int stari, double xMax) => "{\"id\":\"meta" + stari + "\",\"stari\":" + stari + ",\"operace\":\"Transformuj\",\"tvar\":{\"druh\":\"polprostor\",\"x_max\":" + xMax + "}," +
            "\"pravidla\":{\"nahrazuje\":{\"materialy\":[\"granite\"]},\"zdroje\":{\"vrstvy\":true,\"telesa\":\"zadna\",\"transformace\":false}},\"vysledek\":{\"mapa\":{\"granite\":\"orthogneiss\"}}}";
        var rh = K(Uloz() + "," + meta(10, 0) + "," + Skarn(), kat);
        T.Je(rh.Ok, $"starší přeměna + skarn se zkompiluje ({rh.Zprava})");
        if (!rh.Ok) return;
        var c = rh.Chronologie!;
        T.Je(c.Bod(-3, 0, 10.5, P).Material == vap && c.Bod(3, 0, 10.5, P).Material == sk,
            "granit přeměněný STARŠÍ transformací (x < 0) skarn nevytvoří, nepřeměněný (x > 0) ano");
        var m = c.Bod(-3, 0, 10.5, P);
        T.Je(c.Bod(-3, 0, 9, P).Material == og && m.PocetTransformaci == 0, "rula zůstává v cíli geometricky (původ vrstva granitu), ale hostitel neplatí");
        var c2 = K(Uloz() + "," + Skarn() + "," + meta(30, 1e9), kat).Chronologie!;
        T.Je(c2.Bod(3, 0, 10.5, P).Material == sk && c2.Bod(3, 0, 9, P).Material == og, "MLADŠÍ přeměna granitu skarn neovlivní (prefix)");
        string dutina = """{"id":"dutina","stari":10,"operace":"Odstran","tvar":{"druh":"koule","stred":[5,0,9.4],"r":0.8},"pravidla":{"nahrazuje":{"materialy":["granite"]},"hloubka":{"min_m":0}},"vysledek":{"prostor":"DutinaJina"}}""";
        var r3 = K(Uloz() + "," + dutina + "," + Skarn(), kat);
        T.Je(r3.Ok, $"dutina + skarn se zkompiluje ({r3.Zprava})");
        if (!r3.Ok) return;
        var c3 = r3.Chronologie!;
        T.Je(c3.Bod(5, 0, 10.4, P).Material == vap && c3.Bod(9, 0, 10.4, P).Material == sk, "dutina na kontaktu (q′ v dutině) skarn nevytvoří, o kus dál ano");
    }

    private static void Telesa(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: kontakt na těleso (cil.udalosti) a sjednocení s vrstvami");
        int vap = kat.PodleKlice("cave_limestone")!.Id, sk = kat.PodleKlice("skarn")!.Id;
        string ulozVap = """{"id":"zasobnik","stari":0,"operace":"Uloz","tvar":{"druh":"rovina","z0":-50}}""";
        string intr = """{"id":"intruze","stari":10,"operace":"Vnikni","tvar":{"druh":"koule","stred":[0,0,20],"r":5},"pravidla":{"nahrazuje":"*","prostor":[]},"vysledek":{"material":"granite"}}""";
        var c = K(ulozVap + "," + intr + "," + Skarn(cil: "\"udalosti\":[\"intruze\"]"), kat).Chronologie!;
        double k = 1 / Math.Sqrt(3);
        T.Je(c.Bod(6.4 * k, 6.4 * k, 20 + 6.4 * k, P).Material == sk && c.Bod(6.6 * k, 6.6 * k, 20 + 6.6 * k, P).Material == vap,
            "šikmo od koule: 1,4 m skarn, 1,6 m ne (eukleidovsky)");
        var cu = K(Uloz() + "," + intr.Replace("[0,0,20]", "[0,0,30]") + "," + Skarn(cil: "\"vrstvy\":[\"granite\"],\"udalosti\":[\"intruze\"]"), kat).Chronologie!;
        T.Je(cu.Bod(0, 0, 24.2, P).Material == sk && cu.Bod(20, 0, 11.2, P).Material == sk && cu.Bod(20, 0, 12, P).Material == vap,
            "víc cílů = jedna plocha: skarn pod koulí i nad vrstvou granitu, rozhoduje nejbližší");
    }

    private static void Validace(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: validace kontaktu (bez zástupného KONTAKT_K1B)");
        var t = K(Uloz() + "," + Skarn(), kat, ",\"konfigurace\":{\"tau_m\":0.2}");
        T.Je(!t.Ok && t.Zprava.Obsahuje("KONTAKT_TAU"), "τ > e_k u kontaktu na vrstvy = KONTAKT_TAU (2.5: MUSÍ platit τ ≤ e_k)");
        string desk = """{"id":"deska","stari":10,"operace":"Vnikni","tvar":{"druh":"deska_bez_vzdalenosti"},"pravidla":{"nahrazuje":"*","prostor":[]},"vysledek":{"material":"granite"}}""";
        var b = K(Uloz() + "," + desk + "," + Skarn(cil: "\"udalosti\":[\"deska\"]"), kat);
        T.Je(!b.Ok && b.Zprava.Obsahuje("KONTAKT_CIL_BEZ_VZDALENOSTI"), "cíl bez vzdálenosti k primitivu = KONTAKT_CIL_BEZ_VZDALENOSTI");
        var na = K(Uloz() + "," + desk.Replace("\"stari\":10,", "\"stari\":10,\"aktivni\":false,") + "," + Skarn(cil: "\"udalosti\":[\"deska\"]"), kat);
        T.Je(!na.Ok && na.Zprava.Obsahuje("KONTAKT_CIL") && na.Zprava.Obsahuje("ODKAZ_NEAKTIVNI"), "jen neaktivní cíl = KONTAKT_CIL (+ varování ODKAZ_NEAKTIVNI)");
        T.Je(!K(Uloz() + "," + Skarn(), kat).Zprava.Hlaseni.Any(h => h.Kod.StartsWith("KONTAKT_")), "platný kontakt bez hlášení KONTAKT_*");
    }

    private static void Vlakna(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K1b: kontakt ve vláknech (sdílená plocha vrstev)");
        var c = K(Uloz(0.3, 0.1) + "," + Skarn(",\"modulace\":{\"amp_rel\":0.5,\"frekvence_1_m\":0.5}"), kat).Chronologie!;
        var body = Enumerable.Range(0, 4000).Select(i => (x: (i % 63) * 0.37 - 11, y: (i / 63) * 0.41 - 13, z: 10 + (i % 17) * 0.2)).ToArray();
        var a = body.Select(p => c.Bod(p.x, p.y, p.z + 0.3 * p.x + 0.1 * p.y, P)).ToArray();
        var c2 = K(Uloz(0.3, 0.1) + "," + Skarn(",\"modulace\":{\"amp_rel\":0.5,\"frekvence_1_m\":0.5}"), kat).Chronologie!;
        var b = new StavBodu[body.Length];
        Parallel.For(0, body.Length, new ParallelOptions { MaxDegreeOfParallelism = 8 }, i => b[i] = c2.Bod(body[i].x, body[i].y, body[i].z + 0.3 * body[i].x + 0.1 * body[i].y, P));
        T.Je(a.SequenceEqual(b), "8 vláken = 1 vlákno (paměť uzlů je čistá funkce)");
    }

    // ---------- skutečný svět: adaptéry staré cesty ----------
    internal static (ChronologieGeo2 c, VysledekKompilace r, TovarnaE84 t) E84(GeologieCs g, KatalogGeo2 kat, DataSveta d, double krok = 0.5, string? jen = null)
    {
        var json = SadaE84.Json(d);
        if (jen is not null)
        {
            var doc = System.Text.Json.Nodes.JsonNode.Parse(json)!;
            var ud = doc["udalosti"]!.AsArray();
            var keep = jen.Split(',');
            for (int i = ud.Count - 1; i >= 0; i--) if (!keep.Contains(ud[i]!["id"]!.GetValue<string>())) ud.RemoveAt(i);
            json = doc.ToJsonString();
        }
        var t = new TovarnaE84(g.Geo);
        var r = KompilatorChronologie.Kompiluj(UdalostiJson.Nacti(json), kat, t, new MoznostiKompilace(krok));
        return (r.Chronologie!, r, t);
    }

    private static void Adaptery(KatalogGeo2 kat, DataSveta d)
    {
        T.Sekce("GEO2 K1b: adaptéry VrstvySloupce / E84 / sopky (jen čtení staré cesty)");
        var g = new GeologieCs(new ParametrySveta(), d);
        var (c, r, _) = E84(g, kat, d);
        T.Je(r.Ok, $"sada E84 v GEO2 (8 událostí z utvary_hostitele.json) se zkompiluje ({string.Join("; ", r.Zprava.Chyby)})");
        T.Je(r.Zprava.Obsahuje("SOUROZENCI_PARITA"), "tělesa E84: sourozenci nejmensi_sdf = parita, s varováním");
        var (cz, _, _) = E84(g, kat, d, jen: "zasobnik");
        int shod = 0, n = 0;
        for (int i = 0; i < 6; i++)
        {
            double x = 13.37 + 41.3 * i, y = -7.9 + 29.1 * i;
            var old = g.Geo.VyplnSloupecRezim(x, y, 0.25, 128, GeoVrstvy.RezimSloupce.JenVrstvy);
            for (int iz = 0; iz < old.Length; iz++) { n++; if ((byte)cz.Bod(x, y, (iz + 0.5) * 0.25).Material == old[iz]) shod++; }
        }
        T.Je(shod == n, $"jen zásobník = stará cesta „jen vrstvy“ bitově ({shod}/{n} buněk)");
        // zásobník + sopka = stará cesta bez útvarů: sopka ≥ 0 ? sopka : vrstva
        var sopky = g.Svet.Sopky.Seznam;
        T.Je(sopky.Count > 0, $"svět má sopky ({sopky.Count})");
        if (sopky.Count > 0)
        {
            var (cs, _, _) = E84(g, kat, d, jen: "zasobnik,sopka");
            int s2 = 0, n2 = 0, vNitru = 0;
            for (int i = 0; i < 25; i++)
            {
                double x = sopky[0].X + (i % 5 - 2) * sopky[0].R * 0.2, y = sopky[0].Y + (i / 5 - 2) * sopky[0].R * 0.2;
                var w = g.Svet.Vahy(x, y); double zPov = g.Svet.VyskaW(x, y, w);
                var hr = g.Geo.Hranice(x, y);
                for (int iz = 0; iz < 512; iz++)
                {
                    double z = (iz + 0.5) * 0.25; n2++;
                    int sm = z > zPov ? -1 : g.Geo.Sopky.Mat(x, y, z);
                    int ocek = z > zPov ? 0 : sm >= 0 ? sm : VrstvySloupce.VrstvaMat(z, hr);
                    if (sm >= 0) vNitru++;
                    if (cs.Bod(x, y, z).Material == ocek) s2++;
                }
            }
            T.Je(s2 == n2 && vNitru > 0, $"zásobník + sopka = stará skladba sopka ≥ 0 ? sopka : vrstva ({s2}/{n2}, v nitru {vNitru})");
        }
    }

    /// <summary>Chyba d̃ plochy vrstev s krokem g proti jemné referenci (g = 0,125 m) na skutečných hranicích granitoidů.</summary>
    private static void ChybaVzdalenosti(KatalogGeo2 kat, DataSveta d)
    {
        T.Sekce("GEO2 K1b: chyba d̃ na skutečných hranicích VrstvySloupce (měření)");
        var g = new GeologieCs(new ParametrySveta(), d);
        var zas = new ZasobnikVrstvySloupce(g.Geo);
        var cil = SadaE84.Granitoidy.Select(k => kat.PodleKlice(k)!.Id).ToArray();
        var refP = new PlochaVrstev(zas, cil, kat.MaxId, 0.125);
        var body = new List<(double x, double y, double z)>();
        var rnd = new Random(5);
        for (int t = 0; t < 4000 && body.Count < 150; t++)
        {
            double x = rnd.NextDouble() * 512, y = rnd.NextDouble() * 512;
            var u = refP.Uzel((long)Math.Floor(x / 0.125), (long)Math.Floor(y / 0.125));
            for (int k = 0; k < u.Length; k++) if (u[k] > 1e-9) { body.Add((x, y, u[k] + (rnd.NextDouble() * 4 - 2))); break; }
        }
        T.Je(body.Count >= 100, $"nalezeno {body.Count} bodů do 2 m od hranice granitoidu");
        foreach (double krok in new[] { 1.0, 0.5, 0.25 })
        {
            var p = new PlochaVrstev(zas, cil, kat.MaxId, krok);
            var chyby = new List<double>(); int jenJedna = 0;
            foreach (var (x, y, z) in body)
            {
                bool a = p.Nejblizsi(x, y, z, 2.375, out var bp), b = refP.Nejblizsi(x, y, z, 2.375, out var br);
                if (a && b) chyby.Add(Math.Abs(bp.D - br.D)); else if (a != b) jenJedna++;
            }
            chyby.Sort();
            double p99 = chyby.Count == 0 ? 0 : chyby[(int)(0.99 * (chyby.Count - 1))], mx = chyby.Count == 0 ? 0 : chyby[^1], med = chyby.Count == 0 ? 0 : chyby[chyby.Count / 2];
            Console.WriteLine($"  g = {krok} m: |d̃ − d̃ref| medián {med:F3}, p99 {p99:F3}, max {mx:F3} m; jen jedna plocha v dosahu {jenJedna}; nespárovaných trojúhelníků {p.Nesparovanych}");
            T.Je(chyby.Count > 0, $"g = {krok} m změřeno ({chyby.Count} bodů)");
        }
    }

    // ---------- blok 128 m: GEO2 × stará cesta ----------
    public static void Blok(string data, double ox, double oy, int vlaken, double krokXy = 1.0, double krokMrizky = 0.5)
    {
        T.Sekce($"GEO2 K1b: blok 128 × 128 m od ({ox}, {oy}), sloupce po {krokXy} m, z po 0,25 m, {vlaken} vláken, mřížka hranic {krokMrizky} m");
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g0 = new GeologieCs(new ParametrySveta(), d);
        int n = (int)Math.Round(128 / krokXy); const int nz = 512;
        var stary = new byte[(long)n * n * nz]; var novy = new byte[stary.Length]; var typ = new byte[stary.Length];
        var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        var sw = Stopwatch.StartNew();
        Parallel.For(0, n, opt, () => g0.Klon(), (ix, _, g) =>
        {
            for (int iy = 0; iy < n; iy++)
            {
                var s = g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, 0.25, 128.0);
                Array.Copy(s, 0, stary, ((long)ix * n + iy) * nz, nz);
            }
            return g;
        }, _ => { });
        double tStary = sw.Elapsed.TotalSeconds; sw.Restart();
        long nesp = 0;
        Parallel.For(0, n, opt, () => { var g = g0.Klon(); return (g, E84(g, kat, d, krokMrizky).c); }, (ix, _, st) =>
        {
            var (g, c) = st;
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy, zPov = c.Povrch!(x, y);
                long o = ((long)ix * n + iy) * nz;
                for (int iz = 0; iz < nz; iz++)
                {
                    var b = c.BodPred(c.Udalosti.Count, x, y, (iz + 0.5) * 0.25, zPov);
                    novy[o + iz] = (byte)b.Material; typ[o + iz] = (byte)b.Typ;
                }
            }
            return st;
        }, st => { var p = (PlochaVrstev)((KontaktniPasmo)st.c.Udalosti[1].Kontakt!).Plochy[0]; Interlocked.Add(ref nesp, p.Nesparovanych); });
        double tNovy = sw.Elapsed.TotalSeconds;

        long celkem = stary.Length, shoda = 0, pevnych = 0;
        var rozdily = new Dictionary<(int s, int n), long>(); var pocS = new long[256]; var pocN = new long[256];
        for (long i = 0; i < celkem; i++)
        {
            pocS[stary[i]]++; pocN[novy[i]]++;
            if (stary[i] == novy[i]) shoda++;
            else { var k = (stary[i], (int)novy[i]); rozdily[k] = rozdily.GetValueOrDefault(k) + 1; }
            if (typ[i] == (byte)TypProstoru.Pevne) pevnych++;
        }
        string M(int id) => kat.PodleId(id)?.Klic ?? id.ToString();
        Console.WriteLine($"  buněk {celkem:N0}, shoda {100.0 * shoda / celkem:F3} % ({celkem - shoda:N0} rozdílných), pevných v GEO2 {pevnych:N0}");
        Console.WriteLine($"  čas: stará cesta {tStary:F1} s, GEO2 {tNovy:F1} s (×{tNovy / Math.Max(tStary, 1e-9):F1}); nespárovaných trojúhelníků {nesp:N0}");
        foreach (int id in new[] { 42, 38, 8, 9, 21, 47, 0, 75 })
            Console.WriteLine($"  {M(id),-16} stará {pocS[id],10:N0}   GEO2 {pocN[id],10:N0}");
        Console.WriteLine("  největší rozdíly (stará → GEO2):");
        foreach (var kv in rozdily.OrderByDescending(k => k.Value).Take(12))
            Console.WriteLine($"    {M(kv.Key.s),-16} → {M(kv.Key.n),-16} {kv.Value,10:N0}");
        T.Je(shoda > celkem * 0.9, $"blok: shoda > 90 % ({100.0 * shoda / celkem:F2} %)");
    }
}
