using Willage.Gen.Geologie;
using Willage.Gen.Voda.Prusak;

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

    private readonly PobrezniPas? _pas;

    /// <summary>
    /// Krok 7c: dobití hladiny klimatem e(x, y) ∈ [0, 1] (1 = plně dobíjená, 0 = bez dobití ⇒ hladina neexistuje, <see cref="Surova"/> vrací NaN).
    /// null = vypnuto (výchozí, hladina všude jako dosud).
    /// </summary>
    public Func<double, double, double>? Napajeni { get; set; }
    /// <summary>Hloubka (m), o kterou se hladina sníží při nejnižším dobití e → 0+ (hladina = sklonová − SuchoM·(1 − e)).</summary>
    public double NapajeniSuchoM { get; set; } = 30.0;
    private readonly System.Collections.Concurrent.ConcurrentDictionary<(long, long, int), double> _sirky = new();

    /// <param name="pas">šířka pobřežního pásu z koeficientu průsaku; null = konstanta <see cref="ParametryVody.HladinaPrechodM"/></param>
    public RegionalniHladina(IGeologie g, ParametryVody p, PobrezniPas? pas = null) { _g = g; _p = p; _pas = pas; }

    /// <summary>Šířka pásu u břehu v (sx, sy) při rozdílu hladin dhMm; cache po 1 m a spádu.</summary>
    private double SirkaPasu(double sx, double sy, long dhMm)
    {
        int spad = _pas!.SpadPm(dhMm);
        return _sirky.GetOrAdd(((long)Math.Round(sx), (long)Math.Round(sy), spad),
            k => _pas.Sirka(_g.Sloupec(k.Item1, k.Item2), _g.Povrch(k.Item1, k.Item2), dhMm));
    }

    /// <summary>Povrch pro tvar hladiny: krok 6b s erozí = povrch před erozí (hladina pak klesne o hrubou erozi).</summary>
    private double PovrchH(double x, double y) => _p.HladinaSledujeErozi ? _g.PovrchBezEroze(x, y) : _g.Povrch(x, y);

    /// <summary>Hladina bez ořezu povrchem.</summary>
    public double Surova(double x, double y)
    {
        double s = _p.MrizkaHladinyM, R = _p.PolomerHladinyM, R2 = R * R;
        int i0 = (int)Math.Ceiling((x - R) / s), i1 = (int)Math.Floor((x + R) / s);
        int j0 = (int)Math.Ceiling((y - R) / s), j1 = (int)Math.Floor((y + R) / s);
        // krok 7c: dobití klimatem (jen se zapnutým klimatem); e = 0 ⇒ hladina neexistuje (NaN), jinak se sníží o SuchoM·(1 − e)
        double e = 1.0;
        double hmore = _g.HladinaMore;
        bool bezMore = _p.HladinaBezMorskychUzlu && !double.IsNaN(hmore);
        if (Napajeni is not null)
        {
            e = Napajeni(x, y);
            if (e <= 0.0)
            {
                // bez dobití není hladina nikde kromě moře samotného (u břehu dobíjí pobřežní zdroj)
                if (!double.IsNaN(hmore) && _g.JeMoreVyska(x, y, _g.Povrch(x, y))) return hmore;
                return double.NaN;
            }
        }
        double sw = 0, sh = 0, swMore = 0;
        for (int i = i0; i <= i1; i++)
        for (int j = j0; j <= j1; j++)
        {
            double dx = i * s - x, dy = j * s - y, d2 = dx * dx + dy * dy;
            if (d2 >= R2) continue;
            double w = 1.0 - d2 / R2; w *= w;
            double hz = PovrchH(i * s, j * s);
            // krok 7c: uzel v moři přispívá hladinou moře (tlaková výška moře), ne hloubkou dna; dno by hladinu na pevnině táhlo pod hladinu moře
            if (bezMore && hz < hmore && _g.JeMoreVyska(i * s, j * s, hz)) { hz = hmore; swMore += w; }
            sw += w; sh += w * hz;
        }
        double g = sh / sw;
        double l = g - _p.HloubkaD0M + _p.ZesileniUdoliBeta * (g - PovrchH(x, y));
        l = _p.HladinaSledujeErozi ? l - _g.ErozeHruba(x, y) : l;
        if (Napajeni is not null) l -= NapajeniSuchoM * (1.0 - e);
        // krok 7c: podlaha u moře – blízko moře (podíl mořských uzlů v okně ≥ HladinaPodlahaPodil) nesmí být hladina na pevnině pod hladinou moře
        // (ani vlivem poklesu o hrubou erozi); dál od moře podlaha plynule klesá o HladinaPodlahaM a mizí
        if (bezMore && swMore > 0)
        {
            double f = Math.Min(1.0, swMore / sw / Math.Max(1e-9, _p.HladinaPodlahaPodil));
            l = Math.Max(l, hmore - _p.HladinaPodlahaM * (1.0 - f));
        }
        // krok 6e/6g: v moři (JeMore) a v pásu HladinaPrechodM od skutečného břehu hladina = hladina moře, dál původní spád (smoothstep); žádný fallback 60 m
        if (_pas is not null)
        {
            // koeficient průsaku: šířka pásu = dosah mořské vody za horizont podle materiálů u nejbližšího břehu
            double hm = _g.HladinaMore;
            if (!double.IsNaN(hm))
            {
                var (d, sx, sy) = _g.BrehOdMore(x, y, _pas.MaxM);
                if (d <= 0) l = hm;
                else if (d < _pas.MaxM && !double.IsNaN(sx))
                {
                    double w = SirkaPasu(sx, sy, (long)Math.Round((l - hm) * 1000.0));
                    if (d < w) { double t = d / w; t = t * t * (3.0 - 2.0 * t); l = hm + (l - hm) * t; }
                }
            }
        }
        else if (_p.HladinaPrechodM > 0)
        {
            double hm = _g.HladinaMore;
            if (!double.IsNaN(hm))
            {
                double d = _g.VzdalenostOdMore(x, y);
                if (d < _p.HladinaPrechodM)
                {
                    double t = d / _p.HladinaPrechodM; t = t * t * (3.0 - 2.0 * t);
                    l = hm + (l - hm) * t;
                }
            }
        }
        return l;
    }

    /// <summary>Hladina L (m), nikdy nad povrchem; NaN = hladina neexistuje (bez dobití, krok 7c).</summary>
    public double Hladina(double x, double y) => Math.Min(Surova(x, y), _g.Povrch(x, y));

    /// <summary>Krok 7c: existuje v bodě hladina podzemní vody?</summary>
    public bool Existuje(double x, double y) => !double.IsNaN(Surova(x, y));

    /// <summary>Zóna vývěru: regionální hladina dosáhne povrchu (mokřad, pramen, jezero kroku 7).</summary>
    public bool Vyver(double x, double y) => Surova(x, y) >= _g.Povrch(x, y);
}
