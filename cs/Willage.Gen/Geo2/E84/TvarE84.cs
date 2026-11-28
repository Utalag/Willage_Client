using Willage.Gen.Geologie;
using Willage.Gen.Sum;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Tělesa E84 jednoho druhu (žíla, čočka, kras, dóm, komín) nad starou cestou, jen čtení: výskyt z
/// <see cref="TvorbaUtvaru.Features"/>, tvar z <see cref="Utvary.Sdf"/> (SDF &lt; 0 = uvnitř), materiál z
/// <see cref="Utvary.FeatMat"/> s vrstvou v bodě. Víc instancí v bodě: rozhodne nejmenší SDF (sourozenci
/// <c>nejmensi_sdf</c>, parita s E84, 1.4); instance = seed útvaru. Vzdálenost k primitivu neumí (kontakt na E84 tělesa = K4).
/// Není vláknově bezpečný (paměť útvarů staré cesty).
/// </summary>
public sealed class TvarE84 : ITvarSMaterialem
{
    private readonly GeoVrstvy _g;
    private readonly ZasobnikVrstvySloupce _zas;
    public DruhUtvaru Druh { get; }
    private Utvar? _posledni;

    public TvarE84(GeoVrstvy g, ZasobnikVrstvySloupce zas, DruhUtvaru druh) { _g = g; _zas = zas; Druh = druh; }

    public bool Obsahuje(double x, double y, double z, out uint instance)
    {
        instance = 0; _posledni = null;
        double best = 0.0;
        foreach (var f in _g.Utvary.Tvorba.Features(x, y))
        {
            if (f.K != Druh) continue;
            var bx = f.Box;
            if (z < bx[2] || z > bx[5]) continue;
            double d = _g.Utvary.Sdf(f, x, y, z);
            if (d < 0.0 && (_posledni is null || d <= best)) { best = d; _posledni = f; }
        }
        if (_posledni is null) return false;
        instance = (uint)_posledni.Seed;
        return true;
    }

    public int Material(double x, double y, double z, uint instance)
    {
        var f = _posledni;
        if (f is null || (uint)f.Seed != instance) { Obsahuje(x, y, z, out _); f = _posledni!; }
        _zas.Vrstva(x, y, z, out int vrstvaId, out _);
        return _g.Utvary.FeatMat(f, z, vrstvaId);
    }
}

/// <summary>
/// Nitro sopek (průduch, láva, popel) z <see cref="NitroSopky.Mat"/>, jen čtení. K4: segmentace sloupce analyticky z veřejných dat
/// (<see cref="Willage.Gen.Svet.Sopky.Seznam"/>, <c>Kuzel</c>): vrch kužele + 0,05, kráter + 0,05 (průduch), hranice slupek.
/// </summary>
public sealed class TvarSopky : ITvarSMaterialem, IIntervalyTvaru
{
    private readonly NitroSopky _s;
    private readonly Willage.Gen.Svet.SvetFn? _svet;
    public TvarSopky(NitroSopky s, Willage.Gen.Svet.SvetFn? svet = null) { _s = s; _svet = svet; }
    public bool Obsahuje(double x, double y, double z, out uint instance)
    {
        instance = 0;
        if (_s.Mat(x, y, z) < 0) return false;
        instance = (uint)(_s.Nejblizsi(x, y).i + 1);
        return true;
    }
    public int Material(double x, double y, double z, uint instance) => _s.Mat(x, y, z);

    public void Sloupec(double x, double y, SegmentaceSloupce seg)
    {
        if (_svet is null) { seg.Nejista(seg.Z0, seg.Z1); return; }
        var (best, br2) = _s.Nejblizsi(x, y);
        if (best < 0) return;
        var s = _svet.Sopky.Seznam[best]; var p = _svet.P;
        double r = Math.Sqrt(br2), h0 = s.VyskaOkoli, zPovKuz = h0 + _svet.Sopky.Kuzel(best, r);
        seg.Zlom(zPovKuz + 0.05);
        seg.Zlom(zPovKuz); // pod zPovKuz je hloubka ≥ 0 (k ≥ 0), nad ním k = −1 (popel) až do zPovKuz + 0,05; Nejista kvůli floor v kraji
        seg.Nejista(zPovKuz - 1e-9, zPovKuz + 1e-9);
        double rVent = Gd.Maxf(p.SopkaPruduchRM, s.Rc * 0.35);
        if (r < rVent) seg.Zlom(h0 + s.H - s.D + 0.05);
        double sl = Gd.Maxf(p.SopkaSlupkaM, 0.5);
        double zMin = Math.Max(seg.Z0, 0);
        for (long k = Math.Max(1, (long)Math.Floor((zPovKuz - seg.Z1) / sl)); ; k++)
        {
            double z = zPovKuz - k * sl;
            if (z < zMin) break;
            seg.Zlom(z);
            seg.Nejista(z - 1e-9, z + 1e-9); // floor((zPovKuz − z)/sl) může v kraji zaokrouhlit jinak než z − k·sl
        }
    }
}
