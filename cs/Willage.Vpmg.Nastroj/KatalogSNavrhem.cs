using Willage.World.Materials.Catalog;
using Willage.World.Materials.Domain;
using Willage.World.Materials.Ports;

namespace Willage.Vpmg.Nastroj;

/// <summary>Návrh vizuálního profilu jen v paměti (editor: „co kdyby baseColor / zrno …“). Katalog na disku se nemění.</summary>
public sealed record NavrhProfilu(string? Style = null, string? BaseColor = null, int? GrainScalePermille = null, int? LayerDensityPermille = null, int? IrregularityPermille = null)
{
    public MaterialVisualProfile Na(MaterialVisualProfile p) => new(
        Style ?? p.Style, BaseColor ?? p.BaseColor, GrainScalePermille ?? p.GrainScalePermille,
        LayerDensityPermille ?? p.LayerDensityPermille, IrregularityPermille ?? p.IrregularityPermille);
}

/// <summary>IMaterialCatalog Dev s jedním přepsaným profilem jednoho materiálu (adaptér, ne kopie logiky).</summary>
sealed class KatalogSNavrhem
{
    public static IMaterialCatalog S(IMaterialCatalog zaklad, MaterialId id, string profil, NavrhProfilu? navrh)
    {
        if (navrh is null) return zaklad;
        var m = zaklad.GetRequired(id);
        if (!m.VisualProfiles.TryGetValue(profil, out var p)) return zaklad; // runner Dev ohlásí chybějící profil sám
        var prof = new Dictionary<string, MaterialVisualProfile>(m.VisualProfiles, StringComparer.Ordinal) { [profil] = navrh.Na(p) };
        var vse = zaklad.All.Select(x => x.Id == id ? x with { VisualProfiles = prof } : x).ToList();
        return new MaterialCatalog(vse);
    }
}
