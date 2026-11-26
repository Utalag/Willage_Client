using System.Text.Json;
using System.Text.Json.Nodes;

namespace Willage.Gen.Planeta;

/// <summary>
/// G-3 review (bod 1): **zástupný** návrh verzovaného JSON exportu PlanetaV1 pro Willage_Dev / server (formát „willage-planeta-export-v1“).
/// Není zmrazený a Dev ho zatím nečte; WPLN zůstává autorským formátem klienta. Export nese otisk (SHA kanonického textu),
/// takže import může ověřit, že je planeta totožná.
/// </summary>
public static class PlanetaJson
{
    public const string Format = "willage-planeta-export-v1";

    public static string Export(PlanetaV1 p) => new JsonObject
    {
        ["format"] = Format,
        ["zastupny"] = true,
        ["otisk"] = SouborPlanety.Otisk(p),
        ["genVer"] = p.GenVer,
        ["formatWpln"] = SouborPlanety.Verze,
        ["seed"] = p.Seed,
        ["manifestSouhrn"] = p.ManifestSouhrn,
        ["manifest"] = new JsonArray(p.Manifest.Select(m => (JsonNode)new JsonObject { ["cesta"] = m.Cesta, ["velikost"] = m.Velikost, ["sha256"] = m.Sha256 }).ToArray()),
        ["sada"] = JsonNode.Parse(p.SadaJson),
        ["klice"] = new JsonObject(p.Klice.Select(k => new KeyValuePair<string, JsonNode?>(k.Key, k.Value))),
        ["potvrzena"] = p.Potvrzena,
        ["upravy"] = new JsonArray(),
    }.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) + "\n";
}
