using Godot;
using Willage.Gen.Api.Dto;

namespace WillagePrototyp.Jadro.Uzly;

/// <summary>
/// G-4: náhled jedné vrstvy planety (uzel do scény, viditelný v editoru). Po PlanetaHotova si od jádra vyžádá mapu
/// a zobrazí texturu. Žádná logika – jen požadavek a zobrazení.
/// </summary>
[GlobalClass]
public partial class NahledVrstvy : TextureRect
{
    [Export] public VrstvaMapyDto Vrstva { get; set; } = VrstvaMapyDto.Vyska;
    /// <summary>Zmenšení mapy planety (1 = plné rozlišení mapy eroze).</summary>
    [Export(PropertyHint.Range, "1,16,1")] public int Zmenseni { get; set; } = 4;
    [Export] public bool AutomatickyPoGeneraci { get; set; } = true;

    long _uloha = -1;
    public int PrijatychMap { get; private set; }

    public override void _Ready()
    {
        var j = WillageJadro.Instance; if (j is null) return;
        j.PlanetaHotova += _ => { if (AutomatickyPoGeneraci) Obnov(); };
        j.MapaHotova += (id, v, t) => { if (id == _uloha) { Texture = t; PrijatychMap++; } };
        ExpandMode = ExpandModeEnum.IgnoreSize; StretchMode = StretchModeEnum.KeepAspect;
    }

    public void Obnov() { var j = WillageJadro.Instance; if (j is not null) _uloha = j.Mapa((int)Vrstva, Zmenseni); }
}
