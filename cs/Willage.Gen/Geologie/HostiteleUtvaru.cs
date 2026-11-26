using System.Text.Json;
using Willage.Gen.Data;

namespace Willage.Gen.Geologie;

/// <summary>
/// Port scripts/v1/hostitele_utvaru.gd (A1) + tabulka minerálů teren/hostitele.gd (jen hostitelé).
/// Klíče hostitelů minerálů se hledají v poradi_hornin.json (všechny tam jsou; záložní sdílená tabulka vody se nepřenáší).
/// </summary>
public sealed class HostiteleUtvaru
{
    public bool Povoleno { get; }
    private HashSet<int> _nikdy = new();
    private readonly Dictionary<string, (HashSet<int> hosts, double minH)> _typy = new();
    private readonly Dictionary<int, HashSet<int>> _minHostu = new();

    public HostiteleUtvaru(bool zapnuto, DataSveta d)
    {
        Povoleno = zapnuto;
        var klicId = new Dictionary<string, int>(); var vrstvyId = new List<int>();
        using (var doc = JsonDocument.Parse(File.ReadAllText(d.PoradiHornin)))
            foreach (var r in KatalogHornin.Rocks(doc))
            {
                int idx = KatalogHornin.Int(r, "idx", -1);
                if (idx < 0 || idx > 40) continue;
                klicId[KatalogHornin.Str(r, "key", "")] = KatalogHornin.Int(r, "id", 0);
                var kind = KatalogHornin.Str(r, "kind", "layer");
                if (kind is "layer" or "seam") vrstvyId.Add(KatalogHornin.Int(r, "id", 0));
            }
        HashSet<int> Ids(JsonElement a)
        {
            var o = new HashSet<int>();
            foreach (var k in a.EnumerateArray()) if (klicId.TryGetValue(k.GetString()!, out var id)) o.Add(id);
            return o;
        }
        using (var doc = JsonDocument.Parse(File.ReadAllText(d.UtvaryHostitele)))
        {
            var root = doc.RootElement;
            if (root.TryGetProperty("nikdy", out var n)) _nikdy = Ids(n);
            foreach (var t in root.GetProperty("typy").EnumerateObject())
            {
                var e = t.Value;
                HashSet<int> h = e.TryGetProperty("hosts", out var hs) && hs.ValueKind == JsonValueKind.String && hs.GetString() == "*"
                    ? new HashSet<int>(vrstvyId) : Ids(e.GetProperty("hosts"));
                _typy[t.Name] = (h, e.TryGetProperty("min_hloubka_m", out var mh) ? mh.GetDouble() : 0.0);
            }
        }
        var rocks = new Dictionary<string, int>();
        using (var doc = JsonDocument.Parse(File.ReadAllText(d.PoradiHornin)))
            foreach (var r in KatalogHornin.Rocks(doc)) rocks[KatalogHornin.Str(r, "key", "")] = KatalogHornin.Int(r, "id", 0);
        using (var doc = JsonDocument.Parse(File.ReadAllText(d.MineralyHostitele)))
            foreach (var m in doc.RootElement.GetProperty("minerals").EnumerateObject())
            {
                var h = new HashSet<int>();
                foreach (var k in m.Value.GetProperty("hosts").EnumerateArray()) h.Add(rocks[k.GetString()!]);
                _minHostu[(int)m.Value.GetProperty("id").GetDouble()] = h;
            }
    }

    public bool JeHostitel(string typ, int vrstvaId, double hloubkaM)
    {
        if (!Povoleno) return true;
        if (_nikdy.Contains(vrstvaId)) return false;
        if (!_typy.TryGetValue(typ, out var e)) return false;
        if (hloubkaM < e.minH) return false;
        return e.hosts.Contains(vrstvaId);
    }

    public bool MineralOk(int mineralId, int vrstvaId)
    {
        if (!Povoleno) return true;
        if (!_minHostu.TryGetValue(mineralId, out var h)) return true;
        return h.Contains(vrstvaId);
    }
}
