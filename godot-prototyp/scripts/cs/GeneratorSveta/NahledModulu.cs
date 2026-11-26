using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Sluzby;
using WillagePrototyp.Jadro;
using WillagePrototyp.Jadro.Uzly;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-6: náhled vybraného modulu. M1–M3 mají vlastní vrstvy (fasáda INahledyModulu: mapa na oblasti funkce světa 0…4096 m),
/// izolaci (M1 jen reliéf, M2 rozdíl M2−M1) a výběr úsečky řezu dvěma kliky (signál UseckaVybrana v metrech).
/// M4–M7 dál ukazují vrstvy hotové planety (NahledVrstvy, G-5) – vlastní náhledy M4–M6 jsou zástupné (G-7).
/// </summary>
[GlobalClass]
public partial class NahledModulu : VBoxContainer
{
    [Signal] public delegate void UseckaVybranaEventHandler(Vector2 odM, Vector2 doM);

    [Export(PropertyHint.Range, "16,1024,16")] public int Rozliseni { get; set; } = 256;
    /// <summary>Rozlišení pro pomalé vrstvy (materiál povrchu M3 ~1,7 s při 256²).</summary>
    [Export(PropertyHint.Range, "16,1024,16")] public int RozliseniPomale { get; set; } = 128;

    OptionButton _volba = null!;
    TextureRect _mapa = null!;
    UseckaRezu _usecka = null!;
    Label _info = null!;
    Control _poznamka = null!;
    public NahledVrstvy Nahled { get; private set; } = null!;
    public TextureRect MapaModulu => _mapa;
    public string Modul { get; private set; } = "";
    public bool Izolace { get; private set; }
    public VrstvaNahleduDto? VrstvaModulu { get; private set; }
    public int PrijatychNahledu { get; private set; }
    public Vector2 UseckaOdM { get; private set; }
    public Vector2 UseckaDoM { get; private set; }
    VrstvaNahleduDto[] _vrstvyM = System.Array.Empty<VrstvaNahleduDto>();
    VrstvaMapyDto[] _vrstvyP = { VrstvaMapyDto.Vyska };
    long _uloha = -1;
    Vector2? _prvniKlik;

    public bool VlastniNahled => _vrstvyM.Length > 0;

    public override void _Ready()
    {
        _volba = GetNode<OptionButton>("Volba"); Nahled = GetNode<NahledVrstvy>("Nahled");
        _mapa = GetNode<TextureRect>("Mapa"); _usecka = GetNode<UseckaRezu>("Mapa/Usecka"); _info = GetNode<Label>("Info"); _poznamka = GetNode<Control>("Poznamka");
        _mapa.ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize; _mapa.StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered;
        _mapa.TextureFilter = TextureFilterEnum.Nearest;
        _volba.ItemSelected += i => Ukaz((int)i);
        _mapa.GuiInput += Klik;
        _mapa.Resized += PrekresliUsecku;
        var j = WillageJadro.Instance; if (j is null) return;
        j.NahledModuluHotov += (id, m, v, t) =>
        {
            if (id != _uloha) return;
            _mapa.Texture = t; PrijatychNahledu++;
            var n = j.PosledniNahled!;
            _info.Text = n.Popis + "\n" + string.Join(", ", n.Cisla.Select(c => $"{c.Key} {c.Value:0.###}")) + $" · {n.Nx}×{n.Ny} po {n.KrokM:0.#} m · {n.Ms:F0} ms";
            PrekresliUsecku();
        };
        j.PlanetaHotova += _ => { if (VlastniNahled && Modul != "") Ukaz(_volba.Selected); };
    }

    public void NastavModul(string modul)
    {
        Modul = modul; Izolace = false; _prvniKlik = null;
        _vrstvyM = NahledyModuluApi.VrstvyModulu(modul).ToArray();
        _volba.Clear();
        if (VlastniNahled) foreach (var v in _vrstvyM) _volba.AddItem(v.ToString());
        else { _vrstvyP = Willage.Gen.Api.Konfigurator.Konfigurator.VrstvyModulu(modul).ToArray(); foreach (var v in _vrstvyP) _volba.AddItem("planeta: " + v); }
        _mapa.Visible = VlastniNahled; _info.Visible = VlastniNahled; Nahled.Visible = !VlastniNahled; _poznamka.Visible = !VlastniNahled;
        _volba.Select(0); Ukaz(0);
        if (VlastniNahled)
        {
            // výchozí úsečka: M1/M2 řádek startu přes celý svět, M3 řez nástroje „rez“ (x 2048 ± 48, y 1984)
            if (modul == "M3") NastavUsecku(new Vector2(2000, 1984), new Vector2(2096, 1984)); else NastavUsecku(new Vector2(0, 1984), new Vector2(4096, 1984));
        }
    }

    /// <summary>Izolace modulu (M1 reliéf, M2 rozdíl M2−M1): přepne na izolační vrstvu, nebo zpět na první.</summary>
    public void NastavIzolaci(bool zap)
    {
        var iz = NahledyModuluApi.IzolaceModulu(Modul); if (iz is null) return;
        Izolace = zap;
        int i = zap ? System.Array.IndexOf(_vrstvyM, iz.Value) : 0;
        _volba.Select(i); Ukaz(i);
    }

    public void VyberVrstvu(VrstvaNahleduDto v) { int i = System.Array.IndexOf(_vrstvyM, v); if (i >= 0) { _volba.Select(i); Ukaz(i); } }

    void Ukaz(int i)
    {
        var j = WillageJadro.Instance; if (j is null || i < 0) return;
        if (!VlastniNahled)
        {
            var v = _vrstvyP[System.Math.Min(i, _vrstvyP.Length - 1)];
            bool zmena = Nahled.Vrstva != v; Nahled.Vrstva = v;
            if ((zmena || Nahled.Texture is null) && j.PosledniVysledek is not null) Nahled.Obnov();
            return;
        }
        if (j.PosledniVysledek is null) { _info.Text = "planeta zatím nespočtená"; return; }
        VrstvaModulu = _vrstvyM[i];
        int roz = VrstvaModulu == VrstvaNahleduDto.MaterialPovrchu ? RozliseniPomale : Rozliseni;
        _uloha = j.NahledModulu(Modul, (int)VrstvaModulu, roz);
        _info.Text = $"počítám {Modul}.{VrstvaModulu} {roz}×{roz} …";
    }

    // ---- úsečka řezu: pixel textury ↔ metry ↔ plocha prvku ----
    (Vector2 off, float meritko)? Prevod()
    {
        if (_mapa.Texture is not Texture2D t) return null;
        var ts = t.GetSize(); var s = _mapa.Size; float k = System.Math.Min(s.X / ts.X, s.Y / ts.Y);
        return ((s - ts * k) / 2, k);
    }

    Vector2 NaMetry(Vector2 plocha)
    {
        var n = WillageJadro.Instance?.PosledniNahled; var p = Prevod();
        if (n is null || p is null) return Vector2.Zero;
        var px = (plocha - p.Value.off) / p.Value.meritko;
        return new Vector2((float)(n.X0M + px.X * n.KrokM), (float)(n.Y0M + px.Y * n.KrokM));
    }

    Vector2? NaPlochu(Vector2 m)
    {
        var n = WillageJadro.Instance?.PosledniNahled; var p = Prevod();
        if (n is null || p is null) return null;
        return p.Value.off + new Vector2((float)((m.X - n.X0M) / n.KrokM), (float)((m.Y - n.Y0M) / n.KrokM)) * p.Value.meritko;
    }

    void Klik(InputEvent e)
    {
        if (e is not InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left } mb || !VlastniNahled) return;
        var m = NaMetry(mb.Position);
        if (_prvniKlik is null) { _prvniKlik = m; _usecka.Od = NaPlochu(m); _usecka.Do = null; _usecka.QueueRedraw(); return; }
        var a = _prvniKlik.Value; _prvniKlik = null;
        NastavUsecku(a, m);
    }

    /// <summary>Nastaví úsečku řezu v metrech (jako dva kliky) a vyšle UseckaVybrana.</summary>
    public void NastavUsecku(Vector2 odM, Vector2 doM)
    {
        UseckaOdM = odM; UseckaDoM = doM; PrekresliUsecku();
        EmitSignal(SignalName.UseckaVybrana, odM, doM);
    }

    /// <summary>Simulace kliku v pixelech textury (testy): převod pixel → plocha → metry jako u myši.</summary>
    public void KlikniNaPixel(Vector2 pixel)
    {
        var p = Prevod(); if (p is null) return;
        var ev = new InputEventMouseButton { Pressed = true, ButtonIndex = MouseButton.Left, Position = p.Value.off + pixel * p.Value.meritko };
        Klik(ev);
    }

    void PrekresliUsecku()
    {
        if (_prvniKlik is null) { _usecka.Od = NaPlochu(UseckaOdM); _usecka.Do = NaPlochu(UseckaDoM); }
        _usecka.QueueRedraw();
    }
}
