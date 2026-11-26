using System.Security.Cryptography;
using Willage.Gen.Jadro;

namespace Willage.Gen.Voda;

/// <summary>Otisk funkce vody (SHA-256, prvních 16 hex): hodnoty v Q16 (2⁻¹⁶ m), výkon v µl/s.</summary>
public static class OtiskVody
{
    public static string Blok(BlokVody b)
    {
        using var ms = new MemoryStream();
        using var w = new BinaryWriter(ms);
        w.Write(b.Bx); w.Write(b.By); w.Write(Q16.FromMetres(b.Krok)); w.Write(b.N);
        for (int k = 0; k < b.L.Length; k++)
        {
            w.Write(Q16.FromMetres(b.L[k]));
            w.Write(Q16.FromMetres(b.Surova[k]));
            var p = b.Profily[k];
            if (p is null) { w.Write(-1); continue; }
            w.Write(p.HladinaVTesneni);
            if (p.Nasyceno is { } n) { w.Write(Q16.FromMetres(n.Lo)); w.Write(Q16.FromMetres(n.Hi)); } else w.Write(-2L);
            w.Write(p.Zavesena.Count); foreach (var z in p.Zavesena) { w.Write(Q16.FromMetres(z.Lo)); w.Write(Q16.FromMetres(z.Hi)); }
            w.Write(p.Sevrene.Count); foreach (var s in p.Sevrene) { w.Write(Q16.FromMetres(s.Lo)); w.Write(Q16.FromMetres(s.Hi)); w.Write(s.Material); }
        }
        Prameny(w, b.Prameny);
        w.Flush();
        return Convert.ToHexString(SHA256.HashData(ms.ToArray()))[..16].ToLowerInvariant();
    }

    public static void Prameny(BinaryWriter w, IEnumerable<Pramen> ps)
    {
        foreach (var s in ps)
        {
            w.Write(Q16.FromMetres(s.X)); w.Write(Q16.FromMetres(s.Y)); w.Write(s.Kz); w.Write((int)s.Druh);
            w.Write((long)Math.Round(s.Jmenovity * 1e6)); w.Write(s.AkviferMaterial);
        }
    }
}
