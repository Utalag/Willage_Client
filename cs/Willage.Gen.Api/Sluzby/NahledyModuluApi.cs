using System.Diagnostics;
using Willage.Gen.Api.Dto;
using Willage.Gen.Data;
using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Svet;

namespace Willage.Gen.Api.Sluzby;

/// <summary>
/// G-6: náhledy M1–M3 nad výstupy posledního běhu. Žádný vlastní výpočet světa – jen vzorkování funkcí modulů (SvetFn M1 bez moře,
/// SvetFn M2, GeologieCs M3) ve středech buněk mřížky. Řádky mapy se počítají paralelně (každý vzorek nezávislý → stejné hodnoty
/// jako sekvenčně); geologie má na vlákno vlastní Klon (keše útvarů). Výstupy modulů se nemění, otisky ne.
/// </summary>
public sealed class NahledyModuluApi : INahledyModulu
{
    readonly StavGeneratoru _s;
    IReadOnlyList<MaterialDto>? _mat;
    public NahledyModuluApi(StavGeneratoru s) => _s = s;

    static readonly Dictionary<string, VrstvaNahleduDto[]> _vrstvy = new()
    {
        ["M1"] = new[] { VrstvaNahleduDto.Vyska, VrstvaNahleduDto.Biom, VrstvaNahleduDto.Horniny, VrstvaNahleduDto.Sopky, VrstvaNahleduDto.Masiv, VrstvaNahleduDto.Relief },
        ["M2"] = new[] { VrstvaNahleduDto.Pevnina, VrstvaNahleduDto.More, VrstvaNahleduDto.Vyska, VrstvaNahleduDto.Panve, VrstvaNahleduDto.Sev, VrstvaNahleduDto.RozdilM2M1 },
        ["M3"] = new[] { VrstvaNahleduDto.MaterialPovrchu, VrstvaNahleduDto.Mince, VrstvaNahleduDto.Vyska },
    };

    public static IReadOnlyList<string> ModulySNahledem => _vrstvy.Keys.ToList();
    public static IReadOnlyList<VrstvaNahleduDto> VrstvyModulu(string modul) => _vrstvy.TryGetValue(modul, out var v) ? v : Array.Empty<VrstvaNahleduDto>();
    public static VrstvaNahleduDto? IzolaceModulu(string modul) => modul switch { "M1" => VrstvaNahleduDto.Relief, "M2" => VrstvaNahleduDto.RozdilM2M1, _ => null };

    public IReadOnlyList<string> Moduly() => ModulySNahledem;
    public IReadOnlyList<VrstvaNahleduDto> Vrstvy(string modul) => VrstvyModulu(modul);
    public VrstvaNahleduDto? Izolace(string modul) => IzolaceModulu(modul);

    SvetFn M1 => _s.Hotovo().Vystup<VystupFunkceSveta>(M1FunkceSveta.Id_).Svet;
    SvetFn M2 => _s.Hotovo().Vystup<SvetFn>(M2MoreAKontinenty.Id_);
    /// <summary>
    /// Geologie M3 bez eroze. Výstup M3 v paměti nejde použít: M7 do něj napojí erozi (g.Svet.Eroze = …, jediné místo mutace),
    /// takže po běhu ukazuje už erodovaný svět. Náhled modulu M3 = jeho vlastní výsledek (jako nástroj „rez“) → vlastní instance
    /// ze stejných parametrů, keš podle klíče M3.
    /// </summary>
    GeologieCs M3
    {
        get
        {
            string klic = _s.Hotovo().Klice[M3Geologie.Id_];
            if (_m3 is not null && _m3Klic == klic) return _m3;
            var (p, _) = _s.Sada.Sestav();
            _m3 = new GeologieCs(p.Kopie(), _s.Data); _m3Klic = klic;
            return _m3;
        }
    }
    GeologieCs? _m3; string? _m3Klic;

    /// <summary>Funkce vzorku vrstvy (x, y) → hodnota; pro M3 dostane vlastní klon geologie vlákna.</summary>
    Func<GeologieCs?, double, double, float> Vzorek(string modul, VrstvaNahleduDto v)
    {
        if (!VrstvyModulu(modul).Contains(v)) throw new ArgumentException($"modul {modul} nemá vrstvu {v}");
        switch (modul)
        {
            case "M1":
            {
                var s = M1;
                return v switch
                {
                    VrstvaNahleduDto.Vyska => (_, x, y) => (float)s.Vyska(x, y),
                    VrstvaNahleduDto.Biom => (_, x, y) => s.Sloupec(x, y).Biom,
                    VrstvaNahleduDto.Horniny => (_, x, y) => { var h = s.Sloupec(x, y).Horniny; return h.Count == 0 ? -1 : h[0].id; },
                    VrstvaNahleduDto.Sopky => (_, x, y) => s.SopkaV(x, y),
                    VrstvaNahleduDto.Masiv => (_, x, y) => (float)s.Masiv.Vaha(s.Vahy(x, y)[SvetFn.Hornatina]),
                    _ => (_, x, y) => (float)Relief(s, x, y),
                };
            }
            case "M2":
            {
                var s = M2; var s1 = v == VrstvaNahleduDto.RozdilM2M1 ? M1 : null;
                return v switch
                {
                    VrstvaNahleduDto.Vyska => (_, x, y) => (float)s.Vyska(x, y),
                    VrstvaNahleduDto.Pevnina => (_, x, y) => (float)(s.More?.Pevnina(x, y) ?? 1.0),
                    VrstvaNahleduDto.More => (_, x, y) => s.More is not null && s.More.JeMore(x, y, s.Vyska(x, y)) ? 1f : 0f,
                    VrstvaNahleduDto.Panve => (_, x, y) => (float)(s.Panve?.Posun(x, y) ?? 0.0),
                    VrstvaNahleduDto.Sev => (_, x, y) => (float)(s.More?.Maska.DoSevu(x, y) ?? double.NaN),
                    _ => (_, x, y) => (float)(s.Vyska(x, y) - s1!.Vyska(x, y)),
                };
            }
            default:
                return v switch
                {
                    VrstvaNahleduDto.MaterialPovrchu => (g, x, y) => g!.MaterialPovrchu(x, y),
                    VrstvaNahleduDto.Mince => (g, x, y) => (float)g!.Mince82Sila(x, y),
                    _ => (g, x, y) => (float)g!.Povrch(x, y),
                };
        }
    }

    /// <summary>Izolace M1 „jen reliéf bez moře“: NeutralM + Σ w·reliéf biomu (bez masivu, sopek, stropu a moře).</summary>
    public static double Relief(SvetFn s, double x, double y)
    {
        var w = s.Vahy(x, y); double h = s.NeutralM;
        for (int t = 0; t < 5; t++) if (w[t] > 0.0) h += w[t] * s.Relief.Rel(t, x, y);
        return h;
    }

    public NahledMapyDto Mapa(string modul, VrstvaNahleduDto vrstva, int rozliseni = 256, OblastQ16? oblast = null)
    {
        if (rozliseni < 1 || rozliseni > 2048) throw new ArgumentOutOfRangeException(nameof(rozliseni));
        var sw = Stopwatch.StartNew();
        var f = Vzorek(modul, vrstva);
        double svet = M2.SvetM;
        var o = oblast ?? new OblastQ16(new SouradniceQ16(0, 0), SouradniceQ16.ZMetru(svet, svet));
        double x0 = o.Od.XM, y0 = o.Od.YM, sx = o.Do.XM - x0, sy = o.Do.YM - y0;
        double krok = Math.Max(sx, sy) / rozliseni;
        int nx = Math.Max(1, (int)Math.Round(sx / krok)), ny = Math.Max(1, (int)Math.Round(sy / krok));
        var h = new float[nx * ny];
        var g3 = modul == "M3" ? M3 : null;
        Parallel.For(0, ny, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, () => g3?.Klon(), (j, _, g) =>
        {
            double y = y0 + (j + 0.5) * krok;
            for (int i = 0; i < nx; i++) h[j * nx + i] = f(g, x0 + (i + 0.5) * krok, y);
            return g;
        }, _ => { });
        var c = Cisla(modul, vrstva, h);
        bool izol = IzolaceModulu(modul) == vrstva;
        return new NahledMapyDto(modul, vrstva, izol, x0, y0, krok, nx, ny, h, Popis(modul, vrstva), c, sw.Elapsed.TotalMilliseconds);
    }

    Dictionary<string, double> Cisla(string modul, VrstvaNahleduDto v, float[] h)
    {
        var fin = h.Where(float.IsFinite).ToArray();
        var c = new Dictionary<string, double> { ["min"] = fin.Length == 0 ? double.NaN : fin.Min(), ["max"] = fin.Length == 0 ? double.NaN : fin.Max() };
        if (modul == "M1") { c["sopek"] = M1.Sopky.Seznam.Count; if (v == VrstvaNahleduDto.Sopky) c["podil_sopek"] = h.Count(x => x >= 0) / (double)h.Length; }
        if (modul == "M2")
        {
            var s = M2;
            c["more_zapnuto"] = s.More is null ? 0 : 1;
            if (s.More is not null) { c["podil_more_cil"] = s.More.Podil; c["kontinentu"] = s.More.Maska.Kontinentu; c["ostrovu"] = s.More.Maska.Ostrovu; }
            c["panvi"] = s.Panve?.Stredy.Count ?? 0;
            if (v == VrstvaNahleduDto.More) c["podil_more"] = h.Average(x => (double)x);
        }
        if (modul == "M3" && v == VrstvaNahleduDto.Mince) c["podil_mince"] = h.Count(x => x >= 0.5f) / (double)h.Length;
        return c;
    }

    static string Popis(string modul, VrstvaNahleduDto v) => (modul, v) switch
    {
        ("M1", VrstvaNahleduDto.Relief) => "izolace M1: jen reliéf bez moře (bez masivu a sopek)",
        ("M2", VrstvaNahleduDto.RozdilM2M1) => "izolace M2: rozdíl výšky M2 − M1 (moře, sklon kontinentu, pánve)",
        ("M1", VrstvaNahleduDto.Vyska) => "M1: povrch funkce světa bez moře",
        ("M2", VrstvaNahleduDto.Sev) => "M2: vzdálenost od pásu švu torusu (m)",
        _ => $"{modul}: {v}",
    } + " · oblast funkce světa 0…SvetMaxM (startovní svět)";

    public RezModuluDto Rez(string modul, SouradniceQ16 od, SouradniceQ16 @do, double krokM, RezimRezuDto rezim = RezimRezuDto.Vse)
    {
        if (krokM <= 0) throw new ArgumentOutOfRangeException(nameof(krokM));
        if (!_vrstvy.ContainsKey(modul)) throw new ArgumentException($"modul {modul} nemá řez v G-6 (M4–M6 v G-7)");
        var sw = Stopwatch.StartNew();
        double dx = @do.XM - od.XM, dy = @do.YM - od.YM, d = Math.Sqrt(dx * dx + dy * dy);
        int nx = Math.Max(1, (int)Math.Floor(d / krokM));
        if (nx > 8192) throw new ArgumentOutOfRangeException(nameof(krokM), "řez má víc než 8192 vzorků");
        double ux = d == 0 ? 0 : dx / d, uy = d == 0 ? 0 : dy / d;
        double X(int i) => od.XM + (i + 0.5) * krokM * ux;
        double Y(int i) => od.YM + (i + 0.5) * krokM * uy;
        var pov = new double[nx]; double[]? pov1 = null; byte[] mat = Array.Empty<byte>(); int nz = 0;
        double hladina = double.NaN;
        switch (modul)
        {
            case "M1": { var s = M1; for (int i = 0; i < nx; i++) pov[i] = s.Vyska(X(i), Y(i)); break; }
            case "M2":
            {
                var s = M2; var s1 = M1; pov1 = new double[nx];
                for (int i = 0; i < nx; i++) { pov[i] = s.Vyska(X(i), Y(i)); pov1[i] = s1.Vyska(X(i), Y(i)); }
                if (s.More is not null) hladina = s.P.HladinaMoreM;
                break;
            }
            default:
            {
                var g = M3; nz = (int)Math.Ceiling(GeologyGridConstants.ColumnM / GeologyGridConstants.CellM); mat = new byte[nx * nz];
                var rz = (GeoVrstvy.RezimSloupce)(int)rezim; var m = mat;
                Parallel.For(0, nx, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, () => g.Klon(), (i, _, gk) =>
                {
                    pov[i] = gk.Povrch(X(i), Y(i));
                    var sl = rz == GeoVrstvy.RezimSloupce.Vse ? gk.Sloupec(X(i), Y(i)) : gk.Geo.VyplnSloupecRezim(X(i), Y(i), GeologyGridConstants.CellM, GeologyGridConstants.ColumnM, rz);
                    Array.Copy(sl, 0, m, i * nz, nz);
                    return gk;
                }, _ => { });
                if (g.Svet.More is not null) hladina = g.HladinaMore;
                break;
            }
        }
        return new RezModuluDto(modul, od, @do, krokM, nx, nz, GeologyGridConstants.CellM, pov, pov1, hladina, mat, rezim, sw.Elapsed.TotalMilliseconds);
    }

    public IReadOnlyList<MaterialDto> Materialy() => _mat ??= NactiMaterialy(_s.Data);

    public static IReadOnlyList<MaterialDto> NactiMaterialy(DataSveta d)
    {
        var rows = Csv.Radky(File.ReadAllText(d.MaterialyV1)).ToList();
        int iId = rows[0].IndexOf("id"), iN = rows[0].IndexOf("nazev_cs"), iS = rows[0].IndexOf("skupina"), iB = rows[0].IndexOf("barva_hex");
        var o = new List<MaterialDto>();
        foreach (var r in rows.Skip(1))
        {
            if (r.Count <= Math.Max(Math.Max(iId, iN), iB) || !byte.TryParse(r[iId], out var id)) continue;
            string b = r[iB].Trim();
            o.Add(new MaterialDto(id, r[iN].Trim(), r[iS].Trim(), b.StartsWith('#') && b.Length >= 7 ? b[..7] : "#00000000"));
        }
        return o;
    }
}
