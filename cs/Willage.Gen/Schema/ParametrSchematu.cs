using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Willage.Gen.Schema;

/// <summary>Typ parametru pro generovaný konfigurátor (G-5): číslo, přepínač, text, volba, pole čísel, nebo tabulka (vlastní prvek).</summary>
[JsonConverter(typeof(JsonStringEnumConverter<TypParametru>))]
public enum TypParametru { Cele, Desetinne, Logicky, Text, Volba, Pole, Tabulka }

/// <summary>
/// G-2: jeden parametr ve schématu. Id = „Zdroj.Nazev“. Vychozi = dnešní účinná hodnota (soubor v data/v1, jinak C#),
/// VychoziKod = výchozí hodnota v C#. Rozsah je návrh (RozsahZdroj „odhad“, ladí Jan), pokud ho neurčuje kód.
/// Napoveda je slot pro nápovědu (co veličina dělá a k čemu slouží); texty ve v1 nejsou (Jan 16:50).
/// </summary>
public sealed record ParametrSchematu
{
    public string Id { get; init; } = "";
    public string Modul { get; init; } = "";
    public string Zdroj { get; init; } = "";
    public string Nazev { get; init; } = "";
    public string Skupina { get; init; } = "";
    public TypParametru Typ { get; init; }
    public string TypKodu { get; init; } = "";
    public JsonNode? Vychozi { get; init; }
    public JsonNode? VychoziKod { get; init; }
    public double? Min { get; init; }
    public double? Max { get; init; }
    public double? Krok { get; init; }
    public string Jednotka { get; init; } = "";
    public string[]? Volby { get; init; }
    public string RozsahZdroj { get; init; } = "odhad";
    /// <summary>Datový soubor, ze kterého hodnota přichází (relativně k data), nebo null (jen kód).</summary>
    public string? Soubor { get; init; }
    /// <summary>Jen čtení: hodnotu dnes vždy přepíše jiný zdroj (preset klimatu, eroze planety); důvod v Poznamka.</summary>
    public bool JenCteni { get; init; }
    public string? Poznamka { get; init; }
    public string Napoveda { get; init; } = "";
}
