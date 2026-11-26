using Willage.Gen.Jadro;

namespace Willage.Gen.Materialy;

/// <summary>
/// Propustnost buňky podle 1.8.1: X = K × plocha stěny (0,0625 m²) × 1000 l/m³, v l/s herního času při spádu 1.
/// Rozhraní dvou materiálů = minimum. Propustné těleso: K ≥ prah (ponor_perm E67) nebo rozpustná hornina (kras67).
/// </summary>
public sealed class Propustnost
{
    public const int Vzduch = 0;
    private readonly KatalogMaterialu _kat;
    private readonly double[] _x = new double[256];
    private readonly bool[] _teleso = new bool[256];
    private readonly bool[] _rozp = new bool[256];

    /// <summary>Prah K (m/s): ponor_perm 0,3 → 10^(6·0,3 − 9) = 6,31e-8 (mapování E71).</summary>
    public double PrahKMs { get; }

    public Propustnost(KatalogMaterialu kat, double prahKMs = 6.309573444801943e-8)
    {
        _kat = kat; PrahKMs = prahKMs;
        for (int id = 0; id < 256; id++)
        {
            var m = id == Vzduch ? null : kat.Najdi(id);
            if (id == Vzduch) { _x[id] = double.PositiveInfinity; continue; }
            if (m is null) { _kat.NeznamaId.Remove(id); continue; }   // předvýpočet nehlásí; hlásí se až při použití
            double k = m.KMs ?? 0.0;
            _x[id] = k * GeologyGridConstants.CellFaceM2 * 1000.0;
            _rozp[id] = m.Rozpustny;
            _teleso[id] = k >= PrahKMs || m.Rozpustny;
        }
    }

    /// <summary>X buňky v l/s při spádu 1 (vzduch = ∞, otevřená stěna).</summary>
    public double X(int id) { Hlas(id); return _x[id & 0xFF]; }
    public static double Rozhrani(double a, double b) => Math.Min(a, b);
    public double Rozhrani(int a, int b) => Rozhrani(X(a), X(b));
    /// <summary>Propustné těleso (vodonosná vrstva).</summary>
    public bool Teleso(int id) { Hlas(id); return id != Vzduch && _teleso[id & 0xFF]; }
    public bool Rozpustny(int id) => _rozp[id & 0xFF];
    public bool Tesneni(int id) => id != Vzduch && !Teleso(id);

    private void Hlas(int id) { if (id != Vzduch && _x[id & 0xFF] == 0 && !_teleso[id & 0xFF]) _kat.Najdi(id); }
}
