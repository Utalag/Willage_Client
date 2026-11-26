using Willage.Gen.Data;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;
using Willage.Gen.Voda.Prusak;

namespace Willage.Gen.Testy;

/// <summary>Koeficient průsaku (bajt 0–255, zapínatelný): tabulka, celočíselný útlum, plnění dutiny, vypnuto = beze změny.</summary>
public static class TestyPrusak
{
    const int Pisek = 3, Zula = 6, Jil = 12, Spras = 54, Sterk = 66;

    static ZadaniDutiny Z(int mat, int bloku, int dir = 0)
    {
        var s = StenaDutiny.Z(mat, bloku);
        return new(8, 8, 24, 56.0, 60.0, s, s, s, dir);
    }

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogMaterialu.ZeSouboru(data.KatalogMaterialu);
        var pj = File.ReadAllText(data.PrusakV1);
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        T.Sekce("koeficient průsaku: tabulka 0–255");
        T.Je(!new ParametryVody().PrusakKoeficient && !pv.PrusakKoeficient, "výchozí příznak vypnuto (kód i voda_v1.json)");
        var k = new PrusakKoeficient(kat, pj);
        T.Je(k.Koef(Sterk) == 255 && k.Koef(Pisek) == 178 && k.Koef(Jil) == 13 && k.Koef(Zula) == 0 && k.Koef(0) == 255, "štěrk 255, písek 178, jíl 13, žula 0, vzduch 255");
        T.Je(k.Koef(33) == 0 && k.Koef(4) == 13 && k.Koef(Spras) == 38 && k.Koef(60) == 77, "ortorula 0, zvětralý jíl 13, spraš 38 (třída K), zvětralá žula 77");
        T.Je(k.Koef(10) == 0 && k.Koef(100) == 0, "materiál bez K (sníh, diamant) = 0 (těsnění)");
        bool mon = true; var pr = new Propustnost(kat);
        for (int a = 1; a < 256; a++) for (int b = 1; b < 256; b++)
            if (kat.Najdi(a) is { KMs: double ka } && kat.Najdi(b) is { KMs: double kb } && ka > kb && k.Koef(a) < k.Koef(b)) mon = false;
        T.Je(mon, "vyšší K nikdy nemá menší koeficient (monotónnost tříd)");
        bool vyhodi = false;
        try { _ = new PrusakKoeficient(kat, pj.Replace("\"vzduch\": 255", "\"vzduch\": 256")); } catch (ArgumentOutOfRangeException) { vyhodi = true; }
        T.Je(vyhodi, "hodnota mimo 0–255 se odmítne");

        T.Sekce("koeficient průsaku: celočíselný útlum Q24");
        T.Je(PrusakUtlum.Vrstva(255, 50) == PrusakUtlum.Jedna && PrusakUtlum.Vrstva(0, 1) == 0, "255 nic neubere, 0 zavře");
        long t1 = PrusakUtlum.Vrstva(178, 1), t5 = PrusakUtlum.Vrstva(178, 5), t10 = PrusakUtlum.Vrstva(178, 10);
        T.Blizko(PrusakUtlum.NaDouble(t1), 178.0 / 255, 1e-6, "písek 1 blok ≈ 0,698");
        T.Je(PrusakUtlum.NaDouble(t10) < 0.03, $"písek 10 bloků < 3 % ({PrusakUtlum.NaDouble(t10):P2})");
        T.Je(t1 == 11711154 && t5 == 2780473 && t10 == 460804, $"zlatá čísla Q24 (bitově): {t1} {t5} {t10}");
        long t = PrusakUtlum.Jedna; bool klesa = true; int nulaOd = -1;
        for (int n = 1; n <= 80; n++) { long u = PrusakUtlum.Blok(t, 178); if (u > t) klesa = false; t = u; if (t == 0 && nulaOd < 0) nulaOd = n; }
        T.Je(klesa && nulaOd > 0 && nulaOd <= 80, $"písek v tlusté vrstvě dosáhne 0 (od {nulaOd} bloků), nikdy nevzroste");
        T.Je(PrusakUtlum.Cesta(new[] { Pisek, Pisek, Sterk }, k) == PrusakUtlum.Vrstva(178, 2), "cesta = součin po blocích (štěrk 255 beze změny)");

        T.Sekce("koeficient průsaku: přepínač a dutina");
        var geo = new SyntetickaGeologie();
        var vyp = new PodzemniVodaFn(geo, kat, pv);
        var zap = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakKoeficient = true }, pj);
        T.Je(vyp.Prusak is null && zap.Prusak is not null, "vypnuto: žádná tabulka; zapnuto: tabulka");
        bool chybi = false;
        try { _ = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakKoeficient = true }); } catch (InvalidOperationException) { chybi = true; }
        T.Je(chybi, "zapnuto bez dat = chyba, ne tiché ignorování");
        T.Je(OtiskVody.Blok(vyp.Blok(0, 0, 4, true)) == OtiskVody.Blok(zap.Blok(0, 0, 4, true)), "otisk bloku vody stejný s vypnutým i zapnutým příznakem");

        long Vol(PodzemniVodaFn f, int m, int n, long s, int dir = 0) { var d = f.Dutina(Z(m, n, dir)); d.Beh(s); return d.ObjemUl; }
        T.Je(Vol(vyp, Pisek, 1, 3600) == Vol(vyp, Pisek, 10, 3600), "vypnuto (stávající pravidlo): tloušťka písku nehraje roli");
        long v1 = Vol(zap, Pisek, 1, 3600), v5 = Vol(zap, Pisek, 5, 3600), v10 = Vol(zap, Pisek, 10, 3600);
        T.Je(v1 > v5 && v5 > v10 && v10 > 0, $"zapnuto: tlustší stěna písku pustí méně ({v1} > {v5} > {v10} µl za 1 h)");
        T.Je(Vol(vyp, Sterk, 1, 60) == Vol(zap, Sterk, 1, 60), "štěrk (255) se chová stejně vypnuto i zapnuto");
        T.Je(Vol(zap, Zula, 1, 86400) == 0 && Vol(zap, Jil, 10, 86400) == 0, "žula a jíl: za den nic (těsné)");
        T.Je(Vol(zap, Zula, 1, 3600, 1) == Vol(vyp, Zula, 1, 3600, 1) && Vol(zap, Zula, 1, 3600, 1) > 0, "díra ve stěně: teče stejně, koeficient stěny nehraje roli");
        // poměr přítoku v prvním kroku ≈ T cesty (10 bloků písku proti 1 bloku)
        double pomer = (double)Vol(zap, Pisek, 10, 10) / Vol(zap, Pisek, 1, 10);
        T.Blizko(pomer, PrusakUtlum.NaDouble(t10) / PrusakUtlum.NaDouble(t1), 1e-3, "přítok 10 bloků / 1 blok = poměr T");
        long vg = Vol(zap, Pisek, 5, 3600);
        T.Je(vg == Vol(zap, Pisek, 5, 3600) && vg == Vol(new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakKoeficient = true }, pj), Pisek, 5, 3600), "deterministické: stejný objem při opakování");
        Console.WriteLine($"  (písek 5 bloků za 1 h: {vg} µl)");

        var dl = zap.Dutina(Z(Pisek, 1)); double predch = dl.HladinaM; bool nekles = true, podH = true;
        while (dl.Cas < 3 * 86400) { dl.Krok(); if (dl.HladinaM < predch) nekles = false; if (dl.HladinaM > 60.0 + 1e-9) podH = false; predch = dl.HladinaM; }
        T.Je(nekles && podH, "hladina v dutině jen roste a nepřekročí venkovní 60 m");
        T.Blizko(dl.HladinaM, 60.0, 1e-3, "konečná hladina = venkovní 60 m (strop 62 m)");
        var dz = zap.Dutina(Z(Zula, 1)); dz.Beh(30 * 86400);
        T.Je(dz.HladinaM == 56.0, "žula za 30 dnů: hladina beze změny (56 m)");
    }
}
