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
/// G-7: test náhledů M4–M6 v okně (instancuje res://nastroje/GeneratorSveta.tscn): M4 vrstvy planety + vodníci + izolace posunu eroze,
/// M5 biomy + tabulka pásem + izolace jen klima, M6 hladina + prameny + izolace jen hladina / jen prameny, řez s hladinou (start i pobřeží),
/// 7d zástupná vrstva a štítek, otisky. Snímky okna pod Xvfb (bez --headless): --snimky=složka.
/// Spuštění: Godot_mono [--headless] --path godot-prototyp res://nastroje/testy/NahledyM4M6Test.tscn -- --kes=/tmp/willage-test-kes-6d [--snimky=/tmp/g7]
/// </summary>
public partial class NahledyM4M6Test : Node
{
    int _ok, _chyb;
    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }
    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;

    async Task<bool> Cekej(Func<bool> p, int snimku = 3000)
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

    async Task Vyber(string m)
    {
        int n = O.Nahled.PrijatychNahledu, r = O.Rez.PrijatychRezu;
        O.Seznam.Vyber(m);
        await Cekej(() => O.Nahled.PrijatychNahledu > n && O.Rez.PrijatychRezu > r && J.Cekajicich == 0 && J.Bezi is null);
    }

    async Task CekejNahled(Action a) { int n = O.Nahled.PrijatychNahledu; a(); await Cekej(() => O.Nahled.PrijatychNahledu > n && J.Bezi is null && J.Cekajicich == 0); }
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
        GD.Print($"- G-7: náhledy M4–M6 v okně ({DisplayServer.GetName()})");
        O = GD.Load<PackedScene>("res://nastroje/GeneratorSveta.tscn").Instantiate<GeneratorSvetaOkno>();
        O.PrvniModul = "M0";
        var hotovo = ToSignal(J, WillageJadro.SignalName.PlanetaHotova);
        AddChild(O);
        await hotovo;

        // M4 eroze
        await Vyber("M4");
        var n = J.PosledniNahled!; var r = J.PosledniRez!;
        Je(O.Nahled.VlastniNahled && n.Modul == "M4" && n.Vrstva == VrstvaNahleduDto.VyskaPlanety && n.Nx == 256 && n.Ny == 127 && TexturaSedi(), $"M4: vlastní náhled výška planety 256×127 po {n.KrokM:0.#} m, textura = BarvyNahledu ({n.Ms:F0} ms)");
        Je(n.Body!.Count == 92 && O.Nahled.BodyMapy.Body.Count == 92 && n.Popis.Contains("800d420bb00047de"), $"M4: 92 vodníků kroku 6 jako body, otisk mapy v popisu");
        Je(r.Modul == "M4" && r.Nx == 512 && r.PovrchM1 is not null && r.Rady!.ContainsKey("eroze_m") && O.Rez.Plocha.Visible, $"M4: profil přes planetu před / po erozi, {r.Nx} vzorků po {r.KrokM} m ({r.Ms:F0} ms)");
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.Toky));
        await Snimek("02-m4-toky-vodnici.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        n = J.PosledniNahled!;
        Je(n.Vrstva == VrstvaNahleduDto.PosunEroze && n.Izolace && n.Body is null && O.Nahled.BodyMapy.Body.Count == 0 && TexturaSedi(), $"Izolovat (M4) → mapa posunu eroze bez bodů, max {n.Cisla["max"]:F1} m");
        await Snimek("01-m4-izolace-posun-eroze.png");

        // M5 klima + tabulka pásem
        await Vyber("M5");
        n = J.PosledniNahled!;
        Je(n.Vrstva == VrstvaNahleduDto.Teplota && !O.Nahled.Izolace && TexturaSedi(), $"M5: teplota {n.Cisla["min"]:F1}…{n.Cisla["max"]:F1} °C, izolace vypnutá po změně modulu");
        await Cekej(() => O.Nahled.Pasma.Radku > 0);
        Je(O.Nahled.Pasma.Visible && O.Nahled.Pasma.Radku == 3 && J.PosledniTabulkaPasem[1].Id == "mirne", $"M5: tabulka pásem {O.Nahled.Pasma.Radku} řádky (subtropy, mírné, chladné)");
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.BiomKlimatu));
        n = J.PosledniNahled!;
        Je(Math.Abs(n.Cisla["biom_mírný_les_%"] - 91.0) < 0.05 && n.Body!.Count == 86, $"M5 biomy: mírný les {n.Cisla["biom_mírný_les_%"]:F1} % (report 7b 91,0), 86 vodníků");
        r = J.PosledniRez!;
        O.Rez.Kurzor.Text = O.Rez.Popis(new Vector2(O.Rez.Plocha.Size.X * 0.5f, O.Rez.Plocha.Size.Y * 0.5f));
        Je(r.Rady!.ContainsKey("teplota_c") && O.Rez.Kurzor.Text.Contains("°C"), "M5 řez: profil s teplotou a srážkami, popis pod kurzorem: " + O.Rez.Kurzor.Text);
        await Snimek("03-m5-biomy-tabulka-pasem.png");
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.KorytaKlimatu));
        Je(J.PosledniNahled!.Cisla["koryta_aktivni_%"] > 73 && TexturaSedi(), $"M5 koryta: aktivní {J.PosledniNahled.Cisla["koryta_aktivni_%"]:F1} %");
        await Snimek("04-m5-koryta.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.BiomBezOaz && J.PosledniNahled.Izolace && J.PosledniNahled.Body is null, "Izolovat (M5) → jen klima (biom bez oáz), bez bodů");

        // M6 voda
        await Vyber("M6");
        n = J.PosledniNahled!; r = J.PosledniRez!;
        Je(n.Vrstva == VrstvaNahleduDto.Hladina && n.Nx == 128 && n.X0M == 1792 && n.Body!.Count == 21 && O.Nahled.BodyMapy.Body.Count == 21 && TexturaSedi(),
            $"M6: hloubka hladiny 128×128 start 3 × 3, 21 pramenů (report 7c) ({n.Ms:F0} ms)");
        Je(r.Modul == "M6" && r.Nx == 384 && r.Nz == 512 && r.HladinaPodzemniM is not null && r.Body!.Count == 12 && J.PosledniRezTextura is not null,
            $"M6: řez s hladinou 384 × 512 (jako eroze rez), 12 pramenů do 150 m ({r.Ms:F0} ms)");
        var zast = O.Rez.GetNode<Control>("Zastupny");
        Je(zast.Visible && ((Label)zast).Text.Contains("7d") && ((Label)zast).Text.Contains("zástupný"), "M6 řez: štítek zástupné 7d: " + ((Label)zast).Text);
        O.Rez.Kurzor.Text = O.Rez.Popis(new Vector2(O.Rez.Plocha.Size.X * 0.4f, O.Rez.Plocha.Size.Y * 0.5f));
        Je(O.Rez.Kurzor.Text.Contains("hladina") && O.Rez.Kurzor.Text.Contains("materiál"), "M6 pod kurzorem: " + O.Rez.Kurzor.Text);
        await Snimek("05-m6-hladina-prameny.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.JenHladina && J.PosledniNahled.Body is null && O.Nahled.BodyMapy.Body.Count == 0, "Izolovat (M6) 1 → jen hladina (bez pramenů)");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.JenPrameny && J.PosledniNahled.Body!.Count == 21 && O.Nahled.BodyMapy.Body.Count == 21, "Izolovat (M6) 2 → jen prameny (21 bodů)");
        await Snimek("06-m6-jen-prameny.png");
        await CekejNahled(() => O.Konfigurator.PrepniIzolaci());
        Je(J.PosledniNahled!.Vrstva == VrstvaNahleduDto.Hladina && !O.Nahled.Izolace, "třetí klik → zpět hladina");
        // zástupná vrstva 7d
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.ZvodnelaZona7d));
        n = J.PosledniNahled!;
        Je(n.Zastupny && n.Hodnoty.All(float.IsNaN) && TexturaSedi() && O.Nahled.GetNode<Label>("Info").Text.StartsWith("[zástupné]"), "M6: vrstva 7d zástupná (šrafa, NaN, označená)");
        await Snimek("08-m6-7d-zastupna.png");
        // řez s hladinou přes pobřeží (břeh x ≈ 907,6 m na y 1984): náhled oblasti u pobřeží + úsečka
        await CekejNahled(() => O.Nahled.VyberVrstvu(VrstvaNahleduDto.Hladina));
        await CekejNahled(() => O.Nahled.NastavOblast(new Rect2(800, 1856, 256, 256)));
        n = J.PosledniNahled!;
        Je(n.X0M == 800 && n.Y0M == 1856 && n.KrokM == 2 && n.Cisla.ContainsKey("pramenu") && TexturaSedi(), $"M6 náhled oblasti u pobřeží 256 m po 2 m, {n.Cisla["pramenu"]} pramenů ({n.Ms:F0} ms)");
        await CekejRez(() => O.Nahled.NastavUsecku(new Vector2(868, 1984), new Vector2(996, 1984)));
        r = J.PosledniRez!;
        int pod = Enumerable.Range(0, r.Nx).Count(i => r.PovrchM[i] < r.HladinaMoreM);
        Je(r.Nx == 512 && pod > 0 && pod < r.Nx && Math.Abs(r.HladinaPodzemniM![0] - 60) < 1e-9, $"M6 řez přes pobřeží 128 m: {pod} vzorků moře, hladina v moři = 60 m ({r.Ms:F0} ms)");
        O.Rez.Kurzor.Text = O.Rez.Popis(new Vector2(O.Rez.Plocha.Size.X * 0.5f, O.Rez.Plocha.Size.Y * 0.55f));
        await Snimek("07-m6-rez-pobrezi-hladina.png");

        // otisky beze změny
        J.Otisky();
        var o = (Godot.Collections.Dictionary)(await ToSignal(J, WillageJadro.SignalName.OtiskyHotove))[0];
        Je((string)o["Mapa"] == "800d420bb00047de" && (string)o["Klima"] == "cb11da8d141a2a5e" && (string)o["VodaBlok"] == "377a8210f82c856a", $"otisky po náhledech: {o["Mapa"]}, {o["Klima"]}, {o["VodaBlok"]}");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb);
    }
}
