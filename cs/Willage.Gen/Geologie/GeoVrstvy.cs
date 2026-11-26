using Willage.Gen.Data;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>Port scripts/v1/geo_vrstvy.gd (krok 3 + 3b): bod(x, y, z) a vypln_sloupec – vzduch / sopka / útvar / vrstva.</summary>
public sealed class GeoVrstvy
{
    public SvetFn Svet { get; }
    public KatalogHornin Katalog { get; }
    public SumHornin Sum { get; }
    public MinceE82 Mince { get; }
    public VrstvySloupce Vrstvy { get; }
    public NitroSopky Sopky { get; }
    public Utvary Utvary { get; }

    public GeoVrstvy(SvetFn s, DataSveta d)
    {
        Svet = s;
        Katalog = new KatalogHornin(d);
        Sum = new SumHornin(s.H, s.P.A10SumHornin, d);
        Mince = new MinceE82(s.P);
        Vrstvy = new VrstvySloupce(s, Katalog, Sum, Mince);
        Sopky = new NitroSopky(s);
        Utvary = new Utvary(s.Sd, new HostiteleUtvaru(s.P.A1Hostitele, d), new TvorbaUtvaru(s));
    }

    public List<Hranice> Hranice(double x, double y)
    {
        var w = Svet.Vahy(x, y);
        return Vrstvy.Hranice(x, y, w, Svet.VyskaTvar(x, y), Svet.VyskaW(x, y, w));
    }

    public int Bod(double x, double y, double z)
    {
        var w = Svet.Vahy(x, y);
        double zPov = Svet.VyskaW(x, y, w);
        if (z > zPov) return 0;
        int sm = Sopky.Mat(x, y, z);
        if (sm >= 0) return sm;
        var hr = Vrstvy.Hranice(x, y, w, Svet.VyskaTvar(x, y), zPov);
        int vm = VrstvySloupce.VrstvaMat(z, hr);
        int um = Utvary.MatFeats(Utvary.Tvorba.Features(x, y), x, y, z, vm, zPov, hr);
        return um >= 0 ? um : vm;
    }

    /// <summary>G-6: režim sloupce pro izolaci v náhledu M3 (jako GeoLab): vše, jen vrstvy (bez útvarů a nitra sopek), jen útvary + nitro sopek (ostatní 0).</summary>
    public enum RezimSloupce { Vse, JenVrstvy, JenUtvary }

    /// <summary>
    /// G-6: VyplnSloupec s režimem izolace. Režim Vse dává stejné bajty jako VyplnSloupec (test). Jen pro náhledy – hra ani klíče to nečtou.
    /// </summary>
    public byte[] VyplnSloupecRezim(double x, double y, double krokZ, double zmax, RezimSloupce rezim)
    {
        var w = Svet.Vahy(x, y);
        double zPov = Svet.VyskaW(x, y, w);
        var hr = Vrstvy.Hranice(x, y, w, Svet.VyskaTvar(x, y), zPov);
        var feats = Utvary.Tvorba.Features(x, y);
        int n = (int)Math.Ceiling(zmax / krokZ);
        var a = new byte[n];
        for (int iz = 0; iz < n; iz++)
        {
            double z = (iz + 0.5) * krokZ;
            if (z > zPov) { a[iz] = 0; continue; }
            int vm = VrstvySloupce.VrstvaMat(z, hr);
            if (rezim == RezimSloupce.JenVrstvy) { a[iz] = (byte)vm; continue; }
            int sm = Sopky.Mat(x, y, z);
            if (sm >= 0) { a[iz] = (byte)sm; continue; }
            int um = Utvary.MatFeats(feats, x, y, z, vm, zPov, hr);
            a[iz] = (byte)(um >= 0 ? um : rezim == RezimSloupce.JenUtvary ? 0 : vm);
        }
        return a;
    }

    /// <summary>Sloupec po kroku krokZ do zmax (středy buněk); volitelně maska buněk nitra sopky.</summary>
    public byte[] VyplnSloupec(double x, double y, double krokZ, double zmax, bool[]? nitro = null)
    {
        var w = Svet.Vahy(x, y);
        double zPov = Svet.VyskaW(x, y, w);
        var hr = Vrstvy.Hranice(x, y, w, Svet.VyskaTvar(x, y), zPov);
        var feats = Utvary.Tvorba.Features(x, y);
        int n = (int)Math.Ceiling(zmax / krokZ);
        var a = new byte[n];
        for (int iz = 0; iz < n; iz++)
        {
            double z = (iz + 0.5) * krokZ;
            if (z > zPov) { a[iz] = 0; continue; }
            int sm = Sopky.Mat(x, y, z);
            if (sm >= 0) { a[iz] = (byte)sm; if (nitro is not null) nitro[iz] = true; continue; }
            int vm = VrstvySloupce.VrstvaMat(z, hr);
            int um = Utvary.MatFeats(feats, x, y, z, vm, zPov, hr);
            a[iz] = (byte)(um >= 0 ? um : vm);
        }
        return a;
    }
}
