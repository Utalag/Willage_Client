using System.Text.Json;
using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>
/// Popis operací VPMG pro konfigurátor (data/vpmg/operace_vpmg_v0.json). Dev schéma parametrů nemá (operace čtou params ad hoc),
/// proto je popis náš; test T-1 hlídá, že nezástupné operace = registr Dev. Zástupné operace = návrhy pro Willage-backend.
/// </summary>
public sealed class SchemaOperaciVpmg
{
    public IReadOnlyList<OperaceVpmgDto> VsechnyOperace { get; }
    public IReadOnlyList<ParametrVpmgDto> Profil { get; }
    public string DevCommit { get; }
    public int RozliseniMin { get; }
    public int RozliseniMax { get; }
    public int RozliseniVychozi { get; }

    public SchemaOperaciVpmg(string cesta)
    {
        using var d = JsonDocument.Parse(File.ReadAllText(cesta));
        var r = d.RootElement;
        DevCommit = r.GetProperty("devCommit").GetString() ?? "";
        var roz = r.GetProperty("rozliseni");
        RozliseniMin = roz.GetProperty("min").GetInt32(); RozliseniMax = roz.GetProperty("max").GetInt32(); RozliseniVychozi = roz.GetProperty("vychozi").GetInt32();
        VsechnyOperace = r.GetProperty("operace").EnumerateArray().Select(o => new OperaceVpmgDto(
            o.GetProperty("type").GetString()!, o.GetProperty("nazev").GetString()!, o.GetProperty("skupina").GetString()!, o.GetProperty("popis").GetString()!,
            o.TryGetProperty("zastupna", out var z) && z.GetBoolean(),
            o.GetProperty("params").EnumerateArray().Select(Parametr).ToList(),
            o.TryGetProperty("ctiProfil", out var cp) ? cp.EnumerateArray().Select(x => x.GetString()!).ToList() : new List<string>())).ToList();
        Profil = r.GetProperty("profil").EnumerateArray().Select(Parametr).ToList();
    }

    static ParametrVpmgDto Parametr(JsonElement p) => new(
        p.GetProperty("nazev").GetString()!,
        Enum.Parse<DruhParametruVpmg>(p.GetProperty("druh").GetString()!, true),
        p.TryGetProperty("vychozi", out var v) ? v.GetString() ?? "" : "",
        p.TryGetProperty("popis", out var po) ? po.GetString() ?? "" : "",
        p.TryGetProperty("moznosti", out var m) ? m.EnumerateArray().Select(x => x.GetString()!).ToList() : new List<string>(),
        p.TryGetProperty("min", out var mi) ? mi.GetInt32() : null,
        p.TryGetProperty("max", out var ma) ? ma.GetInt32() : null,
        p.TryGetProperty("jednotka", out var j) ? j.GetString() ?? "" : "");

    public OperaceVpmgDto? Operace(string type) => VsechnyOperace.FirstOrDefault(o => o.Type == type);
    public IReadOnlyList<OperaceVpmgDto> Spustitelne => VsechnyOperace.Where(o => !o.Zastupna).ToList();
    public IReadOnlyList<OperaceVpmgDto> Zastupne => VsechnyOperace.Where(o => o.Zastupna).ToList();
}
