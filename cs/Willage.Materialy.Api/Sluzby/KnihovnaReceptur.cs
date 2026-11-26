using System.Security.Cryptography;
using System.Text.Json;
using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>Jedna receptura z data/vpmg/receptury (N8) a odkud je v Dev.</summary>
public sealed record ZaznamReceptury(byte MaterialId, string Soubor, string ZdrojDev, string Sha256, uint GoldenSeed, int GoldenRozliseni, uint GoldenChecksum, RecepturaVpmgDto Receptura);

/// <summary>
/// T-2b: výchozí receptury materiálů = data/vpmg/receptury/&lt;materialId&gt;.json (N8) podle indexu zdroj_receptur.json
/// (bajtové kopie receptur v1 z Willage_Dev). Materiál bez receptury → výchozí receptura v0 (VpmgPreview: base_fill + hash_grain).
/// </summary>
public sealed class KnihovnaReceptur
{
    public string Slozka { get; }
    public string DevCommit { get; }
    public IReadOnlyList<ZaznamReceptury> Zaznamy { get; }

    public KnihovnaReceptur(string slozka)
    {
        Slozka = slozka;
        using var d = JsonDocument.Parse(File.ReadAllText(Path.Combine(slozka, "zdroj_receptur.json")));
        DevCommit = d.RootElement.GetProperty("devCommit").GetString() ?? "";
        Zaznamy = d.RootElement.GetProperty("receptury").EnumerateArray().Select(e =>
        {
            string soubor = e.GetProperty("soubor").GetString()!;
            byte[] b = File.ReadAllBytes(Path.Combine(slozka, soubor));
            var r = RecepturyVpmg.ZJson(System.Text.Encoding.UTF8.GetString(b));
            byte id = (byte)e.GetProperty("materialId").GetInt32();
            if (r.MaterialId != id) throw new InvalidDataException($"receptura {soubor}: materialId {r.MaterialId} ≠ {id}");
            var g = e.GetProperty("golden");
            return new ZaznamReceptury(id, soubor, e.GetProperty("zdrojDev").GetString()!, e.GetProperty("sha256").GetString()!,
                Convert.ToUInt32(g.GetProperty("seed").GetString(), 16), g.GetProperty("resolution").GetInt32(), g.GetProperty("checksum").GetUInt32(), r);
        }).ToList();
    }

    public ZaznamReceptury? Zaznam(byte material) => Zaznamy.FirstOrDefault(z => z.MaterialId == material);

    /// <summary>SHA-256 souboru v knihovně teď (test: = SHA Dev v indexu).</summary>
    public string ShaSouboru(ZaznamReceptury z) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(Slozka, z.Soubor)))).ToLowerInvariant();

    /// <summary>Výchozí receptura materiálu: v1 z knihovny (rozlišení dle přání), jinak v0.</summary>
    public RecepturaVpmgDto Vychozi(byte material, int? rozliseni = null) =>
        Zaznam(material) is { } z ? (rozliseni is { } r ? z.Receptura with { Resolution = r } : z.Receptura) : RecepturyVpmg.Vychozi(material, rozliseni ?? 64);
}
