using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using WillagePrototyp.Jadro;
using WillagePrototyp.OknoGeneratoru;

namespace WillagePrototyp.Testy;

/// <summary>
/// G-5: test okna 1 (instancuje res://nastroje/GeneratorSveta.tscn). Seznam modulů, konfigurátory ze schématu pro všechny moduly
/// (počet editorů, hodnoty editorů = sada), změna parametru přes editor → neplatné jen dotčené, přepočet → M0–M4 z paměti,
/// výchozí hodnoty modulu → otisky zpět, zástupný modul, uložení a potvrzení (zamčené editory). Snímky okna, když běží renderer
/// (pod Xvfb bez --headless): --snimky=složka.
/// Spuštění: Godot_mono [--headless] --path godot-prototyp res://nastroje/testy/GeneratorSvetaTest.tscn -- --kes=/tmp/willage-test-kes-6d [--snimky=/tmp/g5]
/// </summary>
public partial class GeneratorSvetaTest : Node
{
    int _ok, _chyb;
    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }
    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;

    async Task<bool> Cekej(Func<bool> podminka, int snimku = 1200)
    {
        for (int i = 0; i < snimku; i++) { if (podminka()) return true; await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
        return podminka();
    }

    string _snimky = "";
    bool Renderer => DisplayServer.GetName() != "headless";
    async Task Snimek(string jmeno)
    {
        if (_snimky == "" || !Renderer) return;
        for (int i = 0; i < 4; i++) await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        System.IO.Directory.CreateDirectory(_snimky);
        var img = GetViewport().GetTexture().GetImage();
        img.SavePng(System.IO.Path.Combine(_snimky, jmeno));
        GD.Print($"  snímek {jmeno} {img.GetWidth()}×{img.GetHeight()}");
    }

    public override async void _Ready()
    {
        var j = WillageJadro.Instance;
        if (j is null) { GD.Print("CHYBA: autoload WillageJadro chybí"); GetTree().Quit(1); return; }
        j.KesCesta = Arg("kes", j.KesCesta); _snimky = Arg("snimky", "");
        if (Renderer) { GetWindow().Size = new Vector2I(1600, 960); }
        GD.Print($"- G-5: okno Generátor světa ({DisplayServer.GetName()})");
        var moduly = new List<string>();
        j.ModulHotov += (id, n, st, ms) => moduly.Add($"{id}:{st}");

        // 1. otevření okna = generace celé planety na pozadí
        var sw = Stopwatch.StartNew();
        var okno = GD.Load<PackedScene>("res://nastroje/GeneratorSveta.tscn").Instantiate<GeneratorSvetaOkno>();
        var hotovo = ToSignal(j, WillageJadro.SignalName.PlanetaHotova);
        AddChild(okno);
        var s = (Godot.Collections.Dictionary)(await hotovo)[0];
        double celaMs = sw.Elapsed.TotalMilliseconds;
        Je((string)s["OtiskMapy"] == "800d420bb00047de" && (string)s["OtiskKlimatu"] == "cb11da8d141a2a5e" && (int)s["Vodniku"] == 86,
            $"celá planeta při otevření okna {celaMs:F0} ms (fasáda {j.PosledniVysledek?.Ms:F0} ms; keš eroze {j.KesCesta}): mapa {s["OtiskMapy"]}, klima {s["OtiskKlimatu"]}, vodníků {s["Vodniku"]}");
        var seznam = okno.Seznam; var konf = okno.Konfigurator;
        await Cekej(() => seznam.ItemCount == 11 && konf.Modul == "M0" && konf.Postaveni > 0);
        Je(seznam.ItemCount == 11, $"SeznamModulu: {seznam.ItemCount} modulů (M0–M7 + zástupné M6d, M8, M9)");
        Je(konf.Modul == "M0" && konf.Editory.Count() == 10, $"po otevření vybrán M0 s {konf.Editory.Count()} editory");
        await Cekej(() => okno.Retez.Stavy.Count == 11 && okno.Retez.Stavy.Values.All(v => v is "Spocitano" or "Zastupny"));
        Je(okno.Retez.Stavy.Count == 11 && okno.Retez.Stavy.Values.All(v => v is "Spocitano" or "Zastupny"), "RetezPrepoctu: 11 článků, spočteno / zástupný");

        // 2. konfigurátor pro každý modul ze schématu; hodnota editoru = hodnota sady (žádné zaokrouhlení prvkem)
        int editoru = 0, jinych = 0, skupin = 0;
        foreach (var m in j.PosledniModuly)
        {
            int pred = konf.Postaveni; seznam.Vyber(m.Id);
            await Cekej(() => konf.Postaveni > pred);
            int ocek = m.Zastupny ? 0 : j.ParametryDto(m.Id).Count;
            if (konf.Editory.Count() != ocek) Je(false, $"{m.Id}: {konf.Editory.Count()} editorů ≠ {ocek}");
            editoru += konf.Editory.Count(); skupin += m.Zastupny ? 0 : konf.Popis!.Skupiny.Count;
            foreach (var e in konf.Editory) if (e.HodnotaJson() != e.Popis!.Parametr.Hodnota) { jinych++; GD.Print($"    {e.Id}: editor {e.HodnotaJson()} ≠ sada {e.Popis.Parametr.Hodnota}"); }
        }
        Je(editoru == 202 && skupin == 35, $"konfigurátory ze schématu: {editoru} editorů ve {skupin} skupinách (202 / 35)");
        Je(jinych == 0, $"hodnota každého editoru = hodnota sady ({jinych} rozdílů)");

        // 3. M4: 20 editorů v 5 skupinách + náhled eroze
        { int pred = konf.Postaveni; seznam.Vyber("M4"); await Cekej(() => konf.Postaveni > pred); }
        Je(konf.Editory.Count() == 20 && konf.Popis!.Skupiny.Count == 5, $"M4: {konf.Editory.Count()} editorů v {konf.Popis?.Skupiny.Count} skupinách");
        // G-7: M4 má vlastní náhled (výchozí vrstva VyskaPlanety), už ne vrstvu Eroze hotové planety
        await Cekej(() => okno.Nahled.Modul == "M4" && okno.Nahled.VrstvaModulu == Willage.Gen.Api.Dto.VrstvaNahleduDto.VyskaPlanety && okno.Nahled.MapaModulu.Texture is ImageTexture);
        Je(okno.Nahled.VlastniNahled && okno.Nahled.VrstvaModulu == Willage.Gen.Api.Dto.VrstvaNahleduDto.VyskaPlanety && okno.Nahled.MapaModulu.Texture is ImageTexture, "NahledModulu: M4 → vlastní náhled (výška planety), textura");
        await Snimek("01-okno-m4.png");

        // 4. změna parametru M5 přes editor → neplatné jen M5 a závislé
        { int pred = konf.Postaveni; seznam.Vyber("M5"); await Cekej(() => konf.Postaveni > pred); }
        var ed = konf.Editor("ParametryKlimatu.VyskovyGradientCNaM")!;
        var zm = ToSignal(j, WillageJadro.SignalName.ParametrZmenen);
        ed.ZadejJakoUzivatel(0.06);
        var z = await zm;
        var nepl = string.Join(",", z[3].AsStringArray());
        Je(z[1].AsBool() && nepl == "M5,M6,M6d,M7,M8,M9", $"editor VyskovyGradientCNaM 0.05 → 0.06: přijato, neplatné {nepl}");
        await Cekej(() => okno.Retez.Stavy.GetValueOrDefault("M5") == "Ceka");
        Je(okno.Retez.Stavy["M4"] == "Spocitano" && okno.Retez.Stavy["M5"] == "Ceka" && okno.Retez.Stavy["M7"] == "Ceka", "RetezPrepoctu: M4 spočteno, M5 a M7 čeká");
        Je(seznam.StavPolozky("M6").Contains("čeká") && seznam.StavPolozky("M3").Contains("spočteno"), "SeznamModulu ukazuje čeká / spočteno");
        await Cekej(() => okno.Nahled.Nahled.Vrstva == Willage.Gen.Api.Dto.VrstvaMapyDto.Teplota, 60);
        await Snimek("02-okno-m5-zmena.png");

        // 5. Přepočítat modul + závislé
        moduly.Clear(); sw.Restart();
        hotovo = ToSignal(j, WillageJadro.SignalName.PlanetaHotova);
        konf.GetNode<Button>("Akce/Prepocitat").EmitSignal(BaseButton.SignalName.Pressed);
        s = (Godot.Collections.Dictionary)(await hotovo)[0];
        double prepMs = sw.Elapsed.TotalMilliseconds;
        var mstr = string.Join(",", moduly);
        Je(mstr.StartsWith("M0:ZPameti,M1:ZPameti,M2:ZPameti,M3:ZPameti,M4:ZPameti,M5:Spocitano,M6:Spocitano,M6d:Zastupny,M7:Spocitano"), $"přepočet {prepMs:F0} ms: {mstr}");
        Je((string)s["OtiskKlimatu"] != "cb11da8d141a2a5e" && (string)s["OtiskMapy"] == "800d420bb00047de", $"jiný gradient → klima {s["OtiskKlimatu"]}, mapa beze změny");
        await Cekej(() => okno.Diagnostika.Text.Contains("spočteno 3"), 120);
        Je(okno.Diagnostika.Text.Contains("spočteno 3, z paměti 5"), "Diagnostika: spočteno 3 (M5, M6, M7), z paměti 5 (M0–M4): " + okno.Diagnostika.Text.Replace("\n", " | "));

        // 6. výchozí hodnoty modulu → otisky zpět
        { int pred = konf.Postaveni; konf.VychoziModulu(); await Cekej(() => konf.Postaveni > pred); }
        Je(konf.Editor("ParametryKlimatu.VyskovyGradientCNaM")!.HodnotaJson() == "0.05", "Výchozí hodnoty: editor zpět 0.05");
        hotovo = ToSignal(j, WillageJadro.SignalName.PlanetaHotova);
        konf.GetNode<Button>("Akce/Prepocitat").EmitSignal(BaseButton.SignalName.Pressed);
        s = (Godot.Collections.Dictionary)(await hotovo)[0];
        Je((string)s["OtiskKlimatu"] == "cb11da8d141a2a5e" && (int)s["Vodniku"] == 86 && (string)s["OtiskMapy"] == "800d420bb00047de", $"otisky zpět: klima {s["OtiskKlimatu"]}, vodníků {s["Vodniku"]}");

        // 7. zástupný modul
        { int pred = konf.Postaveni; seznam.Vyber("M8"); await Cekej(() => konf.Postaveni > pred); }
        Je(konf.Editory.Count() == 0 && konf.GetNode<Control>("Zastupny").Visible && konf.GetNode<Label>("Zastupny").Text.StartsWith("zástupný"), "M8: zástupný panel, žádné editory");
        Je(GetTree().GetNodesInGroup("zastupne").Count == 4, $"zástupné panely v okně: {GetTree().GetNodesInGroup("zastupne").Count} (náhled modulu, řez, U-1, U-2)");
        await Snimek("03-okno-m8-zastupny.png");

        // 8. uložení a potvrzení
        string wpln = "/tmp/g5test/planeta.wpln"; System.IO.Directory.CreateDirectory("/tmp/g5test");
        okno.Lista.Cesta.Text = wpln;
        if (System.IO.File.Exists(wpln)) System.IO.File.Delete(wpln);
        okno.Lista.GetNode<Button>("Ulozit").EmitSignal(BaseButton.SignalName.Pressed);
        await Cekej(() => System.IO.File.Exists(wpln), 600);
        Je(System.IO.File.Exists(wpln), "Uložit WPLN: soubor existuje");
        { int pred = konf.Postaveni; seznam.Vyber("M5"); await Cekej(() => konf.Postaveni > pred); }
        int predP = konf.Postaveni;
        okno.Lista.GetNode<Button>("Potvrdit").EmitSignal(BaseButton.SignalName.Pressed);
        await Cekej(() => konf.Postaveni > predP && j.PosledniInfo is { Potvrzena: true });
        Je(j.PosledniInfo?.Potvrzena == true && okno.Lista.Info.Text.Contains("POTVRZENÁ"), "Potvrdit planetu: " + okno.Lista.Info.Text);
        Je(konf.Editory.All(e => e.Zamceny), "po potvrzení jsou všechny editory zamčené");
        int odeslano = 0; foreach (var e in konf.Editory) e.Zmena += (_, _) => odeslano++;
        konf.Editor("ParametryKlimatu.VyskovyGradientCNaM")!.ZadejJakoUzivatel(0.07);
        zm = ToSignal(j, WillageJadro.SignalName.ParametrZmenen);
        j.Nastav("ParametryKlimatu.VyskovyGradientCNaM", "0.07");
        z = await zm;
        Je(odeslano == 0 && !z[1].AsBool() && konf.Editor("ParametryKlimatu.VyskovyGradientCNaM")!.HodnotaJson() == "0.05", $"zamčený editor nic neodešle a drží 0.05; Nastav odmítnut: {z[2]}");
        await Snimek("04-okno-potvrzeno.png");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb);
    }
}
