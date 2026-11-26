using System.Text.Json;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>Podkladová dlaždice klienta (data/vpmg/zaklady, T-2c) – PNG ruční dlaždice, kterou Dev má jako baseTile (rgba8, stejné SHA).</summary>
public sealed record ZakladVpmg(byte MaterialId, string Key, string Soubor, string Cesta, string Sha256, string PngSha256);

/// <summary>T-2d: manifest zaklady_v1.json → dlaždice podle materiálu / SHA baseTile (jen čtení; editor ukazuje náhled podkladu).</summary>
public sealed class ZakladyVpmg
{
    public IReadOnlyList<ZakladVpmg> Dlazdice { get; }

    public ZakladyVpmg(string slozka)
    {
        string m = Path.Combine(slozka, "zaklady_v1.json");
        if (!File.Exists(m)) { Dlazdice = []; return; }
        using var d = JsonDocument.Parse(File.ReadAllText(m));
        Dlazdice = d.RootElement.GetProperty("dlazdice").EnumerateArray().Select(x => new ZakladVpmg(
            (byte)x.GetProperty("materialId").GetInt32(), x.GetProperty("key").GetString()!, x.GetProperty("soubor").GetString()!,
            Path.Combine(slozka, x.GetProperty("soubor").GetString()!), x.GetProperty("sha256").GetString()!, x.GetProperty("pngSha256").GetString()!)).ToList();
    }

    /// <summary>Dlaždice klienta se stejným SHA RGBA8 jako baseTile profilu (null = klient ji nemá).</summary>
    public ZakladVpmg? PodleSha(string? sha256) => sha256 is null ? null : Dlazdice.FirstOrDefault(x => string.Equals(x.Sha256, sha256, StringComparison.OrdinalIgnoreCase));
}
