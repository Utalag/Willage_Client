using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Konfigurator;
using WillagePrototyp.Jadro;
using WillagePrototyp.Jadro.Uzly;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-5: náhled vybraného modulu – volba vrstvy (Konfigurator.VrstvyModulu) a NahledVrstvy (G-4). Dočasně ukazuje vrstvy hotové planety;
/// vlastní náhledy a izolace modulů přinesou G-6 (M1–M3) a G-7 (M4–M6) – poznámka v uzlu je označená „zástupný“.
/// </summary>
[GlobalClass]
public partial class NahledModulu : VBoxContainer
{
    OptionButton _volba = null!;
    public NahledVrstvy Nahled { get; private set; } = null!;
    VrstvaMapyDto[] _vrstvy = { VrstvaMapyDto.Vyska };

    public override void _Ready()
    {
        _volba = GetNode<OptionButton>("Volba"); Nahled = GetNode<NahledVrstvy>("Nahled");
        _volba.ItemSelected += i => Ukaz(_vrstvy[(int)i]);
    }

    public void NastavModul(string modul)
    {
        _vrstvy = Konfigurator.VrstvyModulu(modul).ToArray();
        _volba.Clear();
        foreach (var v in _vrstvy) _volba.AddItem(v.ToString());
        _volba.Select(0);
        Ukaz(_vrstvy[0]);
    }

    void Ukaz(VrstvaMapyDto v)
    {
        bool zmena = Nahled.Vrstva != v; Nahled.Vrstva = v;
        if ((zmena || Nahled.Texture is null) && WillageJadro.Instance?.PosledniVysledek is not null) Nahled.Obnov();
    }
}
