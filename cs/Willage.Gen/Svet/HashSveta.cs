using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>svet_fn.gd::_u – hash světa → [0, 1) s 53 bity.</summary>
public sealed class HashSveta
{
    public long Sd { get; }
    public HashSveta(long sd) => Sd = sd;

    public double U(string ucel, long i, long j, long k = 0)
    {
        long h = StableHash.Mix(Sd, ucel, ((i + 4096) << 24) ^ ((j + 4096) << 8) ^ k);
        return StableHash.Shr(h, 11) / 9007199254740992.0;
    }
}
