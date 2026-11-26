using System.Collections.Generic;
using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Konfigurator;
using WillagePrototyp.Jadro;
using WillagePrototyp.Jadro.Uzly;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-5: konfigurátor vybraného modulu = jedna funkční vrstva (jako GeoLab). Editory se generují ze schématu přes
/// Konfigurator.Sestav (skupiny → EditorParametru). Akce: Přepočítat modul + závislé, Výchozí hodnoty modulu,
/// Izolovat vrstvu (zástupné → G-6/G-7), Uložit sadu (zástupné). Zástupné moduly (M6d, M8, M9) ukážou jen ZastupnyPanel.
/// Dětské uzly (Nadpis, Akce/*, Stav, Svitek/Parametry, Zastupny) jsou ve scéně GeneratorSveta.tscn.
/// </summary>
[GlobalClass]
public partial class KonfiguratorModulu : VBoxContainer
{
    [Signal] public delegate void PostavenEventHandler(string modul, int editoru);
    /// <summary>G-6: izolace vrstvy modulu – M1/M2 0 vyp / 1 zap (izolační vrstva náhledu), M3 režim řezu 0 vše / 1 jen vrstvy / 2 jen útvary.</summary>
    [Signal] public delegate void IzolaceZmenenaEventHandler(string modul, int stav);

    public int StavIzolace { get; private set; }

    public string Modul { get; private set; } = "";
    public PopisKonfiguratoru? Popis { get; private set; }
    public int Postaveni { get; private set; }
    bool _potvrzena;
    readonly Dictionary<string, EditorParametru> _editory = new();

    Label _nadpis = null!, _stav = null!;
    VBoxContainer _parametry = null!;
    ZastupnyPanel _zastupny = null!;
    Button _prepocitat = null!, _vychozi = null!, _izolovat = null!, _sada = null!;

    public IEnumerable<EditorParametru> Editory => _editory.Values;
    public EditorParametru? Editor(string id) => _editory.TryGetValue(id, out var e) ? e : null;
    public string StavText => _stav.Text;

    public override void _Ready()
    {
        _nadpis = GetNode<Label>("Nadpis"); _stav = GetNode<Label>("Stav");
        _parametry = GetNode<VBoxContainer>("Svitek/Parametry"); _zastupny = GetNode<ZastupnyPanel>("Zastupny");
        _prepocitat = GetNode<Button>("Akce/Prepocitat"); _vychozi = GetNode<Button>("Akce/Vychozi");
        _izolovat = GetNode<Button>("Akce/Izolovat"); _sada = GetNode<Button>("Akce/UlozitSadu");
        _izolovat.Pressed += PrepniIzolaci;
        _sada.Disabled = true; _sada.TooltipText = "zástupný: pojmenované sady parametrů – zatím se ukládá celá planeta (WPLN)";
        _zastupny.Visible = false;
        var j = WillageJadro.Instance; if (j is null) { _stav.Text = "jádro chybí (autoload WillageJadro)"; return; }
        _prepocitat.Pressed += () => { j.Generuj(); _stav.Text = $"přepočet {Modul} a závislých: {string.Join(", ", Konfigurator.Zavisle(j.PosledniModuly, Modul))} (neplatné moduly, ostatní z paměti)"; };
        _vychozi.Pressed += VychoziModulu;
        j.ParametryModulu += (m, _) => { if (m == Modul) Postav(j.ParametryDto(m)); };
        j.ParametrZmenen += (id, prijato, duvod, neplatne) =>
        {
            if (id.EndsWith(":*")) { if (id == Modul + ":*") _stav.Text = $"{Modul}: výchozí hodnoty, neplatné: {(neplatne.Length == 0 ? "nic" : string.Join(", ", neplatne))}"; return; }
            if (id == "*") { if (Modul != "") j.Parametry(Modul); _stav.Text = "výchozí hodnoty všech modulů, neplatné: " + string.Join(", ", neplatne); return; }
            if (!_editory.TryGetValue(id, out var e)) return;
            e.Oznac(prijato, duvod);
            _stav.Text = prijato ? $"{id}: neplatné {(neplatne.Length == 0 ? "nic" : string.Join(", ", neplatne))}" : $"{id} odmítnuto: {duvod}";
        };
        j.PlanetaInfo += i => { bool p = (bool)i["Potvrzena"]; if (p != _potvrzena) { _potvrzena = p; if (Modul != "") Postav(j.ParametryDto(Modul)); } };
    }

    /// <summary>Zobrazí modul: požádá jádro o parametry (konfigurátor se postaví po signálu ParametryModulu).</summary>
    public void Zobraz(string modul)
    {
        var j = WillageJadro.Instance; if (j is null) return;
        Modul = modul;
        var m = j.PosledniModuly.FirstOrDefault(x => x.Id == modul);
        _nadpis.Text = m is null ? modul : $"{m.Id} · {m.Nazev}  (verze {m.Verze}, závisí na {(m.Zavislosti.Count == 0 ? "–" : string.Join(", ", m.Zavislosti))})";
        bool zast = m?.Zastupny ?? false;
        NastavTlacitkoIzolace(modul, 0);
        _zastupny.Visible = zast; GetNode<Control>("Svitek").Visible = !zast;
        _prepocitat.Disabled = zast; _vychozi.Disabled = zast;
        if (zast) { Vycisti(); _zastupny.Funkce = $"{m!.Id} {m.Nazev}"; _stav.Text = $"modul je zástupný – průchozí, bez parametrů ({m.Popis})"; Postaveni++; EmitSignal(SignalName.Postaven, modul, 0); return; }
        j.Parametry(modul);
    }

    /// <summary>G-6: izolace pro M1–M3 (jako GeoLab); M4–M6 zástupné (G-7).</summary>
    void NastavTlacitkoIzolace(string modul, int stav)
    {
        StavIzolace = stav;
        (string text, string tip) = modul switch
        {
            "M1" => (stav == 0 ? "Izolovat: jen reliéf" : "Izolace: jen reliéf ✓", "náhled jen reliéfu bez moře, masivu a sopek"),
            "M2" => (stav == 0 ? "Izolovat: rozdíl M2 − M1" : "Izolace: rozdíl M2 − M1 ✓", "náhled rozdílu výšky proti M1 (moře, sklon kontinentu, pánve)"),
            "M3" => (stav switch { 0 => "Izolovat řez: jen vrstvy", 1 => "Izolovat řez: jen útvary", _ => "Řez: vše" }, "řez M3: vše → jen vrstvy → jen útvary + nitro sopek"),
            _ => ("Izolovat vrstvu (zástupné)", "zástupný: izolace M4–M6 přijde s náhledy G-7"),
        };
        _izolovat.Text = text; _izolovat.TooltipText = tip;
        _izolovat.Disabled = modul is not ("M1" or "M2" or "M3");
    }

    /// <summary>Přepne izolaci (M1/M2 zap/vyp, M3 cyklus režimů řezu) a vyšle IzolaceZmenena.</summary>
    public void PrepniIzolaci()
    {
        if (_izolovat.Disabled) return;
        int dalsi = Modul == "M3" ? (StavIzolace + 1) % 3 : 1 - StavIzolace;
        NastavTlacitkoIzolace(Modul, dalsi);
        EmitSignal(SignalName.IzolaceZmenena, Modul, dalsi);
    }

    void Vycisti()
    {
        foreach (var c in _parametry.GetChildren()) { _parametry.RemoveChild(c); c.QueueFree(); }
        _editory.Clear();
    }

    void Postav(IReadOnlyList<ParametrDto> par)
    {
        var j = WillageJadro.Instance!;
        Vycisti();
        Popis = Konfigurator.Sestav(Modul, par, _potvrzena);
        foreach (var s in Popis.Skupiny)
        {
            var h = new Label { Text = s.Nazev, Name = "S_" + s.Nazev.Replace(' ', '_') };
            h.AddThemeFontSizeOverride("font_size", 17); h.AddThemeColorOverride("font_color", new Color(0.65f, 0.85f, 1f));
            _parametry.AddChild(h);
            foreach (var pe in s.Editory)
            {
                var e = new EditorParametru();
                _parametry.AddChild(e); e.Nastav(pe);
                e.Zmena += (id, json) => j.Nastav(id, json);
                e.Napoveda += (id, t) => _stav.Text = $"{id}: {t}";
                _editory[pe.Parametr.Id] = e;
            }
        }
        _vychozi.Disabled = _potvrzena;
        _stav.Text = $"{_editory.Count} parametrů ve {Popis.Skupiny.Count} skupinách · změna parametru zneplatní modul a závislé";
        if (_potvrzena) _stav.Text = "planeta je potvrzená – parametry zamčené";
        Postaveni++;
        EmitSignal(SignalName.Postaven, Modul, _editory.Count);
    }

    /// <summary>Vrátí parametry tohoto modulu na výchozí hodnoty (data/v1) a znovu načte konfigurátor.</summary>
    public void VychoziModulu()
    {
        var j = WillageJadro.Instance; if (j is null || Modul == "") return;
        j.VychoziModulu(Modul);   // konfigurátor se postaví po ParametryModulu
    }
}
