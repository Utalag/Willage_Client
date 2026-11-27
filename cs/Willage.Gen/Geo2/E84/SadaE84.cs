using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.Gen.Data;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Dnešní geologie E84 jako události GEO2 v pořadí 2.7 (zasobnik 0 → skarn 20 → čočka 30 → žíla 40 → dóm 50 → komín 60 →
/// kras 70 → sopka 80). Hostitelé a nejmenší hloubky se čtou z dat <c>v1/utvary_hostitele.json</c> (stejná data jako stará cesta).
/// Rozdíly proti staré cestě jsou záměrné (kontrakt): skarn eukleidovsky ke granitoidu a jen v karbonátech (O1);
/// o překryvu těles rozhoduje chronologie, ne nejmenší SDF; hostitel se čte z materiálu v bodě, ne z vrstvy.
/// </summary>
public static class SadaE84
{
    public static readonly string[] Granitoidy = { "granite", "granodiorite", "leucogranite" }; // Utvary.Granitoid: 6, 36, 37
    public static readonly string[] Karbonaty = { "deep_limestone", "cave_limestone", "dolomite" };

    public static string Json(DataSveta d)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(d.UtvaryHostitele));
        var root = doc.RootElement; var typy = root.GetProperty("typy");
        JsonArray Pole(IEnumerable<string> a) => new(a.Select(x => (JsonNode)JsonValue.Create(x)!).ToArray());
        IEnumerable<string> Hosts(string typ) => typy.GetProperty(typ).GetProperty("hosts").EnumerateArray().Select(e => e.GetString()!);
        bool Vse(string typ) => typy.GetProperty(typ).GetProperty("hosts").ValueKind == JsonValueKind.String;
        double MinH(string typ) => typy.GetProperty(typ).TryGetProperty("min_hloubka_m", out var m) ? m.GetDouble() : 0.0;
        JsonObject Nahr(string typ) => Vse(typ) ? new JsonObject() : new JsonObject { ["materialy"] = Pole(Hosts(typ)) };
        JsonNode NahrNode(string typ) => Vse(typ) ? JsonValue.Create("*")! : Nahr(typ);
        JsonObject Hl(string typ) => new() { ["min_m"] = MinH(typ) };

        JsonObject Teleso(string id, int stari, string op, string druh, string typ, JsonObject vysledek, string telesa = "zadna", bool transformace = true)
        {
            var pr = new JsonObject
            {
                ["nahrazuje"] = NahrNode(typ),
                ["zdroje"] = new JsonObject { ["vrstvy"] = true, ["telesa"] = telesa, ["transformace"] = transformace },
                ["hloubka"] = Hl(typ),
            };
            if (op == "Vnikni") pr["prostor"] = new JsonArray();
            return new JsonObject
            {
                ["id"] = id, ["stari"] = stari, ["operace"] = op,
                ["tvar"] = new JsonObject { ["druh"] = druh, ["z_parametru"] = typ },
                ["pravidla"] = pr, ["vysledek"] = vysledek, ["sourozenci"] = "nejmensi_sdf",
            };
        }

        var skarnHost = Hosts("skarn").Where(Karbonaty.Contains).ToArray(); // O1: jen karbonáty
        var ud = new JsonArray
        {
            new JsonObject { ["id"] = "zasobnik", ["stari"] = 0, ["operace"] = "Uloz",
                ["tvar"] = new JsonObject { ["druh"] = "zasobnik", ["zdroj"] = "VrstvySloupce" } },
            new JsonObject { ["id"] = "skarn_kontakt", ["stari"] = 20, ["operace"] = "Transformuj",
                ["tvar"] = new JsonObject { ["druh"] = "kontakt", ["seed_e84"] = true },
                ["pravidla"] = new JsonObject
                {
                    ["nahrazuje"] = new JsonObject { ["materialy"] = Pole(skarnHost) },
                    ["zdroje"] = new JsonObject { ["vrstvy"] = true, ["telesa"] = "zadna", ["transformace"] = false },
                    ["hloubka"] = Hl("skarn"),
                    ["kontakt"] = new JsonObject
                    {
                        ["cil"] = new JsonObject { ["vrstvy"] = Pole(Granitoidy) }, ["strana"] = "vne", ["sirka_m"] = 1.5,
                        ["modulace"] = new JsonObject { ["amp_rel"] = 0.5, ["frekvence_1_m"] = 0.5 },
                        ["hostitel_okoli"] = new JsonObject { ["materialy"] = Pole(Granitoidy), ["hloubka_vzorku_m"] = 0.125 },
                    },
                },
                ["vysledek"] = new JsonObject { ["mapa"] = new JsonObject(skarnHost.Select(k => KeyValuePair.Create(k, (JsonNode?)JsonValue.Create("skarn")))) } },
            Teleso("cocka", 30, "Vnikni", "elipsoid", "cocka", new JsonObject { ["material_z_tvaru"] = true }),
            Teleso("zila", 40, "Vnikni", "deska", "zila", new JsonObject { ["material_z_tvaru"] = true }),
            Teleso("dome", 50, "Vnikni", "elipsoid", "dome", new JsonObject { ["material"] = "rock_salt" }),
            Teleso("pipe", 60, "Vnikni", "elipsoid", "pipe", new JsonObject { ["material"] = "kimberlite" }, telesa: "starsi"),
            Teleso("kras", 70, "Odstran", "kapsle_retez", "kras", new JsonObject { ["prostor"] = "DutinaKras" }, transformace: false),
            new JsonObject { ["id"] = "sopka", ["stari"] = 80, ["operace"] = "Vnikni",
                ["tvar"] = new JsonObject { ["druh"] = "sopka_nitro", ["zdroj"] = "NitroSopky" },
                ["pravidla"] = new JsonObject
                {
                    ["nahrazuje"] = "*", ["ignoruj_nikdy"] = true,
                    ["zdroje"] = new JsonObject { ["vrstvy"] = true, ["telesa"] = "starsi", ["transformace"] = true },
                    ["prostor"] = new JsonArray("DutinaKras", "DutinaJina"),
                },
                ["vysledek"] = new JsonObject { ["material_z_tvaru"] = true } },
        };
        var o = new JsonObject
        {
            ["schema"] = "willage.udalosti.v2", ["verze"] = 3,
            ["nikdy"] = Pole(root.GetProperty("nikdy").EnumerateArray().Select(e => e.GetString()!)),
            ["udalosti"] = ud,
        };
        return o.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
    }
}
