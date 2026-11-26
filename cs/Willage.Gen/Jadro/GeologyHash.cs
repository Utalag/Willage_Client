// ZRCADLO (jen čtení) z Utalag/Willage_Dev main, PR #14 (29bffc0):
// src/Modules/World/Willage.World.Geology.Core/Hash/GeologyHash.cs. Golden vectors: Willage.Gen.Testy/Data/geology-hash-golden-v1.json.
namespace Willage.Gen.Jadro;

/// <summary>Deterministické hashování mřížkových souřadnic bez globálního RNG.</summary>
public static class GeologyHash
{
    public static uint HashInt3(int x, int y, int z, uint seed)
    {
        int h = unchecked(Imul((int)seed, (int)0x27D4EB2D) ^ (int)0x165667B1);
        h = unchecked(Imul(h ^ x, (int)0xCC9E2D51));
        h = unchecked((h << 15) | (int)((uint)h >> 17));
        h = unchecked(Imul(h ^ y, (int)0x1B873593));
        h = unchecked((h << 13) | (int)((uint)h >> 19));
        h = unchecked(Imul(h ^ z, (int)0xE6546B64));
        h = unchecked(h ^ (int)((uint)h >> 16));
        h = unchecked(Imul(h, (int)0x85EBCA6B));
        h = unchecked(h ^ (int)((uint)h >> 13));
        h = unchecked(Imul(h, (int)0xC2B2AE35));
        h = unchecked(h ^ (int)((uint)h >> 16));
        return (uint)h;
    }

    public static uint DeriveSeed(uint seed, int salt) => HashInt3(salt, 0x5EED, 0x1234, seed);

    public static uint HashString(ReadOnlySpan<char> text)
    {
        uint h = 0x811C9DC5;
        foreach (char c in text)
        {
            h = unchecked(h ^ c);
            h = unchecked((uint)Imul(unchecked((int)h), (int)0x01000193));
        }
        return h;
    }

    private static int Imul(int a, int b) => (int)((long)a * b);

    // --- klientské pomůcky (ne zrcadlo) ---
    /// <summary>Hodnota 0–1 z hashe (16 bitů, deterministická).</summary>
    public static double Unit(uint h) => (h & 0xFFFF) / 65536.0;
}
