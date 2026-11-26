using Willage.Gen.Api.Dto;
using Willage.Gen.Klima;

namespace Willage.Gen.Api.Sluzby;

/// <summary>IDotazySveta nad posledním během (SvetKrok06 z M7).</summary>
public sealed class DotazySvetaApi : IDotazySveta
{
    readonly StavGeneratoru _s;
    public DotazySvetaApi(StavGeneratoru s) => _s = s;
    Eroze.SvetKrok06 Svet => _s.Hotovo().Svet;

    public SloupecDto Sloupec(SouradniceQ16 p)
    {
        var g = Svet.Geologie;
        return new SloupecDto(p, g.Povrch(p.XM, p.YM), g.Sloupec(p.XM, p.YM));
    }

    public BodDto Bod(SouradniceQ16 p)
    {
        var s = Svet; var g = s.Geologie; double h = g.Povrch(p.XM, p.YM);
        var k = s.Klima;
        return new BodDto(p, h, g.MaterialPovrchu(p.XM, p.YM), g.JeMoreVyska(p.XM, p.YM, h),
            k?.Teplota(p.XM, p.YM), k?.Srazky(p.XM, p.YM), k is null ? null : KlasifikaceBiomu.NazevCs[(int)k.Biom(p.XM, p.YM)]);
    }

    public RezDto Rez(SouradniceQ16 od, SouradniceQ16 @do, double krokM)
    {
        if (krokM <= 0) throw new ArgumentOutOfRangeException(nameof(krokM));
        var g = Svet.Geologie;
        double dx = @do.XM - od.XM, dy = @do.YM - od.YM, d = Math.Sqrt(dx * dx + dy * dy);
        int n = (int)Math.Floor(d / krokM) + 1;
        var h = new double[n];
        for (int i = 0; i < n; i++) { double t = d == 0 ? 0 : i * krokM / d; h[i] = g.Povrch(od.XM + t * dx, od.YM + t * dy); }
        return new RezDto(od, @do, krokM, h);
    }

    public MapaDto Mapa(VrstvaMapyDto v)
    {
        var s = Svet;
        if (v is VrstvaMapyDto.Vyska or VrstvaMapyDto.Eroze)
        {
            var m = s.Mapa ?? throw new InvalidOperationException("eroze planety je vypnutá (VseKrok06)");
            var h = v == VrstvaMapyDto.Vyska ? (float[])m.H.Clone() : Enumerable.Range(0, m.T.N).Select(m.E).ToArray();
            return new MapaDto(v, m.T.Nx, m.T.Ny, m.T.Krok, h);
        }
        var c = s.Klima?.Mapa ?? throw new InvalidOperationException("klima je vypnuté (KlimaKrok07)");
        float[] a = v switch
        {
            VrstvaMapyDto.Teplota => (float[])c.Teplota.Clone(),
            VrstvaMapyDto.Srazky => (float[])c.Srazky.Clone(),
            _ => c.Biom.Select(b => (float)(int)b).ToArray(),
        };
        return new MapaDto(v, c.T.Nx, c.T.Ny, c.T.Krok, a);
    }
}
