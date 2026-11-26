namespace Willage.Gen.Api.Dto;

/// <summary>
/// Vodorovná poloha na planetě v jednotkách 2⁻¹⁶ m (stejná jednotka jako <c>FxQ16</c> v Willage_Dev Geology.Core G0).
/// Knihovna dnes počítá v <c>double</c> metrech; převod je jen na hranici fasády.
/// </summary>
public readonly record struct SouradniceQ16(long X, long Y)
{
    public const int JednotekNaMetr = 65_536;
    public static SouradniceQ16 ZMetru(double xM, double yM) =>
        new((long)Math.Round(xM * JednotekNaMetr, MidpointRounding.ToEven), (long)Math.Round(yM * JednotekNaMetr, MidpointRounding.ToEven));
    /// <summary>Jednotek Q16 na buňku 0,25 m.</summary>
    public const long JednotekNaBunku = JednotekNaMetr / 4;
    /// <summary>Minimální roh buňky (ix, iy) – konvence indexu buňky jako Dev GeologyCellIndex.</summary>
    public static SouradniceQ16 MinRohBunky(long ix, long iy) => new(ix * JednotekNaBunku, iy * JednotekNaBunku);
    /// <summary>Střed buňky (ix, iy) = min. roh + 0,125 m – tady vzorkuje sloupec buňky.</summary>
    public static SouradniceQ16 StredBunky(long ix, long iy) => new(ix * JednotekNaBunku + JednotekNaBunku / 2, iy * JednotekNaBunku + JednotekNaBunku / 2);
    public double XM => X / (double)JednotekNaMetr;
    public double YM => Y / (double)JednotekNaMetr;
}

/// <summary>Obdélník [Od, Do) na planetě (Q16).</summary>
public readonly record struct OblastQ16(SouradniceQ16 Od, SouradniceQ16 Do);
