using System.Text;

namespace Willage.Gen.Sum;

/// <summary>Port scripts/stable_hash.gd (64bitové hashe s přetečením mod 2^64, shodné s GDScript int).</summary>
public static class StableHash
{
    private const ulong Golden = 0x9E3779B97F4A7C15, M1 = 0xBF58476D1CE4E5B9, M2 = 0x94D049BB133111EB;
    private const ulong FnvOffset = 0xCBF29CE484222325, FnvPrime = 0x100000001B3;

    /// <summary>Logický posun vpravo (GDScript H.shr).</summary>
    public static long Shr(long x, int k) => (long)((ulong)x >> k);

    public static long SplitMix64(long x)
    {
        ulong z = unchecked((ulong)x + Golden);
        z = unchecked((z ^ (z >> 30)) * M1);
        z = unchecked((z ^ (z >> 27)) * M2);
        return (long)(z ^ (z >> 31));
    }

    public static long Fnv1a64(string text)
    {
        ulong h = FnvOffset;
        foreach (byte b in Encoding.UTF8.GetBytes(text)) h = unchecked((h ^ b) * FnvPrime);
        return (long)h;
    }

    public static long Mix(long seed, string purpose, long layer) => SplitMix64(SplitMix64(SplitMix64(seed) ^ Fnv1a64(purpose)) ^ layer);

    public static int NoiseSeed(long seed, string purpose, long layer) => (int)(Mix(seed, purpose, layer) & 0x7FFFFFFF);
}
