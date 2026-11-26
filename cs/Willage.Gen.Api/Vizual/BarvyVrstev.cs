using Willage.Gen.Api.Dto;

namespace Willage.Gen.Api.Vizual;

/// <summary>
/// G-4: převod mapy vrstvy na RGBA8 (řádky po y, nx × ny × 4 bajty) – bez Godotu, aby adaptér v Godotu jen zabalil bajty do Image.
/// Škály jsou pevné a deterministické (stejná mapa → stejné bajty). Biom používá paletu podle KlasifikaceBiomu (11 tříd).
/// </summary>
public static class BarvyVrstev
{
    /// <summary>Barvy biomů v pořadí KlasifikaceBiomu.NazevCs (moře, led, tundra, tajga, mírný les, step, poušť, savana, mírný deštný, tropický deštný, oáza).</summary>
    public static readonly (byte r, byte g, byte b)[] PaletaBiomu =
    {
        (40, 80, 160), (235, 245, 250), (170, 180, 150), (60, 110, 80), (80, 150, 70), (190, 190, 110),
        (230, 205, 140), (200, 180, 90), (40, 130, 90), (20, 100, 40), (90, 200, 160),
    };

    /// <summary>Rozsah škály vrstvy (min, max) – pevný pro teplotu a srážky, z dat pro výšku a erozi.</summary>
    public static (float min, float max) Rozsah(MapaDto m) => m.Vrstva switch
    {
        VrstvaMapyDto.Teplota => (-20f, 35f),
        VrstvaMapyDto.Srazky => (0f, 3000f),
        VrstvaMapyDto.Biom => (0f, PaletaBiomu.Length - 1),
        _ => m.Hodnoty.Length == 0 ? (0f, 1f) : (m.Hodnoty.Min(), m.Hodnoty.Max()),
    };

    public static byte[] Rgba(MapaDto m)
    {
        var o = new byte[m.Hodnoty.Length * 4];
        var (lo, hi) = Rozsah(m); float d = hi > lo ? hi - lo : 1f;
        for (int i = 0; i < m.Hodnoty.Length; i++)
        {
            float t = Math.Clamp((m.Hodnoty[i] - lo) / d, 0f, 1f);
            (byte r, byte g, byte b) c = m.Vrstva switch
            {
                VrstvaMapyDto.Biom => PaletaBiomu[Math.Clamp((int)m.Hodnoty[i], 0, PaletaBiomu.Length - 1)],
                VrstvaMapyDto.Teplota => Mix((40, 60, 200), (240, 240, 120), (200, 40, 30), t),
                VrstvaMapyDto.Srazky => Mix((230, 210, 160), (90, 170, 120), (30, 70, 170), t),
                VrstvaMapyDto.Eroze => Mix((250, 250, 250), (220, 140, 60), (120, 30, 20), t),
                _ => Mix((30, 70, 30), (170, 150, 100), (250, 250, 250), t),
            };
            o[4 * i] = c.r; o[4 * i + 1] = c.g; o[4 * i + 2] = c.b; o[4 * i + 3] = 255;
        }
        return o;
    }

    static (byte, byte, byte) Mix((byte r, byte g, byte b) a, (byte r, byte g, byte b) s, (byte r, byte g, byte b) z, float t)
    {
        var (p, q, u) = t < 0.5f ? (a, s, t * 2) : (s, z, (t - 0.5f) * 2);
        return ((byte)Math.Round(p.r + (q.r - p.r) * u), (byte)Math.Round(p.g + (q.g - p.g) * u), (byte)Math.Round(p.b + (q.b - p.b) * u));
    }

    /// <summary>Zmenšení mapy (průměr bloků f × f) pro náhled; f = 1 vrátí kopii.</summary>
    public static MapaDto Zmensi(MapaDto m, int f)
    {
        if (f <= 1) return m with { Hodnoty = (float[])m.Hodnoty.Clone() };
        int nx = m.Nx / f, ny = m.Ny / f; var h = new float[nx * ny];
        for (int j = 0; j < ny; j++)
        for (int i = 0; i < nx; i++)
        {
            double s = 0;
            if (m.Vrstva == VrstvaMapyDto.Biom) { h[j * nx + i] = m.Hodnoty[(j * f + f / 2) * m.Nx + i * f + f / 2]; continue; }   // biom: prostřední vzorek, ne průměr
            for (int b = 0; b < f; b++) for (int a = 0; a < f; a++) s += m.Hodnoty[(j * f + b) * m.Nx + i * f + a];
            h[j * nx + i] = (float)(s / (f * f));
        }
        return new MapaDto(m.Vrstva, nx, ny, m.KrokM * f, h);
    }
}
