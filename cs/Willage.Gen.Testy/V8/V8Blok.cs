using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.V8;

/// <summary>Porovná jeden blok 128 m: GEO1 <c>VyplnSloupec</c> × GEO2 výchozí <c>KontextBloku.Sloupec</c>, rozdíly klasifikuje.</summary>
public static class V8Blok
{
    public const int Nz = 512;
    public const double KrokZ = 0.25;

    public static V8Soucty Porovnej(GeologieCs g0, KatalogGeo2 kat, DataSveta d, double ox, double oy, double krokXy, int vlaken)
    {
        var o = OblastBloku.Ctverec(ox, oy, 128);
        var (k, r) = KontextBlokuE84.Sestav(g0.Geo, kat, SadaE84.Json(d), o, null, vlaken);
        if (!r.Ok) throw new InvalidOperationException(r.Zprava.ToString());
        var c = k.Chronologie; var z2 = new Zdroj2(c);
        var kp = (KontaktniPasmo)c.Udalosti[c.IndexUdalosti("skarn_kontakt")].Kontakt!;
        var karbonat = new bool[kat.MaxId + 1];
        foreach (var kl in SadaE84.Karbonaty) { var m = kat.PodleKlice(kl); if (m is not null) karbonat[m.Id] = true; }
        var pod = new PodkladyKlasifikace { Skarn = kp.Plochy[0], IndexCocek = IndexUtvaruE84.Sestav(g0.Svet, DruhUtvaru.Cocka, o), Utvary = g0.Geo.Utvary, Karbonat = karbonat, SkarnId = kat.PodleKlice("skarn")!.Id };
        int n = (int)Math.Round(128 / krokXy);
        var celkem = new V8Soucty(); object zamek = new();
        Parallel.For(0, n, new ParallelOptions { MaxDegreeOfParallelism = vlaken }, () => (g0.Klon(), new V8Soucty()), (ix, _, st) =>
        {
            var (g, s) = st; var v2 = new Vzorek[Nz];
            for (int iy = 0; iy < n; iy++)
            {
                double x = ox + (ix + 0.5) * krokXy, y = oy + (iy + 0.5) * krokXy;
                var m1 = g.Geo.VyplnSloupec(x, y, KrokZ, Nz * KrokZ);
                k.Sloupec(x, y, 0, KrokZ, v2);
                s.Bunek += Nz;
                List<Hranice>? hr = null; List<Utvar>? feats = null; double zPov1 = 0;
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
                    s.Pridej(rb, Klasifikator.Urci(rb, pod));
                }
            }
            return (g, s);
        }, st => { lock (zamek) celkem.Slouc(st.Item2); });
        return celkem;
    }
}
