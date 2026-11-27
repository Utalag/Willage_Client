using System.Runtime.CompilerServices;
using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K2: zápis vzorku podle tabulky 3.1 a jejích příkladů, V1 (pole), kompaktní Vzorek, příznak HraniceOdhad,
/// Historie(p) s invariantem, typ prostoru pro vodu (dutina × vzduch bez povrchu) a překryv výkopů.
/// </summary>
public static class TestyGeo2K2
{
    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var d = DataSveta.Najdi(AppContext.BaseDirectory);
        Zapis31(kat);
        V1Pole(kat);
        VzorekKompaktni(kat);
        var g = new GeologieCs(new ParametrySveta(), d);
        var (c, _, _) = TestyGeo2K1b.E84(g, kat, d);
        Priznaky(kat, c);
        Historie(kat, c);
        Voda(kat, g, c);
    }

    private static int Id(KatalogGeo2 k, string s) => k.PodleKlice(s)!.Id;

    private const string Sada31 = """
    [ {"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":10,"material":"granite"},{"do_z":100,"material":"cave_limestone"}]}},
      {"id":"intruze","stari":5,"operace":"Vnikni","tvar":{"druh":"test_koule","stred":[20,0,50],"r":4},"pravidla":{"nahrazuje":{"skupiny":["vapenec"]},"prostor":[]},"vysledek":{"material":"granite"}},
      {"id":"kras","stari":10,"operace":"Odstran","tvar":{"druh":"test_koule","stred":[0,0,50],"r":3},"pravidla":{"nahrazuje":{"skupiny":["vapenec"]},"hloubka":{"min_m":2}},"vysledek":{"prostor":"DutinaKras"}},
      {"id":"sopka","stari":20,"operace":"Vnikni","tvar":{"druh":"test_koule","stred":[0,0,50],"r":1.5},"pravidla":{"nahrazuje":"*","prostor":["DutinaKras"]},"vysledek":{"material":"kimberlite"}},
      {"id":"vyplen","stari":30,"operace":"Vypln","tvar":{"druh":"test_koule","stred":[0,0,50],"r":2.5},"pravidla":{"prostor":["DutinaKras"]},"vysledek":{"material":"clay_deposit"}},
      {"id":"tr1","stari":40,"operace":"Transformuj","tvar":{"druh":"oblast"},"pravidla":{"nahrazuje":{"materialy":["granite"]},"zdroje":{"vrstvy":true,"telesa":"starsi","transformace":true}},"vysledek":{"mapa":{"granite":"orthogneiss"}}},
      {"id":"tr2","stari":50,"operace":"Transformuj","tvar":{"druh":"oblast"},"pravidla":{"nahrazuje":{"materialy":["orthogneiss"]},"zdroje":{"vrstvy":true,"telesa":"starsi","transformace":true}},"vysledek":{"mapa":{"orthogneiss":"migmatite"}}}
    ]
    """;

    private static void Zapis31(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K2: zápis vzorku podle tabulky 3.1");
        var r = TestyGeo2K1.K(Sada31, kat);
        T.Je(r.Ok, $"sada 3.1 se zkompiluje ({r.Zprava})");
        if (!r.Ok) return;
        var c = r.Chronologie!; const double P = 100;
        int I(string id) => c.IndexUdalosti(id);
        var vr = c.Bod(5, 5, 60, P);
        T.Je(vr.Material == Id(kat, "cave_limestone") && vr.GeoUdalost == I("z") && vr.Vrstva == 1 && vr.MaterialPuvodu == vr.Material
             && vr.HostitelPuvodu == -1 && vr.TypHostitele == TypProstoru.Neurceno && vr.PosledniTransformace == -1, $"Uloz: vrstva, původ = materiál, hostitel žádný ({vr})");
        var vz = Vzorek.Z(vr);
        T.Je(vz.HostitelPuvodu == Vzorek.Zadna && vz.PosledniTransformace == Vzorek.Zadna, "Uloz ve Vzorku: HostitelPuvodu = 0xFFFF, PosledniTransformace = 0xFFFF");
        var du = c.Bod(2.8, 0, 50, P);
        T.Je(du.Material == 0 && du.Typ == TypProstoru.DutinaKras && du.GeoUdalost == I("kras") && du.MaterialPuvodu == 0
             && du.HostitelPuvodu == Id(kat, "cave_limestone") && du.TypHostitele == TypProstoru.Pevne, $"Odstran (krasová dutina): 0, DutinaKras, hostitel vápenec / Pevne ({du})");
        var la = c.Bod(0, 0, 50, P);
        T.Je(la.Material == Id(kat, "kimberlite") && la.GeoUdalost == I("sopka") && la.MaterialPuvodu == la.Material
             && la.HostitelPuvodu == 0 && la.TypHostitele == TypProstoru.DutinaKras, $"Vnikni do dutiny (láva v dutině): hostitel 0 / DutinaKras ({la})");
        var jl = c.Bod(2.0, 0, 50, P);
        T.Je(jl.Material == Id(kat, "clay_deposit") && jl.GeoOperace == Operace.Vypln && jl.HostitelPuvodu == 0 && jl.TypHostitele == TypProstoru.DutinaKras,
            $"Vypln (jílová výplň): hostitel 0 / DutinaKras ({jl})");
        var it = c.Bod(20, 0, 50, P);
        T.Je(it.Material == Id(kat, "migmatite") && it.GeoUdalost == I("intruze") && it.MaterialPuvodu == Id(kat, "granite")
             && it.HostitelPuvodu == Id(kat, "cave_limestone") && it.TypHostitele == TypProstoru.Pevne
             && it.PosledniTransformace == I("tr2") && it.PocetTransformaci == 2, $"Vnikni do horniny + 2× Transformuj: původ granit, hostitel vápenec, poslední tr2, počet 2 ({it})");
        var gr = c.Bod(5, 5, 5, P);
        T.Je(gr.Material == Id(kat, "migmatite") && gr.GeoUdalost == I("z") && gr.MaterialPuvodu == Id(kat, "granite") && gr.HostitelPuvodu == -1 && gr.PocetTransformaci == 2,
            "Transformuj nemění geometrický původ ani hostitele (vrstva granitu → migmatit)");
        T.Je(c.Bod(5, 5, 120, P) == StavBodu.NadPovrchem && Vzorek.Z(c.Bod(5, 5, 120, P)).GeoUdalost == Vzorek.Zadna, "nad povrchem: NadPovrchem, GeoUdalost 0xFFFF");
    }

    private static void V1Pole(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K2: V1 – všechna pole 3.1 (příklady kontraktu)");
        var c = TestyGeo2K1.K(TestyGeo2K1.V1Data, kat, nikdy: new[] { "topsoil" }).Chronologie!; const double P = 100;
        int iS = c.IndexUdalosti("skarn"), iZ = c.IndexUdalosti("zila"), iSed = c.IndexUdalosti("sedimentace");
        var sk = c.Bod(1, 5.4, 10, P);
        T.Je(sk.Material == Id(kat, "skarn") && sk.GeoUdalost == iSed && sk.MaterialPuvodu == Id(kat, "cave_limestone") && sk.HostitelPuvodu == -1
             && sk.PosledniTransformace == iS && sk.PocetTransformaci == 1, $"skarn na kontaktu: vrstva vápence, původ vápenec, hostitel – , skarn 1× ({sk})");
        var zs = c.Bod(0.1, 5.4, 10, P);
        T.Je(zs.Material == Id(kat, "quartzite") && zs.GeoUdalost == iZ && zs.MaterialPuvodu == zs.Material && zs.HostitelPuvodu == Id(kat, "skarn")
             && zs.TypHostitele == TypProstoru.Pevne && zs.PosledniTransformace == -1, $"žíla v pásmu skarnu: křemen, HostitelPuvodu = skarn (V1) ({zs})");
        var zg = c.Bod(0.1, 0, 10, P);
        T.Je(zg.Material == Id(kat, "quartzite") && zg.HostitelPuvodu == Id(kat, "granite"), "žíla v granitu: HostitelPuvodu = granit");
        int neurc = 0;
        for (double x = -12; x <= 12; x += 0.7) for (double z = -40; z < P; z += 0.9) if (c.Bod(x, 3.3, z, P).Typ == TypProstoru.Neurceno) neurc++;
        T.Je(neurc == 0, $"žádný bod pod povrchem Neurceno ({neurc})");
    }

    private static void VzorekKompaktni(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K2: kompaktní Vzorek");
        int vel = Vzorek.Velikost, velStav = Unsafe.SizeOf<StavBodu>();
        Console.WriteLine($"  Vzorek {vel} B (Unsafe {Unsafe.SizeOf<Vzorek>()} B), pracovní StavBodu {velStav} B, dnešní sloupec 1 B na buňku");
        T.Je(vel == 20 && Unsafe.SizeOf<Vzorek>() == 20, $"Vzorek = 20 B (2+1+2+4+2+2+2+1+2+1+1), bez výplně");
        var c = TestyGeo2K1.K(Sada31, kat).Chronologie!;
        int ok = 0, n = 0;
        for (double x = -4; x <= 24; x += 0.5) for (double z = -5; z < 110; z += 1.5)
        {
            var s = c.Bod(x, 0.3, z, 100); n++;
            if (Vzorek.Z(s).NaStav(s.GeoOperace) == s) ok++;
        }
        T.Je(ok == n, $"StavBodu → Vzorek → StavBodu beze ztráty ({ok}/{n})");
        bool pret = false;
        try { _ = Vzorek.Z(StavBodu.Neurceno with { Material = 70000 }); } catch (OverflowException) { pret = true; }
        T.Je(pret, "id ≥ 0xFFFF = výjimka, ne tiché zkrácení");
    }

    private static void Priznaky(KatalogGeo2 kat, ChronologieGeo2 e84)
    {
        T.Sekce("GEO2 K2: příznak HraniceOdhad");
        var c = TestyGeo2K1.K(TestyGeo2K1.V1Data, kat, nikdy: new[] { "topsoil" }).Chronologie!;
        int sp = 0;
        for (double x = -8; x <= 8; x += 0.3) for (double z = 3; z < 18; z += 0.3) if ((c.Bod(x, 2, z, 100).Priznaky & PriznakyVzorku.HraniceOdhad) != 0) sp++;
        T.Je(sp == 0, "přesná plocha (koule): žádný bod s HraniceOdhad");
        int iSk = e84.IndexUdalosti("skarn_kontakt"); long skarnu = 0, odhad = 0, mimo = 0;
        for (int ix = 0; ix < 64; ix++) for (int iy = 0; iy < 64; iy++)
        {
            double x = 1024 + ix * 2 + 0.5, y = 512 + iy * 2 + 0.5, zp = e84.Povrch!(x, y);
            for (double z = 0.125; z < Math.Min(zp, 128); z += 0.25)
            {
                var s = e84.BodPred(e84.Udalosti.Count, x, y, z, zp);
                bool o = (s.Priznaky & PriznakyVzorku.HraniceOdhad) != 0;
                if (s.PosledniTransformace == iSk) { skarnu++; if (o) odhad++; }
                else if (o) mimo++;
            }
        }
        Console.WriteLine($"  blok (1024, 512) po 2 m: bodů se skarnem {skarnu:N0}, z toho s HraniceOdhad {odhad:N0} ({100.0 * odhad / Math.Max(skarnu, 1):F2} %)");
        T.Je(skarnu > 0 && mimo == 0, $"HraniceOdhad jen u bodů, které změnil kontakt ({mimo} jinde)");
    }

    private static void Historie(KatalogGeo2 kat, ChronologieGeo2 c)
    {
        T.Sekce("GEO2 K2: Historie(p) jako přepočet");
        var rnd = new Random(3); int n = 0, ok = 0, okPocet = 0, viceTr = 0;
        for (int i = 0; i < 12000; i++)
        {
            double x = rnd.NextDouble() < 0.5 ? 1024 + rnd.NextDouble() * 128 : rnd.NextDouble() * 4096, y = 512 + rnd.NextDouble() * 4096, zp = c.Povrch!(x, y), z = rnd.NextDouble() * Math.Min(zp + 3, 128);
            var b = c.BodPred(c.Udalosti.Count, x, y, z, zp);
            var h = c.Historie(x, y, z, zp); n++;
            if (h.Count == 0 ? (b == StavBodu.NadPovrchem || b == StavBodu.Neurceno) : h[^1].Po == b) ok++;
            int tr = 0; for (int k = h.Count - 1; k >= 0 && h[k].Operace == Operace.Transformuj; k--) tr++;
            if (tr == b.PocetTransformaci) okPocet++;
            if (b.PocetTransformaci > 1) viceTr++;
            for (int k = 1; k < h.Count; k++) if (h[k].Pred != h[k - 1].Po) { ok = -1_000_000; break; }
        }
        T.Je(ok == n, $"poslední krok == Bod a kroky na sebe navazují ({ok}/{n})");
        T.Je(okPocet == n, $"transformace na konci historie = PocetTransformaci ({okPocet}/{n})");
        var s = TestyGeo2K1.K(Sada31, kat).Chronologie!;
        var hs = s.Historie(20, 0, 50, 100);
        T.Je(hs.Select(k => k.Udalost).SequenceEqual(new[] { "z", "intruze", "tr1", "tr2" }) && hs[1].MaterialPred == Id(kat, "cave_limestone")
             && hs[3].MaterialPo == Id(kat, "migmatite") && hs[3].TypPo == TypProstoru.Pevne,
            $"historie bodu intruze: z → intruze → tr1 → tr2 ({string.Join(" → ", hs.Select(k => k.Udalost))})");
        Console.WriteLine($"  skutečný svět: bodů s PocetTransformaci > 1: {viceTr}");
    }

    private sealed class Krychle : IVykopy
    {
        public double X0, X1, Y0, Y1, Z0, Z1;
        public bool Vykopano(double x, double y, double z) => x >= X0 && x < X1 && y >= Y0 && y < Y1 && z >= Z0 && z < Z1;
    }

    private static void Voda(KatalogGeo2 kat, GeologieCs g, ChronologieGeo2 c)
    {
        T.Sekce("GEO2 K2: typ prostoru pro vodu (dutina × vzduch bez povrchu), výkopy");
        var vz = new VzorkovacGeo2(c);
        const int nz = 512; var sl = new Vzorek[nz]; var mat = new byte[nz]; var tr = new TridaVody[nz];
        int sloupcu = 0; long dutin = 0, shoda = 0, buněk = 0, horni = 0, chybaTypu = 0;
        var rv = new Random(17);
        for (int i = 0; i < 20000 && sloupcu < 40; i++)
        {
            double x = rv.NextDouble() * 4096, y = rv.NextDouble() * 4096;
            var stary = g.Geo.VyplnSloupec(x, y, 0.25, 128.0);
            double pov = g.Povrch(x, y); int kTop = Math.Min(nz - 1, (int)Math.Floor((pov - 1e-9) / 0.25));
            bool maDutinu = false; for (int k = 0; k <= kTop; k++) if (stary[k] == 0 && (k + 0.5) * 0.25 <= pov) { maDutinu = true; break; }
            if (!maDutinu) continue;
            sloupcu++;
            vz.Sloupec(x, y, 0, 0.25, sl);
            ProstorVody.DoSloupce(sl, mat, tr);
            for (int k = 0; k < nz; k++)
            {
                double z = (k + 0.5) * 0.25;
                // dnešní voda (ProfilSloupce): k > kTop vzduch, jinak materiál 0 = propustné (dutina), jinak hornina
                var dnes = k > kTop ? TridaVody.Vzduch : stary[k] == 0 ? TridaVody.VolnyProstor : TridaVody.Hornina;
                if (k <= kTop && z > pov) { horni++; continue; } // horní částečná buňka: dnes „dutina“, GEO2 vzduch (střed nad povrchem)
                buněk++; if (dnes == tr[k]) shoda++;
                if (sl[k].Typ == TypProstoru.DutinaKras) dutin++;
                if ((z > pov) != (tr[k] == TridaVody.Vzduch) || sl[k].Typ == TypProstoru.Neurceno || (sl[k].Material == 0 && z <= pov && tr[k] != TridaVody.VolnyProstor)) chybaTypu++;
            }
        }
        Console.WriteLine($"  {sloupcu} sloupců s dutinou: buněk {buněk:N0}, krasových dutin GEO2 {dutin:N0}, shoda tříd s dnešní vodou {100.0 * shoda / Math.Max(buněk, 1):F3} %, horních částečných buněk {horni}");
        T.Je(sloupcu > 0 && dutin > 0 && horni > 0, $"nalezeny sloupce s krasovou dutinou (náhodně po světě, i se šikmým povrchem: {horni} horních částečných buněk)");
        T.Je(chybaTypu == 0, $"vzduch ⇔ nad povrchem, materiál 0 pod povrchem ⇒ volný prostor, žádné Neurceno – jen z Typ ({chybaTypu} chyb)");
        T.Je(shoda >= buněk * 0.99, $"třídy buněk = dnešní voda v ≥ 99 % (rozdíl jen skarn × kras podle chronologie)");

        double bx = 1024 + 40.5, by = 512 + 40.5, bp = c.Povrch!(bx, by);
        var kr = new Krychle { X0 = bx - 2, X1 = bx + 2, Y0 = by - 2, Y1 = by + 2, Z0 = bp - 3, Z1 = bp + 5 };
        var vv = new VzorkovacGeo2(c, kr);
        var a = vv.Vzorek(bx, by, bp - 1.0); var puv = vz.Vzorek(bx, by, bp - 1.0);
        T.Je(a.Typ == TypProstoru.Vykopano && a.Material == 0 && a.GeoUdalost == puv.GeoUdalost && a.MaterialPuvodu == puv.MaterialPuvodu
             && ProstorVody.Trida(a) == TridaVody.VolnyProstor, "výkop: Vykopano, materiál 0, původ zůstane, pro vodu volný prostor");
        T.Je(vv.Vzorek(bx, by, bp + 2.0).Typ == TypProstoru.NadPovrchem && vv.Vzorek(bx, by, bp - 4.0) == vz.Vzorek(bx, by, bp - 4.0),
            "nad povrchem výkop nic nemění, mimo výkop vzorek beze změny");
        T.Je(!PravidloCile.OperaceSmiNaTridu(Operace.Vnikni, Geo2Zaklad.Trida(TypProstoru.Vykopano)) && !PravidloCile.OperaceSmiNaTridu(Operace.Vypln, Geo2Zaklad.Trida(TypProstoru.Vykopano)),
            "Vykopano je mimo geologii: žádná operace ho nezasáhne (2.1)");
    }
}
