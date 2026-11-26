using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Vizual;

namespace WillagePrototyp.Jadro.Adaptery;

/// <summary>G-4: MapaDto → Image / ImageTexture. Barvy počítá BarvyVrstev (bez Godotu); tady se jen zabalí bajty.</summary>
public static class TexturaMapy
{
    public static Image Obrazek(MapaDto m) => Image.CreateFromData(m.Nx, m.Ny, false, Image.Format.Rgba8, BarvyVrstev.Rgba(m));

    /// <summary>Volat na hlavním vlákně (vytváří zdroj v RenderingServeru).</summary>
    public static ImageTexture Textura(MapaDto m) => ImageTexture.CreateFromImage(Obrazek(m));

    /// <summary>G-6: textura z hotových RGBA8 bajtů (BarvyNahledu na vlákně fronty); hlavní vlákno.</summary>
    public static ImageTexture ZRgba(int sirka, int vyska, byte[] rgba) => ImageTexture.CreateFromImage(Image.CreateFromData(sirka, vyska, false, Image.Format.Rgba8, rgba));
}
