namespace Willage.Gen.Jadro;

/// <summary>
/// G-3 review (bod 3): seed světa je 64bitový <c>long</c> (ParametrySveta.Seed, WPLN, JSON). 32bitový seed pro celočíselné hashe
/// (GeologyHash.HashInt3, budoucí VPMG) se odvozuje **jen tady** – nikde jinde se seed nezkracuje.
/// Pravidlo v1: dolních 32 bitů (unchecked) – zachovává dnešní otisky (seed 49 → 49) a je to přesně to, co dělaly oázy.
/// Šum používá vlastní odvození StableHash.NoiseSeed(seed, účel, vrstva) (SplitMix64 + FNV), to se nemění.
/// Pozor: dva seedy lišící se jen v horních 32 bitech dají stejný 32bitový seed – pro hashe je to přijatelné, svět se liší šumem.
/// </summary>
public static class SeedSveta
{
    public static uint Hash32(long seedSveta) => unchecked((uint)seedSveta);
}
