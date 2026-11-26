using Willage.Gen.Data;
using Willage.Gen.Katalogy;
using Willage.Gen.Svet;

namespace Willage.Gen.Pipeline;

/// <summary>Vstupy jednoho běhu pipeline: data, manifest, efektivní parametry světa (kopie po more_v1.json), nastavení modulů, keš a vlákna.</summary>
public sealed class KontextBehu
{
    public DataSveta Data { get; }
    public ManifestKatalogu Manifest { get; }
    /// <summary>Efektivní parametry světa (kopie vstupu s uplatněným more_v1.json). Moduly z nich staví vlastní kopie, tento objekt nemění.</summary>
    public ParametrySveta Parametry { get; }
    public NastaveniModulu Nastaveni { get; }
    /// <summary>Složka keše WGER (null = bez ukládání). Do klíčů nevstupuje.</summary>
    public string? Kes { get; }
    /// <summary>Počet vláken; výsledek na něm nezávisí, do klíčů nevstupuje.</summary>
    public int Vlaken { get; }
    private readonly Func<string, object> _vystup;

    internal KontextBehu(DataSveta d, ManifestKatalogu m, ParametrySveta p, NastaveniModulu n, string? kes, int vlaken, Func<string, object> vystup)
    { Data = d; Manifest = m; Parametry = p; Nastaveni = n; Kes = kes; Vlaken = vlaken; _vystup = vystup; }

    /// <summary>Výstup modulu, na kterém tento modul závisí.</summary>
    public T Vystup<T>(string id) => (T)_vystup(id);
}
