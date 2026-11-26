using System.Collections.Generic;
using System.Linq;
using Godot;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Sluzby;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: konfigurátor receptury VPMG generovaný ze schématu operací – seed, rozlišení, kroky (<see cref="KrokReceptury"/>), přidání kroku
/// (spustitelné z registru Dev; zástupné operace z inspirace jsou v nabídce zamčené s popisem), výchozí receptura, výsledek validace.
/// </summary>
[GlobalClass]
public partial class KonfiguratorReceptury : VBoxContainer
{
    public SpinBox Seed { get; private set; } = null!;
    public OptionButton Rozliseni { get; private set; } = null!;
    public VBoxContainer Kroky { get; private set; } = null!;
    public MenuButton Pridat { get; private set; } = null!;
    public Label Validace { get; private set; } = null!;
    public readonly List<KrokReceptury> KrokyUzly = new();
    public int Postaveni { get; private set; }
    StavEditoru _st = null!;
    SchemaOperaciVpmg _s = null!;
    IReadOnlyList<NabidkaOperacePopis> _nabidka = new List<NabidkaOperacePopis>();
    bool _tichy;

    public override void _Ready()
    {
        Seed = GetNode<SpinBox>("Radek/Seed"); Rozliseni = GetNode<OptionButton>("Radek/Rozliseni");
        Kroky = GetNode<VBoxContainer>("Kroky"); Pridat = GetNode<MenuButton>("Spodek/Pridat"); Validace = GetNode<Label>("Validace");
        Seed.MaxValue = uint.MaxValue;
        Seed.ValueChanged += v => { if (!_tichy) _st.NastavSeed((uint)v); };
        foreach (var r in StavEditoru.Rozliseni) Rozliseni.AddItem($"{r} px");
        Rozliseni.ItemSelected += i => _st.NastavRozliseni(StavEditoru.Rozliseni[(int)i]);
        GetNode<Button>("Radek/Vychozi").Pressed += () => _st.VychoziReceptura();
        Pridat.GetPopup().IdPressed += id => { var n = _nabidka[(int)id]; if (!n.Zamcena) Hlas(_st.PridejKrok(n.Type)); };
    }

    public void Pripoj(StavEditoru st, SchemaOperaciVpmg s)
    {
        _st = st; _s = s;
        _nabidka = PopisKonfiguratoruReceptury.Nabidka(s);
        var pop = Pridat.GetPopup();
        pop.Clear();
        for (int i = 0; i < _nabidka.Count; i++)
        {
            pop.AddItem(_nabidka[i].Nazev, i);
            pop.SetItemDisabled(i, _nabidka[i].Zamcena);
            pop.SetItemTooltip(i, _nabidka[i].Popis);
        }
    }

    void Hlas(string? chyba) { if (chyba != null) { Validace.Text = chyba; Validace.Modulate = new Color(1, 0.6f, 0.6f); } }

    public void Postav()
    {
        _tichy = true;
        Seed.Value = _st.Seed;
        Rozliseni.Select(System.Array.IndexOf(StavEditoru.Rozliseni, _st.Receptura.Resolution));
        _tichy = false;
        foreach (var c in Kroky.GetChildren()) { Kroky.RemoveChild(c); c.QueueFree(); }
        KrokyUzly.Clear();
        var kp = PopisKonfiguratoruReceptury.Kroky(_st.Receptura, _s);
        foreach (var p in kp)
        {
            var k = KrokReceptury.Z(p, kp.Count);
            k.Prepnuto += (i, z) => Hlas(_st.PrepniKrok(i, z));
            k.Posun += (i, o) => Hlas(_st.PosunKrok(i, o));
            k.Odebrat += i => Hlas(_st.OdeberKrok(i));
            k.Parametr += (i, n, h) => Hlas(_st.NastavParametrKroku(i, n, h));
            Kroky.AddChild(k);
            KrokyUzly.Add(k);
        }
        Postaveni++;
        ObnovValidaci();
    }

    public void ObnovValidaci()
    {
        var v = _st.Validace();
        Validace.Text = v.Count == 0 ? $"receptura platná · {_st.Receptura.Kroky.Count(k => k.Enabled)}/{_st.Receptura.Kroky.Count} kroků zapnuto · schéma Dev schemaVersion {_st.Receptura.SchemaVersion}" : "validace: " + string.Join("; ", v);
        Validace.Modulate = v.Count == 0 ? new Color(0.7f, 1, 0.7f) : new Color(1, 0.6f, 0.6f);
    }

    public void NastavSeedUzivatel(uint s) => Seed.Value = s;
}
