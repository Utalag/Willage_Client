using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Sluzby;
using WillagePrototyp.EditorMaterialu;

namespace WillagePrototyp.Testy;

/// <summary>
/// T-1: Godot (net9) volá VPMG Dev (net10) mimo proces přes fasádu Willage.Materialy.Api: golden 1756279408, textura = bajty nástroje,
/// mřížka textur 12 materiálů (první materiál každé skupiny) v uzlech NahledTexturyVpmg. Snímek pod Xvfb: --snimky=složka.
/// Spuštění: Godot_mono [--headless] --path godot-prototyp res://nastroje/testy/VpmgTest.tscn [-- --snimky=/tmp/t1]
/// </summary>
public partial class VpmgTest : Control
{
    int _ok, _chyb;
    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }
    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;

    public override async void _Ready()
    {
        GD.Print("T-1 VpmgTest: VPMG z připnutého Dev přes fasádu");
        if (DisplayServer.GetName() != "headless") GetWindow().Size = new Vector2I(1600, 960);
        var mrizka = GetNode<GridContainer>("Okraj/Svisle/Mrizka");
        var titulek = GetNode<Label>("Okraj/Svisle/Titulek");
        using var api = new MaterialyApi(ProjectSettings.GlobalizePath("res://data"));
        var zdroj = (ZdrojVpmgProces)api.Zdroj;
        var info = zdroj.Info();
        Je(info.Dostupny && info.DevCommit == api.Pin.Commit, $"nástroj VPMG z Godotu: Dev {info.DevCommit[..Math.Min(7, info.DevCommit.Length)]}, operace {string.Join(",", info.Operace)}, start {zdroj.MsStartu:F0} ms");
        var g = zdroj.Spust(RecepturyVpmg.Vychozi(52), 0xC0FFEE00u);
        Je(g.Ok && g.Checksum == api.Pin.GoldenChecksum, $"golden přes Godot → fasáda → nástroj: {g.Checksum} (celkem {g.MsCelkem:F1} ms)");

        var vybrane = api.Katalog.Skupiny.Select(s => api.Katalog.Materialy.First(m => m.Skupina == s)).Take(12).ToList();
        int ok = 0;
        foreach (var m in vybrane)
        {
            var t = zdroj.Spust(RecepturyVpmg.Vychozi(m.Id), 49);
            var bunka = new VBoxContainer();
            var n = new NahledTexturyVpmg { CustomMinimumSize = new Vector2(220, 220), Dlazdice = 2, Name = "Textura" + m.Id };
            bunka.AddChild(n);
            bunka.AddChild(new Label { Text = $"{m.Id} {m.Nazev}\n{m.Skupina} · {m.Profily["default"].BaseColor} · {t.Checksum}", CustomMinimumSize = new Vector2(220, 0), ClipText = true });
            mrizka.AddChild(bunka);
            n.Zobraz(t);
            var tex = (ImageTexture)n.Texture;
            if (t.Ok && tex.GetWidth() == 128 && tex.GetImage().GetPixel(70, 5) == NahledTexturyVpmg.Obraz(t).GetPixel(6, 5)) ok++;
        }
        Je(ok == vybrane.Count, $"{ok}/{vybrane.Count} textur v uzlech NahledTexturyVpmg (dlaždice 2×2, bajty = nástroj)");
        titulek.Text = $"T-1 · VPMG Dev {api.Pin.Commit[..7]} mimo proces (net10) ← Godot net9 · golden {g.Checksum} {(g.Checksum == api.Pin.GoldenChecksum ? "= Dev" : "≠ Dev")} · výchozí receptura base_fill + hash_grain, seed 49, 64 px, dlaždice 2×2";

        string snimky = Arg("snimky", "");
        if (snimky != "" && DisplayServer.GetName() != "headless")
        {
            for (int i = 0; i < 4; i++) await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            System.IO.Directory.CreateDirectory(snimky);
            GetViewport().GetTexture().GetImage().SavePng(System.IO.Path.Combine(snimky, "01-vpmg-materialy.png"));
            GD.Print("  snímek 01-vpmg-materialy.png");
        }
        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb == 0 ? 0 : 1);
    }
}
