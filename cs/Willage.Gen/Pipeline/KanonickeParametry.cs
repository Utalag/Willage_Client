using System.Reflection;
using System.Text;
using System.Text.Json;
using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline;

/// <summary>Kanonický text vybraných polí ParametrySveta (řazeno ordinálně, hodnoty JSON) – vstup klíče modulu.</summary>
public static class KanonickeParametry
{
    private static readonly JsonSerializerOptions O = new() { IncludeFields = true };

    public static string Pole(ParametrySveta p, IEnumerable<string> nazvy)
    {
        var t = typeof(ParametrySveta); var sb = new StringBuilder();
        foreach (var n in nazvy.OrderBy(x => x, StringComparer.Ordinal))
        {
            var f = t.GetField(n, BindingFlags.Public | BindingFlags.Instance) ?? throw new ArgumentException("ParametrySveta nemá pole " + n);
            sb.Append(n).Append('=').Append(JsonSerializer.Serialize(f.GetValue(p), f.FieldType, O)).Append(';');
        }
        return sb.ToString();
    }

    public static string Json<T>(T o) => JsonSerializer.Serialize(o, O);

    /// <summary>Kanonický JSON vybraných vlastností objektu (řazeno ordinálně).</summary>
    public static string Vlastnosti(object o, IEnumerable<string> nazvy)
    {
        var t = o.GetType(); var sb = new StringBuilder();
        foreach (var n in nazvy.OrderBy(x => x, StringComparer.Ordinal))
        {
            var pr = t.GetProperty(n) ?? throw new ArgumentException($"{t.Name} nemá vlastnost {n}");
            sb.Append(n).Append('=').Append(JsonSerializer.Serialize(pr.GetValue(o), pr.PropertyType, O)).Append(';');
        }
        return sb.ToString();
    }

    /// <summary>Kopie recordu (přes JSON) s vybranými vlastnostmi vrácenými na výchozí hodnotu.</summary>
    public static T BezVlastnosti<T>(T o, IEnumerable<string> nazvy) where T : class, new()
    {
        var n = System.Text.Json.Nodes.JsonNode.Parse(JsonSerializer.Serialize(o, O))!.AsObject();
        var v = System.Text.Json.Nodes.JsonNode.Parse(JsonSerializer.Serialize(new T(), O))!.AsObject();
        foreach (var x in nazvy) n[x] = v[x]?.DeepClone();
        return n.Deserialize<T>(O)!;
    }
}

/// <summary>
/// Které pole ParametrySveta patří kterému modulu (každé právě jednomu – hlídá test). Pole moře (M2) se přepisují z more_v1.json
/// (ErozePlanety.NactiMore), proto klíč M2 bere efektivní hodnoty po načtení i SHA souboru.
/// </summary>
public static class RozdeleniParametru
{
    public static readonly string[] M0 = { "Seed", "BlokM", "SloupecM", "SvetMaxM", "StartBlok", "Klima", "More", "Panve", "VseKrok06", "KlimaKrok07" };

    public static readonly string[] M1 =
    {
        "KlimaMapaRoztecM", "KlimaMapaPrechodM", "KlimaMapaSila", "BiomRoztecM", "BiomPrechodM", "BiomVelkeOblasti", "Podil", "Biomy", "Oktav", "RezervaSklonu",
        "HorninyRoztecM", "HorninyPrechodM", "Zastupcu", "HorninyBiomu",
        "MasivM0", "MasivM1", "MasivZdvihM", "P87AmpM", "P87Freq", "P87DetailM", "P87Dfreq", "MasivPodilStropu", "MasivPodilDetail", "DetailMaxM", "PodhuriM", "PodhuriVlnaM",
        "Sopek", "SopkyRoztecM", "SopkyRoztecTol", "SopkaVyskaMinM", "SopkaVyskaMaxM", "SopkaSklonDeg", "SopkaGamma", "SopkaStropDeg", "KraterRPodil",
        "KraterHloubkaPodil", "SopkaRezervaM", "SopkyOkrajM", "SopkaOdOkrajeStartuM", "StropPovrchuHladkostM", "KlimaKHorniny", "KlimaKVoda",
    };

    public static readonly string[] M2 =
    {
        "PlanetaXM", "PlanetaYM", "PodilMore", "OdchylkaMoreProcBodu", "HladinaMoreM", "HloubkaMoreM", "SklonKontinentu", "SklonOdPobreziM",
        "KontinentuMin", "KontinentuMax", "KontinentVelikost", "Clenitost", "ClenitostSila", "SumVln", "WarpVln", "SumLambdaMinM", "SumLambdaMaxM",
        "WarpLambdaMinM", "WarpM", "MorePrechod", "RezervaSevuM", "SevPrechodM", "SevMekkySpad", "SevMekkyPasM",
        "OstrovuPocet", "OstrovPolomerM", "OstrovVyska", "SevZvlneniM", "SevZvlneniLambdaMinM", "SevZvlneniLambdaMaxM",
        "StartPolomerM", "StartPrechodM", "StartRezerva", "MrizkaPrahuM", "MrizkaVzdalenostiM", "PanviPocet", "PanevPolomerM", "PanevHloubkaM",
    };

    public static readonly string[] M3 =
    {
        "P82Vapenec", "P82Podil", "P82PodM", "A1Hostitele", "A10SumHornin", "DomPasmoSedimenty", "SopkaPruduchRM", "SopkaSlupkaM", "SopkaLavaId", "SopkaPopelId",
        "PasmoSpodek", "PasmoKrystalinikum", "PasmoSedimenty", "PasmoSvrchni", "P82PrechodM", "UtvaryKlicGd",
    };

    /// <summary>
    /// G-2: parametry dobití hladiny 7c v ParametryKlimatu (soubor klima_v1.json) patří modulu M6 – klíč M6, ne M5.
    /// (HladinaMoreM v ParametryKlimatu je hladina moře pro klima a zůstává v M5.)
    /// </summary>
    public static readonly string[] KlimaProM6 =
    {
        "HladinaKlimaZapnuta", "HladinaWPrah", "HladinaWPlna", "HladinaSuchoM", "HladinaBrehPlneM", "HladinaBrehDoM",
        "HladinaKorytoPlneM", "HladinaKorytoDoM", "HladinaZdrojPlneM", "HladinaZdrojDoM",
    };

    public static IReadOnlyDictionary<string, string[]> Vse => new Dictionary<string, string[]> { ["M0"] = M0, ["M1"] = M1, ["M2"] = M2, ["M3"] = M3 };
}
