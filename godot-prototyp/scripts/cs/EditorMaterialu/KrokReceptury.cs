using System;
using Godot;
using Willage.Materialy.Api.Editor;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>T-2: jeden krok receptury VPMG – zapnuto, operace, pořadí, odebrání, editory parametrů generované ze schématu.</summary>
[GlobalClass]
public partial class KrokReceptury : PanelContainer
{
    public event Action<int, bool>? Prepnuto;
    public event Action<int, int>? Posun;
    public event Action<int>? Odebrat;
    public event Action<int, string, string>? Parametr;
    public KrokPopis? Popis { get; private set; }
    public CheckBox Zapnuto { get; private set; } = null!;

    public static KrokReceptury Z(KrokPopis p, int pocet)
    {
        var k = new KrokReceptury { Name = "Krok_" + p.Id };
        k.Postav(p, pocet);
        return k;
    }

    void Postav(KrokPopis p, int pocet)
    {
        Popis = p;
        var v = new VBoxContainer();
        AddChild(v);
        var h = new HBoxContainer();
        v.AddChild(h);
        Zapnuto = new CheckBox { Text = $"{p.Id} · {p.Nazev} ({p.Type})", ButtonPressed = p.Enabled, SizeFlagsHorizontal = SizeFlags.ExpandFill, TooltipText = "zapnuto (enabled) – vypnutý krok runner Dev přeskočí" };
        Zapnuto.Toggled += z => Prepnuto?.Invoke(p.Index, z);
        h.AddChild(Zapnuto);
        h.AddChild(new Label { Text = p.Skupina, Modulate = new Color(0.7f, 0.8f, 1f) });
        var nahoru = new Button { Text = "↑", Disabled = p.Index == 0, TooltipText = "posunout výš" };
        var dolu = new Button { Text = "↓", Disabled = p.Index == pocet - 1, TooltipText = "posunout níž" };
        var pryc = new Button { Text = "✕", TooltipText = "odebrat krok" };
        nahoru.Pressed += () => Posun?.Invoke(p.Index, -1);
        dolu.Pressed += () => Posun?.Invoke(p.Index, 1);
        pryc.Pressed += () => Odebrat?.Invoke(p.Index);
        h.AddChild(nahoru); h.AddChild(dolu); h.AddChild(pryc);
        v.AddChild(new Label { Text = p.Popis + (p.CtiProfil.Count > 0 ? $"  [čte profil: {string.Join(", ", p.CtiProfil)}]" : ""), AutowrapMode = TextServer.AutowrapMode.WordSmart, Modulate = new Color(0.75f, 0.75f, 0.8f), CustomMinimumSize = new Vector2(440, 0) });
        foreach (var e in p.Editory)
        {
            var ed = EditorParametruVpmg.Z(e);
            ed.Zmeneno += (n, hod) => Parametr?.Invoke(p.Index, n, hod);
            v.AddChild(ed);
        }
        if (p.Editory.Count == 0) v.AddChild(new Label { Text = "bez parametrů (operace v0 čte jen profil)", Modulate = new Color(0.6f, 0.6f, 0.65f) });
    }
}
