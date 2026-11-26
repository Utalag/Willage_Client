using Willage.Gen.Jadro;

namespace Willage.Gen.Voda.Prusak;

/// <summary>
/// Dosah průsaku v čase: jak daleko dojde čelo vody za horizont v homogenní vrstvě jednoho materiálu.
/// Blok = jedna buňka (0,25 m). Doba přes čistý blok τ₀ = ℓ·n / (K·i) (Darcy, porozita n, spád i); čelo prochází blokem k
/// s propustností T_k = ∏ b/255 (Q24, <see cref="PrusakUtlum"/>), takže τ_k = τ₀ / T_k. Koeficient 255 = stálá rychlost,
/// menší koeficient čelo geometricky zpomaluje (tlustá vrstva = těsná). Celočíselně (Int128, milisekundy a milimetry).
/// </summary>
public static class PrusakDosah
{
    public const long MsDen = 86_400_000;
    private const long BlokMm = GeologyGridConstants.CellEdgeMillimetres;

    /// <summary>Doba přes čistý blok v ms (Darcy), nebo -1 = nepropustné (K ≤ 0, i ≤ 0, n ≤ 0).</summary>
    public static long CasCistehoBlokuMs(double kMs, double porovitost, double spad)
    {
        if (!(kMs > 0) || !(spad > 0) || !(porovitost > 0)) return -1;
        double s = GeologyGridConstants.CellM * porovitost / (kMs * spad);   // sekundy
        double ms = s * 1000.0;
        return ms >= 9e18 ? long.MaxValue : Math.Max(1L, (long)Math.Round(ms));
    }

    /// <summary>
    /// Dosah v mm za <paramref name="horizontMs"/> přes homogenní vrstvu s koeficientem <paramref name="koef"/> a časem čistého bloku
    /// <paramref name="tau0Ms"/>, nejvýš <paramref name="maxMm"/>. Celé bloky + lineární zlomek posledního (celočíselně).
    /// </summary>
    public static long DosahMm(byte koef, long tau0Ms, long horizontMs, long maxMm)
    {
        if (tau0Ms < 0 || koef == 0 || horizontMs <= 0 || maxMm <= 0) return 0;
        Int128 cum = 0; long t = PrusakUtlum.Jedna; long mm = 0;
        while (mm < maxMm)
        {
            t = PrusakUtlum.Blok(t, koef);
            if (t == 0) break;
            Int128 tk = ((Int128)tau0Ms << PrusakUtlum.Q) / t;   // doba přes tento blok (ms)
            if (cum + tk > horizontMs)
            {
                Int128 zlomek = (Int128)(horizontMs - cum) * BlokMm / tk;
                mm += (long)zlomek;
                break;
            }
            cum += tk; mm += BlokMm;
        }
        return Math.Min(mm, maxMm);
    }
}
