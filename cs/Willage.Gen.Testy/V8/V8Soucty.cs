namespace Willage.Gen.Testy.V8;

/// <summary>Součty rozdílů GEO2 × GEO1 pro jednu kategorii (sloučitelné mezi vlákny a bloky; výsledek nezávisí na pořadí).</summary>
public sealed class V8Soucty
{
    public long Bunek, Ruznych;
    public readonly V8Kvalita Kvalita1 = new(), Kvalita2 = new();
    public readonly Dictionary<(Zdroj, Zdroj, Pricina), long> Pary = new();
    public readonly Dictionary<(int, int), long> Prechody = new();
    public readonly Dictionary<Pricina, List<(double X, double Y, double Z, int M1, int M2)>> Priklady = new();

    public void Pridej(in RozdilBunky r, Pricina p)
    {
        Ruznych++;
        var k = (r.Z1, r.Z2, p); Pary[k] = Pary.GetValueOrDefault(k) + 1;
        var t = (r.M1, r.M2); Prechody[t] = Prechody.GetValueOrDefault(t) + 1;
        if (!Priklady.TryGetValue(p, out var l)) Priklady[p] = l = new();
        if (l.Count < 5) l.Add((r.X, r.Y, r.Z, r.M1, r.M2));
    }

    public void Slouc(V8Soucty o)
    {
        Bunek += o.Bunek; Ruznych += o.Ruznych; Kvalita1.Slouc(o.Kvalita1); Kvalita2.Slouc(o.Kvalita2);
        foreach (var kv in o.Pary) Pary[kv.Key] = Pary.GetValueOrDefault(kv.Key) + kv.Value;
        foreach (var kv in o.Prechody) Prechody[kv.Key] = Prechody.GetValueOrDefault(kv.Key) + kv.Value;
        foreach (var kv in o.Priklady)
        {
            if (!Priklady.TryGetValue(kv.Key, out var l)) Priklady[kv.Key] = l = new();
            foreach (var e in kv.Value) if (l.Count < 5) l.Add(e);
        }
    }

    public Dictionary<Pricina, long> PodlePriciny()
    {
        var d = new Dictionary<Pricina, long>();
        foreach (var kv in Pary) d[kv.Key.Item3] = d.GetValueOrDefault(kv.Key.Item3) + kv.Value;
        return d;
    }

    public Dictionary<Verdikt, long> PodleVerdiktu()
    {
        var d = new Dictionary<Verdikt, long>();
        foreach (var kv in PodlePriciny()) { var v = Verdikty.Z(kv.Key); d[v] = d.GetValueOrDefault(v) + kv.Value; }
        return d;
    }
}
