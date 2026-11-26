using Godot;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>G-6: překryv náhledu – nakreslí úsečku řezu (body v pixelech textury, převod na plochu dělá NahledModulu).</summary>
[GlobalClass]
public partial class UseckaRezu : Control
{
    public Vector2? Od { get; set; }
    public Vector2? Do { get; set; }

    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;

    public override void _Draw()
    {
        if (Od is Vector2 a) DrawCircle(a, 4, Colors.Red);
        if (Od is Vector2 p && Do is Vector2 q) { DrawLine(p, q, Colors.Black, 4); DrawLine(p, q, Colors.Red, 2); DrawCircle(q, 4, Colors.Red); }
    }
}
