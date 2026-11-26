using System.Text.Json;
using System.Text.Json.Serialization;
using Willage.Gen.Svet;

namespace Willage.Gen.Schema;

/// <summary>
/// G-2: Biom má jen konstruktor s jinými názvy parametrů (posun, prev, …) než pole (PosunM, PrevyseniM, …), takže ho System.Text.Json
/// neumí načíst. Převodník čte a píše stejná pole jako výchozí serializace (IncludeFields), ParametrySveta se nemění.
/// </summary>
public sealed class BiomJson : JsonConverter<Biom>
{
    public override Biom Read(ref Utf8JsonReader r, Type t, JsonSerializerOptions o)
    {
        var e = JsonElement.ParseValue(ref r);
        double D(string n) => e.GetProperty(n).GetDouble();
        return new Biom(D("PosunM"), D("PrevyseniM"), D("VlnaM"), D("Drsnost"), D("StropDeg"), e.GetProperty("Hreben").GetBoolean());
    }

    public override void Write(Utf8JsonWriter w, Biom b, JsonSerializerOptions o)
    {
        w.WriteStartObject();
        w.WriteNumber("PosunM", b.PosunM); w.WriteNumber("PrevyseniM", b.PrevyseniM); w.WriteNumber("VlnaM", b.VlnaM);
        w.WriteNumber("Drsnost", b.Drsnost); w.WriteNumber("StropDeg", b.StropDeg); w.WriteBoolean("Hreben", b.Hreben);
        w.WriteEndObject();
    }
}
