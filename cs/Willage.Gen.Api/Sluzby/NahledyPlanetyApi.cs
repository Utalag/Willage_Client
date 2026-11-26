using System.Diagnostics;
using Willage.Gen.Api.Dto;
using Willage.Gen.Eroze;
using Willage.Gen.Klima;
using Willage.Gen.Pipeline.Moduly;

namespace Willage.Gen.Api.Sluzby;

/// <summary>
/// G-7: náhledy M4 eroze a M5 klima na mapě planety (torus, uzly MapaEroze po 32 m). Bez výpočtu světa: vzorek = hodnota pole v nejbližším
/// uzlu (jako KlimaSvetaFn.Biom), takže náhled je bitově pole modulu. Souhrnná čísla se počítají z celých polí (stejně jako nástroj „klima mapa“).
/// Řez: M4 profil před / po erozi (svět planety M4), M5 profil povrchu s řadami teplota, srážky, w (bilineárně jako KlimaSvetaFn).
/// </summary>
public sealed class NahledyPlanetyApi
{
    readonly StavGeneratoru _s;
    public NahledyPlanetyApi(StavGeneratoru s) => _s = s;

    public static readonly VrstvaNahleduDto[] VrstvyM4 = { VrstvaNahleduDto.VyskaPlanety, VrstvaNahleduDto.PosunEroze, VrstvaNahleduDto.Toky, VrstvaNahleduDto.Jezera, VrstvaNahleduDto.Koryta };
    public static readonly VrstvaNahleduDto[] VrstvyM5 = { VrstvaNahleduDto.Teplota, VrstvaNahleduDto.Srazky, VrstvaNahleduDto.OdtokW, VrstvaNahleduDto.BiomKlimatu, VrstvaNahleduDto.KorytaKlimatu, VrstvaNahleduDto.BiomBezOaz };

    VystupEroze E => _s.Hotovo().Vystup<VystupEroze>(M4Eroze.Id_);
    VystupKlimatu K => _s.Hotovo().Vystup<VystupKlimatu>(M5KlimaABiomy.Id_);

    MapaEroze Mapa() => E.Zapnuto && E.Mapa is { } m ? m : throw new InvalidOperationException("M4 eroze je vypnutá (VseKrok06 = false) – náhled planety není");
    MapaKlimatu MapaK() => K.Zapnuto && K.Mapa is { } m ? m : throw new InvalidOperationException("M5 klima je vypnuté (KlimaKrok07 = false)");

    static bool More(MapaEroze m, int k) => (m.Priznaky[k] & MapaEroze.Odtok) != 0;

    /// <summary>Izolace M5 „jen klima (bez vlivu na vodu)“: biom klimatu znovu klasifikovaný z T a P bez překryvu oáz (oázy jsou vliv vody).</summary>
    public static BiomKlimatu BiomBezOaz(MapaEroze m, MapaKlimatu mk, ParametryKlimatu p, int k) => KlasifikaceBiomu.Urci(mk.Teplota[k], mk.Srazky[k], More(m, k), p);

    Func<int, float> Pole(string modul, VrstvaNahleduDto v)
    {
        var m = Mapa();
        if (modul == "M4")
            return v switch
            {
                VrstvaNahleduDto.VyskaPlanety => k => m.H[k],
                VrstvaNahleduDto.PosunEroze => k => m.E(k),
                VrstvaNahleduDto.Toky => k => (float)Math.Log10(Math.Max(1.0, m.A[k])),
                VrstvaNahleduDto.Jezera => k => (m.Priznaky[k] & MapaEroze.Jezero) != 0 ? Math.Max(0f, m.Vypln[k] - m.H[k]) : 0f,
                VrstvaNahleduDto.Koryta => k => More(m, k) ? -1f : (m.Priznaky[k] & MapaEroze.Koryto) != 0 ? 1f : 0f,
                _ => throw new ArgumentException($"modul M4 nemá vrstvu {v}"),
            };
        var mk = MapaK(); var hk = K.Hydrologie!; var pk = K.Parametry!;
        return v switch
        {
            VrstvaNahleduDto.Teplota => k => mk.Teplota[k],
            VrstvaNahleduDto.Srazky => k => mk.Srazky[k],
            VrstvaNahleduDto.OdtokW => k => mk.W[k],
            VrstvaNahleduDto.BiomKlimatu => k => (float)mk.Biom[k],
            VrstvaNahleduDto.BiomBezOaz => k => (float)BiomBezOaz(m, mk, pk, k),
            // 0 bez koryta, 1 aktivní, 2 suché, 3 tok mimo koryto, −1 moře
            VrstvaNahleduDto.KorytaKlimatu => k => More(m, k) ? -1f : (hk.Stav[k] & HydrologieKlimatu.Aktivni) != 0 ? 1f : (hk.Stav[k] & HydrologieKlimatu.Suche) != 0 ? 2f : (hk.Stav[k] & HydrologieKlimatu.BezKoryta) != 0 ? 3f : 0f,
            _ => throw new ArgumentException($"modul M5 nemá vrstvu {v}"),
        };
    }

    public NahledMapyDto Mapa(string modul, VrstvaNahleduDto v, int rozliseni, OblastQ16? oblast, bool izolace)
    {
        var sw = Stopwatch.StartNew();
        var m = Mapa(); var t = m.T; var f = Pole(modul, v);
        double px = t.Nx * t.Krok, py = t.Ny * t.Krok;
        var o = oblast ?? new OblastQ16(new SouradniceQ16(0, 0), SouradniceQ16.ZMetru(px, py));
        double x0 = o.Od.XM, y0 = o.Od.YM, sx = o.Do.XM - x0, sy = o.Do.YM - y0, krok = Math.Max(sx, sy) / rozliseni;
        int nx = Math.Max(1, (int)Math.Round(sx / krok)), ny = Math.Max(1, (int)Math.Round(sy / krok));
        var h = new float[nx * ny];
        Parallel.For(0, ny, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, j =>
        {
            int ju = (int)Math.Round(PeriodickyPodklad.Zabal(y0 + (j + 0.5) * krok, py) / t.Krok);
            for (int i = 0; i < nx; i++) h[j * nx + i] = f(t.K((int)Math.Round(PeriodickyPodklad.Zabal(x0 + (i + 0.5) * krok, px) / t.Krok), ju));
        });
        var c = Cisla(modul);
        var fin = h.Where(float.IsFinite).ToArray();
        var cc = new Dictionary<string, double>(c) { ["min"] = fin.Length == 0 ? double.NaN : fin.Min(), ["max"] = fin.Length == 0 ? double.NaN : fin.Max() };
        IReadOnlyList<BodNahleduDto>? body = izolace ? null : Body(modul, x0, y0, x0 + sx, y0 + sy);
        return new NahledMapyDto(modul, v, izolace, x0, y0, krok, nx, ny, h, Popis(modul, v), cc, sw.Elapsed.TotalMilliseconds) { Body = body };
    }

    /// <summary>Body: M4 vodníci kroku 6 (bez klimatu), M5 vodníci s klimatem (oázy s druhem „oáza“).</summary>
    IReadOnlyList<BodNahleduDto> Body(string modul, double x0, double y0, double x1, double y1)
    {
        bool V(Vodnik a) => a.X >= x0 && a.X < x1 && a.Y >= y0 && a.Y < y1;
        if (modul == "M4") return E.Vodnici.Where(V).Select(a => new BodNahleduDto(a.X, a.Y, "vodník", a.QLs)).ToList();
        var oazy = K.Oazy.Select(a => (a.X, a.Y)).ToHashSet();
        return K.Vodnici.Where(V).Select(a => new BodNahleduDto(a.X, a.Y, oazy.Contains((a.X, a.Y)) ? "oáza" : "vodník", a.QLs)).ToList();
    }

    readonly Dictionary<string, (string klic, Dictionary<string, double> c)> _cisla = new();

    /// <summary>Souhrn z celých polí (pevnina = uzly bez příznaku Odtok), stejné vzorce jako KlimaNastroj.Mapa; keš podle klíče modulu.</summary>
    Dictionary<string, double> Cisla(string modul)
    {
        string klic = _s.Hotovo().Klice[modul];
        if (_cisla.TryGetValue(modul, out var x) && x.klic == klic) return x.c;
        var m = Mapa(); var t = m.T; var c = new Dictionary<string, double>();
        int nPev = 0; for (int k = 0; k < t.N; k++) if (!More(m, k)) nPev++;
        c["podil_more"] = 1.0 - nPev / (double)t.N;
        if (modul == "M4")
        {
            double sE = 0, maxE = 0; int kor = 0, jez = 0;
            for (int k = 0; k < t.N; k++)
            {
                if ((m.Priznaky[k] & MapaEroze.Koryto) != 0) kor++;
                if ((m.Priznaky[k] & MapaEroze.Jezero) != 0) jez++;
                if (More(m, k)) continue;
                sE += m.E(k); maxE = Math.Max(maxE, m.E(k));
            }
            c["eroze_prumer_m"] = sE / Math.Max(1, nPev); c["eroze_max_m"] = maxE; c["koryt_uzlu"] = kor; c["jezer_uzlu"] = jez; c["vodniku"] = E.Vodnici.Count;
        }
        else
        {
            var mk = MapaK(); var hk = K.Hydrologie!; var bc = new int[11]; double sT = 0, sP = 0, sW = 0, minT = 1e9, maxT = -1e9;
            for (int k = 0; k < t.N; k++)
            {
                if (More(m, k)) continue;
                bc[(int)mk.Biom[k]]++; sT += mk.Teplota[k]; sP += mk.Srazky[k]; sW += mk.W[k];
                minT = Math.Min(minT, mk.Teplota[k]); maxT = Math.Max(maxT, mk.Teplota[k]);
            }
            c["t_min"] = minT; c["t_max"] = maxT; c["t_prumer"] = sT / nPev; c["p_prumer_mm"] = sP / nPev; c["w_prumer"] = sW / nPev;
            for (int b = 1; b <= 10; b++) if (bc[b] > 0) c["biom_" + KlasifikaceBiomu.NazevCs[b].Replace(' ', '_') + "_%"] = 100.0 * bc[b] / nPev;
            int kor = 0; for (int k = 0; k < t.N; k++) if ((m.Priznaky[k] & MapaEroze.Koryto) != 0) kor++;
            c["koryta_aktivni_%"] = 100.0 * hk.Pocet(HydrologieKlimatu.Aktivni) / Math.Max(1, kor);
            c["koryta_sucha_%"] = 100.0 * hk.Pocet(HydrologieKlimatu.Suche) / Math.Max(1, kor);
            c["oaz"] = K.Oazy.Count; c["vodniku"] = K.Vodnici.Count;
        }
        _cisla[modul] = (klic, c);
        return c;
    }

    string Popis(string modul, VrstvaNahleduDto v)
    {
        string o = modul == "M4" ? $"mapa eroze {SouborMapy.Otisk(Mapa())}" : $"klima {MapaK().Otisk()}";
        return (modul, v) switch
        {
            ("M4", VrstvaNahleduDto.PosunEroze) => "izolace M4: mapa posunu eroze H0 − H (m)",
            ("M4", VrstvaNahleduDto.Toky) => "M4: toky log₁₀ plochy povodí (m²)",
            ("M4", VrstvaNahleduDto.Jezera) => "M4: hloubka jezer (výplň − dno, m)",
            ("M5", VrstvaNahleduDto.BiomBezOaz) => "izolace M5: jen klima – biom z T a P bez oáz (bez vlivu na vodu)",
            ("M5", VrstvaNahleduDto.KorytaKlimatu) => "M5: koryta aktivní (modrá) / suchá (okrová) / tok mimo koryto",
            _ => $"{modul}: {v}",
        } + $" · celá planeta, uzly {Mapa().T.Krok:0} m · {o}";
    }

    /// <summary>Řez M4 / M5 (profil). M4: PovrchM = po erozi, PovrchM1 = před erozí (svět planety M4), Rady eroze_m. M5: povrch po erozi + klima.</summary>
    public RezModuluDto Rez(string modul, SouradniceQ16 od, SouradniceQ16 @do, double krokM)
    {
        var sw = Stopwatch.StartNew();
        var e = E; if (!e.Zapnuto) throw new InvalidOperationException("M4 eroze je vypnutá");
        var (nx, X, Y) = NahledyModuluApi.Vzorky(od, @do, krokM);
        var sp = e.SvetPlanety!; var ef = e.Eroze!;
        var pred = new double[nx]; var po = new double[nx]; var er = new double[nx];
        Parallel.For(0, nx, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, _s.Vlaken) }, i =>
        {
            double h0 = sp.Vyska(X(i), Y(i)), d = ef.Hloubka(X(i), Y(i));
            pred[i] = h0; er[i] = d; po[i] = h0 - d;
        });
        var rady = new Dictionary<string, double[]> { ["eroze_m"] = er };
        double hm = sp.More is not null ? sp.P.HladinaMoreM : double.NaN;
        if (modul == "M5")
        {
            var kf = new KlimaSvetaFn(MapaK());
            rady["teplota_c"] = Enumerable.Range(0, nx).Select(i => kf.Teplota(X(i), Y(i))).ToArray();
            rady["srazky_mm"] = Enumerable.Range(0, nx).Select(i => kf.Srazky(X(i), Y(i))).ToArray();
            rady["w"] = Enumerable.Range(0, nx).Select(i => kf.W(X(i), Y(i))).ToArray();
            rady["biom"] = Enumerable.Range(0, nx).Select(i => (double)kf.Biom(X(i), Y(i))).ToArray();
        }
        return new RezModuluDto(modul, od, @do, krokM, nx, 0, 0, po, modul == "M4" ? pred : null, hm, Array.Empty<byte>(), RezimRezuDto.Vse, sw.Elapsed.TotalMilliseconds) { Rady = rady };
    }

    /// <summary>Tabulka pásem M5: konfigurace zapnutých pásem + změřené hodnoty na pevnině v jejich segmentech (obě poloviny periody).</summary>
    public IReadOnlyList<PasmoNahleduDto> TabulkaPasem()
    {
        if (!K.Zapnuto) return Array.Empty<PasmoNahleduDto>();
        var m = Mapa(); var mk = MapaK(); var z = mk.Zemepis; var t = m.T; int n = z.Pasma.Count;
        var o = new List<PasmoNahleduDto>();
        for (int a = 0; a < n; a++)
        {
            var (id, p) = z.Pasma[a];
            int pev = 0, vse = 0; double sT = 0, sP = 0, sW = 0; var bc = new int[11];
            for (int j = 0; j < t.Ny; j++)
            {
                int s = mk.Radky[j].Segment; if ((s < n ? s : 2 * n - 1 - s) != a) continue;
                for (int i = 0; i < t.Nx; i++)
                {
                    int k = j * t.Nx + i; vse++; if (More(m, k)) continue;
                    pev++; sT += mk.Teplota[k]; sP += mk.Srazky[k]; sW += mk.W[k]; bc[(int)mk.Biom[k]]++;
                }
            }
            int hb = Array.IndexOf(bc, bc.Max());
            string naz = ParametryKlimatu.NazevPasmaCs[Array.IndexOf(ParametryKlimatu.IdPasem, id)];
            o.Add(new PasmoNahleduDto(id, naz, p.Podil, p.TOdC, p.TDoC, p.SrazkyK, p.Vitr, z.Hrana(a), z.Hrana(a + 1),
                vse == 0 ? 0 : pev / (double)vse, pev == 0 ? double.NaN : sT / pev, pev == 0 ? double.NaN : sP / pev, pev == 0 ? double.NaN : sW / pev,
                pev == 0 ? "–" : KlasifikaceBiomu.NazevCs[hb], pev == 0 ? 0 : bc[hb] / (double)pev));
        }
        return o;
    }
}
