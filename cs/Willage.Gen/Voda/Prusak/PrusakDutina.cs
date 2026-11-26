using Willage.Gen.Jadro;
using Willage.Gen.Materialy;

namespace Willage.Gen.Voda.Prusak;

/// <summary>
/// Plnění uzavřené dutiny pod hladinou podzemní vody průsakem stěnami. Celočíselně (Int128, objem v pikolitrech), krok 10 s.
/// Tok jedné stěnové buňky = X_min(cesta) [l/s při spádu 1, stávající pravidlo minima] × T(cesta) [jen při zapnutém koeficientu]
/// × spád, kde spád = (H − max(h, z buňky)) / (H − dno). Stěna do vzduchu (díra) = otevřená buňka, jmenovitě 1 l/s.
/// Dutina je odvzdušněná: voda stoupá nejvýš na min(H, strop).
/// </summary>
public sealed class PrusakDutina
{
    public const int KrokS = 10;
    private const long PlPerUl = 1_000_000;
    private const long MmCell = GeologyGridConstants.CellEdgeMillimetres;

    /// <summary>Jmenovitý tok otevřené stěnové buňky (l/s) – příklad „buňka 1 l/s“ z 1.8.</summary>
    public const double OtevrenaLs = 1.0;

    private readonly record struct Skupina(long Pocet, long ZMm, long RateUlS, long T);

    private readonly Skupina[] _sk;
    private readonly long _dnoMm, _hMm, _stropMm, _plochaMm2, _rovnovahaMm;
    private Int128 _objemPl;   // pikolitry (1 µl = 10⁶ pl; 1 mm³ = 1 µl)

    public bool Koeficient { get; }
    public long Cas { get; private set; }
    public double HladinaM => (_dnoMm + (double)(_objemPl / PlPerUl) / _plochaMm2) / 1000.0;
    public double RovnovahaM => _rovnovahaMm / 1000.0;
    /// <summary>Plnění 0–1 vzhledem k rovnovážné výšce.</summary>
    public double Plneni => _rovnovahaMm == _dnoMm ? 1.0 : Math.Min(1.0, ((double)(_objemPl / PlPerUl) / _plochaMm2) / (_rovnovahaMm - _dnoMm));
    public long ObjemUl => (long)(_objemPl / PlPerUl);

    public PrusakDutina(ZadaniDutiny z, Propustnost pr, PrusakKoeficient? koef)
    {
        Koeficient = koef is not null;
        _dnoMm = (long)Math.Round(z.DnoM * 1000); _hMm = (long)Math.Round(z.HladinaVenkuM * 1000);
        _stropMm = _dnoMm + z.VyskaBunek * MmCell;
        _plochaMm2 = (long)z.SirkaBunek * MmCell * z.HloubkaBunek * MmCell;
        _rovnovahaMm = Math.Min(_hMm, _stropMm);
        var sk = new List<Skupina>();
        long Ul(StenaDutiny s)
        {
            if (s.Cesta.Length == 1 && s.Cesta[0] == Propustnost.Vzduch) return (long)Math.Round(OtevrenaLs * PlPerUl);
            double x = double.PositiveInfinity;
            foreach (int m in s.Cesta) x = Propustnost.Rozhrani(x, pr.X(m));
            return (long)Math.Round(x * PlPerUl);   // l/s → µl/s
        }
        long Teta(StenaDutiny s) => koef is null ? PrusakUtlum.Jedna : PrusakUtlum.Cesta(s.Cesta, koef);
        void Pridej(long pocet, long zMm, StenaDutiny s)
        {
            if (pocet > 0 && zMm < _hMm) sk.Add(new Skupina(pocet, zMm, Ul(s), Teta(s)));
        }
        int dir = Math.Min(z.DirBocnich, 4 * z.VyskaBunek * Math.Max(z.SirkaBunek, z.HloubkaBunek));
        long boku = 2L * (z.SirkaBunek + z.HloubkaBunek);   // buněk na jedné vrstvě obvodu
        for (int k = 0; k < z.VyskaBunek; k++)
        {
            long zMm = _dnoMm + k * MmCell + MmCell / 2;
            Pridej(boku, zMm, z.Bocni);
        }
        Pridej((long)z.SirkaBunek * z.HloubkaBunek, _dnoMm, z.Dno);
        Pridej((long)z.SirkaBunek * z.HloubkaBunek, _stropMm, z.Strop);
        if (dir > 0)
        {   // díry: nejnižší vrstva obvodu; skupina ze stěny se zmenší o díry a přidá se otevřená buňka
            long zMm = _dnoMm + MmCell / 2;
            var i = sk.FindIndex(s => s.ZMm == zMm && s.Pocet == boku);
            if (i >= 0) sk[i] = sk[i] with { Pocet = sk[i].Pocet - dir };
            Pridej(dir, zMm, StenaDutiny.Otevrena);
        }
        _sk = sk.ToArray();
    }

    /// <summary>Jeden krok 10 s.</summary>
    public void Krok()
    {
        long hMm = _dnoMm + (long)(_objemPl / PlPerUl / _plochaMm2);
        long rovnovahaMm = _rovnovahaMm;
        long norm = Math.Max(1, _hMm - _dnoMm);
        Int128 prirustek = 0;
        foreach (var s in _sk)
        {
            long hl = Math.Max(hMm, s.ZMm);
            long spad = Math.Max(0, _hMm - hl);
            // µl/s × pocet × s × T / 2^24 × spad/norm → v pl
            Int128 q = (Int128)s.RateUlS * s.Pocet * KrokS * PlPerUl;
            q = q * s.T >> PrusakUtlum.Q;
            prirustek += q * spad / norm;
        }
        _objemPl += prirustek;
        Int128 maxPl = (Int128)(rovnovahaMm - _dnoMm) * _plochaMm2 * PlPerUl;
        if (_objemPl > maxPl) _objemPl = maxPl;
        Cas += KrokS;
    }

    public void Beh(long doS) { while (Cas < doS) Krok(); }
}
