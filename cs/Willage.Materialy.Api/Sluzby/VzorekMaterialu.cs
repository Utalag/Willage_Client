using System.Text.Json;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>Jeden materiál vzorku a důvod výběru.</summary>
public sealed record MaterialVzorkuDto(byte Id, string Key, string Proc);

/// <summary>
/// Vzorek materiálů, pro které editor zatím funguje (Jan 21:44: „zatím jen vzorek třeba 5 materiálů“; data/vpmg/vzorek_materialu_v0.json).
/// Ostatní materiály katalogu jsou zástupné (vidět, nejde je vybrat). ID i klíč se kontrolují proti katalogu.
/// </summary>
public sealed class VzorekMaterialu
{
    public IReadOnlyList<MaterialVzorkuDto> Materialy { get; }
    readonly HashSet<byte> _ids;

    public VzorekMaterialu(string cesta, KatalogVzhledu katalog)
    {
        using var d = JsonDocument.Parse(File.ReadAllText(cesta));
        Materialy = d.RootElement.GetProperty("materialy").EnumerateArray()
            .Select(m => new MaterialVzorkuDto((byte)m.GetProperty("id").GetInt32(), m.GetProperty("key").GetString()!, m.GetProperty("proc").GetString()!)).ToList();
        foreach (var m in Materialy)
            if (katalog.Material(m.Id) is not { } k || k.Key != m.Key) throw new InvalidDataException($"vzorek: materiál {m.Id} '{m.Key}' neodpovídá katalogu");
        _ids = Materialy.Select(m => m.Id).ToHashSet();
    }

    public bool Obsahuje(byte id) => _ids.Contains(id);
    public static string Zastupny(byte id) => $"zástupné: materiál {id} je mimo vzorek 5 materiálů (Jan 21:44) – editor ho zatím neupravuje";
}
