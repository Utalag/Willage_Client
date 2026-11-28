using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2;

public enum StranaKontaktu { Vne, Uvnitr, Obe }

/// <summary>Zkompilovaná data <c>pravidla.kontakt</c> (2.5). Jednotky: m, 1/m; <c>A</c> bezrozměrné.</summary>
public sealed record ParametryKontaktu(
    IReadOnlySet<int> CilVrstvy, IReadOnlyList<string> CilUdalosti, StranaKontaktu Strana,
    double SirkaM, double AmpRel, double Frekvence1M, FiltrMaterialu? HostitelOkoli, double HloubkaVzorkuM);

/// <summary>
/// Kontaktní pásmo 2.5. w(q) = w₀(1 + a·N(f·q)) [m], N = VNoise se seedem události (|N| ≤ 1).
/// v pásmu ⇔ d̃(q) ≤ w(q) ∧ strana(q) ∧ hostitel_okoli(q); R_max = w₀(1 + a) + e_k je dosah hledání.
/// Členství v cíli T se čte ze stavu bodu těsně před událostí, ne ze znaménka funkce.
/// q′ = π(q) + η·u, u = (π − q)/|π − q|; u bodu na ploše (|π − q| &lt; 2⁻¹⁰ m) normála S orientovaná přes kontakt.
/// </summary>
public sealed class KontaktniPasmo : IKontaktniPasmo, IIntervalyKontaktu
{
    [ThreadStatic] private static List<(double A, double B)>? t_rozsah;
    /// <summary>Diagnostika (lokální vláknu): vyhodnocení d̃ − w při chůzi sloupcem (K4).</summary>
    [ThreadStatic] public static long KrokuChuze;

    private const double MinU = 1.0 / 1024.0;
    private readonly ParametryKontaktu _p;
    private readonly IReadOnlyList<IPlochaKontaktu> _plochy;
    private readonly bool[] _cilVrstvy;
    private readonly HashSet<int> _cilUdalosti;
    public long Seed { get; }
    public double RMaxM { get; }
    public ParametryKontaktu Parametry => _p;
    public IReadOnlyList<IPlochaKontaktu> Plochy => _plochy;

    public KontaktniPasmo(ParametryKontaktu p, IReadOnlyList<IPlochaKontaktu> plochy, IEnumerable<int> cilUdalostiIndexy, long seed,
        double tolerancKontaktuM, int maxId)
    {
        _p = p; _plochy = plochy; Seed = seed;
        _cilVrstvy = new bool[Math.Max(maxId + 1, 1)];
        foreach (var m in p.CilVrstvy) if (m >= 0 && m < _cilVrstvy.Length) _cilVrstvy[m] = true;
        _cilUdalosti = cilUdalostiIndexy.ToHashSet();
        RMaxM = p.SirkaM * (1.0 + p.AmpRel) + tolerancKontaktuM;
    }

    /// <summary>Je bod (stav těsně před kontaktem) v cíli T? Původ ve vrstvě cíle, nebo v cílové události.</summary>
    public bool VCili(in StavBodu s)
    {
        if (s.Typ != TypProstoru.Pevne) return false;
        if (s.GeoOperace == Operace.Uloz && s.GeoUdalost >= 0)
            return s.MaterialPuvodu >= 0 && s.MaterialPuvodu < _cilVrstvy.Length && _cilVrstvy[s.MaterialPuvodu];
        return _cilUdalosti.Contains(s.GeoUdalost);
    }

    /// <summary>Šířka pásma v bodě [m].</summary>
    public double Sirka(double x, double y, double z)
    {
        if (_p.AmpRel == 0) return _p.SirkaM;
        double f = _p.Frekvence1M;
        return _p.SirkaM * (1.0 + _p.AmpRel * VNoise.Noise(Seed, x * f, y * f, z * f));
    }

    /// <summary>Nejbližší bod S přes všechny plochy cíle (shoda: dřívější plocha v pořadí cíle).</summary>
    public bool Nejblizsi(double x, double y, double z, out BodPlochy b)
    {
        b = default; bool ok = false; double r = RMaxM;
        foreach (var pl in _plochy)
            if (pl.Nejblizsi(x, y, z, r, out var c) && (!ok || c.D < b.D)) { b = c; ok = true; r = c.D; }
        return ok;
    }

    public bool Plati(double x, double y, double z, in StavBodu stav, ChronologieGeo2 c, int index, double zPov, out bool odhad)
    {
        odhad = false;
        bool vT = VCili(stav);
        if (_p.Strana == StranaKontaktu.Vne && vT) return false;
        if (_p.Strana == StranaKontaktu.Uvnitr && !vT) return false;
        if (!Nejblizsi(x, y, z, out var b)) return false;
        odhad = b.Odhad;
        if (b.D > Sirka(x, y, z)) return false;
        if (_p.HostitelOkoli is null) return true;
        double eta = _p.HloubkaVzorkuM, ux, uy, uz;
        if (b.D >= MinU) { ux = (b.X - x) / b.D; uy = (b.Y - y) / b.D; uz = (b.Z - z) / b.D; }
        else
        {
            // bod na ploše: normála směrem na druhou stranu (tam, kde se členství v T liší)
            var s1 = Pred(c, index, b.X + eta * b.Nx, b.Y + eta * b.Ny, b.Z + eta * b.Nz, zPov);
            bool otoc = VCili(s1) == vT;
            ux = otoc ? -b.Nx : b.Nx; uy = otoc ? -b.Ny : b.Ny; uz = otoc ? -b.Nz : b.Nz;
        }
        var s2 = Pred(c, index, b.X + eta * ux, b.Y + eta * uy, b.Z + eta * uz, zPov);
        return s2.Typ == TypProstoru.Pevne && _p.HostitelOkoli.Plati(s2.Material);
    }

    /// <summary>Lipschitzova konstanta f(z) = d̃ − w podél přímky: 1 (vzdálenost) + w₀·a·f·3 (|∂N/∂u| ≤ 3 u VNoise).</summary>
    public double LipschitzF => 1.0 + _p.SirkaM * _p.AmpRel * _p.Frekvence1M * 3.0;

    /// <summary>
    /// Pásmo ve sloupci (K4, 1.7): v povolených úsecích ∩ rozsahu ploch do w_max = w₀(1 + a) jde chůzí s f = min(d̃, R_max) − w:
    /// f/L ≥ h → přeskok o f/L (f &gt; 0 jistě, mimo pásmo), jinak [z, z + max(h, −f/L)] nejisté. Plocha bez rozsahu → celé povolené úseky nejisté.
    /// </summary>
    public void Sloupec(double x, double y, IReadOnlyList<(double A, double B)> povolene, double h, SegmentaceSloupce seg)
    {
        double wMax = _p.SirkaM * (1.0 + Math.Abs(_p.AmpRel)), L = 1.0 + _p.SirkaM * Math.Abs(_p.AmpRel) * _p.Frekvence1M * 3.0;
        var roz = t_rozsah ??= new(); roz.Clear();
        foreach (var pl in _plochy)
        {
            if (pl is IPlochaSRozsahem pr) pr.RozsahZ(x, y, wMax, roz);
            else { foreach (var (a, b) in povolene) seg.Nejista(a, b); return; }
        }
        if (roz.Count == 0) return;
        roz.Sort((a, b) => a.A.CompareTo(b.A));
        int w = 0;
        for (int k = 0; k < roz.Count; k++)
            if (w > 0 && roz[k].A <= roz[w - 1].B) roz[w - 1] = (roz[w - 1].A, Math.Max(roz[w - 1].B, roz[k].B)); else roz[w++] = roz[k];
        roz.RemoveRange(w, roz.Count - w);
        int j = 0;
        foreach (var (pa, pb) in povolene)
        {
            while (j < roz.Count && roz[j].B < pa) j++;
            for (int k = j; k < roz.Count && roz[k].A <= pb; k++)
            {
                double a = Math.Max(Math.Max(pa, roz[k].A), seg.Z0), b = Math.Min(Math.Min(pb, roz[k].B), seg.Z1);
                double z = a;
                while (z < b)
                {
                    KrokuChuze++;
                    double d = Nejblizsi(x, y, z, out var bp) ? Math.Min(bp.D, RMaxM) : RMaxM;
                    double f = d - Sirka(x, y, z);
                    if (f >= L * h) { z += f / L; continue; }
                    // f < L·h: [z, z + h] může být v pásmu; hluboko v pásmu (f < 0) je celé [z, z + |f|/L] v pásmu – stejně nejisté (hostitel q′)
                    double skok = Math.Max(h, -f / L);
                    seg.Nejista(z, Math.Min(z + skok, b)); z += skok;
                }
            }
        }
    }

    private static StavBodu Pred(ChronologieGeo2 c, int index, double x, double y, double z, double zPov) =>
        c.BodPredSPovrchemSloupce(index, x, y, z, zPov);
}
