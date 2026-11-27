using System.Text;
using System.Text.Json;
using Willage.Gen.Sum;

namespace Willage.Gen.Geo2;

/// <summary>Stav materiálu v katalogu (kontrakt 06, kap. 8). Dnešní <c>todo_open_range</c> se bere jako aktivní.</summary>
public enum StavMaterialu { Aktivni, Vyrazeny }

public sealed record MaterialGeo2(int Id, string Klic, string Skupina, StavMaterialu Stav, string StavText, int? NahradaId);

/// <summary>
/// Pohled GEO2 na katalog materiálů (stejný <c>materials-catalog-v1.json</c> jako <see cref="Willage.Gen.Materialy.KatalogMaterialu"/>, který zůstává beze změny).
/// Kap. 8: počet ani rozsah id se nepředpokládá, id se nerecyklují, vyřazená hornina má povinnou náhradu, verze a otisk katalogu jsou součástí otisku světa.
/// </summary>
public sealed class KatalogGeo2
{
    private readonly SortedDictionary<int, MaterialGeo2> _podleId = new();
    private readonly Dictionary<string, MaterialGeo2> _podleKlice = new(StringComparer.Ordinal);
    private readonly SortedSet<string> _skupiny = new(StringComparer.Ordinal);
    public ZpravaValidace Zprava { get; } = new();
    public int VerzeSchematu { get; }
    public long Otisk { get; }
    public int MaxId => _podleId.Count == 0 ? -1 : _podleId.Keys.Max();
    public IReadOnlyCollection<MaterialGeo2> Materialy => _podleId.Values;

    public KatalogGeo2(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        VerzeSchematu = root.TryGetProperty("schemaVersion", out var sv) && sv.ValueKind == JsonValueKind.Number ? sv.GetInt32() : 0;
        foreach (var m in root.GetProperty("materials").EnumerateArray())
        {
            int id = m.GetProperty("id").GetInt32();
            string klic = m.TryGetProperty("key", out var k) ? k.GetString() ?? "" : "";
            string sk = m.TryGetProperty("geology", out var g) && g.ValueKind == JsonValueKind.Object && g.TryGetProperty("skupina", out var s)
                ? s.GetString() ?? "" : "";
            string st = m.TryGetProperty("idStatus", out var ist) ? ist.GetString() ?? "active" : "active";
            int? nahr = null;
            if (m.TryGetProperty("replacedBy", out var rb) && rb.ValueKind == JsonValueKind.Number) nahr = rb.GetInt32();
            var mat = new MaterialGeo2(id, klic, sk, st == "retired" ? StavMaterialu.Vyrazeny : StavMaterialu.Aktivni, st, nahr);
            if (!_podleId.TryAdd(id, mat)) { Zprava.Chyba("KAT_ID_DUPLICITNI", null, $"id {id} je v katalogu dvakrát"); continue; }
            if (klic.Length == 0) Zprava.Chyba("KAT_BEZ_KLICE", null, $"id {id} nemá klíč");
            else if (!_podleKlice.TryAdd(klic, mat)) Zprava.Chyba("KAT_KLIC_DUPLICITNI", null, $"klíč {klic} je v katalogu dvakrát");
            if (sk.Length > 0) _skupiny.Add(sk);
        }
        foreach (var m in _podleId.Values.Where(m => m.Stav == StavMaterialu.Vyrazeny))
        {
            if (m.NahradaId is null) Zprava.Chyba("KAT_VYRAZENA_BEZ_NAHRADY", null, $"vyřazená hornina {m.Klic} ({m.Id}) nemá povinnou náhradu");
            else if (Aktivni(m.Id) is null) Zprava.Chyba("KAT_NAHRADA_NEVEDE_K_AKTIVNI", null, $"náhrada {m.Klic} ({m.Id}) nevede k aktivní hornině (neznámé id nebo cyklus)");
        }
        Otisk = SpoctiOtisk();
    }

    public static KatalogGeo2 ZeSouboru(string cesta) => new(File.ReadAllText(cesta));

    public MaterialGeo2? PodleKlice(string klic) => _podleKlice.GetValueOrDefault(klic);
    public MaterialGeo2? PodleId(int id) => _podleId.GetValueOrDefault(id);
    public bool ZnamaSkupina(string s) => _skupiny.Contains(s);

    /// <summary>Aktivní hornina pro id: sám, nebo konec řetězu náhrad. Null = neznámé id, vyřazená bez náhrady, nebo cyklus.</summary>
    public MaterialGeo2? Aktivni(int id)
    {
        var navstiveno = new HashSet<int>();
        var m = PodleId(id);
        while (m is not null && m.Stav == StavMaterialu.Vyrazeny)
        {
            if (m.NahradaId is null || !navstiveno.Add(m.Id)) return null;
            m = PodleId(m.NahradaId.Value);
        }
        return m;
    }

    /// <summary>Aktivní id všech hornin skupiny (nová hornina ve skupině sem spadne automaticky).</summary>
    public IEnumerable<int> IdSkupiny(string skupina) =>
        _podleId.Values.Where(m => m.Stav == StavMaterialu.Aktivni && m.Skupina == skupina).Select(m => m.Id);

    private long SpoctiOtisk()
    {
        var sb = new StringBuilder();
        sb.Append("schema=").Append(VerzeSchematu).Append('\n');
        foreach (var m in _podleId.Values)
            sb.Append(m.Id).Append('|').Append(m.Klic).Append('|').Append(m.Skupina).Append('|').Append(m.StavText).Append('|').Append(m.NahradaId?.ToString() ?? "-").Append('\n');
        return StableHash.Fnv1a64(sb.ToString());
    }
}
