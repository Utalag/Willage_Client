using Willage.Gen.Geologie;

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

/// <summary>Nitro sopek (průduch, láva, popel) z <see cref="NitroSopky.Mat"/>, jen čtení.</summary>
public sealed class TvarSopky : ITvarSMaterialem
{
    private readonly NitroSopky _s;
    public TvarSopky(NitroSopky s) => _s = s;
    public bool Obsahuje(double x, double y, double z, out uint instance)
    {
        instance = 0;
        if (_s.Mat(x, y, z) < 0) return false;
        instance = (uint)(_s.Nejblizsi(x, y).i + 1);
        return true;
    }
    public int Material(double x, double y, double z, uint instance) => _s.Mat(x, y, z);
}
