using System.Text.Json;
using System.Text.Json.Serialization;
using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>
/// Receptury VPMG ve schématu Dev (schemaVersion 1). JSON se zapisuje stejně jako <c>VpmgRecipeJson.ToJson</c> Dev
/// (camelCase, odsazení, stejné pořadí vlastností) – test T-1 porovnává bajt po bajtu s příkazem „kanon“ nástroje.
/// Logiku receptury (spuštění) má jen Dev; tady je jen formát a validace proti schématu operací.
/// </summary>
public static class RecepturyVpmg
{
    static readonly JsonSerializerOptions Jo = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    /// <summary>Výchozí receptura = tools/VpmgPreview Dev.</summary>
    public static RecepturaVpmgDto Vychozi(byte material, int rozliseni = 64) => new(1, material, "default", rozliseni, new[]
    {
        new KrokVpmgDto("s1", "base_fill", true, new Dictionary<string, string> { ["layer"] = "albedo" }),
        new KrokVpmgDto("s2", "hash_grain", true, new Dictionary<string, string>()),
    });

    public static string DoJson(RecepturaVpmgDto r) => JsonSerializer.Serialize(new Dokument
    {
        SchemaVersion = r.SchemaVersion, MaterialId = r.MaterialId, VisualProfile = r.VisualProfile, Resolution = r.Resolution,
        Steps = r.Kroky.Select(k => new Krok { Id = k.Id, Type = k.Type, Enabled = k.Enabled, Params = new Dictionary<string, string>(k.Params, StringComparer.Ordinal) }).ToList(),
    }, Jo);

    public static RecepturaVpmgDto ZJson(string json)
    {
        var d = JsonSerializer.Deserialize<Dokument>(json, Jo) ?? throw new InvalidDataException("prázdná receptura");
        if (d.SchemaVersion != 1) throw new InvalidDataException($"receptura: schemaVersion {d.SchemaVersion} ≠ 1");
        if (d.MaterialId is < 0 or > 255) throw new InvalidDataException($"receptura: materialId {d.MaterialId} mimo u8");
        return new RecepturaVpmgDto(d.SchemaVersion, (byte)d.MaterialId, d.VisualProfile ?? "default", d.Resolution,
            d.Steps.Select(s => new KrokVpmgDto(s.Id, s.Type, s.Enabled, (IReadOnlyDictionary<string, string>?)s.Params ?? new Dictionary<string, string>())).ToList());
    }

    /// <summary>Kontrola proti schématu operací a katalogu: neznámá / zástupná operace, rozlišení, profil, neznámé parametry.</summary>
    public static IReadOnlyList<string> Validuj(RecepturaVpmgDto r, SchemaOperaciVpmg schema, KatalogVzhledu? katalog = null)
    {
        var ch = new List<string>();
        if (r.Resolution < schema.RozliseniMin || r.Resolution > schema.RozliseniMax) ch.Add($"rozlišení {r.Resolution} mimo {schema.RozliseniMin}–{schema.RozliseniMax}");
        if (katalog != null)
        {
            var m = katalog.Material(r.MaterialId);
            if (m is null) ch.Add($"materiál {r.MaterialId} není v katalogu");
            else if (!m.Profily.ContainsKey(r.VisualProfile)) ch.Add($"materiál {r.MaterialId} nemá profil '{r.VisualProfile}'");
        }
        var ids = new HashSet<string>(StringComparer.Ordinal);
        foreach (var k in r.Kroky)
        {
            if (!ids.Add(k.Id)) ch.Add($"krok '{k.Id}': duplicitní id");
            var op = schema.Operace(k.Type);
            if (op is null) { ch.Add($"krok '{k.Id}': neznámá operace '{k.Type}'"); continue; }
            if (op.Zastupna && k.Enabled) ch.Add($"krok '{k.Id}': operace '{k.Type}' je zástupná (není v registru Dev)");
            foreach (var p in k.Params.Keys)
                if (op.Params.All(x => x.Nazev != p)) ch.Add($"krok '{k.Id}': parametr '{p}' operace '{k.Type}' nezná");
        }
        return ch;
    }

    sealed class Dokument
    {
        public int SchemaVersion { get; set; }
        public int MaterialId { get; set; }
        public string? VisualProfile { get; set; }
        public int Resolution { get; set; }
        public List<Krok> Steps { get; set; } = new();
    }

    sealed class Krok
    {
        public string Id { get; set; } = "";
        public string Type { get; set; } = "";
        public bool Enabled { get; set; } = true;
        public Dictionary<string, string>? Params { get; set; }
    }
}
