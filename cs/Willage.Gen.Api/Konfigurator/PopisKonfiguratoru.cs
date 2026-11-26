using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using Willage.Gen.Api.Dto;

namespace Willage.Gen.Api.Konfigurator;

/// <summary>Druh editoru parametru v konfigurátoru modulu (okno 1, G-5).</summary>
public enum DruhEditoru { Cele, Desetinne, Prepinac, Volba, Text, Json }

/// <summary>
/// G-5: popis jednoho editoru parametru (bez Godotu). Godot uzel EditorParametru z něj postaví ovládací prvky.
/// Posuvnik = schéma zná konečný rozsah Min &lt; Max. Krok 0 = bez zaokrouhlení. Zamceny = jen čtení nebo potvrzená planeta.
/// </summary>
public sealed record PopisEditoru(ParametrDto Parametr, DruhEditoru Druh, string Popisek, bool Posuvnik, double Min, double Max, double Krok,
    bool Zamceny, string DuvodZamceni, string Napoveda, bool NapovedaZastupna, string? PoznamkaEditoru);

public sealed record SkupinaKonfiguratoru(string Nazev, IReadOnlyList<PopisEditoru> Editory);

/// <summary>G-5: popis konfigurátoru modulu = jedna „funkční vrstva“ (jako GeoLab): skupiny editorů a vrstvy náhledu.</summary>
public sealed record PopisKonfiguratoru(string Modul, IReadOnlyList<SkupinaKonfiguratoru> Skupiny, IReadOnlyList<VrstvaMapyDto> Vrstvy)
{
    public int PocetEditoru => Skupiny.Sum(s => s.Editory.Count);
}

/// <summary>
/// G-5: konfigurátor generovaný ze schématu parametrů (G-2) – logika mimo Godot, testovaná v Willage.Gen.Testy.
/// Převod hodnot editoru na JSON pro IModuly.Nastav: invariantní kultura, čísla nejkratším zápisem „R“ (0.35, 128), takže hodnota
/// beze změny dá stejný JSON jako sada (stejný klíč modulu).
/// </summary>
public static class Konfigurator
{
    /// <summary>Nápověda ve v1 není (Jan 16:50) – editor ukáže tento zástupný text.</summary>
    public const string NapovedaZastupna = "zástupný: nápověda parametru – texty nejsou ve v1 (slot Napoveda ve schématu G-2)";
    public const string TabulkaZastupna = "zástupný: vlastní prvek pro tabulky a pole přijde později – ve v1 se upravuje JSON";

    public static PopisKonfiguratoru Sestav(string modul, IReadOnlyList<ParametrDto> parametry, bool potvrzena)
    {
        var skupiny = new List<SkupinaKonfiguratoru>();
        foreach (var p in parametry)
        {
            var e = Editor(p, potvrzena);
            int i = skupiny.FindIndex(s => s.Nazev == p.Skupina);
            if (i < 0) skupiny.Add(new SkupinaKonfiguratoru(p.Skupina, new List<PopisEditoru> { e }));
            else ((List<PopisEditoru>)skupiny[i].Editory).Add(e);
        }
        return new PopisKonfiguratoru(modul, skupiny, VrstvyModulu(modul));
    }

    public static DruhEditoru Druh(string typ) => typ switch
    {
        "Cele" => DruhEditoru.Cele,
        "Desetinne" => DruhEditoru.Desetinne,
        "Logicky" => DruhEditoru.Prepinac,
        "Volba" => DruhEditoru.Volba,
        "Text" => DruhEditoru.Text,
        _ => DruhEditoru.Json,    // Pole, Tabulka
    };

    public static PopisEditoru Editor(ParametrDto p, bool potvrzena)
    {
        var d = Druh(p.Typ);
        bool cislo = d is DruhEditoru.Cele or DruhEditoru.Desetinne;
        bool rozsah = cislo && p.Min is double a && p.Max is double b && double.IsFinite(a) && double.IsFinite(b) && b > a;
        double krok = p.Krok ?? (d == DruhEditoru.Cele ? 1 : 0);
        string duvod = p.JenCteni ? "jen čtení" + (string.IsNullOrEmpty(p.Poznamka) ? "" : ": " + p.Poznamka) : potvrzena ? "planeta je potvrzená" : "";
        string popisek = p.Id[(p.Id.LastIndexOf('.') + 1)..] + (string.IsNullOrWhiteSpace(p.Jednotka) || p.Jednotka == "–" ? "" : $" [{p.Jednotka}]");
        bool zastNap = string.IsNullOrWhiteSpace(p.Napoveda);
        return new PopisEditoru(p, d, popisek, rozsah, p.Min ?? double.MinValue, p.Max ?? double.MaxValue, krok,
            p.JenCteni || potvrzena, duvod, zastNap ? NapovedaZastupna : p.Napoveda, zastNap, d == DruhEditoru.Json ? TabulkaZastupna : null);
    }

    // ---- převod hodnot ----
    public static string Json(double v) => v.ToString("R", CultureInfo.InvariantCulture);
    public static string Json(long v) => v.ToString(CultureInfo.InvariantCulture);
    public static string Json(bool v) => v ? "true" : "false";
    public static string Json(string v) => JsonSerializer.Serialize(v);

    public static double Cislo(string json) => JsonNode.Parse(json)!.GetValue<double>();
    public static bool Logicka(string json) => JsonNode.Parse(json)!.GetValue<bool>();
    public static string Retezec(string json) => JsonNode.Parse(json)!.GetValue<string>();

    /// <summary>Hodnota editoru → JSON podle druhu; pro Json ověří, že jde o platný JSON (jinak FormatException).</summary>
    public static string NaJson(DruhEditoru d, object hodnota) => d switch
    {
        DruhEditoru.Cele => Json(Convert.ToInt64(Math.Round(Convert.ToDouble(hodnota, CultureInfo.InvariantCulture)))),
        DruhEditoru.Desetinne => Json(Convert.ToDouble(hodnota, CultureInfo.InvariantCulture)),
        DruhEditoru.Prepinac => Json((bool)hodnota),
        DruhEditoru.Volba or DruhEditoru.Text => Json((string)hodnota),
        _ => Platny((string)hodnota),
    };

    static string Platny(string json)
    {
        try { return JsonNode.Parse(json)?.ToJsonString() ?? "null"; }
        catch (JsonException e) { throw new FormatException("neplatný JSON: " + e.Message, e); }
    }

    /// <summary>
    /// Vrstvy náhledu modulu. Dočasné (G-5): ukazuje se hotová planeta; vlastní náhledy a izolace modulů přinesou G-6 (M1–M3) a G-7 (M4–M6).
    /// </summary>
    public static IReadOnlyList<VrstvaMapyDto> VrstvyModulu(string modul) => modul switch
    {
        "M1" => new[] { VrstvaMapyDto.Biom, VrstvaMapyDto.Vyska },
        "M4" => new[] { VrstvaMapyDto.Eroze, VrstvaMapyDto.Vyska },
        "M5" => new[] { VrstvaMapyDto.Teplota, VrstvaMapyDto.Srazky, VrstvaMapyDto.Biom },
        _ => new[] { VrstvaMapyDto.Vyska, VrstvaMapyDto.Biom },
    };

    /// <summary>Moduly, které se přepočtou při přepočtu modulu: modul + všechny závislé (tranzitivně) podle seznamu modulů.</summary>
    public static IReadOnlyList<string> Zavisle(IReadOnlyList<ModulDto> moduly, string modul)
    {
        var mn = new HashSet<string> { modul };
        foreach (var m in moduly) if (m.Zavislosti.Any(mn.Contains)) mn.Add(m.Id);
        return moduly.Where(m => mn.Contains(m.Id)).Select(m => m.Id).ToList();
    }
}
