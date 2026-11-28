using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.V8;

/// <summary>Porovná jeden blok 128 m: GEO1 <c>VyplnSloupec</c> × GEO2 výchozí <c>KontextBloku.Sloupec</c>, rozdíly klasifikuje.</summary>
public static class V8Blok
{
    /// <summary>Otevřené buňky (verdikt Otevrene) pro ladění; naplní se v Porovnej, vypíše Spust.</summary>
    public static readonly System.Collections.Concurrent.ConcurrentBag<(double X, double Y, double Z, Pricina Pricina)> Otevrene = new();

    /// <summary>Kvalita skarnu (tloušťka pásma, O1, díry) obou systémů ve sloupci se skarnem; drahé, proto jen tam.</summary>
    private static void Kvalita(GeologieCs g, KontextBloku k, PodkladyKlasifikace pod, V8Soucty s, double x, double y, ReadOnlySpan<byte> m1, Vzorek[] v2)
    {
        var w = g.Svet.Vahy(x, y); double zp = g.Svet.VyskaW(x, y, w);
        var hr = g.Geo.Vrstvy.Hranice(x, y, w, g.Svet.VyskaTvar(x, y), zp);
        for (int iz = 0; iz < Nz; iz++)
        {
            double z = (iz + 0.5) * KrokZ; if (z > zp) break;
            int vm = VrstvySloupce.VrstvaMat(z, hr); bool karb = vm >= 0 && vm < pod.Karbonat.Length && pod.Karbonat[vm];
            bool s1 = m1[iz] == pod.SkarnId, s2 = v2[iz].Material == pod.SkarnId;
            if (!karb && !s1 && !s2) continue;
            bool je = pod.Skarn.Nejblizsi(x, y, z, 4.0, out var b); double d = je ? b.D : double.PositiveInfinity; bool od = je && b.Odhad;
            s.Kvalita1.Bunka(s1, karb, m1[iz] == vm, d, od);
            s.Kvalita2.Bunka(s2, karb, v2[iz].Material == vm, d, od);
        }
    }

    public const int Nz = 512;
    public const double KrokZ = 0.25;

    public readonly record struct Vysledek(V8Soucty Soucty, double KontextS, double Geo1S, double Geo2SloupceS);

    public static V8Soucty Porovnej(GeologieCs g0, KatalogGeo2 kat, DataSveta d, double ox, double oy, double krokXy, int vlaken) =>
        Mer(g0, kat, d, ox, oy, krokXy, vlaken).Soucty;

    /// <summary>Jako <see cref="Porovnej"/>, navíc stěnový čas kontextu GEO2, sloupců GEO1 a sloupců GEO2 (dva oddělené paralelní průchody).</summary>
    public static Vysledek Mer(GeologieCs g0, KatalogGeo2 kat, DataSveta d, double ox, double oy, double krokXy, int vlaken)
    {
        var o = OblastBloku.Ctverec(ox, oy, 128);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), o, null, vlaken);
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        double tKontext = sw.Elapsed.TotalSeconds;
        var c = k.Chronologie; var z2 = new Zdroj2(c);
        var kp = (KontaktniPasmo)c.Udalosti[c.IndexUdalosti("skarn_kontakt")].Kontakt!;
        var karbonat = new bool[kat.MaxId + 1];
        foreach (var kl in SadaE84.Karbonaty) { var m = kat.PodleKlice(kl); if (m is not null) karbonat[m.Id] = true; }
        var pod = new PodkladyKlasifikace { Skarn = kp.Plochy[0], IndexCocek = IndexUtvaruE84.Sestav(g0.Svet, DruhUtvaru.Cocka, o), Utvary = g0.Geo.Utvary, Karbonat = karbonat, SkarnId = kat.PodleKlice("skarn")!.Id, Pasmo = kp, Chron = c, IdxSkarn = c.IndexUdalosti("skarn_kontakt") };
        int n = (int)Math.Round(128 / krokXy);
        var celkem = new V8Soucty(); object zamek = new();
        var opt = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        var m1all = new byte[(long)n * n * Nz];
        sw.Restart();
        Parallel.For(0, n, opt, () => g0.Klon(), (ix, _, g) =>
        {
            for (int iy = 0; iy < n; iy++)
            {
                var sl = g.Geo.VyplnSloupec(ox + (ix + 0.5) * krokXy, oy + (iy + 0.5) * krokXy, KrokZ, Nz * KrokZ);
                Array.Copy(sl, 0, m1all, (int)(((long)ix * n + iy) * Nz), Nz);
            }
            return g;
        }, _ => { });
        double tGeo1 = sw.Elapsed.TotalSeconds;
        long geo2Max = 0;
        sw.Restart();
        Parallel.For(0, n, opt, () => (g0.Klon(), new V8Soucty(), 0L), (ix, _, st) =>
        {
            var (g, s, t2) = st; var v2 = new Vzorek[Nz]; var sw2 = new System.Diagnostics.Stopwatch();
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy;
                var m1 = m1all.AsSpan((int)(((long)ix * n + iy) * Nz), Nz);
                sw2.Restart(); k.Sloupec(x, y, 0, KrokZ, v2); t2 += sw2.ElapsedTicks;
                s.Bunek += Nz;
                List<Hranice>? hr = null; List<Utvar>? feats = null; double zPov1 = 0;
                bool maSkarn = false; for (int iz = 0; iz < Nz && !maSkarn; iz++) maSkarn = m1[iz] == pod.SkarnId || v2[iz].Material == pod.SkarnId;
                if (maSkarn) Kvalita(g, k, pod, s, x, y, m1, v2);
                for (int iz = 0; iz < Nz; iz++)
                {
                    if (m1[iz] == v2[iz].Material) continue;
                    double z = (iz + 0.5) * KrokZ;
                    if (hr is null)
                    {
                        var w = g.Svet.Vahy(x, y); zPov1 = g.Svet.VyskaW(x, y, w);
                        hr = g.Geo.Vrstvy.Hranice(x, y, w, g.Svet.VyskaTvar(x, y), zPov1); feats = g.Geo.Utvary.Tvorba.Features(x, y);
                    }
                    double dh = double.PositiveInfinity; foreach (var h in hr) dh = Math.Min(dh, Math.Min(Math.Abs(z - h.Z0), Math.Abs(z - h.Z1)));
                    int vm = z > zPov1 ? -1 : VrstvySloupce.VrstvaMat(z, hr);
                    var rb = new RozdilBunky(x, y, z, m1[iz], v2[iz].Material, Zdroj1.Urci(g.Geo, feats!, hr, x, y, z, zPov1), z2.Urci(v2[iz]), zPov1, k.Povrch(x, y), dh, vm);
                    var pc = Klasifikator.Urci(rb, pod); if (Verdikty.Z(pc) == Verdikt.Otevrene) Otevrene.Add((x, y, z, pc));
                    s.Pridej(rb, pc);
                }
            }
            return (g, s, t2);
        }, st => { lock (zamek) { celkem.Slouc(st.Item2); if (st.Item3 > geo2Max) geo2Max = st.Item3; } });
        return new Vysledek(celkem, tKontext, tGeo1, geo2Max / (double)System.Diagnostics.Stopwatch.Frequency);
    }
}
