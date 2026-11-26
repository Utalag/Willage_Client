using System.Globalization;
using System.Text.Json;
using Willage.Gen.Data;

namespace Willage.Gen.Geologie;

/// <summary>Hornina úrovní 0–40 z data/teren/poradi_hornin.json (jen pole, která geologie V1 čte).</summary>
public sealed record Hornina(int Idx, int Id, string Key, string Kind, bool Active, double Freq, double Thick0, double Thick1);

/// <summary>Port geo_vrstvy.gd::_nacti_katalog: horniny 0–40 v pořadí souboru + těsnění mince (propustnost_0_1 ≤ 0).</summary>
public sealed class KatalogHornin
{
    public List<Hornina> Horniny { get; } = new();
    public HashSet<int> Perm0 { get; } = new();

    public KatalogHornin(DataSveta d)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(d.PoradiHornin));
        foreach (var r in Rocks(doc))
        {
            int idx = Int(r, "idx", -1);
            if (idx < 0 || idx > 40) continue;
            double[] th = r.TryGetProperty("thick", out var t) ? t.EnumerateArray().Select(e => e.GetDouble()).ToArray() : new[] { 1.0, 1.0 };
            Horniny.Add(new Hornina(idx, Int(r, "id", 0), Str(r, "key", ""), Str(r, "kind", "layer"),
                !r.TryGetProperty("active", out var a) || a.ValueKind != JsonValueKind.False,
                r.TryGetProperty("freq", out var f) ? f.GetDouble() : 0.5, th[0], th.Length > 1 ? th[1] : th[0]));
        }
        var rows = Csv.Radky(File.ReadAllText(d.MaterialyV1)).ToList();
        int iId = rows[0].IndexOf("id"), iP = rows[0].IndexOf("propustnost_0_1");
        foreach (var row in rows.Skip(1))
        {
            if (row.Count <= Math.Max(iId, iP)) continue;
            if (!int.TryParse(row[iId], NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out int id)) continue;
            var ps = row[iP].Trim();
            if (double.TryParse(ps, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) && v <= 0.0) Perm0.Add(id);
        }
    }

    public static IEnumerable<JsonElement> Rocks(JsonDocument doc) =>
        doc.RootElement.TryGetProperty("rocks", out var r) ? r.EnumerateArray() : Enumerable.Empty<JsonElement>();
    public static int Int(JsonElement e, string k, int def) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.Number ? (int)v.GetDouble() : def;
    public static string Str(JsonElement e, string k, string def) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString()! : def;
}
