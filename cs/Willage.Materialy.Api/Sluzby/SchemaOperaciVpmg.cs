using System.Text.Json;
using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>
/// T-2c: schéma operací VPMG pro konfigurátor = <b>generovaný</b> popis z Dev (data/vpmg/operace_dev_v1.json, nástroj „parametry“
/// = deskriptory Dev VpmgOperationCatalog / --describe-ops) + klientský překryv (data/vpmg/operace_vpmg_v1.json: české názvy, jednotky,
/// pole profilu čtená mimo výchozí hodnoty, zástupné návrhy pro backend). Typy, parametry, rozsahy a výchozí hodnoty jsou vždy z Dev.
/// </summary>
public sealed class SchemaOperaciVpmg
{
    public IReadOnlyList<OperaceVpmgDto> VsechnyOperace { get; }
    public IReadOnlyList<ParametrVpmgDto> Profil { get; }
    /// <summary>Commit Dev, ze kterého je generovaný popis.</summary>
    public string DevCommit { get; }
    /// <summary>Commit Dev, pro který je psaný překryv.</summary>
    public string PrekryvCommit { get; }
    public int RozliseniMin { get; }
    public int RozliseniMax { get; }
    public int RozliseniVychozi { get; }
    /// <summary>Nesoulad překryvu s Dev (operace / parametr, který Dev nezná) – má být prázdný (test).</summary>
    public IReadOnlyList<string> Nesoulad { get; }

    public SchemaOperaciVpmg(string cestaPrekryvu, string cestaDev)
    {
        using var pd = JsonDocument.Parse(File.ReadAllText(cestaPrekryvu));
        using var dd = JsonDocument.Parse(File.ReadAllText(cestaDev));
        var r = pd.RootElement; var dev = dd.RootElement;
        DevCommit = dev.GetProperty("devCommit").GetString() ?? "";
        PrekryvCommit = r.GetProperty("devCommit").GetString() ?? "";
        var roz = r.GetProperty("rozliseni");
        RozliseniMin = roz.GetProperty("min").GetInt32(); RozliseniMax = roz.GetProperty("max").GetInt32(); RozliseniVychozi = roz.GetProperty("vychozi").GetInt32();
        Profil = r.GetProperty("profil").EnumerateArray().Select(p => new ParametrVpmgDto(
            p.GetProperty("nazev").GetString()!, Enum.Parse<DruhParametruVpmg>(p.GetProperty("druh").GetString()!, true), "",
            Str(p, "popis"), new List<string>(), Int(p, "min"), Int(p, "max"), Str(p, "jednotka"))).ToList();

        var prekryv = r.GetProperty("operace").EnumerateArray().ToDictionary(o => o.GetProperty("type").GetString()!, o => o.Clone(), StringComparer.Ordinal);
        var nes = new List<string>();
        var ops = new List<OperaceVpmgDto>();
        foreach (var o in dev.GetProperty("operace").EnumerateArray())
        {
            string type = o.GetProperty("type").GetString()!;
            JsonElement? pr = prekryv.TryGetValue(type, out var x) ? x : null;
            JsonElement? prp = pr is { } p0 && p0.TryGetProperty("params", out var pp) ? pp : null;
            var par = o.GetProperty("params").EnumerateArray().Select(dp =>
            {
                string n = dp.GetProperty("nazev").GetString()!;
                JsonElement? po = prp is { } q && q.TryGetProperty(n, out var qq) ? qq : null;
                string vd = Str(dp, "vychoziDev");
                string popis = po is { } a && Str(a, "popis") != "" ? Str(a, "popis") : Str(dp, "popisDev");
                if (Str(dp, "vychozi") == "") popis = (popis == "" ? "" : popis + "; ") + $"prázdné = výchozí Dev: {vd}";
                return new ParametrVpmgDto(n, Enum.Parse<DruhParametruVpmg>(dp.GetProperty("druh").GetString()!, true), Str(dp, "vychozi"), popis,
                    new List<string>(), Int(dp, "min") ?? (po is { } b ? Int(b, "min") : null), Int(dp, "max") ?? (po is { } c ? Int(c, "max") : null), po is { } e ? Str(e, "jednotka") : "", vd, po is null);
            }).ToList();
            if (prp is { } pm)
                foreach (var q2 in pm.EnumerateObject())
                    foreach (var mm in new[] { "min", "max" })
                        if (q2.Value.TryGetProperty(mm, out var mv) && o.GetProperty("params").EnumerateArray().FirstOrDefault(x => x.GetProperty("nazev").GetString() == q2.Name) is { ValueKind: JsonValueKind.Object } dx
                            && Int(dx, mm) is { } dvm && dvm != mv.GetInt32())
                            nes.Add($"překryv: '{type}.{q2.Name}' {mm} {mv.GetInt32()} ≠ Dev {dvm}");
            var ctiP = o.GetProperty("ctiProfil").EnumerateArray().Select(c => c.GetString()!)
                .Concat(pr is { } cp0 && cp0.TryGetProperty("ctiProfil", out var cpp) ? cpp.EnumerateArray().Select(c => c.GetString()!) : Array.Empty<string>())
                .Distinct().OrderBy(c => c, StringComparer.Ordinal).ToList();
            foreach (var c in ctiP.Where(c => Profil.All(p2 => p2.Nazev != c))) nes.Add($"'{type}': ctiProfil '{c}' není pole profilu");
            if (prp is { } pq)
                foreach (var n in pq.EnumerateObject().Select(p => p.Name).Where(n => par.All(p => p.Nazev != n)))
                    nes.Add($"překryv: operace '{type}' parametr '{n}' Dev nečte");
            if (pr is { } z && z.TryGetProperty("zastupna", out var zz) && zz.GetBoolean()) nes.Add($"překryv: '{type}' je označená zástupná, ale Dev ji má v registru");
            ops.Add(new OperaceVpmgDto(type, pr is { } n1 ? Str(n1, "nazev") : type, pr is { } s1 ? Str(s1, "skupina") : "Dev (bez popisu klienta)",
                pr is { } d1 ? Str(d1, "popis") : Str(o, "popisDev") is var pd0 && pd0 != "" ? pd0 : "operace z registru Dev bez popisu v překryvu", false, par,
                ctiP, o.TryGetProperty("aliasOf", out var al) ? al.GetString() : null, Str(o, "trida")));
        }
        foreach (var (type, p) in prekryv)
        {
            bool zast = p.TryGetProperty("zastupna", out var z) && z.GetBoolean();
            if (ops.Any(o => o.Type == type)) continue;
            if (!zast) { nes.Add($"překryv: operace '{type}' v registru Dev není"); continue; }
            ops.Add(new OperaceVpmgDto(type, Str(p, "nazev"), Str(p, "skupina"), Str(p, "popis"), true, new List<ParametrVpmgDto>(), new List<string>()));
        }
        // pořadí: podle překryvu (čitelná nabídka), Dev operace bez překryvu na konec
        var poradi = prekryv.Keys.ToList();
        VsechnyOperace = ops.OrderBy(o => poradi.IndexOf(o.Type) is var i && i < 0 ? int.MaxValue : i).ThenBy(o => o.Type, StringComparer.Ordinal).ToList();
        Nesoulad = nes;
    }

    static string Str(JsonElement e, string k) => e.TryGetProperty(k, out var v) ? v.GetString() ?? "" : "";
    static int? Int(JsonElement e, string k) => e.TryGetProperty(k, out var v) ? v.GetInt32() : null;

    public OperaceVpmgDto? Operace(string type) => VsechnyOperace.FirstOrDefault(o => o.Type == type);
    public IReadOnlyList<OperaceVpmgDto> Spustitelne => VsechnyOperace.Where(o => !o.Zastupna).ToList();
    public IReadOnlyList<OperaceVpmgDto> Zastupne => VsechnyOperace.Where(o => o.Zastupna).ToList();
}
