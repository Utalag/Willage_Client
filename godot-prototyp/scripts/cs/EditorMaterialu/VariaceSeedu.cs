using System.Collections.Generic;
using Godot;
using Willage.Materialy.Api.Dto;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>T-2: ukázky variací – stejný profil a receptura, jiný seed (4 dlaždice).</summary>
[GlobalClass]
public partial class VariaceSeedu : HBoxContainer
{
    [Export(PropertyHint.Range, "1,8,1")] public int Pocet { get; set; } = 4;
    public readonly List<NahledTexturyVpmg> Nahledy = new();
    readonly List<Label> _popisky = new();

    public override void _Ready()
    {
        for (int i = 0; i < Pocet; i++)
        {
            var v = new VBoxContainer();
            var n = new NahledTexturyVpmg { CustomMinimumSize = new Vector2(150, 150), Name = "Variace" + i };
            var l = new Label { HorizontalAlignment = HorizontalAlignment.Center, CustomMinimumSize = new Vector2(150, 0), ClipText = true };
            v.AddChild(n); v.AddChild(l); AddChild(v);
            Nahledy.Add(n); _popisky.Add(l);
        }
    }

    public void Zobraz(int i, uint seed, TexturaVpmgDto t)
    {
        if (i >= Nahledy.Count) return;
        Nahledy[i].Zobraz(t);
        _popisky[i].Text = t.Zastupna ? $"seed {seed}\nzástupné" : $"seed {seed}\n{t.Checksum}";
    }
}
