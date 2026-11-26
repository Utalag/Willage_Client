using Willage.Gen.Data;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;
using Willage.Gen.Voda.Prusak;

namespace Willage.Gen.Testy;

/// <summary>Puklinová propustnost krasových uhličitanů (vápenec, dolomit): dosah jako písek, jen při zapnutém přepínači.</summary>
public static class TestyPrusakKras
{
    const int Pisek = 3, KrasJeskyne = 5, KrasHloubka = 44, Dolomit = 49, Vystup = 56, Sadrovec = 48, Sul = 47;

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kat = KatalogMaterialu.ZeSouboru(data.KatalogMaterialu);
        var json = File.ReadAllText(data.PrusakV1);
        var pv = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var k = new PrusakKoeficient(kat, json);
        var pas = new PobrezniPas(kat, k, pv with { PrusakPobrezi = true });
        var pr = new Propustnost(kat);

        T.Sekce("pukliny krasu: data a dosah jako písek");
        T.Je(k.JePukliny(KrasJeskyne) && k.JePukliny(KrasHloubka) && k.JePukliny(Dolomit) && k.JePukliny(Vystup), "čtyři krasové uhličitany mají pukliny");
        T.Je(!k.JePukliny(Pisek) && !k.JePukliny(Sadrovec) && !k.JePukliny(Sul) && !k.JePukliny(6), "písek, sádrovec, sůl a žula bez puklin");
        T.Je(k.Koef(KrasJeskyne) == 178 && k.Koef(Dolomit) == 178 && k.Koef(Pisek) == 178, "koeficient krasu = písek 178");
        T.Blizko(k.KMs(KrasJeskyne) ?? 0, 1e-4 + 3e-8, 1e-12, "efektivní K = matrice + pukliny");
        T.Je(k.Porovitost(KrasJeskyne) == 0.35, "porozita puklin 350 ‰");
        // generátor se nemění
        T.Blizko(pr.X(KrasJeskyne), 3e-8 * 0.0625 * 1000, 1e-18, "Propustnost.X vápence = jen matrice (generátor beze změny)");
        T.Je(k.X(KrasJeskyne) > pr.X(KrasJeskyne) * 1000, "průsakové X krasu ≫ matrice");
        T.Blizko(pas.Material(KrasJeskyne, 50), pas.Material(Pisek, 50), 0.02, $"dosah jeskynního vápence ≈ písek ({pas.Material(KrasJeskyne, 50):F2} vs {pas.Material(Pisek, 50):F2} m)");
        T.Blizko(pas.Material(Dolomit, 10), pas.Material(Pisek, 10), 0.02, "dolomit 10 ‰ ≈ písek");
        T.Blizko(pas.Material(KrasHloubka, 200), pas.Material(Pisek, 200), 0.02, "hluboký vápenec 200 ‰ ≈ písek");
        T.Je(pas.Material(KrasJeskyne, 10) > 1.4 && pas.Material(KrasJeskyne, 200) < 4.0, "pás krasu 1,5–3,5 m podle spádu (strop ne)");
        T.Je(pas.Material(Sadrovec, 50) == 0 && pas.Material(Sul, 50) == 0, "sádrovec a sůl bez puklin zůstávají těsné");

        // bez pole pukliny = staré šířky (0,01 m)
        var json0 = json.Replace("\"pukliny\"", "\"_pukliny_vyp\"");   // pole se ignoruje
        // Lepší: JSON bez klíče pukliny
        int i = json.LastIndexOf("\"pukliny\""); var jsonBez = i < 0 ? json : json[..json.LastIndexOf(',', i)] + "\n}";
        var k0 = new PrusakKoeficient(kat, jsonBez);
        var pas0 = new PobrezniPas(kat, k0, pv with { PrusakPobrezi = true });
        T.Je(!k0.JePukliny(Dolomit) && k0.Koef(Dolomit) == 20, "bez pole pukliny: dolomit koeficient z K matrice (20)");
        T.Je(pas0.Material(Dolomit, 50) < 0.05 && pas.Material(Dolomit, 50) > 1.5, "bez puklin pás ~0,01 m, s puklinami jako písek");

        T.Sekce("pukliny krasu: dutina a vypnuté přepínače");
        var geo = new SyntetickaGeologie();
        var vyp = new PodzemniVodaFn(geo, kat, pv);   // přepínače vypnuto
        var zapK = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakKoeficient = true, PrusakTlak = false }, json);
        var zap0 = new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakKoeficient = true, PrusakTlak = false }, jsonBez);
        T.Je(vyp.Prusak is null, "vypnuto: tabulka (včetně puklin) se nevytvoří");
        var stena = StenaDutiny.Z(Dolomit, 5);
        var zad = new ZadaniDutiny(8, 8, 24, 56.0, 60.0, stena, stena, stena);
        var d0 = zap0.Dutina(zad); d0.Beh(3600);
        var d1 = zapK.Dutina(zad); d1.Beh(3600);
        T.Je(d1.ObjemUl > 1_000_000 && d0.ObjemUl * 1000 < d1.ObjemUl, $"dutina v dolomitu: bez puklin téměř suchá ({d0.ObjemUl} µl), s puklinami teče jako písek ({d1.ObjemUl} µl)");
        T.Je(OtiskVody.Blok(vyp.Blok(0, 0, 4, true)) == OtiskVody.Blok(new PodzemniVodaFn(new SyntetickaGeologie(), kat, pv with { PrusakPobrezi = true, PrusakKoeficient = true }, json).Blok(0, 0, 4, true)), "syntetická geologie bez moře: otisk stejný vypnuto i zapnuto");
    }
}
