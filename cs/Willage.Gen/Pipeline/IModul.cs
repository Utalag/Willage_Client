namespace Willage.Gen.Pipeline;

/// <summary>
/// G-1: modul generátoru světa = obal jednoho stávajícího kroku (jako funkční vrstva GeoLabu: id, verze algoritmu, dependsOn).
/// Modul nic nepočítá sám od sebe; volá dnešní třídy. Klíč modulu skládá <see cref="KlicModulu"/> z toho, co modul deklaruje.
/// </summary>
public interface IModul
{
    /// <summary>Id modulu (M0 … M7), unikátní v grafu.</summary>
    string Id { get; }
    string Nazev { get; }
    /// <summary>Verze algoritmu modulu; zvýší se při záměrné změně výsledku (pak se změní klíč modulu a všech závislých).</summary>
    int VerzeAlgoritmu { get; }
    /// <summary>Id modulů, jejichž výstup (nebo klíč) modul potřebuje.</summary>
    IReadOnlyList<string> Zavislosti { get; }
    /// <summary>Datové soubory, které kód modulu opravdu čte (cesty relativně ke kořeni dat, musí být v manifestu).</summary>
    IReadOnlyList<string> Soubory { get; }
    /// <summary>Kanonické parametry modulu (deterministický text); nesmí záviset na výstupech jiných modulů.</summary>
    string Parametry(KontextBehu k);
    /// <summary>Spustí modul; výstupy závislostí čte přes <see cref="KontextBehu.Vystup{T}"/>.</summary>
    object Spust(KontextBehu k);
}
