using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Konfigurator;
using Willage.Gen.Data;

namespace Willage.Gen.Testy;

/// <summary>G-5 (část bez Godotu): konfigurátor generovaný ze schématu – druhy editorů, skupiny, převod hodnot, přepočet jen dotčených.
/// Godot část: nastroje/testy/GeneratorSvetaTest.tscn.</summary>
public static class TestyG5
{
    static string S(IEnumerable<string> s) => string.Join(",", s);

    public static void Spust()
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);
        var kes = Path.Combine(Path.GetTempPath(), "willage-test-kes-6d");

        T.Sekce("G-5: konfigurátor ze schématu (druhy editorů, skupiny, převod hodnot)");
        var g = new GeneratorSveta(data, kes);
        var moduly = g.Moduly.Seznam();
        T.Je(moduly.Count == 11, "11 modulů včetně zástupných: " + S(moduly.Select(m => m.Id)));
        var vse = new List<PopisEditoru>(); int skupin = 0;
        foreach (var m in moduly)
        {
            var par = g.Moduly.Parametry(m.Id);
            var k = Konfigurator.Sestav(m.Id, par, false);
            T.Je(k.PocetEditoru == par.Count, $"{m.Id}: editor pro každý parametr ({k.PocetEditoru}/{par.Count})");
            T.Je(S(k.Skupiny.Select(s => s.Nazev)) == S(par.Select(p => p.Skupina).Distinct()), $"{m.Id}: skupiny v pořadí schématu");
            T.Je(k.Vrstvy.Count > 0, $"{m.Id}: aspoň jedna vrstva náhledu");
            if (m.Zastupny) T.Je(par.Count == 0, $"{m.Id} zástupný bez parametrů");
            vse.AddRange(k.Skupiny.SelectMany(s => s.Editory)); skupin += k.Skupiny.Count;
        }
        int Poc(DruhEditoru d) => vse.Count(e => e.Druh == d);
        T.Je(vse.Count == 202 && Poc(DruhEditoru.Desetinne) == 160 && Poc(DruhEditoru.Cele) == 14 && Poc(DruhEditoru.Prepinac) == 20
             && Poc(DruhEditoru.Volba) == 2 && Poc(DruhEditoru.Json) == 6 && Poc(DruhEditoru.Text) == 0,
            $"202 editorů: desetinné {Poc(DruhEditoru.Desetinne)}, celé {Poc(DruhEditoru.Cele)}, přepínače {Poc(DruhEditoru.Prepinac)}, volby {Poc(DruhEditoru.Volba)}, JSON {Poc(DruhEditoru.Json)}");
        Console.WriteLine($"  202 editorů ve {skupin} skupinách, s posuvníkem {vse.Count(e => e.Posuvnik)}, zamčených (jen čtení) {vse.Count(e => e.Zamceny)}");
        T.Je(vse.Count(e => e.Zamceny) == 8 && vse.Where(e => e.Zamceny).All(e => e.DuvodZamceni.StartsWith("jen čtení")), "8 zamčených = jen čtení ze schématu");
        T.Je(vse.All(e => e.NapovedaZastupna && e.Napoveda == Konfigurator.NapovedaZastupna), "nápověda: všude zástupný text (ve v1 bez textů)");
        T.Je(vse.Where(e => e.Druh == DruhEditoru.Json).All(e => e.PoznamkaEditoru == Konfigurator.TabulkaZastupna), "tabulky a pole: zástupná poznámka (JSON editor)");
        T.Je(vse.Where(e => e.Druh == DruhEditoru.Volba).All(e => e.Parametr.Volby is { Count: > 1 } v && v.Contains(Konfigurator.Retezec(e.Parametr.Hodnota))), "volby: hodnota je mezi volbami");
        T.Je(Konfigurator.Sestav("M4", g.Moduly.Parametry("M4"), true).Skupiny.SelectMany(s => s.Editory).All(e => e.Zamceny), "potvrzená planeta → všechny editory zamčené");
        var m4 = Konfigurator.Sestav("M4", g.Moduly.Parametry("M4"), false);
        T.Je(m4.PocetEditoru == 20 && m4.Skupiny.Count == 5, $"M4: 20 editorů v 5 skupinách ({m4.PocetEditoru}, {m4.Skupiny.Count})");

        // převod tam a zpět: editor s nezměněnou hodnotou dá stejný JSON a Nastav nezneplatní nic
        int stejnych = 0, nic = 0;
        foreach (var e in vse.Where(e => !e.Zamceny))
        {
            object v = e.Druh switch
            {
                DruhEditoru.Cele or DruhEditoru.Desetinne => Konfigurator.Cislo(e.Parametr.Hodnota),
                DruhEditoru.Prepinac => Konfigurator.Logicka(e.Parametr.Hodnota),
                DruhEditoru.Volba or DruhEditoru.Text => Konfigurator.Retezec(e.Parametr.Hodnota),
                _ => e.Parametr.Hodnota,
            };
            string j = Konfigurator.NaJson(e.Druh, v);
            if (j == e.Parametr.Hodnota) stejnych++; else Console.WriteLine($"  jiný zápis {e.Parametr.Id}: {e.Parametr.Hodnota} → {j}");
            var z = g.Moduly.Nastav(e.Parametr.Id, j);
            if (z.Prijato && z.Neplatne.Count == 0) nic++; else Console.WriteLine($"  {e.Parametr.Id}: {z.Duvod} neplatné {S(z.Neplatne)}");
        }
        int nezamc = vse.Count(e => !e.Zamceny);
        T.Je(nic == nezamc, $"nezměněná hodnota z editoru → Nastav nezneplatní žádný modul ({nic}/{nezamc}; stejný zápis JSON {stejnych})");
        T.Je(Konfigurator.NaJson(DruhEditoru.Cele, 49.6) == "50" && Konfigurator.NaJson(DruhEditoru.Desetinne, 0.06) == "0.06" && Konfigurator.NaJson(DruhEditoru.Volba, "poust") == "\"poust\"",
            "převod: celé zaokrouhlí, desetinné invariantně, volba v uvozovkách");
        bool chyba = false; try { Konfigurator.NaJson(DruhEditoru.Json, "[1, 2"); } catch (FormatException) { chyba = true; }
        T.Je(chyba, "neplatný JSON tabulky → FormatException (editor ho neodešle)");

        T.Sekce("G-5: změna parametru → přepočet jen dotčených modulů");
        g.Sluzba.Generuj();
        var z5 = g.Moduly.Nastav("ParametryKlimatu.VyskovyGradientCNaM", Konfigurator.NaJson(DruhEditoru.Desetinne, 0.06));
        T.Je(z5.Prijato && S(z5.Neplatne) == "M5,M6,M6d,M7,M8,M9", "M5 parametr → neplatné M5,M6,M6d,M7,M8,M9: " + S(z5.Neplatne));
        T.Je(S(Konfigurator.Zavisle(g.Moduly.Seznam(), "M5")) == S(z5.Neplatne), "Konfigurator.Zavisle(M5) = neplatné z klíčů");
        T.Je(g.Moduly.Seznam().Where(m => m.Stav == StavModuluDto.Ceka).Select(m => m.Id).SequenceEqual(new[] { "M5", "M6", "M7" }), "stav Čeká jen M5, M6, M7");
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var r = g.Moduly.Prepocitej();
        var st = S(r.Moduly.Select(m => $"{m.Id}:{m.Stav}"));
        T.Je(st.StartsWith("M0:ZPameti,M1:ZPameti,M2:ZPameti,M3:ZPameti,M4:ZPameti,M5:Spocitano,M6:Spocitano"), "přepočet: M0–M4 z paměti, M5+ spočteno: " + st);
        Console.WriteLine($"  přepočet M5 a závislých {sw.ElapsedMilliseconds} ms (celá planeta viz G-4)");
        T.Je(r.Souhrn.OtiskKlimatu != "cb11da8d141a2a5e" && r.Souhrn.OtiskMapy == "800d420bb00047de", "jiný gradient → jiné klima, mapa stejná");
        foreach (var p in g.Moduly.Parametry("M5").Where(p => p.Hodnota != p.Vychozi && !p.JenCteni)) g.Moduly.Nastav(p.Id, p.Vychozi);
        r = g.Moduly.Prepocitej();
        T.Je(r.Souhrn.OtiskKlimatu == "cb11da8d141a2a5e" && r.Souhrn.Vodniku == 86, $"výchozí hodnoty modulu M5 → otisky zpět ({r.Souhrn.OtiskKlimatu}, {r.Souhrn.Vodniku})");
    }
}
