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
    public double XM => X / (double)JednotekNaMetr;
    public double YM => Y / (double)JednotekNaMetr;
}

/// <summary>Obdélník [Od, Do) na planetě (Q16).</summary>
public readonly record struct OblastQ16(SouradniceQ16 Od, SouradniceQ16 Do);
