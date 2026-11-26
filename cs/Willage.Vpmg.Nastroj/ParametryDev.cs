using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Willage.World.Vpmg;
using Willage.World.Vpmg.Pipeline;

namespace Willage.Vpmg.Nastroj;

/// <summary>
/// T-2b: „schéma“ parametrů operací VPMG z připnutého Dev. Dev formální schéma nemá – operace čtou params ad hoc.
/// Typy operací bere z registru Dev (reflexe), parametry z rozboru zdrojů v pinu (src/.../Operations/&lt;Třída&gt;.cs):
/// <c>VpmgStepParams.GetInt|GetString(step, "klíč", výchozí)</c>, <c>Params.TryGetValue("klíč"</c>, <c>context.VisualProfile.X</c>
/// a pomocníky (VpmgPaletteResolver → palette + baseColor); alias = třída deleguje na <c>_inner = new X()</c>.
/// Křehké vůči přepisu Dev (regex) – proto návrh pro backend: deskriptor parametrů přímo v IVpmgStepOperation.
/// </summary>
public static class ParametryDev
{
    const string Slozka = "src/Modules/World/Willage.World.Vpmg/Operations";
    static readonly Regex GetRe = new(@"VpmgStepParams\.Get(Int|String)\(\s*\w+\s*,\s*""(\w+)""\s*,\s*(?<v>(?:[^()]|\((?<d>)|\)(?<-d>))*?)\s*\)\s*;", RegexOptions.Singleline);
    static readonly Regex TryRe = new(@"Params\.TryGetValue\(\s*""(\w+)""[^?]*\?\s*\w+\s*:\s*""([^""]*)""", RegexOptions.Singleline);
    static readonly Regex ProfRe = new(@"VisualProfile\.(\w+)");
    static readonly Regex InnerRe = new(@"readonly\s+(\w+)\s+_inner\s*=\s*new\s*\(");
    static readonly Regex LokalRe = new(@"var\s+(\w+)\s*=\s*context\.VisualProfile\.(\w+)\s*;");
    static readonly Regex CisloRe = new(@"^-?\d+$");

    static string Camel(string s) => char.ToLowerInvariant(s[0]) + s[1..];

    public static JsonObject Rozbor(PrikazyVpmg p)
    {
        var typy = typeof(VpmgDefaults).Assembly.GetTypes()
            .Where(t => typeof(IVpmgStepOperation).IsAssignableFrom(t) && t is { IsAbstract: false, IsInterface: false } && t.GetConstructor(Type.EmptyTypes) != null)
            .Select(t => (Trida: t.Name, Type: ((IVpmgStepOperation)Activator.CreateInstance(t)!).TypeId))
            .Where(x => p.Registr.CanResolve(x.Type)).OrderBy(x => x.Type, StringComparer.Ordinal).ToList();
        var podleTridy = typy.ToDictionary(x => x.Trida, x => x.Type);
        var ops = new JsonArray();
        foreach (var (trida, type) in typy)
        {
            string zdroj = File.ReadAllText(PinDev.Cesta($"{Slozka}/{trida}.cs"));
            string? alias = InnerRe.Match(zdroj) is { Success: true } im && podleTridy.TryGetValue(im.Groups[1].Value, out var at) ? at : null;
            string tel = alias != null ? File.ReadAllText(PinDev.Cesta($"{Slozka}/{InnerRe.Match(zdroj).Groups[1].Value}.cs")) : zdroj;
            var par = new JsonArray();
            foreach (Match m in TryRe.Matches(tel))
                par.Add(new JsonObject { ["nazev"] = m.Groups[1].Value, ["druh"] = "text", ["vychozi"] = m.Groups[2].Value, ["vychoziDev"] = $"\"{m.Groups[2].Value}\"" });
            foreach (Match m in GetRe.Matches(tel))
            {
                string v = Regex.Replace(m.Groups["v"].Value, @"\s+", " ").Trim();
                bool cislo = CisloRe.IsMatch(v);
                var o = new JsonObject { ["nazev"] = m.Groups[2].Value, ["druh"] = m.Groups[1].Value == "Int" ? "cele" : "text", ["vychozi"] = cislo ? v : "", ["vychoziDev"] = v };
                var lok = LokalRe.Matches(tel).ToDictionary(x => x.Groups[1].Value, x => Camel(x.Groups[2].Value));
                var pz = ProfRe.Matches(v).Select(x => Camel(x.Groups[1].Value))
                    .Concat(Regex.Matches(v, @"\b\w+\b").Select(x => x.Value).Where(lok.ContainsKey).Select(x => lok[x])).Distinct().ToList();
                if (pz.Count > 0) o["zProfilu"] = new JsonArray(pz.Select(x => (JsonNode)x).ToArray());
                par.Add(o);
            }
            var cti = ProfRe.Matches(tel).Select(x => Camel(x.Groups[1].Value)).ToList();
            if (tel.Contains("VpmgPaletteResolver.Resolve")) cti.AddRange(new[] { "palette", "baseColor" });
            var o2 = new JsonObject
            {
                ["type"] = type, ["trida"] = trida,
                ["ctiProfil"] = new JsonArray(cti.Distinct().OrderBy(x => x, StringComparer.Ordinal).Select(x => (JsonNode)x).ToArray()),
                ["params"] = par,
            };
            if (alias != null) o2["aliasOf"] = alias;
            ops.Add(o2);
        }
        return new JsonObject
        {
            ["format"] = "willage-vpmg-operace-dev-v1",
            ["poznamka"] = "GENEROVÁNO nástrojem Willage.Vpmg.Nastroj (příkaz parametry) z připnutého Willage_Dev – needitovat ručně. Typy = registr Dev, parametry = rozbor zdrojů operací (VpmgStepParams.Get*, Params.TryGetValue, VisualProfile.*). vychozi \"\" = výchozí hodnotu bere Dev z profilu (vychoziDev).",
            ["devCommit"] = PinDev.Commit,
            ["operace"] = ops,
        };
    }
}
