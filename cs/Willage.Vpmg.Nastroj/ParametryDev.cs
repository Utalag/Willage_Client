using System.Reflection;
using System.Text.Json.Nodes;
using Willage.World.Vpmg;
using Willage.World.Vpmg.Pipeline;

namespace Willage.Vpmg.Nastroj;

/// <summary>
/// T-2c: schéma parametrů operací VPMG z deskriptorů Dev (<see cref="VpmgOperationCatalog.DescribeAll"/> – stejný zdroj jako
/// <c>tools/VpmgPreview --describe-ops</c>). Žádný rozbor zdrojů. Alias (Dev: prázdné Parameters, „Alias pro …“) se určí reflexí
/// na pole <c>_inner</c> operace v registru Dev a převezme parametry cílové operace.
/// </summary>
public static class ParametryDev
{
    public static JsonObject Rozbor(PrikazyVpmg p)
    {
        var registr = typeof(VpmgDefaults).Assembly.GetTypes()
            .Where(t => typeof(IVpmgStepOperation).IsAssignableFrom(t) && t is { IsAbstract: false, IsInterface: false } && t.GetConstructor(Type.EmptyTypes) != null)
            .Select(t => (IVpmgStepOperation)Activator.CreateInstance(t)!)
            .Where(o => p.Registr.CanResolve(o.TypeId)).ToDictionary(o => o.TypeId, StringComparer.Ordinal);
        var desk = VpmgOperationCatalog.DescribeAll().ToDictionary(d => d.TypeId, StringComparer.Ordinal);
        var bez = registr.Keys.Where(k => !desk.ContainsKey(k)).ToList();
        if (bez.Count > 0) throw new InvalidOperationException("operace registru Dev bez deskriptoru: " + string.Join(",", bez));

        string? Alias(IVpmgStepOperation o) =>
            o.GetType().GetField("_inner", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(o) is IVpmgStepOperation c ? c.TypeId : null;

        var ops = new JsonArray();
        foreach (var (type, op) in registr.OrderBy(x => x.Key, StringComparer.Ordinal))
        {
            string? alias = Alias(op);
            var d = desk[type];
            var parametry = (alias != null && d.Parameters.Count == 0 ? desk[alias] : d).Parameters;
            var par = new JsonArray();
            foreach (var x in parametry)
            {
                var o = new JsonObject
                {
                    ["nazev"] = x.Name, ["druh"] = x.Type == "int" ? "cele" : "text", ["vychozi"] = x.DefaultLiteral ?? "",
                    ["vychoziDev"] = x.DefaultLiteral ?? (x.ProfileField != null ? "profil " + x.ProfileField : "výchozí Dev (z rozměru textury)"),
                    ["popisDev"] = x.Description,
                };
                if (x.Min is { } mi) o["min"] = mi;
                if (x.Max is { } ma) o["max"] = ma;
                if (x.ProfileField != null) o["zProfilu"] = new JsonArray(x.ProfileField);
                par.Add(o);
            }
            var j = new JsonObject
            {
                ["type"] = type, ["trida"] = op.GetType().Name, ["popisDev"] = d.Summary,
                ["ctiProfil"] = new JsonArray(parametry.Where(x => x.ProfileField != null).Select(x => (JsonNode)x.ProfileField!).Distinct().ToArray()),
                ["params"] = par,
            };
            if (alias != null) j["aliasOf"] = alias;
            ops.Add(j);
        }
        return new JsonObject
        {
            ["format"] = "willage-vpmg-operace-dev-v2",
            ["poznamka"] = "GENEROVÁNO nástrojem Willage.Vpmg.Nastroj (příkaz parametry) z deskriptorů Dev VpmgOperationCatalog (= tools/VpmgPreview --describe-ops) – needitovat ručně. ctiProfil = jen pole profilu z deskriptorů (ProfileField); ostatní čtená pole doplňuje klientský překryv. vychozi \"\" = výchozí hodnotu bere Dev z profilu / rozměru (vychoziDev).",
            ["devCommit"] = PinDev.Commit,
            ["operace"] = ops,
        };
    }
}
