using Willage.Gen.Geo2;
using Willage.Gen.Geologie;

namespace Willage.Gen.Testy.V8;

/// <summary>Co v buňce rozhodlo o materiálu (společné pro GEO1 a GEO2, aby šly přechody číst jako „zdroj1 → zdroj2“).</summary>
public enum Zdroj : byte { Vzduch, Sopka, Vrstva, Skarn, Cocka, Zila, Dome, Pipe, Kras }

/// <summary>Zdroj buňky v GEO1: stejný průchod jako <c>GeoVrstvy.VyplnSloupec</c>, ale vrací i vítěze mezi útvary (jen pro rozdílové buňky, je to drahé).</summary>
public static class Zdroj1
{
    public static Zdroj Urci(GeoVrstvy g, List<Utvar> feats, List<Hranice> hr, double x, double y, double z, double zPov)
    {
        if (z > zPov) return Zdroj.Vzduch;
        if (g.Sopky.Mat(x, y, z) >= 0) return Zdroj.Sopka;
        int vm = VrstvySloupce.VrstvaMat(z, hr);
        int um = g.Utvary.MatFeats(feats, x, y, z, vm, zPov, hr);
        if (um < 0) return Zdroj.Vrstva;
        if (um == Utvary.Skarn) return Zdroj.Skarn;
        // stejný výběr jako MatFeats: nejzápornější SDF mezi útvary, které smějí do hostitele (skarn tu už nevyhrál)
        double best = 1e9; Zdroj z0 = Zdroj.Vrstva;
        foreach (var f in feats)
        {
            var bx = f.Box;
            if (z < bx[2] || z > bx[5]) continue;
            if (!g.Utvary.HostOk(f.Klic, vm, zPov, z)) continue;
            double d = g.Utvary.Sdf(f, x, y, z);
            if (d < 0.0 && d <= best) { best = d; z0 = Z(f.K); }
        }
        return z0;
    }

    public static Zdroj Z(DruhUtvaru k) => k switch { DruhUtvaru.Zila => Zdroj.Zila, DruhUtvaru.Cocka => Zdroj.Cocka, DruhUtvaru.Dome => Zdroj.Dome, DruhUtvaru.Pipe => Zdroj.Pipe, _ => Zdroj.Kras };
}

/// <summary>Zdroj buňky v GEO2 z vzorku 3.1 (událost, typ prostoru, transformace).</summary>
public sealed class Zdroj2
{
    private readonly ChronologieGeo2 _c; private readonly int _skarn; private readonly Dictionary<ushort, Zdroj> _udalost = new();

    public Zdroj2(ChronologieGeo2 c)
    {
        _c = c; _skarn = c.IndexUdalosti("skarn_kontakt");
        void P(string id, Zdroj z) { int i = c.IndexUdalosti(id); if (i >= 0) _udalost[(ushort)i] = z; }
        P("cocka", Zdroj.Cocka); P("zila", Zdroj.Zila); P("dome", Zdroj.Dome); P("pipe", Zdroj.Pipe); P("kras", Zdroj.Kras); P("sopka", Zdroj.Sopka);
    }

    public Zdroj Urci(in Vzorek v)
    {
        if (v.Typ == TypProstoru.NadPovrchem) return Zdroj.Vzduch;
        if (v.Typ is TypProstoru.DutinaKras or TypProstoru.DutinaJina or TypProstoru.Vykopano) return Zdroj.Kras;
        if (_udalost.TryGetValue(v.GeoUdalost, out var z)) return z;
        return v.PosledniTransformace == _skarn && _skarn >= 0 ? Zdroj.Skarn : Zdroj.Vrstva;
    }
}
