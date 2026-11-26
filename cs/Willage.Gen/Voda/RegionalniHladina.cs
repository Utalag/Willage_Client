using Willage.Gen.Geologie;

namespace Willage.Gen.Voda;

/// <summary>
/// Hladina podzemní vody jako funkce (E74 bez řešiče): tlumená kopie reliéfu.
/// G = vážený průměr povrchu v uzlech SVĚTOVÉ mřížky (krok s) do poloměru R, váha (1 − d²/R²)²;
/// L = min(G − d₀ + β·(G − povrch), povrch): β zesílí údolí (hladina se v údolí přiblíží povrchu, na hřbetu klesne).
/// β = 0 je čistě tlumená kopie (první běh: na startovním světě 0 % vývěru, 0 pramenů). Uzly nezávisí na bloku, váha je spojitá → hladina je spojitá i přes švy.
/// </summary>
public sealed class RegionalniHladina
{
    private readonly IGeologie _g;
    private readonly ParametryVody _p;

    public RegionalniHladina(IGeologie g, ParametryVody p) { _g = g; _p = p; }

    /// <summary>Hladina bez ořezu povrchem.</summary>
    public double Surova(double x, double y)
    {
        double s = _p.MrizkaHladinyM, R = _p.PolomerHladinyM, R2 = R * R;
        int i0 = (int)Math.Ceiling((x - R) / s), i1 = (int)Math.Floor((x + R) / s);
        int j0 = (int)Math.Ceiling((y - R) / s), j1 = (int)Math.Floor((y + R) / s);
        double sw = 0, sh = 0;
        for (int i = i0; i <= i1; i++)
        for (int j = j0; j <= j1; j++)
        {
            double dx = i * s - x, dy = j * s - y, d2 = dx * dx + dy * dy;
            if (d2 >= R2) continue;
            double w = 1.0 - d2 / R2; w *= w;
            sw += w; sh += w * _g.Povrch(i * s, j * s);
        }
        double g = sh / sw;
        return g - _p.HloubkaD0M + _p.ZesileniUdoliBeta * (g - _g.Povrch(x, y));
    }

    /// <summary>Hladina L (m), nikdy nad povrchem.</summary>
    public double Hladina(double x, double y) => Math.Min(Surova(x, y), _g.Povrch(x, y));

    /// <summary>Zóna vývěru: regionální hladina dosáhne povrchu (mokřad, pramen, jezero kroku 7).</summary>
    public bool Vyver(double x, double y) => Surova(x, y) >= _g.Povrch(x, y);
}
