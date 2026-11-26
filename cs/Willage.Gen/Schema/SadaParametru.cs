using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.Gen.Data;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Pipeline;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Schema;

/// <summary>
/// G-2: konkrétní hodnoty všech parametrů schématu (co bude konfigurátor G-5 ukládat). Drží vlastní kopie ParametrySveta
/// a NastaveniModulu; <see cref="Sestav"/> z nich udělá vstup pipeline (p + PipelineSveta.Nastaveni).
/// JSON: { format, moduly: { "M0": { "ParametrySveta.Seed": 0, … }, … } } – při načtení stačí jen změněné hodnoty.
/// </summary>
public sealed class SadaParametru
{
    public const string Format = "willage-sada-parametru-v1";
    static readonly JsonSerializerOptions O = SchemaParametru.O;

    ParametrySveta _svet;
    ParametryEroze _eroze;
    ParametryKlimatu _klima;
    ParametryVody _voda;
    string _prusak;

    SadaParametru(ParametrySveta s, NastaveniModulu n)
    {
        _svet = s.Kopie(); _eroze = Klon(n.Eroze); _klima = Klon(n.Klima); _voda = Klon(n.Voda); _prusak = n.PrusakJson;
    }

    static T Klon<T>(T o) => JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(o, O), O)!;

    /// <summary>Výchozí hodnoty v kódu (bez souborů v data/v1; průsak prázdný).</summary>
    public static SadaParametru ZKodu() => new(new ParametrySveta(), new NastaveniModulu());

    /// <summary>Dnešní účinné hodnoty: ParametrySveta + more_v1.json, eroze/klima/voda/průsak z data/v1 (jako pipeline bez sady).</summary>
    public static SadaParametru ZDat(DataSveta d) => new(ErozePlanety.NactiMore(new ParametrySveta(), d), NastaveniModulu.ZDat(d));

    public object Objekt(string zdroj) => zdroj switch
    {
        "ParametrySveta" => _svet, "ParametryEroze" => _eroze, "ParametryKlimatu" => _klima, "ParametryVody" => _voda,
        _ => throw new ArgumentException("neznámý zdroj " + zdroj),
    };

    static (string zdroj, string nazev) Rozloz(string id)
    {
        int i = id.LastIndexOf('.');
        if (i <= 0) throw new ArgumentException("Id parametru musí být Zdroj.Nazev: " + id);
        return (id[..i], id[(i + 1)..]);
    }

    static System.Reflection.MemberInfo Clen(string zdroj, string nazev)
    {
        var t = SchemaParametru.Zdroje.Single(z => z.zdroj == zdroj).typ;
        return SchemaParametru.Cleny(t).SingleOrDefault(m => m.Name == nazev) ?? throw new ArgumentException($"{zdroj} nemá parametr {nazev}");
    }

    public JsonNode? Hodnota(string id)
    {
        var (z, n) = Rozloz(id);
        if (z == "prusak_v1.json") return _prusak.Length == 0 ? null : JsonNode.Parse(_prusak);
        var m = Clen(z, n);
        return JsonSerializer.SerializeToNode(SchemaParametru.Hodnota(m, Objekt(z)), SchemaParametru.TypClenu(m), O);
    }

    /// <summary>Nastaví hodnotu (JSON se převede na typ v kódu; chyba typu = výjimka). Rozsah se nehlídá – je to návrh.</summary>
    public SadaParametru Nastav(string id, JsonNode? hodnota)
    {
        var (z, n) = Rozloz(id);
        if (z == "prusak_v1.json")
        {
            // stejný obsah → ponechat původní text (klíč M6 bere text průsaku, formátování ho nesmí měnit)
            if (!(hodnota is not null && _prusak.Length > 0 && JsonNode.DeepEquals(JsonNode.Parse(_prusak), hodnota)))
                _prusak = hodnota?.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) ?? "";
            return this;
        }
        var m = Clen(z, n);
        object? v = hodnota.Deserialize(SchemaParametru.TypClenu(m), O);
        if (m is System.Reflection.FieldInfo f) f.SetValue(_svet, v);
        else ((System.Reflection.PropertyInfo)m).SetValue(Objekt(z), v);   // init vlastnosti: jen na vlastní kopii sady
        return this;
    }

    public SadaParametru Nastav<T>(string id, T hodnota) => Nastav(id, JsonSerializer.SerializeToNode(hodnota, O));

    /// <summary>Vstup pipeline: kopie ParametrySveta a NastaveniModulu (sada se dalším nastavováním nezmění).</summary>
    public (ParametrySveta svet, NastaveniModulu nastaveni) Sestav() =>
        (_svet.Kopie(), new NastaveniModulu { Eroze = Klon(_eroze), Klima = Klon(_klima), Voda = Klon(_voda), PrusakJson = _prusak });

    public string ToJson(SchemaParametru s)
    {
        var moduly = new JsonObject();
        foreach (var g in s.Parametry.GroupBy(p => p.Modul).OrderBy(g => g.Key, StringComparer.Ordinal))
        {
            var o = new JsonObject();
            foreach (var p in g) o[p.Id] = Hodnota(p.Id)?.DeepClone();
            moduly[g.Key] = o;
        }
        return new JsonObject { ["format"] = Format, ["moduly"] = moduly }.ToJsonString(O) + "\n";
    }

    /// <summary>Načte sadu: začne od <paramref name="zaklad"/> (typicky ZDat) a přepíše uvedené hodnoty. Modul musí sedět se schématem.</summary>
    public static SadaParametru ZJson(string json, SchemaParametru s, SadaParametru zaklad)
    {
        var n = JsonNode.Parse(json)!;
        if ((string?)n["format"] != Format) throw new FormatException("neznámý formát sady parametrů");
        var (sv, ns) = zaklad.Sestav();
        var r = new SadaParametru(sv, ns);
        foreach (var (modul, hodnoty) in n["moduly"]!.AsObject())
        foreach (var (id, v) in hodnoty!.AsObject())
        {
            if (!s.Obsahuje(id)) throw new FormatException("neznámý parametr " + id);
            if (s[id].Modul != modul) throw new FormatException($"{id} patří modulu {s[id].Modul}, ne {modul}");
            r.Nastav(id, v?.DeepClone());
        }
        return r;
    }
}
