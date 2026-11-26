using Willage.Gen.Api.Sluzby;
using Willage.Gen.Data;

namespace Willage.Gen.Api;

/// <summary>
/// Vstupní bod fasády: jedna planeta v paměti a její služby. Godot jádro (G-4) drží jednu instanci a volá ji z fronty na pozadí.
/// </summary>
public sealed class GeneratorSveta
{
    public StavGeneratoru Stav { get; }
    public IModuly Moduly { get; }
    public ISluzbaSveta Sluzba { get; }
    public IDotazySveta Dotazy { get; }
    public IKatalogy Katalogy { get; }
    public IVizualniData Vizual { get; }
    public IUpravyRegionu Upravy { get; }
    /// <summary>G-6: náhledy a izolace M1–M3.</summary>
    public INahledyModulu Nahledy { get; }

    public GeneratorSveta(DataSveta d, string? kes = null, int vlaken = 8)
    {
        Stav = new StavGeneratoru(d, kes, vlaken);
        Moduly = new ModulyApi(Stav); Sluzba = new SluzbaSvetaApi(Stav); Dotazy = new DotazySvetaApi(Stav); Katalogy = new KatalogyApi(Stav);
        Nahledy = new NahledyModuluApi(Stav);
        Vizual = new ZastupnaVizualniData(); Upravy = new ZastupneUpravyRegionu();
    }

    /// <summary>Najde godot-prototyp/data od zadané složky nahoru.</summary>
    public static GeneratorSveta Otevri(string odkud, string? kes = null, int vlaken = 8) => new(DataSveta.Najdi(odkud), kes, vlaken);
}
