using System;
using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-6: plocha řezu – M3 obraz materiálů (Nx × 512 buněk 0,25 m) s čárou povrchu, M1/M2 profil povrchu (M2 bíle, M1 oranžově, hladina moře modře).
/// Svisle vždy 0–128 m (sloupec). Jen kreslí; data dává PohledRezu.
/// </summary>
[GlobalClass]
public partial class ProfilRezu : Control
{
    public RezModuluDto? Rez { get; set; }
    public Texture2D? Obraz { get; set; }
    const float SloupecM = 128f;

    public override void _Draw()
    {
        var s = Size;
        DrawRect(new Rect2(Vector2.Zero, s), new Color(0.12f, 0.12f, 0.15f));
        if (Rez is not RezModuluDto r) return;
        if (Obraz is not null) DrawTextureRect(Obraz, new Rect2(Vector2.Zero, s), false);
        float Y(double z) => (float)(s.Y * (1 - z / SloupecM));
        float X(int i) => (i + 0.5f) * s.X / r.Nx;
        if (!double.IsNaN(r.HladinaMoreM)) DrawLine(new Vector2(0, Y(r.HladinaMoreM)), new Vector2(s.X, Y(r.HladinaMoreM)), new Color(0.3f, 0.5f, 1f), 1.5f);
        if (r.PovrchM1 is double[] p1) DrawPolyline(Enumerable.Range(0, r.Nx).Select(i => new Vector2(X(i), Y(p1[i]))).ToArray(), new Color(1f, 0.6f, 0.2f), 1.5f);
        DrawPolyline(Enumerable.Range(0, r.Nx).Select(i => new Vector2(X(i), Y(r.PovrchM[i]))).ToArray(), Obraz is null ? Colors.White : new Color(1, 1, 1, 0.6f), Obraz is null ? 2f : 1f);
        for (int z = 0; z <= 128; z += 32) DrawString(ThemeDB.FallbackFont, new Vector2(2, Math.Max(12, Y(z) - 2)), $"{z} m", HorizontalAlignment.Left, -1, 11, new Color(1, 1, 1, 0.7f));
    }

    /// <summary>Index vzorku a výška (m) pod bodem plochy.</summary>
    public (int ix, double z) Pod(Vector2 p)
    {
        if (Rez is not RezModuluDto r) return (-1, 0);
        int ix = Math.Clamp((int)(p.X / Size.X * r.Nx), 0, r.Nx - 1);
        return (ix, SloupecM * (1 - p.Y / Size.Y));
    }
}
