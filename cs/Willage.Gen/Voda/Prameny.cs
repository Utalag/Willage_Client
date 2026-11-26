using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda;

/// <summary>
/// Prameny ze seedu jako funkce světa. Světová buňka (32 m): kandidáti na mřížce 2 m v zóně vývěru, nejlepší podle
/// (druh, převýšení hladiny nad povrch, hash). Existence buňky z hashe; rozestup řeší priorita z hashe jen mezi
/// sousedními buňkami 3 × 3 → výsledek buňky nezávisí na bloku, ve kterém se počítá.
/// </summary>
public sealed class Prameny
{
    private const int SaltExist = 0x50A1, SaltPrio = 0x50A2, SaltQ = 0x50A3, SaltTie = 0x50A4;
    private readonly IGeologie _g;
    private readonly RegionalniHladina _h;
    private readonly Propustnost _pr;
    private readonly ParametryVody _p;
    private readonly Dictionary<(int, int), Pramen?> _kandidat = new();

    public Prameny(IGeologie g, RegionalniHladina h, Propustnost pr, ParametryVody p) { _g = g; _h = h; _pr = pr; _p = p; }

    /// <summary>Krok 6: vodníci z eroze světa (obdélník → prameny). null = vypnuto (výchozí); přidají se za prameny ze seedu.</summary>
    public Func<double, double, double, double, IEnumerable<Pramen>>? Vodnici { get; set; }

    /// <summary>Prameny světových buněk, jejichž pramen leží v obdélníku [x0, x1) × [y0, y1).</summary>
    public List<Pramen> VOblasti(double x0, double y0, double x1, double y1)
    {
        double b = _p.BunkaPramenuM;
        var out_ = new List<Pramen>();
        for (int cx = (int)Math.Floor(x0 / b); cx <= (int)Math.Floor((x1 - 1e-9) / b); cx++)
        for (int cy = (int)Math.Floor(y0 / b); cy <= (int)Math.Floor((y1 - 1e-9) / b); cy++)
        {
            var s = Vysledny(cx, cy);
            if (s is not null && s.X >= x0 && s.X < x1 && s.Y >= y0 && s.Y < y1) out_.Add(s);
        }
        if (Vodnici is not null) out_.AddRange(Vodnici(x0, y0, x1, y1));
        out_.Sort((a, c) => a.X != c.X ? a.X.CompareTo(c.X) : a.Y.CompareTo(c.Y));
        return out_;
    }

    /// <summary>Pramen buňky po rozestupu (vyhraje vyšší priorita v sousedních buňkách).</summary>
    public Pramen? Vysledny(int cx, int cy)
    {
        var s = Kandidat(cx, cy);
        if (s is null) return null;
        double d2min = _p.RozestupM * _p.RozestupM;
        for (int dx = -1; dx <= 1; dx++)
        for (int dy = -1; dy <= 1; dy++)
        {
            if (dx == 0 && dy == 0) continue;
            var o = Kandidat(cx + dx, cy + dy);
            if (o is null) continue;
            double ex = o.X - s.X, ey = o.Y - s.Y;
            if (ex * ex + ey * ey >= d2min) continue;
            if (o.Priorita > s.Priorita || (o.Priorita == s.Priorita && (o.BunkaX, o.BunkaY).CompareTo((s.BunkaX, s.BunkaY)) < 0)) return null;
        }
        return s;
    }

    /// <summary>Kandidát buňky před rozestupem (memoizováno).</summary>
    public Pramen? Kandidat(int cx, int cy)
    {
        if (_kandidat.TryGetValue((cx, cy), out var c)) return c;
        c = Spocti(cx, cy);
        _kandidat[(cx, cy)] = c;
        return c;
    }

    private Pramen? Spocti(int cx, int cy)
    {
        uint seed = _p.Seed;
        if (GeologyHash.Unit(GeologyHash.HashInt3(cx, cy, SaltExist, seed)) >= _p.PravdepodobnostBunky) return null;
        double b = _p.BunkaPramenuM, st = _p.KrokKandidatuM;
        int n = (int)Math.Round(b / st);
        (int druh, double prevys, uint tie, double x, double y, int kz, int akv)? best = null;
        for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
        {
            double x = cx * b + (i + 0.5) * st, y = cy * b + (j + 0.5) * st;
            double pov = _g.Povrch(x, y);
            double prevys = _h.Surova(x, y) - pov;
            if (prevys < 0) continue;                       // jen zóna vývěru
            var col = _g.Sloupec(x, y);
            int kt = Math.Clamp((int)Math.Floor((pov - 1e-9) / GeologyGridConstants.CellM), 0, col.Length - 1);
            int druh = Druh(x, y, col, kt, pov, _p.SopkaNepropustna ? _g.NitroSopky(x, y) : null);
            if (druh < 0) continue;
            uint tie = GeologyHash.HashInt3((int)Math.Floor(x * 4), (int)Math.Floor(y * 4), SaltTie, seed);
            int akv = kt > 0 ? col[kt - 1] : col[kt];
            if (best is null || druh > best.Value.druh || (druh == best.Value.druh &&
                (prevys > best.Value.prevys || (prevys == best.Value.prevys && tie > best.Value.tie))))
                best = (druh, prevys, tie, x, y, kt, akv);
        }
        if (best is null) return null;
        var v = best.Value;
        var d = (DruhPramene)v.druh;
        double zaklad = d switch { DruhPramene.Snih => _p.QSnih, DruhPramene.Kontakt => _p.QKontakt, DruhPramene.Kras => _p.QKras, _ => _p.QVyver };
        double q = zaklad * (0.5 + GeologyHash.Unit(GeologyHash.HashInt3(cx, cy, SaltQ, seed)));
        uint prio = GeologyHash.HashInt3(cx, cy, SaltPrio, seed);
        return new Pramen(v.x, v.y, v.kz, d, q, cx, cy, prio, v.akv);
    }

    /// <summary>Druh podle povrchu a horniny (pořadí E47c: sníh > kontakt > kras > vývěr); −1 = voda z těsnění nevyteče.</summary>
    private int Druh(double x, double y, byte[] col, int kt, double pov, bool[]? ni)
    {
        bool N(int k) => ni is not null && ni[k];
        bool Tel(int k) => !N(k) && _pr.Teleso(col[k]);
        bool Tes(int k) => N(k) || _pr.Tesneni(col[k]);
        bool Roz(int k) => !N(k) && _pr.Rozpustny(col[k]);
        int top = col[kt];
        if (top == 10) return (int)DruhPramene.Snih;
        int k1 = Math.Max(0, kt - 4);                       // 1 m pod povrchem
        bool propNahore = Tel(kt) || Tel(k1);
        if (propNahore && Sklon(x, y, pov) >= _p.SklonKontakt)
            for (int k = k1; k >= Math.Max(0, kt - 12); k--)  // těsnění do 3 m
                if (Tes(k)) return (int)DruhPramene.Kontakt;
        if (Roz(kt) || Roz(k1)) return (int)DruhPramene.Kras;
        return Tel(kt) ? (int)DruhPramene.Vyver : -1;
    }

    private double Sklon(double x, double y, double pov)
    {
        const double d = 2.0; double s = 0;
        foreach (var (ox, oy) in new[] { (d, 0.0), (-d, 0.0), (0.0, d), (0.0, -d) })
            s = Math.Max(s, (pov - _g.Povrch(x + ox, y + oy)) / d);
        return s;
    }

    /// <summary>Filtr pro vložení (krok 5): pramen ne blíž než okraj od hrany ostrova [x0, x1) × [y0, y1).</summary>
    public static bool MimoOkraj(Pramen s, double x0, double y0, double x1, double y1, double okraj) =>
        s.X - x0 >= okraj && x1 - s.X >= okraj && s.Y - y0 >= okraj && y1 - s.Y >= okraj;
}
