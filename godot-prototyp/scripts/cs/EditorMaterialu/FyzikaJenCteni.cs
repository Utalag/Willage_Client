using Godot;
using Willage.Materialy.Api.Dto;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>T-2: sekce geology katalogu – jen ke čtení (N5: editor mění jen vzhled; fyzika patří světu a backendu).</summary>
[GlobalClass]
public partial class FyzikaJenCteni : GridContainer
{
    public int Radku { get; private set; }

    public override void _Ready() => Columns = 2;

    public void Zobraz(MaterialVzhleduDto m)
    {
        foreach (var c in GetChildren()) { RemoveChild(c); c.QueueFree(); }
        Pridej("id (u8 buňky)", m.Id.ToString());
        Pridej("key", m.Key);
        Pridej("idStatus", m.IdStatus);
        foreach (var f in m.Fyzika) Pridej(f.Nazev, f.Hodnota);
        Radku = 3 + m.Fyzika.Count;
    }

    void Pridej(string n, string h)
    {
        AddChild(new Label { Text = n, Modulate = new Color(0.75f, 0.75f, 0.8f), CustomMinimumSize = new Vector2(190, 0) });
        AddChild(new Label { Text = h, TooltipText = "jen čtení – fyzika se v editoru materiálů nemění" });
    }
}
