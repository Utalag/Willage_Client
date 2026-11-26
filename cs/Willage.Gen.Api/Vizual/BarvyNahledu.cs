using System.Globalization;
using Willage.Gen.Api.Dto;

namespace Willage.Gen.Api.Vizual;

/// <summary>
/// G-6: náhledy M1–M3 → RGBA8 bez Godotu (adaptér jen zabalí bajty do Image). Deterministické škály:
/// výška 0–128 m (sloupec), rozdíl a pánve ±rozsah z dat (modrá − / červená +), indexy paletou, materiály barvou z materialy_v1.csv.
/// Řez M3: obraz Nx × Nz, řádek 0 = nahoře (z nejvyšší), vzduch průhledný.
/// </summary>
public static class BarvyNahledu
{
    /// <summary>Barvy pěti typů reliéfu funkce světa (MapaBiomu: 0, 1, 2 pahorkatina, 3 hornatina, 4 sopečná) – index SvetFn.Sloupec.Biom.</summary>
    /// <summary>G-7: barvy biomů klimatu (BiomKlimatu 0–10: moře, led, tundra, tajga, mírný les, step, poušť, savana, mírný deštný, tropický deštný, oáza).</summary>
    public static readonly (byte r, byte g, byte b)[] PaletaBiomuKlimatu =
    {
        (20, 40, 90), (235, 245, 255), (170, 180, 150), (60, 110, 90), (70, 140, 70), (190, 190, 100), (230, 200, 130), (200, 170, 60), (40, 120, 110), (20, 100, 40), (40, 220, 120),
    };

    public static readonly (byte r, byte g, byte b)[] PaletaBiomuSveta = { (190, 200, 110), (70, 140, 70), (150, 130, 80), (120, 110, 110), (150, 60, 50) };

    public static (byte r, byte g, byte b, byte a) Barva(string hex)
    {
        if (hex.Length < 7 || hex[0] != '#') return (0, 0, 0, 0);
        byte P(int i) => byte.Parse(hex.AsSpan(i, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        return (P(1), P(3), P(5), hex.Length >= 9 ? P(7) : (byte)255);
    }

    /// <summary>Paleta materiálů id → RGBA (256 položek; neznámé id = barva z hashe id, ať jsou odlišitelné).</summary>
    public static (byte r, byte g, byte b, byte a)[] PaletaMaterialu(IReadOnlyList<MaterialDto> m)
    {
        var p = new (byte, byte, byte, byte)[256];
        for (int i = 0; i < 256; i++) { uint h = (uint)i * 2654435761u; p[i] = ((byte)(h >> 24), (byte)(h >> 16), (byte)(h >> 8), (byte)255); }
        foreach (var x in m) p[x.Id] = Barva(x.BarvaHex);
        p[0] = (0, 0, 0, 0);
        return p;
    }

    public static byte[] Rgba(NahledMapyDto m, IReadOnlyList<MaterialDto> materialy)
    {
        var o = new byte[m.Hodnoty.Length * 4];
        var pm = PaletaMaterialu(materialy);
        float amp = 1f;
        if (m.Vrstva is VrstvaNahleduDto.RozdilM2M1 or VrstvaNahleduDto.Panve or VrstvaNahleduDto.PosunEroze)
            amp = Math.Max(1e-3f, m.Hodnoty.Where(float.IsFinite).Select(Math.Abs).DefaultIfEmpty(1f).Max());
        float sevMax = m.Vrstva == VrstvaNahleduDto.Sev ? Math.Max(1f, m.Hodnoty.Where(float.IsFinite).DefaultIfEmpty(1f).Max()) : 1f;
        for (int i = 0; i < m.Hodnoty.Length; i++)
        {
            float v = m.Hodnoty[i];
            (byte r, byte g, byte b, byte a) c = m.Vrstva switch
            {
                // G-7 M4–M6
                VrstvaNahleduDto.VyskaPlanety => A(v < 60f ? Mix((10, 20, 70), (20, 50, 120), (50, 90, 160), Math.Clamp(v / 60f, 0, 1)) : Mix((30, 70, 30), (170, 150, 100), (250, 250, 250), Math.Clamp((v - 60f) / 68f, 0, 1))),
                // posun eroze: většina pod 1 m, max 20 m → odmocninová škála (tmavá 0 → oranžová → světlá max)
                VrstvaNahleduDto.PosunEroze => v < 0 ? A((40, 90, 200)) : A(Mix((25, 25, 35), (200, 90, 40), (255, 240, 200), MathF.Sqrt(Math.Clamp(v / amp, 0, 1)))),
                VrstvaNahleduDto.Toky => A(Mix((25, 25, 30), (40, 110, 200), (200, 240, 255), Math.Clamp((v - 3f) / 6f, 0, 1))),
                VrstvaNahleduDto.Jezera => v > 0 ? A(Mix((120, 180, 240), (40, 90, 200), (10, 30, 120), Math.Clamp(v / 10f, 0, 1))) : A((70, 70, 70)),
                VrstvaNahleduDto.Koryta => v < 0 ? A((20, 40, 90)) : v > 0.5f ? A((60, 150, 255)) : A((90, 85, 70)),
                VrstvaNahleduDto.Teplota => A(Mix((40, 60, 200), (235, 235, 200), (200, 40, 30), Math.Clamp((v + 30f) / 65f, 0, 1))),
                VrstvaNahleduDto.Srazky => A(Mix((190, 150, 80), (80, 170, 80), (40, 70, 200), Math.Clamp(v / 2000f, 0, 1))),
                VrstvaNahleduDto.OdtokW => A(Mix((170, 120, 60), (220, 220, 200), (30, 90, 220), Math.Clamp(v / 2f, 0, 1))),
                VrstvaNahleduDto.BiomKlimatu or VrstvaNahleduDto.BiomBezOaz => A(PaletaBiomuKlimatu[Math.Clamp((int)v, 0, 10)]),
                VrstvaNahleduDto.KorytaKlimatu => v switch { < 0 => A((20, 40, 90)), < 0.5f => A((90, 85, 70)), < 1.5f => A((60, 150, 255)), < 2.5f => A((220, 170, 70)), _ => A((80, 230, 230)) },
                // hloubka hladiny: NaN šedá (bez hladiny), < −0,25 m hladina nad povrchem (moře, zaplavené) tmavě modrá, −0,25…0 vývěr tyrkysová
                VrstvaNahleduDto.Hladina or VrstvaNahleduDto.JenHladina => float.IsNaN(v) ? A((110, 110, 110)) : v < -0.25f ? A((15, 25, 75)) : v <= 0 ? A((60, 240, 240)) : A(Mix((40, 140, 255), (30, 60, 160), (40, 20, 40), Math.Clamp(v / 40f, 0, 1))),
                VrstvaNahleduDto.HladinaAbs => float.IsNaN(v) ? A((110, 110, 110)) : A(Mix((10, 20, 90), (40, 120, 220), (210, 240, 255), Math.Clamp(v / 128f, 0, 1))),
                VrstvaNahleduDto.Dobiti => A(Mix((150, 60, 40), (220, 200, 120), (40, 110, 230), Math.Clamp(v, 0, 1))),
                VrstvaNahleduDto.Vyver => v > 0.5f ? A((60, 240, 240)) : A((50, 50, 55)),
                VrstvaNahleduDto.PobrezniPas => v > 1.5f ? A((20, 40, 90)) : v > 0.5f ? A((60, 200, 230)) : A((150, 140, 110)),
                VrstvaNahleduDto.JenPrameny => A(Mix((40, 40, 40), (120, 120, 120), (220, 220, 220), Math.Clamp(v / 128f, 0, 1))),
                // zástupná vrstva 7d: šrafa (šedá / fialová), ať je vidět, že tu není výsledek
                VrstvaNahleduDto.ZvodnelaZona7d => ((i % m.Nx + i / m.Nx) / 6) % 2 == 0 ? A((90, 90, 90)) : A((150, 60, 150)),
                VrstvaNahleduDto.Vyska or VrstvaNahleduDto.Relief => A(Mix((30, 70, 30), (170, 150, 100), (250, 250, 250), Math.Clamp(v / 128f, 0, 1))),
                VrstvaNahleduDto.Biom => A(PaletaBiomuSveta[Math.Clamp((int)v, 0, 4)]),
                VrstvaNahleduDto.Horniny or VrstvaNahleduDto.MaterialPovrchu => v < 0 ? ((byte)0, (byte)0, (byte)0, (byte)255) : pm[Math.Clamp((int)v, 0, 255)],
                VrstvaNahleduDto.Sopky => v >= 0 ? A(((byte)(180 + (int)v * 37 % 70), (byte)50, (byte)40)) : A((60, 60, 60)),
                VrstvaNahleduDto.Masiv or VrstvaNahleduDto.Mince => A(Mix((40, 40, 40), (140, 130, 120), (255, 240, 200), Math.Clamp(v, 0, 1))),
                VrstvaNahleduDto.Pevnina => A(Mix((30, 60, 150), (200, 200, 150), (60, 140, 60), Math.Clamp(v, 0, 1))),
                VrstvaNahleduDto.More => v > 0.5f ? A((40, 80, 170)) : A((180, 170, 120)),
                VrstvaNahleduDto.Sev => float.IsFinite(v) ? A(Mix((220, 40, 40), (240, 200, 80), (60, 60, 60), Math.Clamp(v / sevMax, 0, 1))) : A((60, 60, 60)),
                _ => A(Mix((30, 60, 200), (235, 235, 235), (200, 40, 30), Math.Clamp(0.5f + 0.5f * v / amp, 0, 1))),
            };
            o[4 * i] = c.r; o[4 * i + 1] = c.g; o[4 * i + 2] = c.b; o[4 * i + 3] = c.a;
        }
        return o;
    }

    /// <summary>Řez M3 → RGBA (Nx × Nz, řádek 0 nahoře). M1/M2 se kreslí jako profil v Godotu (ne obraz) – pro ně prázdné pole.</summary>
    public static byte[] RgbaRezu(RezModuluDto r, IReadOnlyList<MaterialDto> materialy)
    {
        if (r.Nz == 0) return Array.Empty<byte>();
        var pm = PaletaMaterialu(materialy); var o = new byte[r.Nx * r.Nz * 4];
        for (int iz = 0; iz < r.Nz; iz++)
        {
            int radek = r.Nz - 1 - iz;
            for (int ix = 0; ix < r.Nx; ix++)
            {
                var c = pm[r.Material(ix, iz)]; int k = 4 * (radek * r.Nx + ix);
                o[k] = c.r; o[k + 1] = c.g; o[k + 2] = c.b; o[k + 3] = c.a;
            }
        }
        return o;
    }

    static (byte, byte, byte, byte) A((byte r, byte g, byte b) c) => (c.r, c.g, c.b, 255);
    static (byte, byte, byte) Mix((byte r, byte g, byte b) a, (byte r, byte g, byte b) s, (byte r, byte g, byte b) z, float t)
    {
        var (p, q, u) = t < 0.5f ? (a, s, t * 2) : (s, z, (t - 0.5f) * 2);
        return ((byte)Math.Round(p.r + (q.r - p.r) * u), (byte)Math.Round(p.g + (q.g - p.g) * u), (byte)Math.Round(p.b + (q.b - p.b) * u));
    }
}
