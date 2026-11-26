using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;

namespace Willage.Gen.Eroze;

/// <summary>
/// Uložení mapy s planetou: formát WGER v1 (Deflate): magie, verze, nx, ny, krok, Px, Py, seed, klíč keše (UTF-8),
/// pak H0 float32, H float32, A float32, příjemce sbyte, příznaky byte. Klíč keše = SHA-256 (hex) z verze generátoru,
/// seedu, kanonických parametrů eroze a hashů datových souborů světa.
/// </summary>
public static class SouborMapy
{
    public const string Magie = "WGER"; public const int Verze = 1;
    public const string VerzeGeneratoru = "krok06-eroze-v1";

    public static string KlicKese(long seed, ParametryEroze p, IEnumerable<string> datoveSoubory, string svet = "")
    {
        var sb = new StringBuilder();
        sb.Append(VerzeGeneratoru).Append('|').Append(seed).Append('|').Append(p.Kanonicky());
        if (svet.Length > 0) sb.Append('|').Append(svet);   // krok 6b: parametry světa, které mapu mění (moře)
        foreach (var f in datoveSoubory.OrderBy(f => Path.GetFileName(f), StringComparer.Ordinal))
            sb.Append('|').Append(Path.GetFileName(f)).Append('=').Append(Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(f))));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sb.ToString()))).ToLowerInvariant();
    }

    public static void Uloz(string cesta, MapaEroze m, long seed)
    {
        using var fs = File.Create(cesta);
        using var z = new DeflateStream(fs, CompressionLevel.Optimal);
        using var w = new BinaryWriter(z);
        w.Write(Encoding.ASCII.GetBytes(Magie)); w.Write(Verze);
        w.Write(m.T.Nx); w.Write(m.T.Ny); w.Write(m.T.Krok); w.Write(m.T.Nx * m.T.Krok); w.Write(m.T.Ny * m.T.Krok);
        w.Write(seed); w.Write(m.KlicKese);
        foreach (var a in new[] { m.H0, m.H, m.A }) w.Write(System.Runtime.InteropServices.MemoryMarshal.AsBytes(a.AsSpan()));
        w.Write(System.Runtime.InteropServices.MemoryMarshal.AsBytes(m.Prijemce.AsSpan()));
        w.Write(m.Priznaky);
    }

    /// <summary>Načte mapu; vrátí null, pokud soubor chybí nebo nesedí klíč keše (pak se počítá znovu).</summary>
    public static MapaEroze? Nacti(string cesta, string klic)
    {
        if (!File.Exists(cesta)) return null;
        using var fs = File.OpenRead(cesta);
        using var z = new DeflateStream(fs, CompressionMode.Decompress);
        using var r = new BinaryReader(z);
        if (Encoding.ASCII.GetString(r.ReadBytes(4)) != Magie || r.ReadInt32() != Verze) return null;
        int nx = r.ReadInt32(), ny = r.ReadInt32(); double krok = r.ReadDouble(); r.ReadDouble(); r.ReadDouble(); r.ReadInt64();
        string k = r.ReadString();
        if (k != klic) return null;
        var m = new MapaEroze(new Torus(nx, ny, krok)) { KlicKese = k };
        foreach (var a in new[] { m.H0, m.H, m.A }) r.BaseStream.ReadExactly(System.Runtime.InteropServices.MemoryMarshal.AsBytes(a.AsSpan()));
        r.BaseStream.ReadExactly(System.Runtime.InteropServices.MemoryMarshal.AsBytes(m.Prijemce.AsSpan()));
        r.BaseStream.ReadExactly(m.Priznaky);
        return m;
    }

    /// <summary>Otisk mapy (FNV-1a 64 přes všechna pole) – pro determinismus.</summary>
    public static string Otisk(MapaEroze m)
    {
        ulong h = 14695981039346656037UL;
        void B(ReadOnlySpan<byte> s) { foreach (var b in s) { h ^= b; h *= 1099511628211UL; } }
        foreach (var a in new[] { m.H0, m.H, m.A }) B(System.Runtime.InteropServices.MemoryMarshal.AsBytes(a.AsSpan()));
        B(System.Runtime.InteropServices.MemoryMarshal.AsBytes(m.Prijemce.AsSpan()));
        B(m.Priznaky);
        return h.ToString("x16");
    }
}
