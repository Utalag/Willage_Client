using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Vizual;
using WillagePrototyp.Jadro;
using WillagePrototyp.OknoGeneratoru;

namespace WillagePrototyp.Testy;

/// <summary>
/// G-6: test náhledů M1–M3 v okně (instancuje res://nastroje/GeneratorSveta.tscn): vrstvy, textura = BarvyNahledu, izolace,
/// úsečka dvěma kliky, řez M1/M2 profil a M3 materiály 384 × 512 s režimy izolace, materiál pod kurzorem, M4 zástupné, otisky.
/// Snímky okna pod Xvfb (bez --headless): --snimky=složka.
/// Spuštění: Godot_mono [--headless] --path godot-prototyp res://nastroje/testy/NahledyTest.tscn -- --kes=/tmp/willage-test-kes-6d [--snimky=/tmp/g6]
/// </summary>
public partial class NahledyTest : Node
{
    int _ok, _chyb;
    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }
    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;

    async Task<bool> Cekej(Func<bool> p, int snimku = 1800)
    {
        for (int i = 0; i < snimku; i++) { if (p()) return true; await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
        return p();
    }

    string _snimky = "";
    bool Renderer => DisplayServer.GetName() != "headless";
    async Task Snimek(string jmeno)
    {
        if (_snimky == "" || !Renderer) return;
        for (int i = 0; i < 4; i++) await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        System.IO.Directory.CreateDirectory(_snimky);
        GetViewport().GetTexture().GetImage().SavePng(System.IO.Path.Combine(_snimky, jmeno));
        GD.Print($"  snímek {jmeno}");
    }

    WillageJadro J = null!;
    GeneratorSvetaOkno O = null!;

    /// <summary>Vybere modul a počká na náhled i řez.</summary>
    async Task Vyber(string m)
    {
        int n = O.Nahled.PrijatychNahledu, r = O.Rez.PrijatychRezu;
        O.Seznam.Vyber(m);
        if (Willage.Gen.Api.Sluzby.NahledyModuluApi.ModulySNahledem.Contains(m)) await Cekej(() => O.Nahled.PrijatychNahledu > n && O.Rez.PrijatychRezu > r && J.Cekajicich == 0 && J.Bezi is null);
        else await Cekej(() => O.Konfigurator.Modul == m, 120);
    }

    async Task CekejNahled(Action a) { int n = O.Nahled.PrijatychNahledu; a(); await Cekej(() => O.Nahled.PrijatychNahledu > n && J.Bezi is null); }
    async Task CekejRez(Action a) { int n = O.Rez.PrijatychRezu; a(); await Cekej(() => O.Rez.PrijatychRezu > n && J.Bezi is null); }

    bool TexturaSedi()
    {
        var n = J.PosledniNahled!; var t = O.Nahled.MapaModulu.Texture as ImageTexture;
        return t is not null && t.GetWidth() == n.Nx && t.GetHeight() == n.Ny && t.GetImage().GetData().SequenceEqual(BarvyNahledu.Rgba(n, J.MaterialyDto));
    }

    public override async void _Ready()
    {
        J = WillageJadro.Instance!;
        if (J is null) { GD.Print("CHYBA: autoload WillageJadro chybí"); GetTree().Quit(1); return; }
        J.KesCesta = Arg("kes", J.KesCesta); _snimky = Arg("snimky", "");
        if (Renderer) GetWindow().Size = new Vector2I(1600, 960);
        GD.Print($"- G-6: náhledy M1–M3 v okně ({DisplayServer.GetName()})");
        O = GD.Load<PackedScene>("res://nastroje/GeneratorSveta.tscn").Instantiate<GeneratorSvetaOkno>();
        O.PrvniModul = "M0";
        var hotovo = ToSignal(J, WillageJadro.SignalName.PlanetaHotova);
        AddChild(O);
        await hotovo;

        // M1
        await Vyber("M1");
        var n = J.PosledniNahled!;
        Je(O.Nahled.VlastniNahled && n.Modul == "M1" && n.Vrstva == VrstvaNahleduDto.Vyska && n.Nx == 256 && n.Ny == 256 && n.KrokM == 16, $"M1: vlastní náhled výška 256×256 po 16 m ({n.Ms:F0} ms)");
        Je(TexturaSedi(), "textura náhledu = BarvyNahledu.Rgba (bajtově)");
        var r = J.PosledniRez!;
        Je(r.Modul == "M1" && r.Nx == 512 && r.PovrchM1 is null && r.Nz == 0 && O.Rez.Plocha.Visible, $"M1: profil řezu y 1984 přes 4096 m, {r.Nx} vzorků po {r.KrokM} m ({r.Ms:F0} ms)");
        await Snimek("01-m1-vyska.png");
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.Horniny));
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.Horniny && TexturaSedi(), $"M1 horniny: textura = BarvyNahledu, {J.PosledniNahled.Ms:F0} ms");
        await Snimek("02-m1-horniny.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.Relief && J.PosledniNahled.Izolace && O.Nahled.Izolace, "Izolovat (M1) → vrstva Relief, příznak izolace");
        await Snimek("03-m1-izolace-relief.png");

        // M2
        await Vyber("M2");
        n = J.PosledniNahled!; r = J.PosledniRez!;
        Je(n.Vrstva == VrstvaNahleduDto.Pevnina && !O.Nahled.Izolace && n.Cisla["kontinentu"] == 3, $"M2: pevnina, izolace vypnutá po změně modulu, kontinentů {n.Cisla["kontinentu"]}, ostrovů {n.Cisla["ostrovu"]}");
        Je(r.PovrchM1 is not null && r.HladinaMoreM == 60 && r.Nx == 512, $"M2: profil s M1 a hladinou {r.HladinaMoreM} m");
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.More));
        Je(J.PosledniNahled!.Cisla.ContainsKey("podil_more"), $"M2 moře: podíl v náhledu {J.PosledniNahled.Cisla["podil_more"]:F3} (cíl masky {J.PosledniNahled.Cisla["podil_more_cil"]:F3})");
        await Snimek("04-m2-more.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.RozdilM2M1 && J.PosledniNahled.Cisla["min"] < -10, $"Izolovat (M2) → rozdíl M2 − M1, min {J.PosledniNahled.Cisla["min"]:F1} m");
        await Snimek("05-m2-izolace-rozdil.png");

        // M3
        await Vyber("M3");
        n = J.PosledniNahled!; r = J.PosledniRez!;
        Je(n.Vrstva == VrstvaNahleduDto.MaterialPovrchu && n.Nx == 128 && TexturaSedi(), $"M3: materiál povrchu 128×128 ({n.Ms:F0} ms; pomalá vrstva, RozliseniPomale)");
        Je(r.Nx == 384 && r.Nz == 512 && r.KrokM == 0.25 && J.PosledniRezTextura is { } rt && rt.GetWidth() == 384 && rt.GetHeight() == 512, $"M3: řez nástroje x 2048 ± 48, y 1984 – 384 × 512 buněk, obraz 384×512 ({r.Ms:F0} ms)");
        var plocha = O.Rez.Plocha;
        string pod = O.Rez.Popis(new Vector2(plocha.Size.X * 0.5f, plocha.Size.Y * 0.6f));
        Je(pod.Contains("materiál") && !pod.Contains("?"), "materiál pod kurzorem: " + pod);
        O.Rez.Kurzor.Text = pod;   // pod Xvfb není myš – ať snímek ukáže popis
        await Snimek("06-m3-rez.png");
        int vse = r.Materialy.Count(b => b != 0);
        await CekejRez(() => O.Konfigurator.PrepniIzolaci());
        var rv = J.PosledniRez!;
        await CekejRez(() => O.Konfigurator.PrepniIzolaci());
        var ru = J.PosledniRez!;
        int utv = ru.Materialy.Count(b => b != 0);
        Je(rv.Rezim == RezimRezuDto.JenVrstvy && ru.Rezim == RezimRezuDto.JenUtvary && O.Rez.Rezim == RezimRezuDto.JenUtvary && utv > 0 && utv < vse,
            $"izolace řezu M3: vše {vse} buněk, jen útvary {utv} buněk");
        await Snimek("07-m3-jen-utvary.png");
        await CekejRez(() => O.Konfigurator.PrepniIzolaci());
        Je(O.Rez.Rezim == RezimRezuDto.Vse, "třetí klik → zpět vše");

        // úsečka dvěma kliky na náhled
        n = J.PosledniNahled!;
        O.Nahled.KlikniNaPixel(new Vector2(10, 64));
        await CekejRez(() => O.Nahled.KlikniNaPixel(new Vector2(100, 64)));
        r = J.PosledniRez!;
        double ocek = n.X0M + 10 * n.KrokM;
        Je(Math.Abs(O.Nahled.UseckaOdM.X - ocek) < 1 && Math.Abs(O.Nahled.UseckaDoM.X - (n.X0M + 100 * n.KrokM)) < 1 && Math.Abs(r.Od.XM - ocek) < 1 && r.Nx == 512,
            $"dva kliky (pixel 10 → 100, řádek 64) → úsečka {O.Nahled.UseckaOdM} → {O.Nahled.UseckaDoM} m, řez {r.Nx} vzorků po {r.KrokM:F3} m");
        await Snimek("08-m3-usecka-kliky.png");

        // M4: zástupné (G-7)
        await Vyber("M4");
        Je(!O.Nahled.VlastniNahled && !O.Rez.Plocha.Visible && O.Rez.GetNode<Control>("Zastupny").Visible && O.Nahled.GetNode<Control>("Poznamka").Visible, "M4: planeta (G-5) + zástupný řez a náhled (G-7)");

        // otisky beze změny
        J.Otisky();
        var o = (Godot.Collections.Dictionary)(await ToSignal(J, WillageJadro.SignalName.OtiskyHotove))[0];
        Je((string)o["Mapa"] == "800d420bb00047de" && (string)o["Klima"] == "cb11da8d141a2a5e" && (string)o["VodaBlok"] == "377a8210f82c856a", $"otisky po náhledech: {o["Mapa"]}, {o["Klima"]}, {o["VodaBlok"]}");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb);
    }
}
