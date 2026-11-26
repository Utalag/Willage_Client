using System;
using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-6 / G-7: plocha řezu – M3/M6 obraz materiálů (Nx × 512 buněk 0,25 m) s čárou povrchu, M1/M2/M4/M5 profil povrchu (bíle; M1 nebo
/// povrch před erozí oranžově, hladina moře modře). M6: surová hladina 7c azurově, bez hladiny = červený pruh nahoře, prameny trojúhelníky.
/// M5: teplota (červeně) a srážky (zeleně) v dolním pruhu. Svisle vždy 0–128 m (sloupec). Jen kreslí; data dává PohledRezu.
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
        if (r.HladinaPodzemniM is double[] hl)
        {
            var useky = new System.Collections.Generic.List<Vector2>();
            void Zavri() { if (useky.Count > 1) DrawPolyline(useky.ToArray(), new Color(0.2f, 1f, 1f), 2f); useky.Clear(); }
            for (int i = 0; i < r.Nx; i++)
            {
                if (double.IsNaN(hl[i])) { Zavri(); DrawRect(new Rect2(X(i) - s.X / r.Nx / 2, 0, s.X / r.Nx + 0.5f, 4), new Color(0.9f, 0.1f, 0.1f)); continue; }
                useky.Add(new Vector2(X(i), Y(hl[i])));
            }
            Zavri();
        }
        if (r.Body is { } body)
        {
            double d = Math.Sqrt(Math.Pow(r.Do.XM - r.Od.XM, 2) + Math.Pow(r.Do.YM - r.Od.YM, 2));
            foreach (var b in body)
            {
                if (d <= 0 || double.IsNaN(b.S)) continue;
                var p = new Vector2((float)(b.S / d * s.X), Y(double.IsNaN(b.Z) ? 0 : b.Z));
                DrawColoredPolygon(new[] { p + new Vector2(0, -7), p + new Vector2(-5, 2), p + new Vector2(5, 2) }, BodyNahledu.Barva(b.Druh));
            }
        }
        if (r.Rady is { } rd && rd.TryGetValue("teplota_c", out var tc) && rd.TryGetValue("srazky_mm", out var sr))
        {
            float pas = s.Y * 0.25f;
            double tMin = tc.Min(), tMax = Math.Max(tMin + 1, tc.Max()), pMax = Math.Max(1, sr.Max());
            DrawPolyline(Enumerable.Range(0, r.Nx).Select(i => new Vector2(X(i), s.Y - (float)((tc[i] - tMin) / (tMax - tMin)) * pas)).ToArray(), new Color(1f, 0.35f, 0.3f), 1.5f);
            DrawPolyline(Enumerable.Range(0, r.Nx).Select(i => new Vector2(X(i), s.Y - (float)(sr[i] / pMax) * pas)).ToArray(), new Color(0.4f, 1f, 0.4f), 1.5f);
            DrawString(ThemeDB.FallbackFont, new Vector2(s.X - 210, s.Y - pas - 2), $"T {tMin:0.#}…{tMax:0.#} °C, P ≤ {pMax:0} mm", HorizontalAlignment.Left, -1, 11, new Color(1, 1, 1, 0.8f));
        }
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
