using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Willage.Materialy.Api.Sluzby;
using WillagePrototyp.EditorMaterialu;

namespace WillagePrototyp.Testy;

/// <summary>
/// T-2: test okna Editor materiálů (instancuje res://nastroje/EditorMaterialu.tscn): kontrola Dev (golden, zrcadlo), seznam a filtr,
/// vzorek 5 materiálů (Jan 21:44; ostatní zástupné), T-2d: receptury v2 (base_texture + baseTile, přepínače, 4 variace), T-2b: receptury v1 z Dev → golden v okně, paleta, operace v1 ze schématu Dev, variace seedu, návrh profilu jen pro náhled, konfigurátor kroků (vypnout, přidat, zástupné zamčené),
/// jiný materiál + dlaždice, odezva, a okno bez nástroje (zástupné). Snímky pod Xvfb: --snimky=složka.
/// Spuštění: Godot_mono [--headless] --path godot-prototyp res://nastroje/testy/EditorMaterialuTest.tscn [-- --snimky=/tmp/t2]
/// </summary>
public partial class EditorMaterialuTest : Node
{
    int _ok, _chyb;
    void Je(bool c, string co) { if (c) { _ok++; GD.Print("  OK: ", co); } else { _chyb++; GD.Print("  CHYBA: ", co); } }
    static string Arg(string k, string d) => OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--" + k + "="))?.Split('=', 2)[1] ?? d;
    string _snimky = "";
    bool Renderer => DisplayServer.GetName() != "headless";

    async Task<bool> Cekej(Func<bool> p, int snimku = 3000)
    {
        for (int i = 0; i < snimku; i++) { if (p()) return true; await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
        return p();
    }

    async Task Snimek(string jmeno)
    {
        if (_snimky == "" || !Renderer) return;
        for (int i = 0; i < 4; i++) await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        System.IO.Directory.CreateDirectory(_snimky);
        GetViewport().GetTexture().GetImage().SavePng(System.IO.Path.Combine(_snimky, jmeno));
        GD.Print($"  snímek {jmeno}");
    }

    EditorMaterialuOkno O = null!;
    readonly System.Collections.Generic.List<(byte Id, string Key, string Nazev, string Dlazdice, Willage.Materialy.Api.Dto.TexturaVpmgDto Golden, System.Collections.Generic.List<Willage.Materialy.Api.Dto.TexturaVpmgDto> Var)> _arch = new();

    /// <summary>Textura VPMG jako 2×2 dlaždice (TextureRect, nejbližší soused).</summary>
    static TextureRect Bunka(Image img, int px)
    {
        var dl = Image.CreateEmpty(img.GetWidth() * 2, img.GetHeight() * 2, false, Image.Format.Rgba8);
        for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) dl.BlitRect(img, new Rect2I(0, 0, img.GetWidth(), img.GetHeight()), new Vector2I(x * img.GetWidth(), y * img.GetHeight()));
        return new TextureRect { Texture = ImageTexture.CreateFromImage(dl), CustomMinimumSize = new Vector2(px, px), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.Scale, TextureFilter = CanvasItem.TextureFilterEnum.Nearest };
    }
    static Image Img(Willage.Materialy.Api.Dto.TexturaVpmgDto t) => Image.CreateFromData(t.Sirka, t.Vyska, false, Image.Format.Rgba8, t.Rgba);
    static Label Pop(string t, int fs = 13) { var l = new Label { Text = t, CustomMinimumSize = new Vector2(150, 0), VerticalAlignment = VerticalAlignment.Center }; l.AddThemeFontSizeOverride("font_size", fs); return l; }

    /// <summary>T-2d: arch (Godot UI, snímek pod Xvfb): řádek = materiál, sloupce podle <paramref name="hlavicky"/>.</summary>
    async Task Arch(string soubor, string titul, string[] hlavicky, Func<int, Control[]> radek, int px)
    {
        if (_snimky == "" || !Renderer) return;
        var bg = new Panel { Name = "Arch" }; bg.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        var sb = new StyleBoxFlat { BgColor = new Color(0.12f, 0.12f, 0.14f) }; bg.AddThemeStyleboxOverride("panel", sb);
        var v = new VBoxContainer { Position = new Vector2(16, 10) };
        v.AddChild(Pop(titul, 16));
        var g = new GridContainer { Columns = hlavicky.Length };
        g.AddThemeConstantOverride("h_separation", 10); g.AddThemeConstantOverride("v_separation", 6);
        foreach (var h in hlavicky) { var l = Pop(h, 12); l.Modulate = new Color(0.7f, 0.8f, 1f); g.AddChild(l); }
        for (int i = 0; i < _arch.Count; i++) foreach (var c in radek(i)) g.AddChild(c);
        v.AddChild(g); bg.AddChild(v); AddChild(bg);
        await Snimek(soubor);
        bg.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    /// <summary>Uloží samotnou texturu VPMG (dlaždice 2×2, zvětšená 4× nejbližším sousedem) – i headless.</summary>
    void UlozTexturu(Willage.Materialy.Api.Dto.TexturaVpmgDto t, string jmeno)
    {
        if (_snimky == "") return;
        var img = Image.CreateFromData(t.Sirka, t.Vyska, false, Image.Format.Rgba8, t.Rgba);
        var dl = Image.CreateEmpty(t.Sirka * 2, t.Vyska * 2, false, Image.Format.Rgba8);
        for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++) dl.BlitRect(img, new Rect2I(0, 0, t.Sirka, t.Vyska), new Vector2I(x * t.Sirka, y * t.Vyska));
        dl.Resize(t.Sirka * 8, t.Vyska * 8, Image.Interpolation.Nearest);
        System.IO.Directory.CreateDirectory(_snimky);
        dl.SavePng(System.IO.Path.Combine(_snimky, jmeno));
    }

    /// <summary>Provede akci a počká na nový hlavní náhled i 4 variace.</summary>
    async Task Hotovo(Action a)
    {
        a();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        int n = O.Jadro.Hotovych;
        await Cekej(() => O.Jadro.Cekajicich == 0 && O.Jadro.Hotovych >= n);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    static bool Jednobarevna(byte[] b) { for (int i = 4; i < b.Length; i++) if (b[i] != b[i % 4]) return false; return true; }

    public override async void _Ready()
    {
        _snimky = Arg("snimky", "");
        if (Renderer) GetWindow().Size = new Vector2I(1600, 960);
        GD.Print("T-2 EditorMaterialuTest");
        O = GD.Load<PackedScene>("res://nastroje/EditorMaterialu.tscn").Instantiate<EditorMaterialuOkno>();
        AddChild(O);
        var J = O.Jadro; var st = J.Stav; var api = J.Api;
        string shaPred = api.Pin.ZrcadloSha;

        await Cekej(() => J.Info != null && J.Cekajicich == 0);
        Je(J.Info!.Dostupny && J.GoldenVysledek is { } g0 && g0.Ocekavany == 1756279408u && g0.Spocteny == g0.Ocekavany && O.Lista.Golden.Text.Contains("= Dev"),
            $"lišta: {O.Lista.Pin.Text} | {O.Lista.Golden.Text}");
        Je(J.Zrcadlo is { BajtyBezKonce: true, Zaznamy: true, Pocet: 75 }, "lišta: zrcadlo = katalog Dev v pinu");
        // vzorek 5 materiálů (Jan 21:44): seznam výchozí filtr = vzorek, ostatní zástupné
        var vz = api.Vzorek.Materialy;
        Je(O.Seznam.Seznam.ItemCount == 5 && O.Seznam.Zobrazene.SequenceEqual(vz.Select(m => m.Id)) && st.Material == 1, $"seznam: výchozí filtr vzorek 5 materiálů ({string.Join(",", O.Seznam.Zobrazene)}), vybrán 1 tráva");
        O.Seznam.FiltrSkupiny("");
        int zast = Enumerable.Range(0, O.Seznam.Seznam.ItemCount).Count(i => O.Seznam.Seznam.GetItemText(i).EndsWith("(zástupné)"));
        Je(O.Seznam.Seznam.ItemCount == 75 && zast == 70, $"filtr všechny: 75 materiálů, {zast} označeno (zástupné)");
        O.Seznam.FiltrSkupiny("pisek");
        int pisku = api.Katalog.Materialy.Count(m => m.Skupina == "pisek");
        Je(O.Seznam.Seznam.ItemCount == pisku && O.Seznam.Zobrazene.All(id => api.Katalog.Material(id)!.Skupina == "pisek"), $"filtr skupiny písek: {O.Seznam.Seznam.ItemCount}");
        O.Seznam.FiltrSkupiny(SeznamMaterialu.FiltrVzorek);
        Je(O.Profil.PodleNazvu.Count == 6 && O.Profil.PodleNazvu["palette"].BarevVzorniku == 4 && O.Konfigurator.KrokyUzly.Count == 4 && O.Fyzika.Radku >= 11,
            $"uzly: profil 6 editorů (paleta 4 barvy), receptura v2 trávy 4 kroky ({O.Konfigurator.KrokyUzly.Count}), fyzika {O.Fyzika.Radku} řádků");

        // T-2b/T-2d: každý materiál vzorku – výchozí receptura v2 z data/vpmg/receptury (base_texture nad baseTile), seed goldenu → golden Dev v okně, 4 variace
        await Hotovo(() => O.Konfigurator.NastavSeedUzivatel(0xC0FFEE00u));
        int c = 1;
        foreach (var m in vz)
        {
            if (st.Material != m.Id) await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, m.Id));
            var zr = api.Receptury.Zaznam(m.Id)!;
            var tm = J.Posledni["hlavni"];
            Je(st.Material == m.Id && RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(zr.Receptura) && O.Konfigurator.KrokyUzly.Count == zr.Receptura.Kroky.Count
               && tm.Ok && tm.Checksum == zr.GoldenChecksum && O.InfoNahledu.Text.Contains("golden v2 Dev") && O.Konfigurator.Validace.Text.Contains(zr.Soubor),
                $"vzorek {m.Id} {m.Key}: receptura v2 ({zr.Soubor}, {zr.Receptura.Kroky.Count} kroků) → {tm.Checksum} = golden Dev {zr.GoldenChecksum}");
            var zk = api.Zaklady.Dlazdice.Single(x => x.MaterialId == m.Id);
            Je(O.Profil.PopisDlazdice.Text.Contains("data/vpmg/zaklady/" + zk.Soubor) && O.Profil.Dlazdice.GetChildCount() == 3 && O.Konfigurator.KrokyUzly[0].Editory.Any(e => e.Ovladac is CheckBox),
                $"vzorek {m.Id}: profil ukazuje baseTile = {zk.Soubor} (náhled PNG), krok base_texture má přepínače");
            var vv = Enumerable.Range(0, 4).Select(i => J.Posledni["var" + i]).ToList();
            Je(vv.All(t => t.Ok) && vv.Select(t => t.Checksum).Distinct().Count() == 4, $"vzorek {m.Id}: 4 variace seedu ({string.Join(",", vv.Select(t => t.Checksum))})");
            _arch.Add((m.Id, m.Key, api.Katalog.Material(m.Id)!.Nazev, zk.Cesta, tm, vv));
            UlozTexturu(tm, $"textura-v2-{m.Id}-{m.Key}.png");
            for (int i = 0; i < 4; i++) UlozTexturu(vv[i], $"variace-v2-{m.Id}-{m.Key}-{i}.png");
            await Snimek($"{c++:00}-v2-{m.Id}-{m.Key}.png");
        }
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 52));
        Je(st.Material == 6 && O.Titulek.Text.StartsWith("zástupné") && st.VyberMaterial(52) is { } ch52 && ch52.Contains("mimo vzorek"), "materiál 52 mimo vzorek: odmítnut, titulek „zástupné…“, zůstává 6");
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 1));
        uint REF = api.Receptury.Zaznam(1)!.GoldenChecksum;
        var tg = J.Posledni["hlavni"];
        var tex = (ImageTexture)O.Nahled.Texture;
        Je(tex.GetWidth() == 128 && tex.GetImage().GetRegion(new Rect2I(0, 0, 64, 64)).GetData().SequenceEqual(tg.Rgba) && tex.GetImage().GetRegion(new Rect2I(64, 64, 64, 64)).GetData().SequenceEqual(tg.Rgba),
            "náhled: dlaždice 2×2, každá dlaždice = bajty VPMG");
        var var4 = Enumerable.Range(0, 4).Select(i => J.Posledni["var" + i].Checksum).ToList();
        Je(var4.Distinct().Count() == 4 && !var4.Contains(tg.Checksum), $"variace seedu: 4 různé checksumy ({string.Join(",", var4)})");
        Je(O.Profil.PodleNazvu["layerDensityPermille"].GetChild<Label>(0).TooltipText.Contains("nečte") && O.Profil.PodleNazvu["palette"].GetChild<Label>(0).TooltipText.Contains("Čte ho"),
            "profil trávy: layerDensity „nečte žádná zapnutá operace“, palette „čte ho zapnutý krok“");

        // odezva
        var sw = new Stopwatch(); double suma = 0; int n = 8;
        for (int i = 0; i < n; i++) { sw.Restart(); await Hotovo(() => O.Konfigurator.NastavSeedUzivatel((uint)(1000 + i))); suma += sw.Elapsed.TotalMilliseconds; }
        GD.Print($"  odezva změna seedu → hlavní + 4 variace hotové: průměr {suma / n:F1} ms (včetně čekání na snímky)");
        Je(suma / n < 500, $"odezva < 500 ms ({suma / n:F1} ms)");
        await Hotovo(() => O.Konfigurator.NastavSeedUzivatel(0xC0FFEE00u));

        // návrh profilu (paleta) jen pro náhled
        await Hotovo(() => O.Profil.PodleNazvu["palette"].ZadejJakoUzivatel("#2F4F2F, #4A7A3A, #8FBC5A, #C8E07A"));
        var tn = J.Posledni["hlavni"];
        Je(st.Navrh.Palette is { Count: 4 } && tn.Ok && tn.Checksum != REF && O.Profil.StavNavrhu.Text.Contains("NÁVRH") && O.Titulek.Text.Contains("NÁVRH") && O.Profil.PodleNazvu["palette"].BarevVzorniku == 4,
            $"návrh palety (4 barvy) → {tn.Checksum}, lišta profilu „NÁVRH jen pro náhled“");
        await Snimek("06-navrh-palety.png");
        Je(PinDev.Nacti(api.KorenDat).ZrcadloSha == shaPred, "katalog (zrcadlo) na disku beze změny");
        await Hotovo(() => O.Profil.ZrusitNavrh.EmitSignal(BaseButton.SignalName.Pressed));
        Je(st.Navrh.Prazdny && J.Posledni["hlavni"].Checksum == REF && O.InfoNahledu.Text.Contains("golden v2 Dev"), "Zpět na katalog → znovu golden v2");

        // T-2d: přepínač base_texture offsetEnabled (bool Dev) → v receptuře "false", výstup jiný
        uint predOff = J.Posledni["hlavni"].Checksum;
        var off = O.Konfigurator.KrokyUzly[0].Editory.First(e => e.Name.ToString() == "Par_offsetEnabled");
        await Hotovo(() => off.ZadejJakoUzivatel("false"));
        await Cekej(() => J.Posledni["hlavni"].Checksum != predOff, 600);
        GD.Print($"  offset: {st.Receptura.Kroky[0].Params["offsetEnabled"]} {predOff} → {J.Posledni["hlavni"].Checksum} {J.Posledni["hlavni"].Chyba}");
        Je(st.Receptura.Kroky[0].Params["offsetEnabled"] == "false" && J.Posledni["hlavni"].Ok && J.Posledni["hlavni"].Checksum != predOff && predOff == REF, "přepínač offsetEnabled vypnut → \"false\" v receptuře, jiný výstup");
        await Hotovo(() => off.ZadejJakoUzivatel("true"));
        await Cekej(() => J.Posledni["hlavni"].Checksum == REF, 600);
        Je(J.Posledni["hlavni"].Checksum == REF, "přepínač zpět true → znovu golden v2");

        // konfigurátor: nabídka z Dev schématu, krok strata s parametry z Dev
        var pop = O.Konfigurator.Pridat.GetPopup();
        int zamcenych = Enumerable.Range(0, pop.ItemCount).Count(i => pop.IsItemDisabled(i));
        Je(pop.ItemCount == 18 && zamcenych == 6, $"nabídka přidat krok: {pop.ItemCount} položek (12 z registru Dev), {zamcenych} zástupných zamčených");
        var nab = Willage.Materialy.Api.Editor.PopisKonfiguratoruReceptury.Nabidka(api.Schema);
        int iStrata = nab.ToList().FindIndex(x => x.Type == "strata");
        await Hotovo(() => pop.EmitSignal(PopupMenu.SignalName.IdPressed, iStrata));
        await Cekej(() => O.Konfigurator.KrokyUzly.Count == 5);
        var ks = O.Konfigurator.KrokyUzly.LastOrDefault();
        Je(st.Receptura.Kroky.Count == 5 && st.Receptura.Kroky[4].Type == "strata" && ks != null && ks.Editory.Select(e => e.Name.ToString()).SequenceEqual(new[] { "Par_bandMinPx", "Par_bandJitterPermille" })
           && ks.Editory.All(e => e.Ovladac is LineEdit { PlaceholderText: "výchozí Dev" }) && J.Posledni["hlavni"].Ok,
            "přidán krok strata → editory bandMinPx, bandJitterPermille ze schématu Dev (prázdné = výchozí Dev z profilu)");
        Je(O.Profil.PodleNazvu["layerDensityPermille"].GetChild<Label>(0).TooltipText.Contains("Čte ho"), "po přidání strata profil layerDensity „čte ho zapnutý krok“");
        await Hotovo(() => ks!.Editory[0].ZadejJakoUzivatel("6"));
        Je(st.Receptura.Kroky[4].Params.TryGetValue("bandMinPx", out var bm) && bm == "6", "bandMinPx 6 zadán v editoru → v receptuře");
        await Snimek("07-receptura-trava-plus-strata.png");
        await Hotovo(() => O.Konfigurator.KrokyUzly[3].Zapnuto.ButtonPressed = false);
        Je(!st.Receptura.Kroky[3].Enabled && J.Posledni["hlavni"].Checksum != REF, "vypnutý grass_tufts změní výstup");

        // jiný materiál → jeho receptura v1, dlaždice 3×3
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 3));
        await Cekej(() => st.Material == 3 && O.Konfigurator.KrokyUzly.Count == 3);
        Je(st.Material == 3 && RecepturyVpmg.DoJson(st.Receptura) == RecepturyVpmg.DoJson(api.Receptury.Zaznam(3)!.Receptura) && O.Fyzika.GetChild<Label>(1).Text == "3", "výběr materiálu 3: načtena jeho receptura v2 (úpravy trávy se nepřenesou), fyzika 3");
        O.Dlazdice.Select(2); O.Dlazdice.EmitSignal(OptionButton.SignalName.ItemSelected, 2);
        Je(((ImageTexture)O.Nahled.Texture).GetWidth() == 192, "dlaždice 3×3 → 192 px");
        await Snimek("08-pisek-v2-dlazdice-3x3.png");

        // T-2d: archy pro report – variace seedu a srovnání v1 (procedurální, fixture Dev) / v2 (base_texture)
        O.Visible = false;
        await Arch("20-variace.png", "T-2d – vzorek 5 materiálů: receptury v2 (Dev 36ac11f), dlaždice 2×2 z 64 px; variace = seed + i·7919 (tint pevný v receptuře)",
            new[] { "materiál", "baseTile (klient, 128 px)", "v2 seed 0xC0FFEE00", "variace 1", "variace 2", "variace 3", "variace 4" },
            i => new Control[] { Pop($"{_arch[i].Id} {_arch[i].Key}\n{_arch[i].Nazev}") , Bunka(Image.LoadFromFile(_arch[i].Dlazdice), 160), Bunka(Img(_arch[i].Golden), 160) }
                .Concat(_arch[i].Var.Select(t => (Control)Bunka(Img(t), 160))).ToArray(), 160);
        string devKoren = System.IO.Path.GetFullPath(System.IO.Path.Combine(api.KorenDat, "..", "..", ".willage-dev", api.Pin.Commit, "tests/Willage.World.Vpmg.Tests/Fixtures/recipes"));
        var v1 = new[] { "grass", "topsoil", "gravel-sand", "cave-limestone", "granite" }
            .Select(f => J.Api.Zdroj.Spust(RecepturyVpmg.ZJson(System.IO.File.ReadAllText(System.IO.Path.Combine(devKoren, $"recipe-{f}-v1.json"))), 0xC0FFEE00u)).ToList();
        Je(v1.All(t => t.Ok) && v1.Select((t, i) => t.Checksum).SequenceEqual(new uint[] { 756991887u, 2725408357u, 3628591702u, 2752359023u, 917430836u }), "srovnání: receptury v1 z Dev = goldeny v1");
        await Arch("10-srovnani-v1-v2.png", "T-2d – srovnání: v1 procedurální (Dev 42e7475 = 36ac11f, bez dlaždice) vs v2 base_texture nad dlaždicí Gemini; seed 0xC0FFEE00, 2×2 dlaždice z 64 px",
            new[] { "materiál", "v1 procedurální", "v2 base_texture", "baseTile (klient, 128 px)" },
            i => new Control[] { Pop($"{_arch[i].Id} {_arch[i].Key}\n{_arch[i].Nazev}"), Bunka(Img(v1[i]), 175), Bunka(Img(_arch[i].Golden), 175), Bunka(Image.LoadFromFile(_arch[i].Dlazdice), 175) }, 175);
        O.Visible = true;

        // bez nástroje → zástupné
        O.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var O2 = GD.Load<PackedScene>("res://nastroje/EditorMaterialu.tscn").Instantiate<EditorMaterialuOkno>();
        O2.GetNode<JadroMaterialu>("Jadro").BezVpmg = true;
        AddChild(O2);
        O = O2;
        await Cekej(() => O2.Jadro.Info != null && O2.Jadro.Posledni.ContainsKey("hlavni") && O2.Jadro.Cekajicich == 0);
        var tz = O2.Jadro.Posledni["hlavni"];
        Je(tz.Zastupna && O2.Lista.Vpmg.Text.Contains("zástupné") && O2.Seznam.Seznam.ItemCount == 5 && O2.InfoNahledu.Text.Contains("zástupné"), "bez nástroje: okno běží, náhled zástupný (šrafy), lišta to říká");
        await Snimek("09-bez-vpmg-zastupne.png");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb == 0 ? 0 : 1);
    }
}
