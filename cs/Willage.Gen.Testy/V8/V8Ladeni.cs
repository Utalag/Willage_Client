using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.V8;

/// <summary>Ladicí výpis jednoho sloupce GEO1 × GEO2 (<c>--jen=GEO2V8L --blok=ox,oy,x,y</c>).</summary>
public static class V8Ladeni
{
    public static void Sloupec(string data, double ox, double oy, double x, double y)
    {
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        var (k, r) = KontextBlokuE84.Sestav(g.Geo, kat, SadaE84.Json(d), OblastBloku.Ctverec(ox, oy, 128), null, 1);
        var m1 = g.Geo.VyplnSloupec(x, y, 0.25, 128);
        var v2 = new Vzorek[512]; k.Sloupec(x, y, 0, 0.25, v2);
        var w = g.Svet.Vahy(x, y); double zp1 = g.Svet.VyskaW(x, y, w), zp2 = k.Povrch(x, y);
        Console.WriteLine($"  zPov GEO1 {zp1:F4}, GEO2 {zp2:F4}");
        var s = g.Svet.Sopky.Seznam; var (bi, br2) = g.Geo.Sopky.Nejblizsi(x, y);
        if (bi >= 0) { var q = s[bi]; double zk = q.VyskaOkoli + g.Svet.Sopky.Kuzel(bi, Math.Sqrt(br2)); Console.WriteLine($"  sopka {bi}: r {Math.Sqrt(br2):F3}, zPovKuz {zk:F4}, slupka {g.Svet.P.SopkaSlupkaM}"); }
        for (int i = 0; i < 512; i++)
        {
            if (m1[i] == v2[i].Material) continue;
            double z = (i + 0.5) * 0.25;
            Console.WriteLine($"  z {z:F3}: GEO1 {kat.PodleId(m1[i])?.Klic}, GEO2 {kat.PodleId(v2[i].Material)?.Klic} (udalost {v2[i].GeoUdalost}), Sopky.Mat {g.Geo.Sopky.Mat(x, y, z)}, Bod2 {k.Chronologie.Vzorek(x, y, z, zp2).Material}");
        }
        var kp = (KontaktniPasmo)k.Chronologie.Udalosti[k.Chronologie.IndexUdalosti("skarn_kontakt")].Kontakt!;
        for (int i = 0; i < 512; i++)
        {
            if (m1[i] == v2[i].Material) continue;
            double z = (i + 0.5) * 0.25; var st = k.Chronologie.Bod(x, y, z, zp2);
            bool ok = kp.Plochy[0].Nejblizsi(x, y, z, 4, out var bp);
            bool pl = kp.Plati(x, y, z, st, k.Chronologie, k.Chronologie.IndexUdalosti("skarn_kontakt"), zp2, out bool od);
            Console.WriteLine($"  z {z:F3}: D {(ok ? bp.D : double.NaN):F3} (odhad {(ok ? bp.Odhad : false)}), pasmo.Plati {pl} (odhad {od}), plocha n=({bp.Nx:F2},{bp.Ny:F2},{bp.Nz:F2})");
        }
        var b = new List<Beh>(); k.Behy(x, y, 128, b);
        foreach (var e in b.Where(e => e.Z1 > 60 && e.Z0 < 80)) Console.WriteLine($"  beh [{e.Z0:F4}, {e.Z1:F4}) mat {kat.PodleId(e.Stav.Material)?.Klic} hr {e.HraniceZ0}");
    }
}
