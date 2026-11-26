using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>Port geo_vrstvy.gd::sopka_mat: průduch (75) od kráteru dolů, slupky lávy / popela; −1 mimo těleso sopky.</summary>
public sealed class NitroSopky
{
    public const int Pruduch = 75;
    private readonly SvetFn _s;
    public NitroSopky(SvetFn s) => _s = s;

    /// <summary>Index nejbližší sopky, v jejímž úpatí (x, y) leží, a vzdálenost², nebo −1.</summary>
    public (int i, double r2) Nejblizsi(double x, double y)
    {
        int best = -1; double br2 = 1e30; var ss = _s.Sopky.Seznam;
        for (int i = 0; i < ss.Count; i++)
        {
            double dx = x - ss[i].X, dy = y - ss[i].Y, r2 = dx * dx + dy * dy, R = ss[i].R;
            if (r2 < R * R && r2 < br2) { br2 = r2; best = i; }
        }
        return (best, br2);
    }

    public int Mat(double x, double y, double z)
    {
        if (z < 0.0) return 0;
        var (best, br2) = Nejblizsi(x, y);
        if (best < 0) return -1;
        var s = _s.Sopky.Seznam[best]; var p = _s.P;
        double r = Math.Sqrt(br2), h0 = s.VyskaOkoli, zPovKuz = h0 + _s.Sopky.Kuzel(best, r);
        if (z > zPovKuz + 0.05) return -1;
        double rVent = Gd.Maxf(p.SopkaPruduchRM, s.Rc * 0.35);
        double zKrater = h0 + s.H - s.D;
        if (r < rVent && z <= zKrater + 0.05) return Pruduch;
        if (z < 0.0) return -1;
        double hloubka = zPovKuz - z;
        long k = (long)Math.Floor(hloubka / Gd.Maxf(p.SopkaSlupkaM, 0.5));
        return k % 2 == 0 ? p.SopkaLavaId : p.SopkaPopelId;
    }
}
