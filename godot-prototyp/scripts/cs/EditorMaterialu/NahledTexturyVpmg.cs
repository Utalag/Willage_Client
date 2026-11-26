using Godot;
using Willage.Materialy.Api.Dto;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-1: 2D náhled textury VPMG (RGBA8 z nástroje Dev → ImageTexture, bez filtrování). <see cref="Dlazdice"/> &gt; 1 = opakování
/// (kontrola švu dlaždice). Zástupná textura (nástroj chybí) = šedé šrafy. Uzel viditelný v editoru, znovu použitý v okně T-2.
/// </summary>
[GlobalClass]
public partial class NahledTexturyVpmg : TextureRect
{
    /// <summary>Počet opakování dlaždice v každé ose (1 = jedna dlaždice).</summary>
    [Export(PropertyHint.Range, "1,4,1")] public int Dlazdice { get; set; } = 1;

    public TexturaVpmgDto? Posledni { get; private set; }
    public int Prijatych { get; private set; }

    public override void _Ready()
    {
        TextureFilter = TextureFilterEnum.Nearest;
        ExpandMode = ExpandModeEnum.IgnoreSize;
        StretchMode = StretchModeEnum.KeepAspectCentered;
    }

    public void Zobraz(TexturaVpmgDto t)
    {
        Posledni = t;
        Prijatych++;
        var img = Obraz(t);
        if (Dlazdice > 1)
        {
            var vel = Image.CreateEmpty(img.GetWidth() * Dlazdice, img.GetHeight() * Dlazdice, false, Image.Format.Rgba8);
            for (int y = 0; y < Dlazdice; y++)
                for (int x = 0; x < Dlazdice; x++)
                    vel.BlitRect(img, new Rect2I(0, 0, img.GetWidth(), img.GetHeight()), new Vector2I(x * img.GetWidth(), y * img.GetHeight()));
            img = vel;
        }
        Texture = ImageTexture.CreateFromImage(img);
        TooltipText = t.Zastupna ? t.Chyba ?? "zástupné" : t.Ok ? $"{t.Sirka}×{t.Vyska} {t.Vrstva}, checksum {t.Checksum}" : "chyba VPMG: " + t.Chyba;
    }

    /// <summary>RGBA8 z nástroje → Image (bajty beze změny). Zástupná / chybná textura = šedé šrafy (jasně odlišené).</summary>
    public static Image Obraz(TexturaVpmgDto t)
    {
        int w = Mathf.Max(1, t.Sirka), h = Mathf.Max(1, t.Vyska);
        if (t.Ok && t.Rgba.Length == w * h * 4) return Image.CreateFromData(w, h, false, Image.Format.Rgba8, t.Rgba);
        var img = Image.CreateEmpty(w, h, false, Image.Format.Rgba8);
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                img.SetPixel(x, y, ((x + y) / 4) % 2 == 0 ? new Color(0.35f, 0.35f, 0.38f) : (t.Zastupna ? new Color(0.55f, 0.55f, 0.6f) : new Color(0.75f, 0.2f, 0.2f)));
        return img;
    }
}
