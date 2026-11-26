using Willage.Materialy.Api.Dto;

namespace Willage.Materialy.Api.Rozhrani;

/// <summary>Katalog vzhledu materiálů ze zrcadla katalogu Dev (jen čtení).</summary>
public interface IKatalogVzhledu
{
    IReadOnlyList<MaterialVzhleduDto> Materialy { get; }
    MaterialVzhleduDto? Material(byte id);
    IReadOnlyList<string> Skupiny { get; }
}

/// <summary>Zdroj textur VPMG (T-1: nástroj mimo proces nad připnutým Dev; později případně přímý odkaz).</summary>
public interface IZdrojVpmg : IDisposable
{
    bool Dostupny { get; }
    string Popis { get; }
    InfoVpmgDto Info();
    TexturaVpmgDto Spust(RecepturaVpmgDto receptura, uint seed, NavrhProfiluDto? navrh = null);
    (uint Ocekavany, uint Spocteny) Golden();
    KontrolaZrcadlaDto KontrolaZrcadla(string zrcadlo);
    /// <summary>Kanonický JSON receptury podle VpmgRecipeJson Dev (parse → ToJson).</summary>
    string Kanon(string recepturaJson);
}
