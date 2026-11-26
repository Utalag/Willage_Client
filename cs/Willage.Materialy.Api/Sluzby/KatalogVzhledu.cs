using System.Globalization;
using System.Text.Json;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Rozhrani;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>Zrcadlo katalogu Dev → materiály s profily a fyzikou. Jen čte; validaci schématu dělá loader Dev v nástroji (kontrola zrcadla).</summary>
public sealed class KatalogVzhledu : IKatalogVzhledu
{
    readonly Dictionary<byte, MaterialVzhleduDto> _podle;
    public IReadOnlyList<MaterialVzhleduDto> Materialy { get; }
    public IReadOnlyList<string> Skupiny { get; }
    public string Cesta { get; }

    public KatalogVzhledu(string cesta)
    {
        Cesta = cesta;
        using var d = JsonDocument.Parse(File.ReadAllText(cesta));
        var l = new List<MaterialVzhleduDto>();
        foreach (var m in d.RootElement.GetProperty("materials").EnumerateArray())
        {
            var g = m.GetProperty("geology");
            var fyz = g.EnumerateObject().Select(p => new UdajFyzikyDto(p.Name, Text(p.Value))).ToList();
            var prof = new SortedDictionary<string, ProfilVzhleduDto>(StringComparer.Ordinal);
            foreach (var p in m.GetProperty("visualProfiles").EnumerateObject())
            {
                var v = p.Value;
                prof[p.Name] = new ProfilVzhleduDto(v.GetProperty("style").GetString() ?? "", v.GetProperty("baseColor").GetString() ?? "",
                    v.GetProperty("grainScalePermille").GetInt32(), v.GetProperty("layerDensityPermille").GetInt32(), v.GetProperty("irregularityPermille").GetInt32());
            }
            l.Add(new MaterialVzhleduDto((byte)m.GetProperty("id").GetInt32(), m.GetProperty("key").GetString() ?? "", m.GetProperty("name").GetString() ?? "",
                m.GetProperty("idStatus").GetString() ?? "", g.TryGetProperty("skupina", out var s) ? s.GetString() ?? "" : "", prof, fyz));
        }
        Materialy = l.OrderBy(x => x.Id).ToList();
        _podle = Materialy.ToDictionary(x => x.Id);
        Skupiny = Materialy.Select(x => x.Skupina).Distinct().OrderBy(x => x, StringComparer.Ordinal).ToList();
    }

    static string Text(JsonElement e) => e.ValueKind switch
    {
        JsonValueKind.Null => "—",
        JsonValueKind.String => e.GetString() ?? "",
        JsonValueKind.Number => e.GetRawText(),
        _ => e.GetRawText(),
    };

    public MaterialVzhleduDto? Material(byte id) => _podle.GetValueOrDefault(id);

    /// <summary>Barva #RRGGBB → (r, g, b) 0–255 (pro seznam a vzorky; nic nepočítá za VPMG).</summary>
    public static (byte R, byte G, byte B) Barva(string hex)
    {
        var h = hex.Trim().TrimStart('#');
        if (h.Length != 6) return (255, 0, 255);
        return (byte.Parse(h[..2], NumberStyles.HexNumber), byte.Parse(h[2..4], NumberStyles.HexNumber), byte.Parse(h[4..], NumberStyles.HexNumber));
    }
}
