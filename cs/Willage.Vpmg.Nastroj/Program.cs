using System.Text.Json.Nodes;
using Willage.Vpmg.Nastroj;
using Willage.World.Vpmg.Export.Png;
using Willage.World.Vpmg.Recipe;

// T-1: nástroj VPMG nad připnutým Willage_Dev. Použití:
//   info | golden | goldeny | parametry [vystup.json] | katalog <zrcadlo.json> | kanon <receptura.json>
//   spust <materialId|receptura.json> <seed> <vystup.png> [--navrh '{"baseColor":"#aabbcc"}']
//   server            (JSON řádky stdin/stdout, viz ServerVpmg)
// Volba --katalog <cesta> (před příkazem) = katalog ze zrcadla klienta místo embedded katalogu Dev.
var a = args.ToList();
string? katalog = null;
int ki = a.IndexOf("--katalog");
if (ki >= 0) { katalog = a[ki + 1]; a.RemoveRange(ki, 2); }
if (a.Count == 0) { Console.Error.WriteLine("Použití: info | golden | katalog <zrcadlo> | kanon <receptura> | spust <material|receptura> <seed> <png> | server"); return 2; }

var p = new PrikazyVpmg(katalog);
var s = new ServerVpmg(p);
switch (a[0])
{
    case "info":
        Console.WriteLine(s.Info().ToJsonString());
        return 0;
    case "golden":
    {
        var (oc, sp) = p.Golden();
        Console.WriteLine($"golden Dev {PinDev.Commit[..7]}: očekávaný {oc}, spočtený {sp} → {(oc == sp ? "SHODA" : "ROZDÍL")}");
        return oc == sp ? 0 : 1;
    }
    case "goldeny":
    {
        var g = p.GoldenyReceptur();
        foreach (var x in g) Console.WriteLine($"{x.Soubor}: očekávaný {x.Ocekavany}, spočtený {x.Spocteny} → {(x.Ocekavany == x.Spocteny ? "SHODA" : "ROZDÍL")}");
        return g.All(x => x.Ocekavany == x.Spocteny) ? 0 : 1;
    }
    case "parametry":
    {
        string j = ParametryDev.Rozbor(p).ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }) + "\n";
        if (a.Count > 1) File.WriteAllText(a[1], j); else Console.Write(j);
        return 0;
    }
    case "katalog":
    {
        var k = PrikazyVpmg.KontrolaZrcadla(a[1]);
        Console.WriteLine($"zrcadlo {a[1]}: bajty bez konce {(k.BajtyBezKonce ? "=" : "≠")} Dev, záznamy {(k.Zaznamy ? "=" : "≠")} ({k.Pocet}/{k.PocetDev}), rozdíl: {k.Rozdil}");
        return k.BajtyBezKonce && k.Zaznamy ? 0 : 1;
    }
    case "kanon":
        Console.Write(VpmgRecipeJson.ToJson(VpmgRecipeJson.Parse(File.ReadAllText(a[1]))));
        return 0;
    case "spust":
    {
        var r = File.Exists(a[1]) ? VpmgRecipeJson.Parse(File.ReadAllText(a[1])) : PrikazyVpmg.Vychozi(byte.Parse(a[1]));
        uint seed = a[2].StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? Convert.ToUInt32(a[2], 16) : uint.Parse(a[2]);
        int ni = a.IndexOf("--navrh");
        var navrh = ni >= 0 ? System.Text.Json.JsonSerializer.Deserialize<NavrhProfilu>(a[ni + 1], new System.Text.Json.JsonSerializerOptions { PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase }) : null;
        var b = p.Spust(r, seed, navrh);
        using (var f = File.Create(a[3])) RgbaPngWriter.Write(b.Vrstva, f);
        Console.WriteLine($"{a[3]}: {b.Vrstva.Width}×{b.Vrstva.Height}, checksum {b.Checksum}, {b.Ms:F2} ms");
        return 0;
    }
    case "server":
        s.Bez(Console.In, Console.Out);
        return 0;
    default:
        Console.Error.WriteLine("neznámý příkaz " + a[0]);
        return 2;
}
