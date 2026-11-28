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
        var ch = k.Chronologie; int iu = ch.IndexUdalosti("skarn_kontakt"); var par = kp.Parametry;
        for (int i = 0; i < 512; i++)
        {
            if (m1[i] == v2[i].Material) continue;
            double z = (i + 0.5) * 0.25; var st = ch.Bod(x, y, z, zp2);
            bool vT = kp.VCili(st); bool ok = kp.Nejblizsi(x, y, z, out var b2);
            double eta = par.HloubkaVzorkuM, dd = b2.D;
            double ux = (b2.X - x) / dd, uy = (b2.Y - y) / dd, uz = (b2.Z - z) / dd;
            var s2 = ch.BodPred(iu, b2.X + eta * ux, b2.Y + eta * uy, b2.Z + eta * uz, ch.Povrch?.Invoke(b2.X + eta * ux, b2.Y + eta * uy) ?? zp2);
            Console.WriteLine($"  z {z:F3}: stav pred: mat {kat.PodleId(st.Material)?.Klic} typ {st.Typ} vT {vT} strana {par.Strana}; D {dd:F3} Sirka {kp.Sirka(x, y, z):F3}; bod plochy ({b2.X:F3},{b2.Y:F3},{b2.Z:F3}) odhad {b2.Odhad}; q' ({b2.X + eta * ux:F3},{b2.Y + eta * uy:F3},{b2.Z + eta * uz:F3}) eta {eta}: mat {kat.PodleId(s2.Material)?.Klic} typ {s2.Typ} hostitelOk {(par.HostitelOkoli is null ? "-" : par.HostitelOkoli.Plati(s2.Material).ToString())}");
        }
        {
            void Stack(string n, double sx, double sy)
            {
                var w2 = g.Svet.Vahy(sx, sy); double zq = g.Svet.VyskaW(sx, sy, w2);
                var hh = g.Geo.Vrstvy.Hranice(sx, sy, w2, g.Svet.VyskaTvar(sx, sy), zq);
                Console.WriteLine($"  vrstvy {n} ({sx:F3},{sy:F3}) zPov {zq:F3}: " + string.Join("; ", hh.Where(e => e.Z1 > 30 && e.Z0 < 46).Select(e => $"id {e.Id} {kat.PodleId(e.Id)?.Klic} [{e.Z0:F3},{e.Z1:F3}]")));
            }
            Stack("sloupec", x, y);
            for (int i = 0; i < 512; i++)
            {
                if (m1[i] == v2[i].Material) continue; double z = (i + 0.5) * 0.25;
                if (kp.Nejblizsi(x, y, z, out var b3)) { Stack("plocha", b3.X, b3.Y); break; }
            }
        }
        {
            for (int i = 0; i < 512; i++)
            {
                if (m1[i] == v2[i].Material) continue; double z = (i + 0.5) * 0.25;
                if (!kp.Nejblizsi(x, y, z, out var b4)) continue;
                double dd = b4.D, eta = kp.Parametry.HloubkaVzorkuM; double qx = b4.X + eta * (b4.X - x) / dd, qy = b4.Y + eta * (b4.Y - y) / dd;
                var w3 = g.Svet.Vahy(qx, qy); double zq = g.Svet.VyskaW(qx, qy, w3);
                var hq = g.Geo.Vrstvy.Hranice(qx, qy, w3, g.Svet.VyskaTvar(qx, qy), zq);
                Console.WriteLine($"  q' xy ({qx:F3},{qy:F3}) zPov {zq:F3} GEO1 vrstvy: " + string.Join("; ", hq.Where(e => e.Z1 > 30 && e.Z0 < 46).Select(e => $"{kat.PodleId(e.Id)?.Klic} [{e.Z0:F3},{e.Z1:F3}]")));
                var sb = new System.Text.StringBuilder("  q' BodPred po z: ");
                for (double zz = 36.0; zz <= 37.3; zz += 0.1) sb.Append($"{zz:F1}:{kat.PodleId(ch.BodPred(iu, qx, qy, zz, ch.Povrch?.Invoke(qx, qy) ?? zp2).Material)?.Klic} ");
                Console.WriteLine(sb.ToString());
                break;
            }
        }
        var b = new List<Beh>(); k.Behy(x, y, 128, b);
        foreach (var e in b.Where(e => e.Z1 > 60 && e.Z0 < 80)) Console.WriteLine($"  beh [{e.Z0:F4}, {e.Z1:F4}) mat {kat.PodleId(e.Stav.Material)?.Klic} hr {e.HraniceZ0}");
    }
}
