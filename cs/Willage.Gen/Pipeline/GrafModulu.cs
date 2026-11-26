namespace Willage.Gen.Pipeline;

/// <summary>G-1: graf modulů (dependsOn): kontrola id a cyklů, deterministické topologické pořadí, tranzitivně závislé moduly.</summary>
public sealed class GrafModulu
{
    private readonly Dictionary<string, IModul> _podle;
    public IReadOnlyList<IModul> Poradi { get; }

    public GrafModulu(IEnumerable<IModul> moduly)
    {
        var l = moduly.ToList();
        _podle = new Dictionary<string, IModul>(StringComparer.Ordinal);
        foreach (var m in l) if (!_podle.TryAdd(m.Id, m)) throw new ArgumentException("duplicitní id modulu: " + m.Id);
        foreach (var m in l)
            foreach (var z in m.Zavislosti)
                if (!_podle.ContainsKey(z)) throw new ArgumentException($"modul {m.Id} závisí na neznámém {z}");
        // Kahn s ordinálním řazením připravených → stejné pořadí na každém stroji
        var vstupu = l.ToDictionary(m => m.Id, m => m.Zavislosti.Distinct().Count(), StringComparer.Ordinal);
        var pripr = new SortedSet<string>(vstupu.Where(v => v.Value == 0).Select(v => v.Key), StringComparer.Ordinal);
        var por = new List<IModul>();
        while (pripr.Count > 0)
        {
            string id = pripr.Min!; pripr.Remove(id); por.Add(_podle[id]);
            foreach (var m in l.Where(m => m.Zavislosti.Contains(id)))
                if (--vstupu[m.Id] == 0) pripr.Add(m.Id);
        }
        if (por.Count != l.Count) throw new ArgumentException("cyklus v grafu modulů: " + string.Join(", ", vstupu.Where(v => v.Value > 0).Select(v => v.Key)));
        Poradi = por;
    }

    public IModul this[string id] => _podle[id];
    public bool Obsahuje(string id) => _podle.ContainsKey(id);

    /// <summary>Moduly, které na id závisí (tranzitivně), v topologickém pořadí; bez id samého.</summary>
    public IReadOnlyList<string> Zavisle(string id)
    {
        var s = new HashSet<string>(StringComparer.Ordinal) { id };
        foreach (var m in Poradi) if (m.Zavislosti.Any(s.Contains)) s.Add(m.Id);
        s.Remove(id);
        return Poradi.Select(m => m.Id).Where(s.Contains).ToList();
    }

    /// <summary>Moduly, na kterých id závisí (tranzitivně), v topologickém pořadí; bez id samého.</summary>
    public IReadOnlyList<string> Predchudci(string id)
    {
        var s = new HashSet<string>(StringComparer.Ordinal);
        void Pridej(string x) { foreach (var z in _podle[x].Zavislosti) if (s.Add(z)) Pridej(z); }
        Pridej(id);
        return Poradi.Select(m => m.Id).Where(s.Contains).ToList();
    }
}
