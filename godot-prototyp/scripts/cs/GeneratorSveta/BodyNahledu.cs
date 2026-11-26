using System.Collections.Generic;
using Godot;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-7: překryv náhledu – body (vodníci M4, oázy a vodníci M5, prameny M6) v souřadnicích plochy; převod metry → plocha dělá NahledModulu.
/// Barva podle druhu, velikost podle výkonu (l/s). Jen kreslí.
/// </summary>
[GlobalClass]
public partial class BodyNahledu : Control
{
    public readonly List<(Vector2 p, string druh, double q)> Body = new();
    [Export] public float Polomer { get; set; } = 3f;

    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;

    public static Color Barva(string druh) => druh switch
    {
        "vodník" or "Vodnik" => new Color(0.2f, 0.6f, 1f),
        "oáza" => new Color(0.2f, 1f, 0.4f),
        "Kras" => new Color(1f, 0.85f, 0.2f),
        "Kontakt" => new Color(1f, 0.5f, 0.2f),
        "Snih" => Colors.White,
        _ => new Color(0.3f, 1f, 1f),   // Vyver
    };

    public override void _Draw()
    {
        foreach (var (p, d, q) in Body)
        {
            float r = Polomer + (float)Mathf.Clamp(Mathf.Log(1 + q), 0, 3);
            DrawCircle(p, r + 1, Colors.Black); DrawCircle(p, r, Barva(d));
        }
    }
}
