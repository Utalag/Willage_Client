using System.Globalization;
using System.Text.Json;
using Willage.Gen.Jadro;

namespace Willage.Gen.Materialy;

/// <summary>
/// Koeficient průsaku (těsnost) každého materiálu jako celé číslo 0–255 (255 = plně propustné, 0 = těsné)
/// a efektivní K / porozita pro průsak. Tabulka z katalogu (K) a <c>prusak_v1.json</c>: přepis podle klíče,
/// jinak třída podle K; pole <c>pukliny</c> přidá puklinovou propustnost (kras) jen pro tento výpočet —
/// <see cref="Propustnost"/> generátoru se nemění.
/// </summary>
public sealed class PrusakKoeficient
{
    public const int Vzduch = 0;
    private readonly byte[] _b = new byte[256];
    private readonly double?[] _k = new double?[256];   // efektivní K pro průsak (m/s)
    private readonly double?[] _n = new double?[256];   // efektivní porozita
    private readonly bool[] _puk = new bool[256];
    private readonly double[] _x = new double[256];     // l/s při spádu 1 z efektivního K

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
        var puk = new Dictionary<string, (double kMs, byte? koef, double? n)>();
        if (r.TryGetProperty("pukliny", out var pu) && pu.ValueKind == JsonValueKind.Object)
            foreach (var p in pu.EnumerateObject())
            {
                if (p.Name.StartsWith('_')) continue;   // poznámky
                var v = p.Value;
                double kMs = CisloK(v.GetProperty("kMs")) ?? throw new ArgumentException("pukliny." + p.Name + ": chybí kMs");
                byte? ko = v.TryGetProperty("koef", out var ke) ? Bajt(ke.GetInt32(), "pukliny." + p.Name + ".koef") : null;
                double? n = null;
                if (v.TryGetProperty("porosityPermille", out var pp) && pp.ValueKind == JsonValueKind.Number) n = pp.GetInt32() / 1000.0;
                else if (v.TryGetProperty("porovitost", out var po) && po.ValueKind == JsonValueKind.Number) n = po.GetDouble();
                puk[p.Name] = (kMs, ko, n);
            }

        for (int id = 0; id < 256; id++)
        {
            if (id == Vzduch) { _b[id] = vzduch; _k[id] = null; _x[id] = double.PositiveInfinity; continue; }
            var m = kat.Najdi(id);
            if (m is null) { kat.NeznamaId.Remove(id); _b[id] = 0; continue; }
            double? kMat = m.KMs;
            if (klice.TryGetValue(m.Key, out byte pr)) _b[id] = pr;
            else _b[id] = kMat is not double km ? bezK : TridaPodleK(tridy, km);
            _k[id] = kMat;
            _n[id] = m.Porovitost > 0 ? m.Porovitost : null;
            if (puk.TryGetValue(m.Key, out var pk))
            {
                _puk[id] = true;
                _k[id] = (kMat ?? 0) + pk.kMs;   // přidaná puklinová propustnost
                if (pk.koef is byte b) _b[id] = b;
                if (pk.n is double nn) _n[id] = nn;
            }
            _x[id] = (_k[id] ?? 0) * GeologyGridConstants.CellFaceM2 * 1000.0;
        }
    }

    private static byte TridaPodleK(List<(double kOd, byte koef)> tridy, double k)
    {
        foreach (var (kOd, koef) in tridy) if (k >= kOd) return koef;
        return 0;
    }

    private static byte Bajt(int v, string co) =>
        v is >= 0 and <= 255 ? (byte)v : throw new ArgumentOutOfRangeException(co, v, "koeficient průsaku musí být celé číslo 0–255");

    private static double? CisloK(JsonElement e) => e.ValueKind switch
    {
        JsonValueKind.Number => e.GetDouble(),
        JsonValueKind.String when double.TryParse(e.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var v) => v,
        _ => null,
    };

    /// <summary>Koeficient materiálu 0–255 (u krasu po přepisu z puklin).</summary>
    public byte Koef(int id) => _b[id & 0xFF];
    /// <summary>Efektivní K pro průsak (m/s): matrice + pukliny, jinak K z katalogu.</summary>
    public double? KMs(int id) => _k[id & 0xFF];
    /// <summary>Efektivní porozita pro dosah (z puklin, jinak katalog); null = použít náhradní z parametrů.</summary>
    public double? Porovitost(int id) => _n[id & 0xFF];
    public bool JePukliny(int id) => _puk[id & 0xFF];
    /// <summary>X buňky v l/s při spádu 1 z efektivního K (vzduch = ∞). Generátor používá <see cref="Propustnost.X"/>, ne toto.</summary>
    public double X(int id) => _x[id & 0xFF];
}
