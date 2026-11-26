using Willage.Gen.Data;
using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>Sloupec rozhraní 2.2 (bez hranic a hladiny – ty má geologie a voda).</summary>
public sealed record SloupecSveta(double PovrchM, int Biom, double[] BiomVahy, List<(int id, double podil)> Horniny, double Masiv, int Sopka);

/// <summary>
/// Port scripts/v1/svet_fn.gd (krok 2): funkce světa I – povrch, biomy, horniny, sopky. Čistá funkce v metrech (double).
/// Pořadí stavby jako v GDScriptu: klima → mapa biomů → reliéf → masiv → sopky → mapa hornin.
/// </summary>
public sealed class SvetFn
{
    public const int Hornatina = 3, Sopecna = 4, Vzduch = 0;
    public ParametrySveta P { get; }
    public long Sd { get; }
    public double SloupecM, NeutralM, SvetM, StropPovrchuM, Hladkost;
    public HashSveta H { get; }
    public Sumy Sumy { get; } = new();
    public MapaBiomu Biomy { get; }
    public Relief Relief { get; }
    public Masiv Masiv { get; }
    public Sopky Sopky { get; }
    public MapaHornin Horniny { get; }
    public string KlimaId { get; } = "mirne";
    /// <summary>Krok 6: eroze světa (hrubá mapa + koryta). null = vypnuto (výchozí); uplatní se jen v povrchu s detaily, tvar (VyskaTvar) nemění.</summary>
    public Willage.Gen.Eroze.IErozeSveta? Eroze { get; set; }
    /// <summary>Krok 6b: moře a sklon kontinentu (p.More), jinak null.</summary>
    public MoreSklon? More { get; }
    /// <summary>Krok 6b: velké pánve (p.Panve), jinak null.</summary>
    public Panve? Panve { get; }

    public SvetFn(ParametrySveta p, DataSveta data)
    {
        P = p; Sd = p.Seed; H = new HashSveta(Sd);
        SloupecM = p.SloupecM; NeutralM = SloupecM * 0.5; SvetM = p.SvetMaxM;
        StropPovrchuM = SloupecM - p.SopkaRezervaM; Hladkost = p.StropPovrchuHladkostM;
        if (p.Klima == "ze_seedu") throw new NotSupportedException("klima=ze_seedu není přeneseno do C# (výchozí svět ho nepoužívá)");
        var (podle, _) = KlimaPresety.Nacti(data.KlimaPresety);
        if (podle.TryGetValue(p.Klima, out var pr)) KlimaId = p.Klima; else pr = podle["mirne"];
        KlimaPresety.Uplatni(p, pr);
        Biomy = new MapaBiomu(p, H, SvetM);
        Relief = new Relief(p, Sd);
        Masiv = new Masiv(p, Sd, Sumy);
        Sopky = new Sopky(p, H, Biomy, (x, y, w) => VyskaBezSopek(x, y, w, true), Relief, SvetM, StropPovrchuM);
        Horniny = new MapaHornin(p, H, SvetM);
        if (p.More) More = new MoreSklon(p, Sd);
        if (p.Panve) Panve = new Panve(p, H, More);
    }

    public double[] Vahy(double x, double y) => Biomy.Vahy(x, y);

    public double VyskaBezSopek(double x, double y, double[] w, bool detaily)
    {
        double h = NeutralM;
        for (int t = 0; t < 5; t++) if (w[t] > 0.0) h += w[t] * Relief.Rel(t, x, y);
        double wm = Masiv.Vaha(w[Hornatina]);
        if (wm > 0.0)
        {
            h += wm * Masiv.H(x, y, detaily);
            h += 4.0 * wm * (1.0 - wm) * Masiv.PodAmp * Masiv.PodNoise.Noise2D(x, y);
        }
        return h;
    }

    private double Smin(double h)
    {
        double c = StropPovrchuM, k = Hladkost;
        double m = Gd.Minf(h, c);
        return m - k * Math.Log(1.0 + Math.Exp(-Math.Abs(h - c) / k));
    }

    public double Vyska(double x, double y) => VyskaW(x, y, Vahy(x, y), true);
    public double VyskaTvar(double x, double y) => VyskaW(x, y, Vahy(x, y), false);
    /// <summary>Krok 6b: povrch s detaily bez eroze světa (stejné jako Vyska, když je eroze vypnutá).</summary>
    public double VyskaBezEroze(double x, double y) => VyskaW(x, y, Vahy(x, y), true, false);

    public double VyskaW(double x, double y, double[] w, bool detaily = true, bool eroze = true)
    {
        double h = VyskaBezSopek(x, y, w, detaily);
        var s = Sopky.Seznam;
        for (int i = 0; i < s.Count; i++)
        {
            double dx = x - s[i].X, dy = y - s[i].Y, r2 = dx * dx + dy * dy;
            if (r2 < s[i].R * s[i].R) h += Sopky.Kuzel(i, Math.Sqrt(r2));
        }
        if (More != null) h += More.Posun(x, y);
        if (Panve != null) h += Panve.Posun(x, y);
        h = Smin(h);
        if (detaily && eroze && Eroze != null) h -= Eroze.Hloubka(x, y);
        return h;
    }

    /// <summary>Index sopky, v jejímž úpatí bod leží (poslední vyhrává), jinak −1.</summary>
    public int SopkaV(double x, double y)
    {
        int r = -1; var s = Sopky.Seznam;
        for (int i = 0; i < s.Count; i++)
            if ((x - s[i].X) * (x - s[i].X) + (y - s[i].Y) * (y - s[i].Y) < s[i].R * s[i].R) r = i;
        return r;
    }

    public SloupecSveta Sloupec(double x, double y)
    {
        var w = Vahy(x, y);
        int biom = 0; for (int t = 0; t < 5; t++) if (w[t] > w[biom]) biom = t;
        var hr = Horniny.Horniny(x, y, w);
        if (hr.Count > P.Zastupcu)
        {
            hr = hr.GetRange(0, P.Zastupcu);
            double sm = 0.0; foreach (var e in hr) sm += e.podil;
            hr = hr.Select(e => (e.id, e.podil / sm)).ToList();
        }
        return new SloupecSveta(VyskaW(x, y, w), biom, w, hr, Masiv.Vaha(w[Hornatina]), SopkaV(x, y));
    }
}
