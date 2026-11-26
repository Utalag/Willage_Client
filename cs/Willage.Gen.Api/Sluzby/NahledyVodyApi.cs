using System.Diagnostics;
using Willage.Gen.Api.Dto;
using Willage.Gen.Eroze;
using Willage.Gen.Geologie;
using Willage.Gen.Jadro;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Voda;

namespace Willage.Gen.Api.Sluzby;

/// <summary>
/// G-7: náhled M6 voda a průsak nad hotovou planetou (výstup M7 – erodovaná geologie, klima, dobití 7c; stejně jako otisky a nástroj „eroze rez“).
/// Hladina = RegionalniHladina.Surova (7c), prameny = Prameny.VOblasti (ze seedu + vodníci). Vláknům vlastní PodzemniVodaFn nad Klon geologie
/// (keše nejsou vláknově bezpečné), výsledek nezávisí na počtu vláken.
/// 7d (zvodnělá zóna šířením průsaku, strop hladiny u pobřeží 60 m) je ZÁSTUPNÁ – Jan odložil; vrstva vrací NaN, řez jen štítek.
/// </summary>
public sealed class NahledyVodyApi
{
    readonly StavGeneratoru _s;
    public NahledyVodyApi(StavGeneratoru s) => _s = s;

    public static readonly VrstvaNahleduDto[] VrstvyM6 =
    {
        VrstvaNahleduDto.Hladina, VrstvaNahleduDto.HladinaAbs, VrstvaNahleduDto.Dobiti, VrstvaNahleduDto.Vyver, VrstvaNahleduDto.PobrezniPas,
        VrstvaNahleduDto.JenHladina, VrstvaNahleduDto.JenPrameny, VrstvaNahleduDto.ZvodnelaZona7d,
    };
    public const string Zastupne7d = "7d zvodnělá zóna (šíření průsaku od zdrojů) a strop hladiny u pobřeží 60 m – zástupné, Jan: odloženo";
    /// <summary>Výchozí oblast M6: start 3 × 3 bloky (1792…2176 m), kde reporty 6–7c počítají prameny.</summary>
    public static readonly OblastQ16 VychoziOblast = new(SouradniceQ16.ZMetru(1792, 1792), SouradniceQ16.ZMetru(2176, 2176));

    SvetKrok06 Svet => _s.Hotovo().Vystup<VystupPlanety>(M7VystupPlanety.Id_).Svet;
    VystupVody V => _s.Hotovo().Vystup<VystupVody>(M6VodaAPrusak.Id_);

    /// <summary>
    /// Voda nad vlastní kopií geologie (Klon sdílí funkci světa i napojenou erozi) a vlastním katalogem materiálů: KatalogMaterialu.NeznamaId
    /// mění Najdi (se zámkem) i PobrezniPas (bez zámku) → sdílený katalog mezi vlákny padal (nález G-7). Katalog ze stejného souboru = stejné hodnoty.
    /// </summary>
    PodzemniVodaFn VodaKlon()
    {
        var s = Svet;
        var k = new SvetKrok06
        {
            Geologie = s.Geologie.Klon(), Mapa = s.Mapa, Eroze = s.Eroze, Vodnici = s.Vodnici, Klima = s.Klima, Hydrologie = s.Hydrologie,
            Oazy = s.Oazy, ParametryKlimatu = s.ParametryKlimatu, VodniciBezKlimatu = s.VodniciBezKlimatu, Napajeni = s.Napajeni,
        };
        var v = V;
        return k.Voda(Willage.Gen.Materialy.KatalogMaterialu.ZeSouboru(_s.Data.KatalogMaterialu), v.Parametry, v.PrusakJson);
    }

    /// <summary>
    /// Prameny v obdélníku – stejný výsledek jako Prameny.VOblasti (buňky po BunkaPramenuM, Vysledny, pak vodníci a stejné řazení), jen buňky
    /// se počítají paralelně (každé vlákno vlastní voda; Vysledny buňky nezávisí na pořadí). Sekvenčně trval start 3 × 3 ~1,4 s (nález G-7).
    /// </summary>
    List<Pramen> Prameny(double x0, double y0, double x1, double y1)
    {
        double b = V.Parametry.BunkaPramenuM;
        int cx0 = (int)Math.Floor(x0 / b), cx1 = (int)Math.Floor((x1 - 1e-9) / b), cy0 = (int)Math.Floor(y0 / b), cy1 = (int)Math.Floor((y1 - 1e-9) / b);
        int ny = cy1 - cy0 + 1, nb = (cx1 - cx0 + 1) * ny;
        var bunky = new Pramen?[nb];
        Parallel.For(0, nb, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, VodaKlon, (q, _, fn) =>
        {
            bunky[q] = fn.Prameny.Vysledny(cx0 + q / ny, cy0 + q % ny);
            return fn;
        }, _ => { });
        var o = new List<Pramen>();
        foreach (var s in bunky) if (s is not null && s.X >= x0 && s.X < x1 && s.Y >= y0 && s.Y < y1) o.Add(s);
        var vod = VodaKlon().Prameny.Vodnici;
        if (vod is not null) o.AddRange(vod(x0, y0, x1, y1));
        o.Sort((a, c) => a.X != c.X ? a.X.CompareTo(c.X) : a.Y.CompareTo(c.Y));
        return o;
    }

    public NahledMapyDto Mapa(VrstvaNahleduDto v, int rozliseni, OblastQ16? oblast)
    {
        if (Array.IndexOf(VrstvyM6, v) < 0) throw new ArgumentException($"modul M6 nemá vrstvu {v}");
        var sw = Stopwatch.StartNew();
        var o = oblast ?? VychoziOblast;
        double x0 = o.Od.XM, y0 = o.Od.YM, sx = o.Do.XM - x0, sy = o.Do.YM - y0, krok = Math.Max(sx, sy) / rozliseni;
        int nx = Math.Max(1, (int)Math.Round(sx / krok)), ny = Math.Max(1, (int)Math.Round(sy / krok));
        var h = new float[nx * ny];
        bool zast = v == VrstvaNahleduDto.ZvodnelaZona7d;
        var nap = Svet.Napajeni;
        if (zast) Array.Fill(h, float.NaN);
        else Parallel.For(0, ny, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, VodaKlon, (j, _, fn) =>
        {
            var g = fn.Geologie; double hm = g.HladinaMore;
            double y = y0 + (j + 0.5) * krok;
            for (int i = 0; i < nx; i++)
            {
                double x = x0 + (i + 0.5) * krok;
                h[j * nx + i] = v switch
                {
                    VrstvaNahleduDto.Dobiti => (float)(nap?.Dobiti(x, y) ?? 1.0),
                    VrstvaNahleduDto.JenPrameny => (float)g.Povrch(x, y),
                    _ => Hodnota(v, fn, g, hm, x, y),
                };
            }
            return fn;
        }, _ => { });
        var c = new Dictionary<string, double>();
        var fin = h.Where(float.IsFinite).ToArray();
        c["min"] = fin.Length == 0 ? double.NaN : fin.Min(); c["max"] = fin.Length == 0 ? double.NaN : fin.Max();
        if (zast) c["zastupny"] = 1;
        if (v is VrstvaNahleduDto.Hladina or VrstvaNahleduDto.JenHladina) c["podil_bez_hladiny"] = h.Count(float.IsNaN) / (double)h.Length;
        if (v == VrstvaNahleduDto.Vyver) c["podil_vyveru"] = h.Average(q => (double)q);
        foreach (var kv in DobitiPlanety()) c[kv.Key] = kv.Value;
        List<BodNahleduDto>? body = null;
        if (v is not (VrstvaNahleduDto.JenHladina or VrstvaNahleduDto.ZvodnelaZona7d))
        {
            var swp = Stopwatch.StartNew();
            var pr = Prameny(x0, y0, x0 + sx, y0 + sy);
            c["ms_prameny"] = swp.Elapsed.TotalMilliseconds;
            body = pr.Select(p => new BodNahleduDto(p.X, p.Y, p.Druh.ToString(), p.Jmenovity, double.NaN, p.Z)).ToList();
            c["pramenu"] = body.Count; c["vodniku"] = pr.Count(p => p.Druh == DruhPramene.Vodnik);
        }
        bool izol = v is VrstvaNahleduDto.JenHladina or VrstvaNahleduDto.JenPrameny;
        return new NahledMapyDto("M6", v, izol, x0, y0, krok, nx, ny, h, Popis(v), c, sw.Elapsed.TotalMilliseconds) { Body = body, Zastupny = zast };
    }

    static float Hodnota(VrstvaNahleduDto v, PodzemniVodaFn fn, IGeologie g, double hm, double x, double y)
    {
        double l = fn.Hladina.Surova(x, y), pov = g.Povrch(x, y);
        return v switch
        {
            VrstvaNahleduDto.HladinaAbs => (float)l,
            VrstvaNahleduDto.Vyver => !double.IsNaN(l) && l >= pov ? 1f : 0f,
            VrstvaNahleduDto.PobrezniPas => !double.IsNaN(hm) && g.JeMoreVyska(x, y, pov) ? 2f : !double.IsNaN(hm) && Math.Abs(l - hm) < 0.01 ? 1f : 0f,
            _ => (float)(pov - l),   // Hladina, JenHladina: hloubka pod povrchem (záporná = vývěr), NaN bez hladiny
        };
    }

    string? _dobKlic; Dictionary<string, double>? _dob;
    /// <summary>Dobití 7c na pevnině celé mapy (bez / částečně / plně, %) – stejně jako nástroj „klima mapa“.</summary>
    Dictionary<string, double> DobitiPlanety()
    {
        string klic = _s.Hotovo().Klice[M6VodaAPrusak.Id_];
        if (_dob is not null && _dobKlic == klic) return _dob;
        var d = new Dictionary<string, double>();
        if (Svet.Napajeni is { } nap && Svet.Mapa is { } m)
        {
            int nb = 0, nd = 0, np = 0;
            for (int k = 0; k < m.T.N; k++) { if ((m.Priznaky[k] & MapaEroze.Odtok) != 0) continue; np++; if (nap.E[k] <= 0f) nb++; else if (nap.E[k] < 1f) nd++; }
            d["planeta_bez_hladiny_%"] = 100.0 * nb / np; d["planeta_castecne_%"] = 100.0 * nd / np; d["planeta_plne_%"] = 100.0 * (np - nb - nd) / np;
        }
        _dob = d; _dobKlic = klic;
        return d;
    }

    static string Popis(VrstvaNahleduDto v) => v switch
    {
        VrstvaNahleduDto.Hladina => "M6: hloubka hladiny pod povrchem (7c, m; tyrkys = vývěr, tmavě modrá = hladina nad povrchem / moře, šedá = bez hladiny) + prameny",
        VrstvaNahleduDto.HladinaAbs => "M6: surová hladina podzemní vody (m n. m.)",
        VrstvaNahleduDto.Dobiti => "M6: dobití hladiny klimatem 7c (0 bez hladiny … 1 plně)",
        VrstvaNahleduDto.Vyver => "M6: zóna vývěru (hladina ≥ povrch)",
        VrstvaNahleduDto.PobrezniPas => "M6: pobřežní pás (hladina = hladina moře; moře tmavě)",
        VrstvaNahleduDto.JenHladina => "izolace M6: jen hladina (hloubka pod povrchem, bez pramenů)",
        VrstvaNahleduDto.JenPrameny => "izolace M6: jen prameny (body na šedém povrchu)",
        VrstvaNahleduDto.ZvodnelaZona7d => "ZÁSTUPNÁ VRSTVA 7d: " + Zastupne7d,
        _ => "M6: " + v,
    } + " · výchozí oblast start 3 × 3 bloky";

    /// <summary>Řez s hladinou: materiály po 0,25 m (erodovaná geologie M7), povrch, surová hladina 7c, hladina moře, dobití, prameny do 150 m.</summary>
    public RezModuluDto Rez(SouradniceQ16 od, SouradniceQ16 @do, double krokM)
    {
        var sw = Stopwatch.StartNew();
        var (nx, X, Y) = NahledyModuluApi.Vzorky(od, @do, krokM);
        int nz = (int)Math.Ceiling(GeologyGridConstants.ColumnM / GeologyGridConstants.CellM);
        var mat = new byte[nx * nz]; var pov = new double[nx]; var hl = new double[nx]; var dob = new double[nx];
        var nap = Svet.Napajeni;
        Parallel.For(0, nx, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, VodaKlon, (i, _, fn) =>
        {
            double x = X(i), y = Y(i); var g = fn.Geologie;
            pov[i] = g.Povrch(x, y); hl[i] = fn.Hladina.Surova(x, y); dob[i] = nap?.Dobiti(x, y) ?? 1.0;
            Array.Copy(g.Sloupec(x, y), 0, mat, i * nz, nz);
            return fn;
        }, _ => { });
        // prameny do 150 m od úsečky (jako nástroj „eroze rez“)
        double x0 = od.XM, y0 = od.YM, x1 = @do.XM, y1 = @do.YM;
        var pr = Prameny(Math.Min(x0, x1) - 150, Math.Min(y0, y1) - 150, Math.Max(x0, x1) + 150, Math.Max(y0, y1) + 150);   // nástroj bere ±200 m a filtruje 150 m – stejná množina
        double vx = x1 - x0, vy = y1 - y0, L2 = vx * vx + vy * vy;
        var body = new List<BodNahleduDto>();
        foreach (var p in pr)
        {
            double t = L2 <= 0 ? 0 : Math.Clamp(((p.X - x0) * vx + (p.Y - y0) * vy) / L2, 0, 1);
            double dx = x0 + t * vx - p.X, dy = y0 + t * vy - p.Y;
            if (Math.Sqrt(dx * dx + dy * dy) <= 150) body.Add(new BodNahleduDto(p.X, p.Y, p.Druh.ToString(), p.Jmenovity, t * Math.Sqrt(L2), p.Z));
        }
        double hm = Svet.Geologie.HladinaMore;
        return new RezModuluDto("M6", od, @do, krokM, nx, nz, GeologyGridConstants.CellM, pov, null, hm, mat, RezimRezuDto.Vse, sw.Elapsed.TotalMilliseconds)
        {
            HladinaPodzemniM = hl, Rady = new Dictionary<string, double[]> { ["dobiti"] = dob }, Body = body, Zastupne = new[] { Zastupne7d },
        };
    }
}
