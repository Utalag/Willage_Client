using System.Reflection;
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
/// G-2: schéma všech laditelných parametrů modulů M0–M7 sestavené z kódu (reflexe: pole ParametrySveta, init vlastnosti
/// ParametryEroze / ParametryKlimatu / ParametryVody, tabulka prusak_v1.json) a doplněné o <see cref="MetadataParametru"/>.
/// Výchozí hodnota = dnešní účinná hodnota (soubory v data/v1 přes <see cref="SadaParametru.ZDat"/>), VychoziKod = výchozí C#.
/// </summary>
public sealed class SchemaParametru
{
    public const string Format = "willage-schema-parametru-v1";
    internal static readonly JsonSerializerOptions O = new() { IncludeFields = true, WriteIndented = true };

    public IReadOnlyList<ParametrSchematu> Parametry { get; }
    private readonly Dictionary<string, ParametrSchematu> _podle;

    public SchemaParametru(IEnumerable<ParametrSchematu> p)
    {
        Parametry = p.ToList();
        _podle = Parametry.ToDictionary(x => x.Id, StringComparer.Ordinal);
    }

    public ParametrSchematu this[string id] => _podle[id];
    public bool Obsahuje(string id) => _podle.ContainsKey(id);
    public IEnumerable<ParametrSchematu> Modulu(string modul) => Parametry.Where(p => p.Modul == modul);

    /// <summary>Zdroje parametrů: název, typ v kódu, vlastník a soubor.</summary>
    public static readonly (string zdroj, Type typ, string? soubor)[] Zdroje =
    {
        ("ParametrySveta", typeof(ParametrySveta), null),
        ("ParametryEroze", typeof(ParametryEroze), "v1/eroze_v1.json"),
        ("ParametryKlimatu", typeof(ParametryKlimatu), "v1/klima_v1.json"),
        ("ParametryVody", typeof(ParametryVody), "v1/voda_v1.json"),
    };

    /// <summary>Členy zdroje, které schéma pokrývá: veřejná pole instance (ParametrySveta) nebo vlastnosti s init/set.</summary>
    public static IEnumerable<MemberInfo> Cleny(Type t) => t == typeof(ParametrySveta)
        ? t.GetFields(BindingFlags.Public | BindingFlags.Instance)
        : t.GetProperties(BindingFlags.Public | BindingFlags.Instance).Where(p => p.CanWrite);

    public static Type TypClenu(MemberInfo m) => m is FieldInfo f ? f.FieldType : ((PropertyInfo)m).PropertyType;
    public static object? Hodnota(MemberInfo m, object o) => m is FieldInfo f ? f.GetValue(o) : ((PropertyInfo)m).GetValue(o);

    /// <summary>Modul, kterému člen patří (RozdeleniParametru pro ParametrySveta, jinak vlastník zdroje).</summary>
    public static string ModulClenu(string zdroj, string nazev) => zdroj switch
    {
        "ParametrySveta" => RozdeleniParametru.Vse.Single(kv => kv.Value.Contains(nazev)).Key,
        "ParametryEroze" => "M4",
        "ParametryKlimatu" => RozdeleniParametru.KlimaProM6.Contains(nazev) ? "M6" : "M5",
        _ => "M6",
    };

    static TypParametru Typ(Type t, bool volby) =>
        t == typeof(bool) ? TypParametru.Logicky
        : t == typeof(int) || t == typeof(long) || t == typeof(uint) ? TypParametru.Cele
        : t == typeof(double) || t == typeof(float) ? TypParametru.Desetinne
        : t == typeof(string) ? (volby ? TypParametru.Volba : TypParametru.Text)
        : t == typeof(double[]) || t == typeof(int[]) ? TypParametru.Pole
        : TypParametru.Tabulka;

    static string Skupina(string zdroj, string nazev) =>
        MetadataParametru.Skupiny.TryGetValue(zdroj, out var sk) ? sk.Where(s => s.nazvy.Contains(nazev)).Select(s => s.skupina).SingleOrDefault() ?? "" : "";

    /// <summary>Sestaví schéma z kódu, metadat a dnešních dat (výchozí = účinné hodnoty po načtení souborů).</summary>
    public static SchemaParametru Sestav(DataSveta d)
    {
        var vych = SadaParametru.ZDat(d);
        var kod = SadaParametru.ZKodu();
        var l = new List<ParametrSchematu>();
        foreach (var (zdroj, typ, soubor) in Zdroje)
        foreach (var m in Cleny(typ))
        {
            string id = zdroj + "." + m.Name; var t = TypClenu(m);
            MetadataParametru.Volby.TryGetValue(id, out var volby);
            if (id == "ParametrySveta.Klima") volby = IdPresetuKlimatu(d);
            var tp = Typ(t, volby is not null);
            object? v0 = Hodnota(m, kod.Objekt(zdroj));
            var r = tp is TypParametru.Cele or TypParametru.Desetinne
                ? (MetadataParametru.Rozsahy.TryGetValue(id, out var rr) ? rr : MetadataParametru.Odvozeni.Rozsah(m.Name, v0)) : null;
            MetadataParametru.JenCteni.TryGetValue(id, out var jc);
            string? soub = zdroj == "ParametrySveta" ? (RozdeleniParametru.M2.Contains(m.Name) ? "v1/more_v1.json" : null) : soubor;
            l.Add(new ParametrSchematu
            {
                Id = id, Modul = ModulClenu(zdroj, m.Name), Zdroj = zdroj, Nazev = m.Name, Skupina = Skupina(zdroj, m.Name),
                Typ = tp, TypKodu = t.Name, Vychozi = vych.Hodnota(id), VychoziKod = kod.Hodnota(id),
                Min = r?.Min, Max = r?.Max, Krok = r?.Krok ?? (tp == TypParametru.Cele ? 1 : null), RozsahZdroj = r?.Zdroj ?? "",
                Jednotka = tp is TypParametru.Cele or TypParametru.Desetinne or TypParametru.Pole ? MetadataParametru.Odvozeni.Jednotka(m.Name) : "",
                Volby = volby, Soubor = soub, JenCteni = jc is not null, Poznamka = jc,
            });
        }
        l.Add(new ParametrSchematu
        {
            Id = "prusak_v1.json.Tabulka", Modul = "M6", Zdroj = "prusak_v1.json", Nazev = "Tabulka", Skupina = "Koeficient průsaku",
            Typ = TypParametru.Tabulka, TypKodu = "JSON", Vychozi = vych.Hodnota("prusak_v1.json.Tabulka"), VychoziKod = null, RozsahZdroj = "",
            Soubor = "v1/prusak_v1.json", Poznamka = "koeficient průsaku 0–255 podle K a výjimky materiálů (PrusakKoeficient)",
        });
        return new SchemaParametru(l);
    }

    /// <summary>Id presetů z klima_presety.csv (první sloupec, bez komentářů a hlavičky).</summary>
    public static string[] IdPresetuKlimatu(DataSveta d) => File.ReadLines(d.KlimaPresety)
        .Where(r => r.Length > 0 && r[0] != '#').Skip(1).Select(r => r.Split(',')[0].Trim()).Where(x => x.Length > 0).ToArray();

    public string ToJson() => JsonSerializer.Serialize(new { format = Format, parametru = Parametry.Count, parametry = Parametry }, O) + "\n";

    public static SchemaParametru ZJson(string json)
    {
        var n = JsonNode.Parse(json)!;
        if ((string?)n["format"] != Format) throw new FormatException("neznámý formát schématu");
        return new SchemaParametru(n["parametry"]!.Deserialize<List<ParametrSchematu>>(O)!);
    }
}
