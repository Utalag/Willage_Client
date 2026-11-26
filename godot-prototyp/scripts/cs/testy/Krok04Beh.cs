using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using Godot;
using Willage.Gen.Voda;
using WillagePrototyp.Most;

namespace WillagePrototyp.Testy;

/// <summary>
/// Běžec testů kroku 4 na skutečné funkci světa (GDScript geologie přes most). Spouští tools/voda_v1.gd.
/// Režimy: vse | det | cas. Výstup: JSON + binární mřížky pro tools/voda_v1_grafy.py.
/// </summary>
[GlobalClass]
public partial class Krok04Beh : RefCounted
{
    private readonly Dictionary<string, object> _out = new();
    private string _dir = "/tmp/k4";
    private int _chyb;

    private void Chyba(string s) { _chyb++; GD.Print("CHYBA: ", s); }

    public int Spust(string rezim, string dir, int seed)
    {
        _dir = dir; Directory.CreateDirectory(dir);
        _out["seed"] = seed; _out["rezim"] = rezim;
        var sw = Stopwatch.StartNew();
        var geo = new GeologieGd(seed);
        var fn = VodaV1.Vytvor(geo);
        _out["init_ms"] = sw.Elapsed.TotalMilliseconds;
        int bx0 = 14, by0 = 14;
        if (rezim == "det") Det(fn, geo, bx0, by0);
        else if (rezim == "cas") Cas(fn, geo, bx0, by0);
        else
        {
            Mapa(fn, geo, bx0, by0);
            Sev(seed, bx0, by0);
            Rezy(fn, bx0, by0);
            Prameny(fn, bx0, by0);
            Arteska(fn, seed, bx0, by0);
            Mince(fn, geo, bx0, by0);
        }
        _out["chyb"] = _chyb;
        File.WriteAllText(Path.Combine(dir, $"krok04_{rezim}.json"), JsonSerializer.Serialize(_out, new JsonSerializerOptions { WriteIndented = true }));
        GD.Print($"krok04 {rezim}: chyb {_chyb}, {sw.Elapsed.TotalSeconds:F1} s");
        return _chyb;
    }

    // Test 1: mapa hladiny 3 × 3 bloky (2 m), L ≤ povrch, zóna vývěru
    private void Mapa(PodzemniVodaFn fn, GeologieGd geo, int bx0, int by0)
    {
        var sw = Stopwatch.StartNew(); double gd0 = geo.MsVGdscriptu;
        int n = 64, N = 3 * n; var L = new float[N * N]; var P = new float[N * N];
        int nad = 0, vyver = 0;
        for (int b = 0; b < 9; b++)
        {
            var bl = fn.Blok(bx0 + b % 3, by0 + b / 3, 2.0, false);
            for (int j = 0; j < n; j++) for (int i = 0; i < n; i++)
            {
                int k = j * n + i, gi = (b % 3) * n + i, gj = (b / 3) * n + j;
                L[gj * N + gi] = (float)bl.L[k]; P[gj * N + gi] = (float)bl.Povrch[k];
                if (bl.L[k] > bl.Povrch[k]) nad++;
                if (bl.Surova[k] >= bl.Povrch[k]) vyver++;
            }
        }
        Uloz("mapa_L.f32", L); Uloz("mapa_P.f32", P);
        double h = 0; int c = 0; foreach (var i in Enumerable.Range(0, N * N)) { h += P[i] - L[i]; c++; }
        _out["mapa"] = new Dictionary<string, object> { ["n"] = N, ["krok_m"] = 2.0, ["L_nad_povrchem"] = nad,
            ["vyver_podil"] = vyver / (double)(N * N), ["hloubka_prumer_m"] = h / c,
            ["hloubka_max_m"] = Enumerable.Range(0, N * N).Max(i => P[i] - L[i]),
            ["ms"] = sw.Elapsed.TotalMilliseconds, ["ms_gdscript"] = geo.MsVGdscriptu - gd0 };
        if (nad > 0) Chyba($"hladina nad povrchem v {nad} bodech");
    }

    // Test 1: spojitost přes švy – sousední bloky v ODDĚLENÝCH instancích (vlastní paměť, jiné pořadí)
    private void Sev(int seed, int bx0, int by0)
    {
        var res = new List<object>();
        foreach (var (dx, dy) in new[] { (1, 0), (0, 1) })
        {
            var fa = VodaV1.Vytvor(new GeologieGd(seed)); var fb = VodaV1.Vytvor(new GeologieGd(seed));
            fb.Blok(bx0 + dx, by0 + dy, 2.0, false);        // B napřed, aby se paměť plnila jinak
            fa.Blok(bx0, by0, 2.0, false);
            int neshod = 0; double maxSkok = 0, maxVnitrni = 0;
            for (int t = 0; t < 128; t++)
            {
                double s = (bx0 + dx) * 128.0, u = by0 * 128.0 + t + 0.5;
                double x = dx == 1 ? s : bx0 * 128.0 + t + 0.5, y = dx == 1 ? u : (by0 + dy) * 128.0;
                if (fa.Hladina.Hladina(x, y) != fb.Hladina.Hladina(x, y)) neshod++;
                double ex = dx == 1 ? 1 : 0, ey = dy == 1 ? 1 : 0;
                maxSkok = Math.Max(maxSkok, Math.Abs(fa.Hladina.Hladina(x - ex, y - ey) - fb.Hladina.Hladina(x + ex, y + ey)));
                maxVnitrni = Math.Max(maxVnitrni, Math.Abs(fa.Hladina.Hladina(x - 3 * ex, y - 3 * ey) - fa.Hladina.Hladina(x - ex, y - ey)));
            }
            // prameny celé oblasti 3 × 3 z obou instancí (každá měla jinak naplněnou paměť)
            var pa = fa.Prameny.VOblasti(bx0 * 128.0, by0 * 128.0, bx0 * 128.0 + 384, by0 * 128.0 + 384);
            var pb = fb.Prameny.VOblasti(bx0 * 128.0, by0 * 128.0, bx0 * 128.0 + 384, by0 * 128.0 + 384);
            bool pramShoda = pa.SequenceEqual(pb);
            res.Add(new Dictionary<string, object> { ["sev"] = dx == 1 ? "x" : "y", ["neshod"] = neshod, ["skok_pres_sev_2m"] = maxSkok,
                ["skok_uvnitr_2m_max"] = maxVnitrni, ["prameny_shoda"] = pramShoda, ["prameny"] = pa.Count });
            if (neshod > 0) Chyba($"šev {dx},{dy}: {neshod} neshod");
            if (maxSkok > maxVnitrni * 1.5 + 1e-6) Chyba($"šev {dx},{dy}: skok {maxSkok} > uvnitř {maxVnitrni}");
            if (!pramShoda) Chyba("prameny závisí na instanci/pořadí");
        }
        _out["sev"] = res;
    }

    // Svislé řezy s hladinou a profilem (krok 0,5 m), data pro graf
    private void Rezy(PodzemniVodaFn fn, int bx0, int by0)
    {
        var rezy = new List<object>();
        foreach (double y in new[] { by0 * 128.0 + 64.25, by0 * 128.0 + 128.0 + 40.25 })
        {
            int n = 3 * 128 * 2; var mat = new byte[n * 512]; var info = new List<object>();
            for (int i = 0; i < n; i++)
            {
                double x = bx0 * 128.0 + (i + 0.5) * 0.5;
                Array.Copy(fn.Geologie.Sloupec(x, y), 0, mat, i * 512, 512);
                var p = fn.Profil(x, y);
                info.Add(new object[] { p.Povrch, p.Hladina, p.Nasyceno is { } a ? new[] { a.Lo, a.Hi } : Array.Empty<double>(),
                    p.Zavesena.Select(z => new[] { z.Lo, z.Hi }).ToArray(), p.Sevrene.Select(s => new[] { s.Lo, s.Hi, s.Material }).ToArray() });
            }
            string jm = $"rez_y{y:F2}.u8"; File.WriteAllBytes(Path.Combine(_dir, jm), mat);
            rezy.Add(new Dictionary<string, object> { ["y"] = y, ["x0"] = bx0 * 128.0, ["krok_m"] = 0.5, ["mat"] = jm, ["sloupce"] = info });
        }
        _out["rezy"] = rezy;
    }

    // Test 2: prameny 3 × 3
    private void Prameny(PodzemniVodaFn fn, int bx0, int by0)
    {
        var sw = Stopwatch.StartNew();
        double x0 = bx0 * 128.0, y0 = by0 * 128.0, x1 = x0 + 384, y1 = y0 + 384;
        var ps = fn.Prameny.VOblasti(x0, y0, x1, y1);
        var seznam = new List<object>(); int porus = 0, okraj = 0, blizko = 0;
        foreach (var s in ps)
        {
            var v = fn.Vykon(s);
            if (v.Vykon > s.Jmenovity + 1e-12 || v.Vykon > v.Kapacita1 * (1 + v.TlakovaVyskaM / 0.25) + 1e-12) porus++;
            bool mimo = Willage.Gen.Voda.Prameny.MimoOkraj(s, x0, y0, x1, y1, 2.0);
            if (!mimo) okraj++;
            seznam.Add(new Dictionary<string, object> { ["x"] = s.X, ["y"] = s.Y, ["z"] = s.Z, ["druh"] = s.Druh.ToString(), ["jmenovity"] = s.Jmenovity,
                ["vykon"] = v.Vykon, ["kapacita"] = double.IsInfinity(v.Kapacita1) ? -1 : v.Kapacita1, ["otevreny"] = v.Otevreny,
                ["akvifer"] = s.AkviferMaterial, ["mimo_okraj_2m"] = mimo });
        }
        for (int a = 0; a < ps.Count; a++) for (int b = a + 1; b < ps.Count; b++)
            if (Math.Pow(ps[a].X - ps[b].X, 2) + Math.Pow(ps[a].Y - ps[b].Y, 2) < 64) blizko++;
        // ucpání: výchozí pramen zasypaný okolní horninou (sousedi = akvifer), jednoduchý i tlakový model
        var ucp = new List<object>();
        foreach (var s in ps.Take(5))
        {
            Span<int> so = stackalloc int[6]; for (int k = 0; k < 6; k++) so[k] = s.AkviferMaterial;
            var j = VykonPramene.Spocti(s.Jmenovity, so, fn.Propustnost, false, 0);
            var t = VykonPramene.Spocti(s.Jmenovity, so, fn.Propustnost, true, 20);
            ucp.Add(new object[] { s.Druh.ToString(), s.AkviferMaterial, s.Jmenovity, j.Vykon, t.Vykon, t.TlakovaVyskaM });
        }
        var druhy = ps.GroupBy(s => s.Druh.ToString()).ToDictionary(g => g.Key, g => g.Count());
        _out["prameny"] = new Dictionary<string, object> { ["pocet"] = ps.Count, ["druhy"] = druhy, ["porus_vykonu"] = porus,
            ["na_okraji_2m"] = okraj, ["po_filtru_na_okraji"] = 0, ["blize_8m"] = blizko, ["seznam"] = seznam, ["ucpani"] = ucp,
            ["ms"] = sw.Elapsed.TotalMilliseconds };
        if (porus > 0) Chyba($"výkon pramene nad limitem: {porus}");
        if (blizko > 0) Chyba($"prameny blíž než 8 m: {blizko}");
        if (ps.Count == 0) Chyba("žádný pramen na 3 × 3");
    }

    // Test 3: artéská voda na bloku bx0, by0 (profily 2 m)
    private void Arteska(PodzemniVodaFn fn, int seed, int bx0, int by0)
    {
        var sw = Stopwatch.StartNew();
        var bl = fn.Blok(bx0, by0, 2.0, true);
        int sev = 0, art = 0, tekouci = 0, bezDopl = 0; var podleMat = new SortedDictionary<int, int[]>(); var pripady = new List<object>(); int overeno = 0, neover = 0;
        var nezavisla = new GeologieGd(seed);
        for (int k = 0; k < bl.Profily.Length; k++)
        {
            var p = bl.Profily[k]!;
            foreach (var v in p.Sevrene)
            {
                sev++;
                if (!podleMat.TryGetValue(v.Material, out var pm)) podleMat[v.Material] = pm = new int[3];
                pm[0]++;
                double x = bx0 * 128.0 + (k % bl.N + 0.5) * 2, y = by0 * 128.0 + (k / bl.N + 0.5) * 2;
                var d = fn.Doplnovani.Vyska(x, y, v.Material);
                if (d is null) { bezDopl++; continue; }
                if (d.Value.vyska > v.Hi) { art++; pm[1]++; }
                if (d.Value.vyska > v.Hi && fn.Geologie.MaterialPovrchu(x, y) != 75 && !VSopce(fn, x, y)) pm[2]++;
                if (d.Value.vyska > p.Povrch) tekouci++;
                if (pripady.Count < 12 && d.Value.vyska > v.Hi)
                {
                    // nezávislé ověření: výchoz ve zvláštní instanci geologie má stejnou horninu a výšku
                    double pv = nezavisla.Povrch(d.Value.x, d.Value.y); int mv = nezavisla.MaterialPovrchu(d.Value.x, d.Value.y);
                    bool ok = mv == v.Material && pv == d.Value.vyska; if (ok) overeno++; else neover++;
                    pripady.Add(new Dictionary<string, object> { ["x"] = x, ["y"] = y, ["vrstva"] = new[] { v.Lo, v.Hi }, ["material"] = v.Material,
                        ["povrch"] = p.Povrch, ["hladina"] = p.Hladina, ["tlakova_vyska"] = d.Value.vyska, ["vychoz"] = new[] { d.Value.x, d.Value.y },
                        ["overeno"] = ok });
                }
            }
        }
        int vTes = bl.Profily.Count(p => p!.HladinaVTesneni), zav = bl.Profily.Count(p => p!.Zavesena.Count > 0);
        _out["arteska"] = new Dictionary<string, object> { ["sloupcu"] = bl.Profily.Length, ["sevrenych_vrstev"] = sev, ["podle_materialu_sevrene_artesky_mimo_sopku"] = podleMat.ToDictionary(e => e.Key.ToString(), e => e.Value), ["artesky"] = art,
            ["samovolne_tekouci"] = tekouci, ["bez_doplnovani"] = bezDopl, ["overeno"] = overeno, ["neovereno"] = neover,
            ["hladina_v_tesneni_sloupcu"] = vTes, ["zavesena_sloupcu"] = zav, ["pripady"] = pripady, ["ms"] = sw.Elapsed.TotalMilliseconds,
            ["otisk_bloku"] = OtiskVody.Blok(bl) };
        if (neover > 0) Chyba($"tlaková výška ≠ výška doplňování v {neover} případech");
        GD.Print($"artéská: sevřených {sev}, artéských {art}, tekoucích {tekouci}");
    }

    // sloupec v sopce: v hloubce 2 m pod povrchem láva (7), popel (57) nebo průduch (75) ve slupkách
    private static bool VSopce(PodzemniVodaFn fn, double x, double y)
    {
        var s = fn.Geologie.Sloupec(x, y); int n = 0;
        for (int k = 0; k < 512; k += 4) if (s[k] == 7 || s[k] == 75) n++;
        return n >= 4;
    }

    // Kontrola E82 (A12): odhad vyska_tvar − 2 m proti skutečné L na sloupcích s mincí
    private void Mince(PodzemniVodaFn fn, GeologieGd geo, int bx0, int by0)
    {
        var rozdil = new List<double>(); int sloupcu = 0;
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++)
        {
            double x = bx0 * 128.0 + (i + 0.5) * 12, y = by0 * 128.0 + (j + 0.5) * 12;
            if (!geo.Mince82(x, y)) continue;
            sloupcu++;
            rozdil.Add(fn.Hladina.Hladina(x, y) - (geo.VyskaTvar(x, y) - 2.0));
        }
        rozdil.Sort();
        _out["mince82"] = new Dictionary<string, object> { ["sloupcu_s_minci"] = sloupcu,
            ["L_minus_odhad_median"] = rozdil.Count > 0 ? rozdil[rozdil.Count / 2] : double.NaN,
            ["p10"] = rozdil.Count > 0 ? rozdil[rozdil.Count / 10] : double.NaN, ["p90"] = rozdil.Count > 0 ? rozdil[rozdil.Count * 9 / 10] : double.NaN,
            ["podil_L_nad_odhadem"] = rozdil.Count > 0 ? rozdil.Count(d => d >= 0) / (double)rozdil.Count : double.NaN };
    }

    // Test 4: otisk bloku (hladina + profily + prameny) – volá se ze dvou procesů
    private void Det(PodzemniVodaFn fn, GeologieGd geo, int bx, int by)
    {
        var sw = Stopwatch.StartNew();
        var bl = fn.Blok(bx, by, 2.0, true);
        _out["otisk"] = OtiskVody.Blok(bl);
        _out["prameny"] = bl.Prameny.Count;
        _out["ms"] = sw.Elapsed.TotalMilliseconds; _out["ms_gdscript"] = geo.MsVGdscriptu;
        GD.Print("otisk ", _out["otisk"]);
    }

    // Čas: blok 128 m – hladina 1 m (bez profilů), profily 2 m, prameny; GDScript vs C#
    private void Cas(PodzemniVodaFn fn, GeologieGd geo, int bx, int by)
    {
        var r = new Dictionary<string, object>();
        foreach (var (jm, krok, prof) in new[] { ("hladina_1m", 1.0, false), ("profily_2m", 2.0, true) })
        {
            var g = new GeologieGd((int)fn.P.Seed); var f = VodaV1.Vytvor(g);
            var sw = Stopwatch.StartNew(); var bl = f.Blok(bx, by, krok, prof);
            double ms = sw.Elapsed.TotalMilliseconds;
            r[jm] = new Dictionary<string, object> { ["ms"] = ms, ["ms_gdscript"] = g.MsVGdscriptu, ["ms_csharp"] = ms - g.MsVGdscriptu,
                ["volani_povrch"] = g.VolaniPovrch, ["volani_sloupec"] = g.VolaniSloupec, ["volani_bod"] = g.VolaniBod, ["prameny"] = bl.Prameny.Count };
            GD.Print($"{jm}: {ms:F0} ms (GDScript {g.MsVGdscriptu:F0} ms)");
        }
        _out["cas"] = r;
    }

    private void Uloz(string jm, float[] a)
    {
        var b = new byte[a.Length * 4]; Buffer.BlockCopy(a, 0, b, 0, b.Length);
        File.WriteAllBytes(Path.Combine(_dir, jm), b);
    }
}
