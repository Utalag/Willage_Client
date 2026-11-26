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
/// vzorek 5 materiálů (Jan 21:44; ostatní zástupné), každý náhled = nástroj, seed 0xC0FFEE00 v okně, variace seedu, návrh profilu jen pro náhled, konfigurátor kroků (vypnout, přidat, zástupné zamčené),
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
        Je(O.Profil.PodleNazvu.Count == 5 && O.Konfigurator.KrokyUzly.Count == 2 && O.Fyzika.Radku >= 11, $"uzly: profil 5 editorů, receptura 2 kroky, fyzika {O.Fyzika.Radku} řádků");

        await Hotovo(() => { });
        int c = 1;
        foreach (var m in vz)
        {
            if (st.Material != m.Id) await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, m.Id));
            var tm = J.Posledni["hlavni"];
            Je(st.Material == m.Id && tm.Ok && tm.Checksum == api.Zdroj.Spust(RecepturyVpmg.Vychozi(m.Id), 49).Checksum, $"vzorek {m.Id} {m.Key}: náhled seed 49 = nástroj ({tm.Checksum})");
            UlozTexturu(tm, $"textura-{m.Id}-{m.Key}.png");
            await Snimek($"{c++:00}-vzorek-{m.Id}-{m.Key}.png");
        }
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 52));
        Je(st.Material == 6 && O.Titulek.Text.StartsWith("zástupné") && st.VyberMaterial(52) is { } ch52 && ch52.Contains("mimo vzorek"), "materiál 52 mimo vzorek: odmítnut, titulek „zástupné…“, zůstává 6");
        await Snimek("06-mimo-vzorek-52-zastupne.png");
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 1));

        uint REF = api.Zdroj.Spust(RecepturyVpmg.Vychozi(1), 0xC0FFEE00u).Checksum;
        await Hotovo(() => O.Konfigurator.NastavSeedUzivatel(0xC0FFEE00u));
        var tg = J.Posledni["hlavni"];
        var tex = (ImageTexture)O.Nahled.Texture;
        Je(st.Material == 1 && st.Seed == 0xC0FFEE00u && tg.Checksum == REF, $"okno: tráva 1, seed 0xC0FFEE00, 64 px → {tg.Checksum} = nástroj");
        Je(tex.GetWidth() == 128 && tex.GetImage().GetRegion(new Rect2I(0, 0, 64, 64)).GetData().SequenceEqual(tg.Rgba) && tex.GetImage().GetRegion(new Rect2I(64, 64, 64, 64)).GetData().SequenceEqual(tg.Rgba),
            "náhled: dlaždice 2×2, každá dlaždice = bajty VPMG");
        var var4 = Enumerable.Range(0, 4).Select(i => J.Posledni["var" + i].Checksum).ToList();
        Je(var4.Distinct().Count() == 4 && !var4.Contains(tg.Checksum), $"variace seedu: 4 různé checksumy ({string.Join(",", var4)})");
        Je(O.Profil.PodleNazvu["layerDensityPermille"].GetChild<Label>(0).TooltipText.Contains("nečte") && O.Profil.PodleNazvu["grainScalePermille"].GetChild<Label>(0).TooltipText.Contains("Čte ho"),
            "profil: layerDensity označen „v0 nečte žádná operace“, grain „čte ho zapnutý krok“");
        await Snimek("07-trava-seed-c0ffee00.png");

        // odezva
        var sw = new Stopwatch(); double suma = 0; int n = 8;
        for (int i = 0; i < n; i++) { sw.Restart(); await Hotovo(() => O.Konfigurator.NastavSeedUzivatel((uint)(1000 + i))); suma += sw.Elapsed.TotalMilliseconds; }
        GD.Print($"  odezva změna seedu → hlavní + 4 variace hotové: průměr {suma / n:F1} ms (včetně čekání na snímky)");
        Je(suma / n < 500, $"odezva < 500 ms ({suma / n:F1} ms)");
        await Hotovo(() => O.Konfigurator.NastavSeedUzivatel(0xC0FFEE00u));

        // návrh profilu jen pro náhled
        await Hotovo(() => O.Profil.PodleNazvu["grainScalePermille"].ZadejJakoUzivatel("0"));
        var tn = J.Posledni["hlavni"];
        Je(st.Navrh.GrainScalePermille == 0 && Jednobarevna(tn.Rgba) && O.Profil.StavNavrhu.Text.Contains("NÁVRH"), "návrh grain 0 → jednobarevný náhled, lišta profilu „NÁVRH jen pro náhled“");
        uint jednobarevna = tn.Checksum;
        await Hotovo(() => { O.Profil.PodleNazvu["baseColor"].ZadejJakoUzivatel("#4a7a3a"); O.Profil.PodleNazvu["grainScalePermille"].ZadejJakoUzivatel("320"); });
        var tb = J.Posledni["hlavni"];
        Je(st.Navrh.BaseColor == "#4a7a3a" && st.Navrh.GrainScalePermille == 320 && tb.Ok && tb.Checksum != REF && O.Titulek.Text.Contains("NÁVRH"), $"návrh baseColor #4a7a3a + grain 320 → {tb.Checksum}");
        await Snimek("08-navrh-profilu.png");
        Je(PinDev.Nacti(api.KorenDat).ZrcadloSha == shaPred, "katalog (zrcadlo) na disku beze změny");
        await Hotovo(() => O.Profil.ZrusitNavrh.EmitSignal(BaseButton.SignalName.Pressed));
        Je(st.Navrh.Prazdny && J.Posledni["hlavni"].Checksum == REF && O.Profil.PodleNazvu["grainScalePermille"].Popis!.Hodnota == "500", "Zpět na katalog → znovu referenční bajty, editory = katalog");

        // konfigurátor kroků
        await Hotovo(() => O.Konfigurator.KrokyUzly[1].Zapnuto.ButtonPressed = false);
        Je(!st.Receptura.Kroky[1].Enabled && J.Posledni["hlavni"].Checksum == jednobarevna, "vypnutý hash_grain = stejné bajty jako návrh grain 0");
        Je(O.Profil.PodleNazvu["grainScalePermille"].GetChild<Label>(0).TooltipText.Contains("nečte"), "po vypnutí hash_grain profil grain označen „nečte“");
        await Hotovo(() => O.Konfigurator.KrokyUzly[1].Zapnuto.ButtonPressed = true);
        var pop = O.Konfigurator.Pridat.GetPopup();
        int zamcenych = Enumerable.Range(0, pop.ItemCount).Count(i => pop.IsItemDisabled(i));
        Je(pop.ItemCount == 9 && zamcenych == 7, $"nabídka přidat krok: {pop.ItemCount} položek, {zamcenych} zástupných zamčených");
        await Hotovo(() => pop.EmitSignal(PopupMenu.SignalName.IdPressed, 1));
        await Cekej(() => O.Konfigurator.KrokyUzly.Count == 3);
        Je(st.Receptura.Kroky.Count == 3 && st.Receptura.Kroky[2].Type == "hash_grain" && O.Konfigurator.KrokyUzly.Count == 3 && J.Posledni["hlavni"].Ok, "přidán krok hash_grain (s3) → 3 uzly KrokReceptury, náhled OK");
        await Hotovo(() => pop.EmitSignal(PopupMenu.SignalName.IdPressed, 3));
        Je(st.Receptura.Kroky.Count == 3, "zástupná operace z nabídky se nepřidá");
        await Snimek("09-receptura-tri-kroky.png");

        // jiný materiál, dlaždice 3×3
        await Hotovo(() => O.Seznam.EmitSignal(SeznamMaterialu.SignalName.MaterialVybran, 3));
        await Cekej(() => O.Konfigurator.KrokyUzly.Count == 3 && st.Material == 3);
        Je(st.Material == 3 && st.Receptura.MaterialId == 3 && st.Receptura.Kroky.Count == 3 && O.Fyzika.GetChild<Label>(1).Text == "3", "výběr materiálu 3: receptura přenesena, fyzika materiálu 3");
        O.Dlazdice.Select(2); O.Dlazdice.EmitSignal(OptionButton.SignalName.ItemSelected, 2);
        Je(((ImageTexture)O.Nahled.Texture).GetWidth() == 192, "dlaždice 3×3 → 192 px");
        await Snimek("10-pisek-dlazdice-3x3.png");

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
        await Snimek("11-bez-vpmg-zastupne.png");

        GD.Print($"OK {_ok}, chyb {_chyb}");
        GetTree().Quit(_chyb == 0 ? 0 : 1);
    }
}
