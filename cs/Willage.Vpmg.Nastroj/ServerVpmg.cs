using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.World.Vpmg.Recipe;

namespace Willage.Vpmg.Nastroj;

/// <summary>
/// Režim server: jeden JSON objekt na řádek ze stdin → jeden JSON objekt na řádek na stdout (stejné „id“).
/// Příkazy: info, golden, katalog {zrcadlo}, kanon {receptura}, spust {receptura | materialId, seed, navrh?, rozliseni?}, konec.
/// Chyba (neznámá operace, chybný JSON …) = {"ok":false,"chyba":…}, proces běží dál.
/// </summary>
public sealed class ServerVpmg
{
    static readonly JsonSerializerOptions Jo = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
    static readonly JsonSerializerOptions Ven = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
    readonly PrikazyVpmg _p;
    public ServerVpmg(PrikazyVpmg p) => _p = p;

    public void Bez(TextReader vstup, TextWriter vystup)
    {
        string? radek;
        while ((radek = vstup.ReadLine()) != null)
        {
            if (radek.Length == 0) continue;
            var o = Zpracuj(radek, out bool konec);
            vystup.WriteLine(o.ToJsonString(Ven));
            vystup.Flush();
            if (konec) break;
        }
    }

    public JsonObject Zpracuj(string radek, out bool konec)
    {
        konec = false;
        JsonNode? id = null;
        try
        {
            var q = JsonNode.Parse(radek)!.AsObject();
            id = q["id"]?.DeepClone();
            string prikaz = (string?)q["prikaz"] ?? "";
            var o = prikaz switch
            {
                "info" => Info(),
                "golden" => Golden(),
                "katalog" => Katalog((string)q["zrcadlo"]!),
                "kanon" => new JsonObject { ["receptura"] = VpmgRecipeJson.ToJson(VpmgRecipeJson.Parse((string)q["receptura"]!)) },
                "spust" => Spust(q),
                "konec" => new JsonObject(),
                _ => throw new ArgumentException($"neznámý příkaz '{prikaz}'"),
            };
            konec = prikaz == "konec";
            o["ok"] = true; o["id"] = id;
            return o;
        }
        catch (Exception e)
        {
            return new JsonObject { ["ok"] = false, ["id"] = id, ["chyba"] = $"{e.GetType().Name}: {e.Message}" };
        }
    }

    public JsonObject Info() => new()
    {
        ["nastroj"] = "Willage.Vpmg.Nastroj",
        ["devCommit"] = PinDev.Commit,
        ["katalog"] = _p.ZdrojKatalogu,
        ["materialu"] = _p.Katalog.All.Count,
        ["operace"] = new JsonArray(_p.Operace().Select(x => (JsonNode)x).ToArray()),
        ["runtime"] = Environment.Version.ToString(),
    };

    JsonObject Golden()
    {
        var (oc, sp) = _p.Golden();
        return new JsonObject { ["ocekavany"] = oc, ["spocteny"] = sp, ["shoda"] = oc == sp };
    }

    static JsonObject Katalog(string zrcadlo)
    {
        var k = PrikazyVpmg.KontrolaZrcadla(zrcadlo);
        return new JsonObject { ["bajtyBezKonce"] = k.BajtyBezKonce, ["zaznamy"] = k.Zaznamy, ["pocet"] = k.Pocet, ["pocetDev"] = k.PocetDev, ["rozdil"] = k.Rozdil };
    }

    JsonObject Spust(JsonObject q)
    {
        var r = q["receptura"] is { } rj ? VpmgRecipeJson.Parse((string)rj!) : PrikazyVpmg.Vychozi((byte)(int)q["materialId"]!, (int?)q["rozliseni"] ?? 64);
        uint seed = (uint)q["seed"]!;
        var navrh = q["navrh"] is JsonObject n ? n.Deserialize<NavrhProfilu>(Jo) : null;
        var b = _p.Spust(r, seed, navrh);
        return new JsonObject
        {
            ["sirka"] = b.Vrstva.Width, ["vyska"] = b.Vrstva.Height, ["vrstva"] = b.Vrstva.LayerId,
            ["checksum"] = b.Checksum, ["ms"] = Math.Round(b.Ms, 3), ["rgba"] = Convert.ToBase64String(b.Vrstva.Pixels),
        };
    }
}
