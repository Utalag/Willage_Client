namespace Willage.Gen.Geo2;

/// <summary>Filtr materiálů <c>nahrazuje</c> / <c>hostitel_okoli</c> (kap. 2.2). Maska podle id; velikost podle katalogu, ne pevná.</summary>
public sealed class FiltrMaterialu
{
    private readonly bool[] _ano, _krome, _nikdy;
    public bool Vse { get; }
    public bool IgnorujNikdy { get; }

    public FiltrMaterialu(bool vse, IEnumerable<int> ano, IEnumerable<int> krome, IEnumerable<int> nikdy, bool ignorujNikdy, int maxId)
    {
        int n = Math.Max(maxId + 1, 1);
        _ano = new bool[n]; _krome = new bool[n]; _nikdy = new bool[n];
        foreach (var i in ano) if (i >= 0 && i < n) _ano[i] = true;
        foreach (var i in krome) if (i >= 0 && i < n) _krome[i] = true;
        foreach (var i in nikdy) if (i >= 0 && i < n) _nikdy[i] = true;
        Vse = vse; IgnorujNikdy = ignorujNikdy;
    }

    public bool Plati(int material)
    {
        if (material < 0 || material >= _ano.Length) return false;
        if (!IgnorujNikdy && _nikdy[material]) return false;
        if (_krome[material]) return false;
        return Vse || _ano[material];
    }

    public IEnumerable<int> Ano => Enumerable.Range(0, _ano.Length).Where(i => _ano[i]);
}

public enum RezimTeles { Zadna, Starsi, Vycet }

/// <summary><c>zdroje</c> (kap. 2.2): do čeho smí událost podle geometrického původu cíle.</summary>
public sealed record ZdrojeZasahu(bool VrstvyVse, IReadOnlySet<int>? VrstvyMaterialy, RezimTeles Telesa, IReadOnlySet<int> TelesaUdalosti, bool Transformace)
{
    /// <summary>Id událostí z dat (před převodem na indexy chronologie).</summary>
    public IReadOnlySet<string> TelesaId { get; init; } = new HashSet<string>();

    public bool Plati(in StavBodu s)
    {
        if (s.PocetTransformaci > 0 && !Transformace) return false;
        if (s.GeoOperace == Operace.Uloz)
            return VrstvyVse || (VrstvyMaterialy?.Contains(s.MaterialPuvodu) ?? false);
        if (Geo2Zaklad.JeTeleso(s.GeoOperace))
            return Telesa switch { RezimTeles.Starsi => true, RezimTeles.Vycet => TelesaUdalosti.Contains(s.GeoUdalost), _ => false };
        return false;
    }
}

public readonly record struct Hloubka(double? MinM, double? MaxM)
{
    public bool Plati(double z, double zPov)
    {
        double h = zPov - z;
        return (MinM is null || h >= MinM.Value) && (MaxM is null || h <= MaxM.Value);
    }
}

/// <summary>Pravidlo cíle 2.3: materiál → <c>nahrazuje</c> + <c>zdroje</c>; prázdno → jen <c>prostor</c>; nikdy obojí.</summary>
public static class PravidloCile
{
    public static bool OperaceSmiNaTridu(Operace o, TridaCile t) => t switch
    {
        TridaCile.Neurceno => o == Operace.Uloz,
        TridaCile.Material => o is Operace.Vnikni or Operace.Odstran or Operace.Transformuj,
        TridaCile.Prazdno => o is Operace.Vnikni or Operace.Vypln,
        _ => false,
    };

    public static bool Povoluje(KompilovanaUdalost e, in StavBodu s, double x, double y, double z, double zPov, PrefixVyhodnoceni? pred)
    {
        if (!e.Hloubka.Plati(z, zPov)) return false;
        var t = s.Trida;
        if (!OperaceSmiNaTridu(e.Operace, t)) return false;
        bool cil = t switch
        {
            TridaCile.Neurceno => true,
            TridaCile.Material => (e.Nahrazuje?.Plati(s.Material) ?? false) && (e.Zdroje?.Plati(s) ?? false),
            TridaCile.Prazdno => e.Prostor.Contains(s.Typ),
            _ => false,
        };
        if (!cil) return false;
        return e.Kontakt is null || (pred is not null && e.Kontakt.Plati(x, y, z, s, pred));
    }
}
