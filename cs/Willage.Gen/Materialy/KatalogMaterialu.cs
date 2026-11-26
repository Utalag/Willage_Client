using System.Text.Json;

namespace Willage.Gen.Materialy;

/// <summary>
/// Načte materials-catalog-v1.json Willage-backendu (Willage_Dev main 3476488, jen čtení; kopie v godot-prototyp/data/v1).
/// Nová ID se tu nepřidělují. Neznámé ID = těsnění (počítá se v <see cref="NeznamaId"/>).
/// </summary>
public sealed class KatalogMaterialu
{
    /// <summary>Rozpustné horniny (kras) – stejný seznam jako E67 (voda/podzemi.gd::_soluble).</summary>
    public static readonly string[] RozpustneKlice =
        { "cave_limestone", "deep_limestone", "dolomite", "limestone_outcrop", "gypsum", "rock_salt" };

    private readonly Material?[] _podleId = new Material?[256];
    public HashSet<int> NeznamaId { get; } = new();
    public int Pocet { get; }

    public KatalogMaterialu(string json)
    {
        using var doc = JsonDocument.Parse(json);
        foreach (var m in doc.RootElement.GetProperty("materials").EnumerateArray())
        {
            int id = m.GetProperty("id").GetInt32();
            string key = m.GetProperty("key").GetString() ?? "";
            var g = m.GetProperty("geology");
            double? k = g.TryGetProperty("permeabilityMs", out var kp) ? CisloK(kp) : null;
            double por = g.TryGetProperty("porosityPermille", out var pp) && pp.ValueKind == JsonValueKind.Number ? pp.GetInt32() / 1000.0 : 0.0;
            string sk = g.TryGetProperty("skupina", out var s) ? s.GetString() ?? "" : "";
            if (id is >= 0 and < 256)
                _podleId[id] = new Material(id, key, k, por, sk, RozpustneKlice.Contains(key));
            Pocet++;
        }
    }

    /// <summary>K je v katalogu řetězec v desítkovém zápisu („1e-5“), připouští se i číslo.</summary>
    private static double? CisloK(JsonElement e) => e.ValueKind switch
    {
        JsonValueKind.Number => e.GetDouble(),
        JsonValueKind.String when double.TryParse(e.GetString(), System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture, out var v) => v,
        _ => null,
    };

    public static KatalogMaterialu ZeSouboru(string cesta) => new(File.ReadAllText(cesta));

    public Material? Najdi(int id)
    {
        var m = id is >= 0 and < 256 ? _podleId[id] : null;
        if (m is null) lock (NeznamaId) NeznamaId.Add(id);
        return m;
    }
}
