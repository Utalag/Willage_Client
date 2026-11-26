using System.Globalization;
using Willage.Gen.Data;
using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>Port scripts/v1/sum_hornin.gd (A10): šum mocnosti podle horniny, fBm hodnotového šumu nad hashem světa.</summary>
public sealed class SumHornin
{
    public sealed record Par(double MeritkoM, double Amplituda, int Oktavy, double Persistence);
    public static readonly Par Legacy = new(180.0, 1.0, 1, 0.5);
    private const string Ucel = "V1_THICK";
    private readonly HashSveta _h;
    private readonly bool _povoleno;
    private readonly Dictionary<int, Par> _tab = new();

    public SumHornin(HashSveta h, bool zapnuto, DataSveta d)
    {
        _h = h; _povoleno = zapnuto;
        var rows = Csv.Radky(File.ReadAllText(d.SumHornin)).ToList();
        var hl = rows[0];
        int iId = hl.IndexOf("id"), iM = hl.IndexOf("meritko_m"), iA = hl.IndexOf("amplituda"), iO = hl.IndexOf("oktavy"), iP = hl.IndexOf("persistence");
        foreach (var r in rows.Skip(1))
        {
            if (r.Count <= iP || !int.TryParse(r[iId], NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out int id)) continue;
            _tab[id] = new Par(Gd.Maxf(F(r[iM]), 1.0), Gd.Clampf(F(r[iA]), 0.0, 1.0), Gd.Clampi(I(r[iO]), 1, 6), Gd.Clampf(F(r[iP]), 0.0, 1.0));
        }
    }

    private static double F(string s) => double.TryParse(s.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0.0;
    private static int I(string s) => int.TryParse(s.Trim(), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var v) ? v : 0;

    public Par Parametry(int id) => _povoleno && _tab.TryGetValue(id, out var p) ? p : Legacy;

    public double Oktava(string ucel, long k, double x, double y, double s)
    {
        long i0 = Gd.Floori(x / s), j0 = Gd.Floori(y / s);
        double tx = x / s - i0, ty = y / s - j0;
        tx = tx * tx * (3.0 - 2.0 * tx); ty = ty * ty * (3.0 - 2.0 * ty);
        double a = _h.U(ucel, i0, j0, k), b = _h.U(ucel, i0 + 1, j0, k), c = _h.U(ucel, i0, j0 + 1, k), d = _h.U(ucel, i0 + 1, j0 + 1, k);
        return Gd.Lerpf(Gd.Lerpf(a, b, tx), Gd.Lerpf(c, d, tx), ty);
    }

    public double Fbm(string ucel, long k, double x, double y, double meritko, int oktavy, double persistence)
    {
        if (oktavy <= 1) return Oktava(ucel, k, x, y, meritko);
        double suma = 0.0, vahy = 0.0, w = 1.0, s = meritko;
        for (int o = 0; o < oktavy; o++)
        {
            string u = o == 0 ? ucel : $"{ucel}_O{o}";
            suma += w * Oktava(u, k, x, y, s);
            vahy += w; w *= persistence; s /= 2.0;
        }
        return suma / vahy;
    }

    public double MocnostN01(int id, long k, double x, double y)
    {
        var p = Parametry(id);
        double n = Fbm(Ucel, k, x, y, p.MeritkoM, p.Oktavy, p.Persistence);
        if (p.Amplituda >= 1.0) return n;
        return 0.5 + (n - 0.5) * p.Amplituda;
    }
}
