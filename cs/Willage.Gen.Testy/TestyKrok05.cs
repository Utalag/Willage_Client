using System.Security.Cryptography;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Sum;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Testy;

/// <summary>Krok 5: port geologie do C# (ekvivalence s GDScriptem přes zlaté otisky) a opravy z kroku 4.</summary>
public static class TestyKrok05
{
    public static void Spust(KatalogMaterialu kat, Propustnost pr)
    {
        var data = DataSveta.Najdi(AppContext.BaseDirectory);

        T.Sekce("krok 5: matematika Godotu");
        T.Je(Gd.Smoothstep(1, 1, 0.5) == 0.0 && Gd.Smoothstep(1, 1, 1.5) == 1.0, "smoothstep se shodnými mezemi jako Godot");
        T.Blizko(Gd.Smoothstep(0, 2, 1), 0.5, 0, "smoothstep střed");
        T.Je(Gd.Round(-2.5) == -3 && Gd.Round(2.5) == 3, "round od nuly");
        T.Je(StableHash.Shr(-1, 60) == 15, "logický posun");

        T.Sekce("krok 5: ekvivalence s GDScriptem (zlaté otisky z tools/geo_cs_cas.gd, Godot 4.7.2)");
        var gp = new GeologieCs(ParametrySveta.Puvodni(), data);
        T.Je(Segment(gp, 2104, 2104) == "059d807ab04b7f00", "segment 8 m 2104,2104 = GDScript 059d807ab04b7f00");
        T.Je(Segment(gp, 2000, 1800) == "4391f413f91891ef", "segment 8 m 2000,1800 = GDScript 4391f413f91891ef");

        T.Sekce("krok 5: mince E82 spojitá přes šev");
        var p = new ParametrySveta(); var m = new MinceE82(p); var m0 = new MinceE82(ParametrySveta.Puvodni());
        double maxKrok = 0; int mimo = 0, mimoChyb = 0;
        for (double x = 1700; x < 2300; x += 0.05)
        {
            double y = 1984.3, a = m.Sila(x, y), b = m.Sila(x + 0.05, y);
            maxKrok = Math.Max(maxKrok, Math.Abs(a - b));
            double ds = Math.Abs(x - Math.Round(x / 128) * 128), dy = Math.Abs(y - Math.Round(y / 128) * 128);
            if (ds > 16.01 && dy > 16.01) { mimo++; if (a != (m0.Puvodni(x, y) ? 1.0 : 0.0)) mimoChyb++; }
        }
        T.Je(maxKrok < 0.01, $"max změna síly na 5 cm {maxKrok:F4} (< 0,01)");
        T.Je(mimo > 0 && mimoChyb == 0, $"mimo pás přechodu = mince bloku ({mimo} bodů, {mimoChyb} chyb)");
        var pv = ParametrySveta.Puvodni();
        T.Je(new MinceE82(pv).Sila(2047.9, 1984) is 0.0 or 1.0, "P82PrechodM = 0 → původní 0/1");

        T.Sekce("krok 5: nitro sopky nepropustné");
        var syn = new SyntetickaGeologie { Pov = (x, y) => 23.0 };
        var sl = syn.Sloupec(0, 0); var maska = new bool[sl.Length];
        for (int k = 0; k < sl.Length; k++) maska[k] = k * 0.25 < 23.0;
        var pr0 = ProfilSloupce.Spocti(sl, 23.0, 18.0, pr, 0.5);
        var pr1 = ProfilSloupce.Spocti(sl, 23.0, 18.0, pr, 0.5, maska);
        T.Je(pr0.Sevrene.Count == 1 && pr1.Sevrene.Count == 0 && pr1.Nasyceno is null && pr1.HladinaVTesneni, "maska nitra → bez sevřené i volné vody");
        T.Je(VykonPramene.Spocti(10, new[] { -1, -1, -1, -1, -1, -1 }, pr, false, 0).Vykon == 0, "sousedé v nitru sopky → výkon 0");
        var go = new GeologieCs(new ParametrySveta(), data);
        var s0 = go.Svet.Sopky.Seznam[0];
        var ni = go.NitroSopky(s0.X, s0.Y);
        T.Je(ni is not null && ni.Count(b => b) > 40, $"střed sopky: maska nitra {ni?.Count(b => b)} buněk");
        T.Je(go.NitroSopky(1792 + 64, 1792 + 64) is null, "mimo sopku maska null");

        T.Sekce("krok 5: hustota pramenů parametry (čtverec, pravděpodobnost)");
        var pvd = ParametryVody.ZJson(File.ReadAllText(data.VodaV1));
        var kes = new KesGeologie(go);
        int N(double b, double pp) => new PodzemniVodaFn(kes, kat, pvd with { BunkaPramenuM = b, PravdepodobnostBunky = pp }).Prameny.VOblasti(1792, 1792, 2176, 2176).Count;
        int a1 = N(32, 0.6), a2 = N(32, 1.0), a3 = N(16, 0.6);
        T.Je(a2 >= a1 && a3 >= a1 && a2 + a3 > 2 * a1, $"víc pramenů s p = 1 ({a2}) i čtvercem 16 m ({a3}) než výchozí ({a1})");
        T.Je(N(32, 0.0) == 0, "p = 0 → žádné prameny");
    }

    private static string Segment(GeologieCs g, double ox, double oy)
    {
        using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        for (int ix = 0; ix < 32; ix++)
        for (int iy = 0; iy < 32; iy++)
            sha.AppendData(g.Geo.VyplnSloupec(ox + (ix + 0.5) * 0.25, oy + (iy + 0.5) * 0.25, 0.25, 128.0));
        return Convert.ToHexString(sha.GetHashAndReset())[..16].ToLowerInvariant();
    }
}
