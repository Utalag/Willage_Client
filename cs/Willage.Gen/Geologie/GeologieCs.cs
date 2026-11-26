using Willage.Gen.Data;
using Willage.Gen.Jadro;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>
/// IGeologie nativně v C# (krok 5): funkce světa kroků 1–3 bez Godotu. Nahrazuje most GeologieGd (ten zůstává jako reference).
/// Instance není vláknově bezpečná (cache útvarů); pro paralelní běh jedna instance na vlákno.
/// </summary>
public sealed class GeologieCs : IGeologie
{
    public SvetFn Svet { get; }
    public GeoVrstvy Geo { get; }
    private const double C = GeologyGridConstants.CellM, Zmax = GeologyGridConstants.ColumnM;

    public GeologieCs(ParametrySveta p, DataSveta d)
    {
        Svet = new SvetFn(p, d);
        Geo = new GeoVrstvy(Svet, d);
    }

    public double Povrch(double x, double y) => Svet.Vyska(x, y);
    public byte[] Sloupec(double x, double y) => Geo.VyplnSloupec(x, y, C, Zmax);

    public int MaterialPovrchu(double x, double y)
    {
        double p = Svet.Vyska(x, y);
        return Geo.Bod(x, y, Math.Floor((p - 1e-9) / C) * C + 0.125);
    }

    public double VyskaTvar(double x, double y) => Svet.VyskaTvar(x, y);
    public bool Mince82(double x, double y) => Geo.Mince.Sila(x, y) >= 0.5;
    public double Mince82Sila(double x, double y) => Geo.Mince.Sila(x, y);

    public bool VNitruSopky(double x, double y, double z) => Geo.Sopky.Mat(x, y, z) >= 0;

    public bool[]? NitroSopky(double x, double y)
    {
        if (Geo.Sopky.Nejblizsi(x, y).i < 0) return null;
        var m = new bool[GeologyGridConstants.CellsPerColumnHeight];
        Geo.VyplnSloupec(x, y, C, Zmax, m);
        return m;
    }
}
