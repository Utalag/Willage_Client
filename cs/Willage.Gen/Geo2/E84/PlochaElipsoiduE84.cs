using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Těleso E84 s elipsoidem bez šumu (čočka, dóm, komín) přes index bloku: navíc vzdálenost k primitivu (2.5, 2.6), takže smí být cílem kontaktu (K4).
/// </summary>
public sealed class TvarE84Elipsoid : TvarE84Index, ITvarSVzdalenosti
{
    public IPlochaKontaktu Plocha { get; }
    public TvarE84Elipsoid(GeoVrstvy g, ZasobnikVrstvySloupce zas, DruhUtvaru druh) : base(g, zas, druh)
    {
        if (!PrimkaE84.JeElipsoid(druh)) throw new ArgumentException("jen čočka, dóm, komín", nameof(druh));
        Plocha = new PlochaElipsoiduE84(this);
    }
}

/// <summary>
/// Povrch instancí elipsoidu jednoho druhu (2.5): d̃ = min přes instance v dosahu přesné vzdálenosti bod–elipsoid (<see cref="VzdalenostElipsoidu"/>,
/// δ_S = 0 ≤ e_k). Měří se k primitivu: bez ořezu obálkou staré cesty a bez podmínky rozsahu buněk <c>Features</c>. Instance
/// s neortonormálními osami: vzdálenost = |SDF| s příznakem <see cref="BodPlochy.Odhad"/>. Vláknově bezpečná po přípravě indexu.
/// </summary>
public sealed class PlochaElipsoiduE84 : IPlochaKontaktu, IPlochaSRozsahem
{
    private readonly TvarE84Index _t;
    [ThreadStatic] private static List<int>? t_k;
    public PlochaElipsoiduE84(TvarE84Index t) => _t = t;

    private IndexUtvaruE84 Ix => _t.Index ?? throw new InvalidOperationException("PlochaElipsoiduE84: kontext bloku není připraven");

    public bool Nejblizsi(double x, double y, double z, double rMax, out BodPlochy b)
    {
        b = default; bool ok = false; double best = rMax;
        var k = t_k ??= new(); var ix = Ix;
        ix.Okoli(x, y, z, rMax, k);
        foreach (int i in k)
        {
            var P = ix.Polozky[i].F.P;
            if (!Ortonormalni(P))
            {
                // nejde přesně: hrubý odhad z SDF (není ≤ e_k zaručeno)
                double sdf = _t.SdfPolozky(i, x, y, z), d0 = Math.Abs(sdf);
                if (d0 < best) { best = d0; b = new BodPlochy(x, y, z, 0, 0, 1, d0, true); ok = true; }
                continue;
            }
            double d = VzdalenostElipsoidu.Nejblizsi(x, y, z, P[0], P[1], P[2], P.AsSpan(3, 9), P[12], P[13], P[14],
                out var px, out var py, out var pz, out var nx, out var ny, out var nz);
            if (d < best || (!ok && d <= best)) { best = d; b = new BodPlochy(px, py, pz, nx, ny, nz, d); ok = true; }
        }
        return ok;
    }

    /// <summary>Kde ve sloupci může být povrch blíž než r: tětiva elipsoidu s poloosami r_i + r (⊇ E ⊕ B_r); neortonormální: obálka ± r.</summary>
    public void RozsahZ(double x, double y, double r, List<(double A, double B)> cil)
    {
        var k = t_k ??= new(); var ix = Ix;
        ix.OkoliSloupce(x, y, r, k);
        var pr = Primka.Svisla(x, y);
        foreach (int i in k)
        {
            var pol = ix.Polozky[i];
            if (!Ortonormalni(pol.F.P)) { cil.Add((pol.Z0 - r, pol.Z1 + r)); continue; }
            if (PrimkaE84.Tetiva(pol.F, pr, r, out var a, out var b)) cil.Add((a, b));
        }
    }

    internal static bool Ortonormalni(double[] P)
    {
        double D(int i, int j) => P[i] * P[j] + P[i + 1] * P[j + 1] + P[i + 2] * P[j + 2];
        const double e = 1e-9;
        return Math.Abs(D(3, 3) - 1) < e && Math.Abs(D(6, 6) - 1) < e && Math.Abs(D(9, 9) - 1) < e
            && Math.Abs(D(3, 6)) < e && Math.Abs(D(3, 9)) < e && Math.Abs(D(6, 9)) < e;
    }
}
