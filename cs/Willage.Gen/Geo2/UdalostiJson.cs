using System.Text.Json;

namespace Willage.Gen.Geo2;

/// <summary>Jedna událost tak, jak je v datech (kontrakt 06, kap. 1.2, 2.7). Bez výkladu: ten dělá <see cref="KompilatorChronologie"/>.</summary>
public sealed record UdalostData(
    string Id, int? Stari, string? OperaceText, bool Aktivni, string? TvarDruh,
    JsonElement Tvar, JsonElement Vyskyt, JsonElement Pravidla, JsonElement Vysledek, string? SourozenciText,
    IReadOnlyList<string> NeznameKlice, int Poradi);

/// <summary>Obsah <c>udalosti_v2.json</c>: konfigurace, globální <c>nikdy</c>, události (pořadí v souboru nemá význam).</summary>
public sealed record SadaUdalosti(string Schema, int Verze, KonfiguraceGeo2 Konfigurace, IReadOnlyList<string> Nikdy,
    IReadOnlyList<UdalostData> Udalosti, ZpravaValidace Zprava);

/// <summary>Čtyři samostatné parametry (O3). Výchozí 0,125 m; změna jednoho nemění ostatní ani geometrii.</summary>
public sealed record KonfiguraceGeo2(
    double MinTloustkaDetekceM = 0.125, double TolerancKontaktuM = 0.125, double TauM = 0.125, double VyskaDetailnihoVoxeluM = 0.125);

public static class UdalostiJson
{
    public const string Schema = "willage.udalosti.v2";
    private static readonly HashSet<string> KliceUdalosti = new(StringComparer.Ordinal)
        { "id", "stari", "operace", "aktivni", "tvar", "vyskyt", "pravidla", "vysledek", "sourozenci" };
    private static readonly HashSet<string> KliceKorene = new(StringComparer.Ordinal) { "schema", "verze", "konfigurace", "nikdy", "udalosti" };
    private static readonly HashSet<string> KliceKonfigurace = new(StringComparer.Ordinal)
        { "minTloustkaDetekce_m", "tolerancKontaktu_m", "tau_m", "vyskaDetailnihoVoxelu_m" };

    public static SadaUdalosti Nacti(string json)
    {
        var z = new ZpravaValidace();
        using var doc = JsonDocument.Parse(json, new JsonDocumentOptions { CommentHandling = JsonCommentHandling.Skip });
        var r = doc.RootElement;
        foreach (var p in r.EnumerateObject()) if (!KliceKorene.Contains(p.Name)) z.Chyba("NEZNAMY_KLIC", null, $"kořen: {p.Name}");
        string schema = r.TryGetProperty("schema", out var s) ? s.GetString() ?? "" : "";
        if (schema != Schema) z.Chyba("SCHEMA", null, $"očekáváno {Schema}, je {schema}");
        int verze = r.TryGetProperty("verze", out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt32() : 0;

        var kf = new KonfiguraceGeo2();
        if (r.TryGetProperty("konfigurace", out var k))
        {
            foreach (var p in k.EnumerateObject())
            {
                if (!KliceKonfigurace.Contains(p.Name)) { z.Chyba("NEZNAMY_KLIC", null, $"konfigurace: {p.Name}"); continue; }
                if (p.Value.ValueKind != JsonValueKind.Number || p.Value.GetDouble() <= 0) { z.Chyba("KONFIGURACE", null, $"{p.Name} musí být kladné číslo"); continue; }
                double d = p.Value.GetDouble();
                kf = p.Name switch
                {
                    "minTloustkaDetekce_m" => kf with { MinTloustkaDetekceM = d },
                    "tolerancKontaktu_m" => kf with { TolerancKontaktuM = d },
                    "tau_m" => kf with { TauM = d },
                    _ => kf with { VyskaDetailnihoVoxeluM = d },
                };
            }
        }
        var nikdy = new List<string>();
        if (r.TryGetProperty("nikdy", out var n)) foreach (var e in n.EnumerateArray()) nikdy.Add(e.GetString() ?? "");

        var ud = new List<UdalostData>();
        if (!r.TryGetProperty("udalosti", out var ua) || ua.ValueKind != JsonValueKind.Array) z.Chyba("BEZ_UDALOSTI", null, "chybí pole udalosti");
        else
        {
            int i = 0;
            foreach (var e in ua.EnumerateArray()) ud.Add(NactiUdalost(e, i++));
        }
        return new SadaUdalosti(schema, verze, kf, nikdy, ud, z);
    }

    /// <summary>Pole událostí bez kořene (pohodlí pro testy a příklad z kontraktu 2.7).</summary>
    public static SadaUdalosti NactiPole(string jsonPole, IEnumerable<string>? nikdy = null, KonfiguraceGeo2? konfigurace = null)
    {
        var nik = JsonSerializer.Serialize((nikdy ?? Array.Empty<string>()).ToArray());
        var sada = Nacti($$"""{"schema":"{{Schema}}","verze":3,"nikdy":{{nik}},"udalosti":{{jsonPole}}}""");
        return konfigurace is null ? sada : sada with { Konfigurace = konfigurace };
    }

    private static UdalostData NactiUdalost(JsonElement e, int poradi)
    {
        var nezname = e.EnumerateObject().Select(p => p.Name).Where(x => !KliceUdalosti.Contains(x)).ToList();
        JsonElement Obj(string k) => e.TryGetProperty(k, out var x) ? x.Clone() : default;
        string id = e.TryGetProperty("id", out var i) ? i.GetString() ?? "" : "";
        int? stari = e.TryGetProperty("stari", out var st) && st.ValueKind == JsonValueKind.Number && st.TryGetInt32(out var si) ? si : null;
        string? op = e.TryGetProperty("operace", out var o) ? o.GetString() : null;
        bool akt = !e.TryGetProperty("aktivni", out var a) || a.ValueKind != JsonValueKind.False;
        var tvar = Obj("tvar");
        string? druh = tvar.ValueKind == JsonValueKind.Object && tvar.TryGetProperty("druh", out var d) ? d.GetString() : null;
        string? sour = e.TryGetProperty("sourozenci", out var so) ? so.GetString() : null;
        return new UdalostData(id, stari, op, akt, druh, tvar, Obj("vyskyt"), Obj("pravidla"), Obj("vysledek"), sour, nezname, poradi);
    }
}
