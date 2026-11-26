using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-5: kořen okna 1 „Generátor světa“ (nastroje/GeneratorSveta.tscn, samostatná hlavní scéna / proces). Jen propojuje uzly:
/// výběr v SeznamModulu → KonfiguratorModulu + NahledModulu; změna parametru / hotová planeta → obnovit seznam modulů a info.
/// Všechna práce běží v jádře (autoload WillageJadro, fronta na pozadí).
/// Spuštění: godot --path godot-prototyp res://nastroje/GeneratorSveta.tscn
/// </summary>
[GlobalClass]
public partial class GeneratorSvetaOkno : Control
{
    /// <summary>Po otevření okna hned spočítat planetu (s keší eroze ~2 s).</summary>
    [Export] public bool AutoGenerovat { get; set; } = true;
    [Export] public string PrvniModul { get; set; } = "M0";

    public SeznamModulu Seznam { get; private set; } = null!;
    public KonfiguratorModulu Konfigurator { get; private set; } = null!;
    public NahledModulu Nahled { get; private set; } = null!;
    public RetezPrepoctu Retez { get; private set; } = null!;
    public HorniLista Lista { get; private set; } = null!;
    public Diagnostika Diagnostika { get; private set; } = null!;
    public PohledRezu Rez { get; private set; } = null!;

    public override void _Ready()
    {
        Seznam = GetNode<SeznamModulu>("%SeznamModulu"); Konfigurator = GetNode<KonfiguratorModulu>("%KonfiguratorModulu");
        Nahled = GetNode<NahledModulu>("%NahledModulu"); Retez = GetNode<RetezPrepoctu>("%RetezPrepoctu");
        Lista = GetNode<HorniLista>("%HorniLista"); Diagnostika = GetNode<Diagnostika>("%Diagnostika");
        var j = WillageJadro.Instance; if (j is null) { GD.PushError("GeneratorSveta: chybí autoload WillageJadro"); return; }

        Rez = GetNode<PohledRezu>("%PohledRezu");
        Seznam.ModulVybran += id => { Konfigurator.Zobraz(id); Rez.NastavModul(id); Nahled.NastavModul(id); };
        // G-6: úsečka z náhledu → řez; izolace z konfigurátoru → náhled (M1, M2) nebo režim řezu (M3)
        Nahled.UseckaVybrana += (od, @do) => Rez.NastavUsecku(od, @do);
        Konfigurator.IzolaceZmenena += (m, st) => { if (m == "M3") Rez.NastavRezim(st); else Nahled.NastavIzolaci(st > 0); };
        j.ParametrZmenen += (_, prijato, _, _) => { if (prijato) { j.Moduly(); j.InfoPlanety(); } };
        j.PlanetaHotova += _ => { j.Moduly(); j.InfoPlanety(); };
        // načtení WPLN mění sadu parametrů: úlohy jdou do fronty za Nacti, takže přijdou už nové hodnoty
        Lista.NacitaniPlanety += () => { j.Moduly(); if (Konfigurator.Modul != "") Konfigurator.Zobraz(Konfigurator.Modul); };
        bool prvni = true;
        j.ModulySeznam += _ => { if (prvni) { prvni = false; Seznam.Vyber(PrvniModul); } };

        j.Moduly(); j.InfoPlanety();
        if (AutoGenerovat) j.Generuj();
    }
}
