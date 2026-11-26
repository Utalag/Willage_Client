using Willage.Gen.Sum;
using Willage.Gen.Svet;

namespace Willage.Gen.Geologie;

/// <summary>Port geo_vrstvy.gd: zástupci pásem, hranice vrstev, mince E82 (zvednutí vápence, vyklínění jílu), slučování tenkých.</summary>
public sealed class VrstvySloupce
{
    private static readonly int[] Jil = { 4, 12, 51 }, Vapenec = { 5, 44, 49 };
    private static readonly (string jmeno, int idx0, int idx1)[] Pasma = { ("spodek", 0, 12), ("krystalinikum", 13, 25), ("sedimenty", 26, 36), ("svrchni", 37, 40) };
    private const double MinT = 0.25;
    private readonly SvetFn _s; private readonly KatalogHornin _k; private readonly SumHornin _sum; private readonly MinceE82 _m;
    private readonly List<Hornina>[] _pasmoHornin = new List<Hornina>[4];

    public VrstvySloupce(SvetFn s, KatalogHornin k, SumHornin sum, MinceE82 m)
    {
        _s = s; _k = k; _sum = sum; _m = m;
        for (int i = 0; i < 4; i++)
        {
            var p = Pasma[i];
            _pasmoHornin[i] = k.Horniny.Where(r => r.Idx >= p.idx0 && r.Idx <= p.idx1 && r.Kind is "layer" or "soil" or "seam").ToList();
        }
    }

    private double[] Podily()
    {
        var p = _s.P; return new[] { p.PasmoSpodek, p.PasmoKrystalinikum, p.PasmoSedimenty, p.PasmoSvrchni };
    }

    private List<(int id, double v)> Zastupci(double x, double y, int ip, List<(int id, double podil)> hr)
    {
        var vahy = new OrderedMap(); var band = new HashSet<int>();
        foreach (var r in _pasmoHornin[ip]) if (r.Active) { if (!band.Contains(r.Id)) band.Add(r.Id); vahy.Set(r.Id, 0); }
        // přítomnost a mocnost ze seedu (pořadí vložení = pořadí katalogu, poslední výskyt id vyhrává)
        var posl = new Dictionary<int, Hornina>();
        foreach (var r in _pasmoHornin[ip]) if (r.Active) posl[r.Id] = r;
        foreach (int id in vahy.Keys.ToList())
        {
            var r = posl[id];
            double pres = Gd.Smoothstep(1.0 - r.Freq - 0.12, 1.0 - r.Freq + 0.12, _sum.Oktava("V1_PRES", r.Idx, x, y, 180.0));
            double t = Gd.Lerpf(r.Thick0, r.Thick1, _sum.MocnostN01(r.Id, r.Idx, x, y));
            vahy.Set(id, Gd.Maxf(t * pres, 0.0));
        }
        foreach (var e in hr) if (band.Contains(e.id)) vahy.Set(e.id, vahy.Get(e.id) + e.podil * 2.0);
        double k = _s.P.KlimaKHorniny;
        if (Math.Abs(k - 1.0) > 1e-12) foreach (int id in vahy.Keys.ToList()) vahy.Set(id, Math.Pow(Gd.Maxf(vahy.Get(id), 1e-12), k));
        double suma = 0.0; foreach (int id in vahy.Keys) suma += vahy.Get(id);
        if (suma <= 1e-12)
        {
            var r0 = _pasmoHornin[ip].FirstOrDefault();
            if (r0 is not null) { vahy.Set(r0.Id, 1.0); suma = 1.0; }
        }
        var arr = vahy.Keys.Select(id => (id, v: vahy.Get(id) / Gd.Maxf(suma, 1e-12))).ToList();
        arr.Sort((a, b) => a.v > b.v || (a.v == b.v && a.id < b.id) ? -1 : (b.v > a.v || (a.v == b.v && b.id < a.id) ? 1 : 0));
        int n = Math.Max(1, _s.P.Zastupcu);
        if (arr.Count > n) arr = arr.GetRange(0, n);
        var o = new List<(int id, double v)>(); double s2 = 0.0;
        foreach (var e in arr) { if (e.v < 0.06) continue; o.Add(e); s2 += e.v; }
        if (o.Count == 0 && arr.Count > 0) { o.Add(arr[0]); s2 = arr[0].v; }
        if (s2 > 0.0) for (int i = 0; i < o.Count; i++) o[i] = (o[i].id, o[i].v / s2);
        return o;
    }

    /// <summary>geo_vrstvy.gd::hranice (z tvaru a skutečného povrchu); mince se uplatní silou 0–1.</summary>
    public List<Hranice> Hranice(double x, double y, double[] w, double zTvar, double zPov)
    {
        double hgt = Gd.Maxf(zTvar, 0.25), maxT = 0.25 * hgt;
        var pod = Podily(); double ps = 0.0; foreach (var v in pod) ps += v;
        if (ps <= 0.0) ps = 1.0;
        var hrMap = _s.Horniny.Horniny(x, y, w);
        var vrstvy = new List<Vrstva>();
        for (int i = 0; i < 4; i++)
        {
            double bandH = hgt * pod[i] / ps;
            foreach (var e in Zastupci(x, y, i, hrMap))
            {
                double th = bandH * e.v;
                if (th < MinT * 0.5) continue;
                vrstvy.Add(new Vrstva(e.id, Gd.Clampf(th, MinT, maxT)));
            }
        }
        double suma = 0.0; foreach (var v in vrstvy) suma += v.Thick;
        if (vrstvy.Count == 0) { vrstvy.Add(new Vrstva(20, hgt)); suma = hgt; }
        if (suma < hgt) vrstvy[0].Thick += hgt - suma;
        else if (suma > hgt)
        {
            double extra = suma - hgt;
            for (int i = vrstvy.Count - 1; i >= 0; i--)
            {
                double can = vrstvy[i].Thick - MinT;
                if (can <= 0.0) continue;
                double take = Gd.Minf(can, extra);
                vrstvy[i].Thick -= take; extra -= take;
                if (extra <= 1e-12) break;
            }
        }
        SlucTenke(vrstvy);
        double sila = _m.Sila(x, y);
        if (sila > 0.0) { MinceZvedni(vrstvy, zTvar, sila); SlucTenke(vrstvy); }
        var o = new List<Hranice>(); double z = 0.0;
        foreach (var v in vrstvy)
        {
            double z0 = z, z1 = z + v.Thick; z = z1;
            double d1 = Gd.Minf(z1, zPov);
            if (d1 <= z0) continue;
            o.Add(new Hranice(v.Id, z0, d1, v.Thick));
        }
        return o;
    }

    private bool Tesni(int id) => Jil.Contains(id) || _k.Perm0.Contains(id);

    /// <summary>Zvedne vápenec k odhadu hladiny − p82_pod_m a vyklíní jíl nad ním; sila 1 = krok 3 bitově, menší = část cesty.</summary>
    private void MinceZvedni(List<Vrstva> vrstvy, double zTvar, double sila)
    {
        double cil = zTvar - _s.P.P82PodM;
        if (cil < 0.25) return;
        double z = 0.0; int iVap = -1; double z1Vap = 0.0;
        for (int i = 0; i < vrstvy.Count; i++)
        {
            z += vrstvy[i].Thick;
            if (Vapenec.Contains(vrstvy[i].Id)) { iVap = i; z1Vap = z; }
        }
        if (iVap < 0 || z1Vap >= cil) return;
        double need = (cil - z1Vap) * sila;
        for (int j = iVap + 1; j < vrstvy.Count && need > 1e-9; j++)
        {
            double th = vrstvy[j].Thick, take = 0.0;
            if (th <= need + 1e-12) take = th;
            else if (th - need >= MinT) take = need;
            else if (th > MinT) take = th - MinT;
            if (take > 1e-12) { vrstvy[j].Thick = th - take; vrstvy[iVap].Thick += take; need -= take; }
        }
        for (int j = iVap + 1; j < vrstvy.Count; j++)
        {
            if (!Tesni(vrstvy[j].Id)) continue;
            double th = vrstvy[j].Thick, pres = th * sila;
            vrstvy[j].Thick = th - pres;
            int kam = -1;
            for (int k = j + 1; k < vrstvy.Count; k++) if (!Tesni(vrstvy[k].Id)) { kam = k; break; }
            if (kam >= 0) vrstvy[kam].Thick += pres; else vrstvy[iVap].Thick += pres;
        }
        vrstvy.RemoveAll(v => !(v.Thick > 1e-9));
    }

    private static void SlucTenke(List<Vrstva> vrstvy)
    {
        for (int guard = 0; guard < 64; guard++)
        {
            int i = vrstvy.FindIndex(v => v.Thick < MinT - 1e-12);
            if (i < 0) break;
            if (vrstvy.Count == 1) { vrstvy[0].Thick = Gd.Maxf(vrstvy[0].Thick, MinT); break; }
            int j = i > 0 ? i - 1 : i + 1;
            if (i + 1 < vrstvy.Count && (i == 0 || vrstvy[i + 1].Thick >= vrstvy[i - 1].Thick)) j = i + 1;
            vrstvy[j].Thick += vrstvy[i].Thick;
            vrstvy.RemoveAt(i);
        }
        vrstvy.RemoveAll(v => !(v.Thick > 1e-9));
    }

    public static int VrstvaMat(double z, List<Hranice> hr)
    {
        foreach (var e in hr) if (z >= e.Z0 && z < e.Z1) return e.Id;
        if (hr.Count > 0 && z >= hr[^1].Z1 - 1e-9) return hr[^1].Id;
        return 0;
    }
}
