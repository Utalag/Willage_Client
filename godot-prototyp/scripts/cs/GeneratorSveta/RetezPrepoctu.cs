using System.Collections.Generic;
using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>G-5: řetěz přepočtu M0 → … → M9: stav a čas každého modulu, průběžně ze signálu ModulHotov (po modulech na pozadí).</summary>
[GlobalClass]
public partial class RetezPrepoctu : HFlowContainer
{
    readonly Dictionary<string, Label> _clanky = new();
    readonly Dictionary<string, string> _stav = new();
    public IReadOnlyDictionary<string, string> Stavy => _stav;
    public double PosledniCelkemMs { get; private set; }
    double _beh;

    public override void _Ready()
    {
        var j = WillageJadro.Instance; if (j is null) return;
        j.ModulySeznam += _ => { foreach (var m in j.PosledniModuly) Nastav(m.Id, m.Nazev, m.Stav.ToString(), m.Ms); };
        j.ModulHotov += (id, n, st, ms) => { _beh += ms; Nastav(id, n, st, ms); };
        j.PlanetaHotova += _ => { PosledniCelkemMs = j.PosledniVysledek?.Ms ?? _beh; _beh = 0; };
    }

    void Nastav(string id, string nazev, string stav, double ms)
    {
        if (!_clanky.TryGetValue(id, out var l))
        {
            if (_clanky.Count > 0) AddChild(new Label { Text = "→" });
            l = new Label { Name = "R_" + id, MouseFilter = MouseFilterEnum.Pass }; AddChild(l); _clanky[id] = l;
        }
        _stav[id] = stav;
        l.Text = $"{id} {StavyModulu.Text(stav)}{(ms > 0 ? $" {ms:F0} ms" : "")}";
        l.TooltipText = nazev; l.Modulate = StavyModulu.Barva(stav);
    }
}
