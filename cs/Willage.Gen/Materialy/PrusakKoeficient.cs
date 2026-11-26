using System.Text.Json;

namespace Willage.Gen.Materialy;

/// <summary>
/// Koeficient průsaku (těsnost) každého materiálu jako celé číslo 0–255 (255 = plně propustné, 0 = těsné).
/// Tabulka vzniká z katalogu (K) a dat <c>prusak_v1.json</c>: přepis podle klíče materiálu, jinak třída podle K.
/// </summary>
public sealed class PrusakKoeficient
{
    public const int Vzduch = 0;
    private readonly byte[] _b = new byte[256];

    public PrusakKoeficient(KatalogMaterialu kat, string json)
    {
        using var doc = JsonDocument.Parse(json);
        var r = doc.RootElement;
        byte vzduch = Bajt(r.GetProperty("vzduch").GetInt32(), "vzduch");
        byte bezK = Bajt(r.GetProperty("bezK").GetInt32(), "bezK");
        var tridy = new List<(double kOd, byte koef)>();
        foreach (var t in r.GetProperty("tridyPodleK").EnumerateArray())
            tridy.Add((t.GetProperty("kOd").GetDouble(), Bajt(t.GetProperty("koef").GetInt32(), "koef")));
        tridy.Sort((a, b) => b.kOd.CompareTo(a.kOd));
        var klice = new Dictionary<string, byte>();
        foreach (var p in r.GetProperty("podleKlice").EnumerateObject()) klice[p.Name] = Bajt(p.Value.GetInt32(), p.Name);

        for (int id = 0; id < 256; id++)
        {
            if (id == Vzduch) { _b[id] = vzduch; continue; }
            var m = kat.Najdi(id);
            if (m is null) { kat.NeznamaId.Remove(id); _b[id] = 0; continue; }   // neznámé ID = těsnění
            if (klice.TryGetValue(m.Key, out byte pr)) { _b[id] = pr; continue; }
            _b[id] = m.KMs is not double k ? bezK : TridaPodleK(tridy, k);
        }
    }

    private static byte TridaPodleK(List<(double kOd, byte koef)> tridy, double k)
    {
        foreach (var (kOd, koef) in tridy) if (k >= kOd) return koef;
        return 0;
    }

    private static byte Bajt(int v, string co) =>
        v is >= 0 and <= 255 ? (byte)v : throw new ArgumentOutOfRangeException(co, v, "koeficient průsaku musí být celé číslo 0–255");

    /// <summary>Koeficient materiálu 0–255.</summary>
    public byte Koef(int id) => _b[id & 0xFF];
}
