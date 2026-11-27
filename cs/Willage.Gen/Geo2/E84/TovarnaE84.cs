using System.Text.Json;
using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Továrna tvarů GEO2 nad starou cestou (jen čtení, stará cesta se nemění):
/// <c>zasobnik</c> (zdroj VrstvySloupce), tělesa E84 podle <c>z_parametru</c> (zila, cocka, kras, dome, pipe), <c>sopka_nitro</c>.
/// Povrch = <see cref="Willage.Gen.Svet.SvetFn.Vyska"/>. Seed šumu události s <c>tvar.seed_e84: true</c> = Sd ^ 84
/// (jako dnešní SkarnD), jinak výchozí z id. Bez indexu: jedna instance (a chronologie) na vlákno (keš <c>Features</c>).
/// S <c>indexBloku</c> (K3): tělesa jsou <see cref="TvarE84Index"/>, chronologie se připraví <see cref="KontextBloku.Sestav"/>
/// a jedna instance slouží všem vláknům.
/// </summary>
public sealed class TovarnaE84 : ITovarnaTvaru
{
    private readonly GeoVrstvy _g;
    public ZasobnikVrstvySloupce Zasobnik { get; }
    public Func<double, double, double>? Povrch { get; }

    private readonly bool _index;

    public TovarnaE84(GeoVrstvy g, bool indexBloku = false)
    {
        _g = g; _index = indexBloku; Zasobnik = new ZasobnikVrstvySloupce(g);
        var s = g.Svet; Povrch = (x, y) => s.Vyska(x, y);
    }

    public object? Vytvor(UdalostData u)
    {
        var t = u.Tvar;
        string? Str(string k) => t.ValueKind == JsonValueKind.Object && t.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        switch (u.TvarDruh)
        {
            case "zasobnik": return Str("zdroj") == "VrstvySloupce" ? Zasobnik : null;
            case "sopka_nitro": return new TvarSopky(_g.Sopky);
            case "elipsoid" or "deska" or "kapsle_retez":
                return Str("z_parametru") switch
                {
                    "zila" => Teleso(DruhUtvaru.Zila),
                    "cocka" => Teleso(DruhUtvaru.Cocka),
                    "kras" => Teleso(DruhUtvaru.Kras),
                    "dome" => Teleso(DruhUtvaru.Dome),
                    "pipe" => Teleso(DruhUtvaru.Pipe),
                    _ => null,
                };
            default: return null;
        }
    }

    private ITvar Teleso(DruhUtvaru d) => _index ? new TvarE84Index(_g, Zasobnik, d) : new TvarE84(_g, Zasobnik, d);

    public long SeedUdalosti(UdalostData u) =>
        u.Tvar.ValueKind == JsonValueKind.Object && u.Tvar.TryGetProperty("seed_e84", out var v) && v.ValueKind == JsonValueKind.True
            ? _g.Svet.Sd ^ 84
            : Willage.Gen.Sum.StableHash.Fnv1a64("geo2:" + u.Id);
}
