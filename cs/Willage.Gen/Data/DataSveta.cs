namespace Willage.Gen.Data;

/// <summary>Cesty k datům prototypu (godot-prototyp/data) – data se nemění, C# je jen čte.</summary>
public sealed class DataSveta
{
    public string Koren { get; }
    public DataSveta(string korenData) => Koren = korenData;
    public string Cesta(string rel) => Path.Combine(Koren, rel);
    public string PoradiHornin => Cesta("teren/poradi_hornin.json");
    public string MaterialyV1 => Cesta("materialy_v1.csv");
    public string KlimaPresety => Cesta("klima_presety.csv");
    public string UtvaryHostitele => Cesta("v1/utvary_hostitele.json");
    public string SumHornin => Cesta("v1/sum_hornin_v1.csv");
    public string MineralyHostitele => Cesta("teren/mineraly_hostitele.json");
    public string KatalogMaterialu => Cesta("v1/materials-catalog-v1.json");
    public string VodaV1 => Cesta("v1/voda_v1.json");

    /// <summary>Najde godot-prototyp/data od zadané složky nahoru.</summary>
    public static DataSveta Najdi(string odkud)
    {
        var d = new DirectoryInfo(odkud);
        while (d is not null)
        {
            var c = Path.Combine(d.FullName, "godot-prototyp", "data");
            if (Directory.Exists(c)) return new DataSveta(c);
            if (File.Exists(Path.Combine(d.FullName, "project.godot"))) return new DataSveta(Path.Combine(d.FullName, "data"));
            d = d.Parent;
        }
        throw new DirectoryNotFoundException("godot-prototyp/data nenalezeno od " + odkud);
    }
}
