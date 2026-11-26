using System.Collections;
using System.Reflection;
using Godot;

namespace WillagePrototyp.Jadro.Adaptery;

/// <summary>G-4: DTO fasády → Godot Dictionary/Array (pro signály a GDScript). Reflexe vlastností; enumy jako text.</summary>
public static class DtoNaVariant
{
    public static Variant Hodnota(object? o) => o switch
    {
        null => default,
        string s => s,
        bool b => b,
        int i => i,
        long l => l,
        uint u => (long)u,
        double d => d,
        float f => f,
        System.Enum e => e.ToString(),
        byte[] by => by,
        float[] fa => fa,
        double[] da => da,
        IDictionary dict => Slovnik(dict),
        IEnumerable en => Pole(en),
        _ => Slovnik(o),
    };

    public static Godot.Collections.Dictionary Slovnik(object o)
    {
        var d = new Godot.Collections.Dictionary();
        if (o is IDictionary id) { foreach (DictionaryEntry e in id) d[e.Key.ToString()!] = Hodnota(e.Value); return d; }
        foreach (var p in o.GetType().GetProperties(BindingFlags.Public | BindingFlags.Instance))
            if (p.GetIndexParameters().Length == 0) d[p.Name] = Hodnota(p.GetValue(o));
        return d;
    }

    public static Godot.Collections.Array Pole(IEnumerable en)
    {
        var a = new Godot.Collections.Array();
        foreach (var x in en) a.Add(Hodnota(x));
        return a;
    }
}
