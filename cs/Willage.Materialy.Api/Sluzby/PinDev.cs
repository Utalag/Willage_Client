using System.Security.Cryptography;
using System.Text.Json;
using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>Čte data/vpmg/dev_pin.json a spočte SHA zrcadla katalogu (bajty souboru).</summary>
public static class PinDev
{
    public static PinDevDto Nacti(string koren)
    {
        using var d = JsonDocument.Parse(File.ReadAllText(Path.Combine(koren, "vpmg", "dev_pin.json")));
        var r = d.RootElement; var k = r.GetProperty("katalog"); var g = r.GetProperty("golden");
        string zr = k.GetProperty("zrcadlo").GetString()!;
        string sha = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(koren, zr)))).ToLowerInvariant();
        return new PinDevDto(r.GetProperty("repo").GetString()!, r.GetProperty("commit").GetString()!, r.GetProperty("popis").GetString()!,
            k.GetProperty("sha256").GetString()!, zr, sha, g.GetProperty("checksum").GetUInt32(), (byte)g.GetProperty("materialId").GetInt32(),
            Convert.ToUInt32(g.GetProperty("seed").GetString(), 16), g.GetProperty("resolution").GetInt32());
    }
}
