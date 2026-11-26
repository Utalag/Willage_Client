using Willage.Gen.Materialy;

namespace Willage.Gen.Voda.Prusak;

/// <summary>
/// Útlum průsaku vrstvou: každý projitý blok násobí průtok koeficientem b/255. Celočíselně v pevné řádové čárce Q24
/// (t ← t · b / 255, zaokrouhleno dolů), takže výsledek je bitově shodný na všech zařízeních. Q24 = 1,0 → 16 777 216.
/// </summary>
public static class PrusakUtlum
{
    public const int Q = 24;
    public const long Jedna = 1L << Q;

    /// <summary>Průchod jedním blokem s koeficientem b (0–255).</summary>
    public static long Blok(long t, byte b) => t * b / 255;   // dolů: s ±0,5 by koeficient ≥ 128 uvízl na 1 LSB a nikdy nedosáhl 0

    /// <summary>Průchod n bloky stejného koeficientu.</summary>
    public static long Vrstva(byte b, int n, long t = Jedna)
    {
        for (int i = 0; i < n; i++) t = Blok(t, b);
        return t;
    }

    /// <summary>Průchod cestou materiálů (jeden prvek = jeden blok).</summary>
    public static long Cesta(ReadOnlySpan<int> materialy, PrusakKoeficient k)
    {
        long t = Jedna;
        foreach (int m in materialy) t = Blok(t, k.Koef(m));
        return t;
    }

    public static double NaDouble(long t) => t / (double)Jedna;
}
