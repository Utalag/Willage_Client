using System.Text.Json.Nodes;
using Willage.Gen.Api.Dto;
using Willage.Gen.Schema;

namespace Willage.Gen.Api.Sluzby;

/// <summary>IModuly nad stavem generátoru a schématem G-2.</summary>
public sealed class ModulyApi : IModuly
{
    readonly StavGeneratoru _s;
    public ModulyApi(StavGeneratoru s) => _s = s;

    public IReadOnlyList<ModulDto> Seznam() => _s.Moduly();

    public IReadOnlyList<ParametrDto> Parametry(string modul) => _s.Schema.Modulu(modul).Select(Dto).ToList();

    ParametrDto Dto(ParametrSchematu p) => new(p.Id, p.Modul, p.Skupina, p.Typ.ToString(), _s.Sada.Hodnota(p.Id)?.ToJsonString() ?? "null",
        p.Vychozi?.ToJsonString() ?? "null", p.Min, p.Max, p.Krok, p.Jednotka, p.Volby, p.JenCteni, p.Poznamka, p.Napoveda);

    public ZmenaParametruDto Nastav(string id, string hodnotaJson)
    {
        if (_s.Potvrzena) return new(false, "planeta je potvrzená – parametry jsou zamčené", Array.Empty<string>());
        if (!_s.Schema.Obsahuje(id)) return new(false, "neznámý parametr " + id, Array.Empty<string>());
        if (_s.Schema[id].JenCteni) return new(false, "jen čtení: " + _s.Schema[id].Poznamka, Array.Empty<string>());
        var pred = _s.Klice();
        try { _s.Sada.Nastav(id, JsonNode.Parse(hodnotaJson)); }
        catch (Exception e) when (e is System.Text.Json.JsonException or FormatException or InvalidOperationException) { return new(false, "špatná hodnota: " + e.Message, Array.Empty<string>()); }
        return new(true, null, Zmenene(pred, _s.Klice()));
    }

    public ZmenaParametruDto Vychozi()
    {
        if (_s.Potvrzena) return new(false, "planeta je potvrzená – parametry jsou zamčené", Array.Empty<string>());
        var pred = _s.Klice();
        _s.Sada = SadaParametru.ZDat(_s.Data);
        return new(true, null, Zmenene(pred, _s.Klice()));
    }

    public ZmenaParametruDto VychoziModulu(string modul)
    {
        if (_s.Potvrzena) return new(false, "planeta je potvrzená – parametry jsou zamčené", Array.Empty<string>());
        var pred = _s.Klice();
        foreach (var p in _s.Schema.Modulu(modul).Where(p => !p.JenCteni))
        {
            var v = p.Vychozi?.ToJsonString() ?? "null";
            if ((_s.Sada.Hodnota(p.Id)?.ToJsonString() ?? "null") != v) _s.Sada.Nastav(p.Id, JsonNode.Parse(v));
        }
        return new(true, null, Zmenene(pred, _s.Klice()));
    }

    static IReadOnlyList<string> Zmenene(IReadOnlyDictionary<string, string> a, IReadOnlyDictionary<string, string> b) =>
        a.Keys.Where(k => a[k] != StavGeneratoru.Klic(b, k)).ToList();

    public VysledekGeneraceDto Prepocitej() => _s.Generuj();

    public PrepocetOblastiDto PrepocitejOblast(string modul, OblastQ16 oblast)
    {
        var r = _s.Spust();
        return new(modul, oblast, true, "zástupné (U-2): částečný přepočet oblasti zatím není, přepočetly se neplatné moduly celé", r.Prepocitane);
    }

    public NapovedaDto Napoveda(string id) => new(id, _s.Schema.Obsahuje(id) ? _s.Schema[id].Napoveda : "", true);
}
