using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Materialy.Api.Editor;

/// <summary>Jeden editor parametru kroku (nebo profilu) – druh a hodnota ze schématu operací.</summary>
/// <param name="VychoziDev">výchozí výraz Dev (prázdná hodnota = Dev ho použije); BezPrekryvu = parametr z Dev bez popisu klienta</param>
public sealed record EditorParametruPopis(string Nazev, DruhParametruVpmg Druh, string Hodnota, string Popis, IReadOnlyList<string> Moznosti, int? Min, int? Max, string Jednotka,
    string VychoziDev = "", bool BezPrekryvu = false);

/// <summary>Popis jednoho kroku pro UI: operace, zapnuto, editory parametrů, profilové hodnoty, které operace čte.</summary>
public sealed record KrokPopis(int Index, string Id, string Type, string Nazev, string Skupina, bool Enabled, string Popis, IReadOnlyList<EditorParametruPopis> Editory, IReadOnlyList<string> CtiProfil);

/// <summary>Položka nabídky „přidat krok“: spustitelné operace + zástupné (zamčené s důvodem).</summary>
public sealed record NabidkaOperacePopis(string Type, string Nazev, bool Zamcena, string Popis);

/// <summary>
/// T-2 / T-2b: z receptury a schématu operací (generovaného z Dev) udělá popis konfigurátoru (editory se generují, nic není ručně v UI) – stejný princip
/// jako G-5 (konfigurátor generovaný ze schématu G-2). Parametr kroku, který schéma nezná, se ukáže jako text (a validace ho hlásí).
/// </summary>
public static class PopisKonfiguratoruReceptury
{
    public static IReadOnlyList<KrokPopis> Kroky(RecepturaVpmgDto r, SchemaOperaciVpmg s) => r.Kroky.Select((k, i) =>
    {
        var op = s.Operace(k.Type);
        var ed = (op?.Params ?? Array.Empty<ParametrVpmgDto>()).Select(p => Editor(p, k.Params.TryGetValue(p.Nazev, out var v) ? v : p.Vychozi)).ToList();
        ed.AddRange(k.Params.Where(kv => op is null || op.Params.All(p => p.Nazev != kv.Key))
            .Select(kv => new EditorParametruPopis(kv.Key, DruhParametruVpmg.Text, kv.Value, "parametr mimo schéma operací", Array.Empty<string>(), null, null, "")));
        return new KrokPopis(i, k.Id, k.Type, op?.Nazev ?? k.Type, op?.Skupina ?? "?", k.Enabled, op?.Popis ?? "neznámá operace", ed, op?.CtiProfil ?? Array.Empty<string>());
    }).ToList();

    public static IReadOnlyList<EditorParametruPopis> Profil(ProfilVzhleduDto p, SchemaOperaciVpmg s) => s.Profil.Select(x => Editor(x, x.Nazev switch
    {
        "style" => p.Style, "baseColor" => p.BaseColor, "grainScalePermille" => p.GrainScalePermille.ToString(System.Globalization.CultureInfo.InvariantCulture),
        "layerDensityPermille" => p.LayerDensityPermille.ToString(System.Globalization.CultureInfo.InvariantCulture),
        "irregularityPermille" => p.IrregularityPermille.ToString(System.Globalization.CultureInfo.InvariantCulture),
        "palette" => p.PaletaText, _ => "",
    })).ToList();

    public static IReadOnlyList<NabidkaOperacePopis> Nabidka(SchemaOperaciVpmg s) =>
        s.Spustitelne.Select(o => new NabidkaOperacePopis(o.Type, o.Nazev, false, o.Popis + (o.Params.Count > 0 ? " Parametry (Dev): " + string.Join(", ", o.Params.Select(p => p.Nazev)) : "")))
         .Concat(s.Zastupne.Select(o => new NabidkaOperacePopis(o.Type, o.Nazev + " (zástupné)", true, o.Popis))).ToList();

    /// <summary>Které parametry profilu čte aspoň jeden zapnutý krok (ostatní UI označí „v0 nečte žádná operace“).</summary>
    public static IReadOnlySet<string> CtenyProfil(RecepturaVpmgDto r, SchemaOperaciVpmg s) =>
        r.Kroky.Where(k => k.Enabled).SelectMany(k => s.Operace(k.Type)?.CtiProfil ?? Array.Empty<string>()).ToHashSet(StringComparer.Ordinal);

    static EditorParametruPopis Editor(ParametrVpmgDto p, string h) => new(p.Nazev, p.Druh, h, p.Popis, p.Moznosti, p.Min, p.Max, p.Jednotka, p.VychoziDev, p.BezPrekryvu);
}
