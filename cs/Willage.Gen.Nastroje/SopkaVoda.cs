using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Materialy;
using Willage.Gen.Svet;
using Willage.Gen.Voda;

namespace Willage.Gen.Nastroje;

/// <summary>Voda v bloku se sopkou s přepínačem SopkaNepropustna vyp / zap (geologie s opravami, stejná).</summary>
public static class SopkaVoda
{
    public static void Spust(DataSveta d)
    {
        var geo = new GeologieCs(new ParametrySveta(), d);
        var kat = KatalogMaterialu.ZeSouboru(d.KatalogMaterialu);
        var pv0 = ParametryVody.ZJson(File.ReadAllText(d.VodaV1));
        foreach (var s in geo.Svet.Sopky.Seznam)
        {
            int bx = (int)Math.Floor(s.X / 128), by = (int)Math.Floor(s.Y / 128);
            Console.WriteLine($"sopka ({s.X:F1}, {s.Y:F1}) H {s.H:F1} m R {s.R:F1} m → blok {bx},{by}");
            foreach (bool zap in new[] { false, true })
            {
                var fn = new PodzemniVodaFn(geo, kat, pv0 with { SopkaNepropustna = zap });
                var bl = fn.Blok(bx, by, 2.0, true);
                int vSopce = 0, sev = 0, sevArt = 0, nas = 0, vTes = 0;
                for (int k = 0; k < bl.L.Length; k++)
                {
                    double x = bx * 128 + (k % bl.N + 0.5) * 2, y = by * 128 + (k / bl.N + 0.5) * 2;
                    if (geo.Geo.Sopky.Nejblizsi(x, y).i < 0) continue;
                    vSopce++;
                    var p = bl.Profily[k]!;
                    if (p.Nasyceno is not null) nas++;
                    if (p.HladinaVTesneni) vTes++;
                    foreach (var v in p.Sevrene)
                    {
                        sev++;
                        var t = fn.TlakovaVyska(x, y, v);
                        if (t is not null && t.Value > v.Hi && t.Value > p.Povrch) sevArt++;
                    }
                }
                int prSopka = bl.Prameny.Count(pr => geo.Geo.Sopky.Nejblizsi(pr.X, pr.Y).i >= 0);
                Console.WriteLine($"  SopkaNepropustna={zap}: sloupců v sopce {vSopce}, volná zvodeň {nas}, hladina v těsnění {vTes}, " +
                                  $"sevřených vrstev {sev} (artéských {sevArt}), pramenů v bloku {bl.Prameny.Count} (v sopce {prSopka}), otisk {OtiskVody.Blok(bl)}");
            }
        }
    }
}
