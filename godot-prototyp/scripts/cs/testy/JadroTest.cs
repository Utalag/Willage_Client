using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Willage.Gen.Api.Dto;
using WillagePrototyp.Jadro;
using WillagePrototyp.Jadro.Uzly;

namespace WillagePrototyp.Testy;

/// <summary>
/// G-4: headless test jádra (scéna res://nastroje/testy/JadroTest.tscn). Generace přes autoload WillageJadro na pozadí:
/// volání na hlavním vlákně &lt; 1 ms, snímky běží, signály po modulech, otisky = CLI, mapa → textura v uzlu NahledVrstvy,
/// zrušení. Výsledek: řádky OK/CHYBA, ukončí se kódem = počet chyb.
/// Spuštění: Godot_mono --headless --path godot-prototyp res://nastroje/testy/JadroTest.tscn -- --kes=/tmp/willage-test-kes-6d [--png=/tmp/g4]
/// </summary>
public partial class JadroTest : Node
{
    int _ok, _chyb, _snimku;
    double _maxSnimekMs; bool _merim;
    readonly Stopwatch _snimek = new();
    readonly List<string> _moduly = new();

    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }

    public override void _Process(double delta)
    {
        if (!_merim) return;
        _snimku++;
        if (_snimek.IsRunning) _maxSnimekMs = Math.Max(_maxSnimekMs, _snimek.Elapsed.TotalMilliseconds);
        _snimek.Restart();
    }

    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;

    public override async void _Ready()
    {
        var j = WillageJadro.Instance;
        if (j is null) { GD.Print("CHYBA: autoload WillageJadro chybí"); GetTree().Quit(1); return; }
        j.KesCesta = Arg("kes", j.KesCesta);
        string png = Arg("png", "");
        int hlavni = System.Environment.CurrentManagedThreadId;
        j.ModulHotov += (id, n, st, ms) => _moduly.Add($"{id}:{st}");
        GD.Print("- G-4: jádro WillageJadro (headless)");

        // 1. generace na pozadí
        var nahled = GetNode<NahledVrstvy>("%NahledVyska");
        var nahledB = GetNode<NahledVrstvy>("%NahledBiom");
        var sw = Stopwatch.StartNew();
        _merim = true;
        long u = j.Generuj();
        double volani = sw.Elapsed.TotalMilliseconds;
        GD.Print($"  první Generuj (studené: JIT + start vlákna fronty) {volani:F3} ms");
        Je(j.IdVlaknaFronty != hlavni, $"fronta běží na vlastním vlákně ({j.IdVlaknaFronty} ≠ hlavní {hlavni})");
        var s = (Godot.Collections.Dictionary)(await ToSignal(j, WillageJadro.SignalName.PlanetaHotova))[0];
        double gen = sw.Elapsed.TotalMilliseconds; _merim = false;
        Je(_snimku > 10, $"během generace {gen:F0} ms proběhlo {_snimku} snímků, nejdelší {_maxSnimekMs:F1} ms");
        Je(string.Join(",", _moduly) == "M0:Spocitano,M1:Spocitano,M2:Spocitano,M3:Spocitano,M4:Spocitano,M5:Spocitano,M6:Spocitano,M6d:Zastupny,M7:Spocitano,M8:Zastupny,M9:Zastupny",
            "ModulHotov po každém modulu v pořadí (zástupné označené): " + string.Join(",", _moduly));
        Je((string)s["OtiskMapy"] == "800d420bb00047de" && (string)s["OtiskKlimatu"] == "cb11da8d141a2a5e" && (int)s["Vodniku"] == 86, $"PlanetaHotova: mapa {s["OtiskMapy"]}, klima {s["OtiskKlimatu"]}, vodníků {s["Vodniku"]}");

        // 2. otisky = CLI
        j.Otisky();
        var o = (Godot.Collections.Dictionary)(await ToSignal(j, WillageJadro.SignalName.OtiskyHotove))[0];
        Je((string)o["VodaBlok"] == "377a8210f82c856a", $"otisk vody 14,14 přes jádro {o["VodaBlok"]} = CLI");

        // 3. náhledy vrstev (uzly NahledVrstvy si mapu vyžádaly samy po PlanetaHotova)
        for (int i = 0; i < 600 && (nahled.PrijatychMap == 0 || nahledB.PrijatychMap == 0); i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var t = nahled.Texture as ImageTexture; var tb = nahledB.Texture as ImageTexture;
        Je(t is not null && t.GetWidth() == 980 / 4 && t.GetHeight() == 488 / 4 && tb is not null, $"NahledVrstvy: výška {t?.GetWidth()}×{t?.GetHeight()} (mapa 980×488 / 4), biom {tb?.GetWidth()}×{tb?.GetHeight()}");
        if (png != "" && t is not null && tb is not null)
        {
            System.IO.Directory.CreateDirectory(png);
            t.GetImage().SavePng(System.IO.Path.Combine(png, "vyska.png")); tb.GetImage().SavePng(System.IO.Path.Combine(png, "biom.png"));
        }

        // 4. zrušení během generace (změna klimatu → přepočet M5…; zrušit po prvním přepočteném modulu)
        _moduly.Clear();
        j.Nastav("ParametryKlimatu.KontinentalitaM", "1000");
        var z = await ToSignal(j, WillageJadro.SignalName.ParametrZmenen);
        Je((bool)z[1] && string.Join(",", (string[])z[3]) == "M5,M6,M6d,M7,M8,M9", "Nastav přes jádro: neplatné " + string.Join(",", (string[])z[3]));
        void zrusPoM5(string id, string n, string st, double ms) { if (id == "M5") j.Zrus(); }
        j.ModulHotov += zrusPoM5;
        var sw2 = Stopwatch.StartNew();
        long uz = j.Generuj();
        double volani2 = sw2.Elapsed.TotalMilliseconds;
        Je(volani2 < 1.0 && uz > 0, $"Generuj na hlavním vlákně (zahřáté) {volani2:F3} ms < 1 ms; studené {volani:F3} ms");
        var zr = await ToSignal(j, WillageJadro.SignalName.PraceZrusena);
        j.ModulHotov -= zrusPoM5;
        Je((long)zr[0] == uz && !_moduly.Contains("M7:Spocitano"), "zrušení během generace → PraceZrusena, M7 se nespočítal (" + string.Join(",", _moduly) + ")");
        _moduly.Clear();
        j.Generuj();
        await ToSignal(j, WillageJadro.SignalName.PlanetaHotova);
        Je(_moduly.Contains("M5:ZPameti") && _moduly.Contains("M7:Spocitano") && _moduly.Contains("M4:ZPameti"), "po zrušení další generace doběhne, M5 z paměti (spočten před zrušením): " + string.Join(",", _moduly));

        // 5. chyba úlohy → PraceSelhala, fronta žije dál
        j.Nacti("/neexistuje/planeta.wpln");
        var ch = await ToSignal(j, WillageJadro.SignalName.PraceSelhala);
        j.Moduly();
        var ms2 = (Godot.Collections.Array)(await ToSignal(j, WillageJadro.SignalName.ModulySeznam))[0];
        Je((string)ch[1] == "Nacti" && ms2.Count == 11, $"chyba ({ch[2]}) → PraceSelhala, fronta dál: {ms2.Count} modulů");

        // 6. zástupné panely
        var zp = GetTree().GetNodesInGroup("zastupne").OfType<ZastupnyPanel>().ToList();
        Je(zp.Count == 6 && zp.All(p => p.Text.StartsWith("zástupný: ")), $"{zp.Count} zástupných panelů (7d, M8, M9, U-1, U-2, nápověda)");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb);
    }
}
