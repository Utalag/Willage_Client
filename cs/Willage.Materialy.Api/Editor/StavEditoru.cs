using System.Globalization;
using System.Text.RegularExpressions;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Materialy.Api.Editor;

/// <summary>
/// T-2: stav okna Editor materiálů bez Godotu – vybraný materiál a profil, receptura VPMG (schéma Dev), seed, návrh profilu
/// (jen pro náhled, katalog se nemění). Každá změna zvýší <see cref="Verze"/> a vyvolá <see cref="Zmeneno"/>.
/// Odmítnutá změna (zástupná operace, barva, rozsah) vrátí text chyby a stav nezmění.
/// </summary>
public sealed class StavEditoru
{
    static readonly Regex BarvaRe = new("^#[0-9a-fA-F]{6}$", RegexOptions.Compiled);
    public static readonly int[] Rozliseni = { 32, 64, 128, 256 };
    readonly KatalogVzhledu _k;
    readonly SchemaOperaciVpmg _s;
    readonly VzorekMaterialu? _v;
    readonly KnihovnaReceptur? _r;

    public byte Material { get; private set; }
    public string Profil { get; private set; } = "default";
    public RecepturaVpmgDto Receptura { get; private set; }
    public uint Seed { get; private set; } = 49;
    public NavrhProfiluDto Navrh { get; private set; } = new();
    public long Verze { get; private set; }
    public event Action<string>? Zmeneno;

    /// <param name="vzorek">Vzorek materiálů (null = všechny); výchozí materiál = první ve vzorku.</param>
    /// <param name="receptury">T-2b: knihovna výchozích receptur (null = v0 VpmgPreview pro všechny).</param>
    public StavEditoru(KatalogVzhledu katalog, SchemaOperaciVpmg schema, VzorekMaterialu? vzorek = null, byte? material = null, KnihovnaReceptur? receptury = null)
    {
        _k = katalog; _s = schema; _v = vzorek; _r = receptury;
        Material = material ?? vzorek?.Materialy[0].Id ?? 52;
        Receptura = Vychozi(Material, null);
    }

    RecepturaVpmgDto Vychozi(byte m, int? roz) => _r?.Vychozi(m, roz) ?? RecepturyVpmg.Vychozi(m, roz ?? _s.RozliseniVychozi);
    /// <summary>Odkud je výchozí receptura materiálu (soubor knihovny + zdroj v Dev), nebo null = v0.</summary>
    public ZaznamReceptury? ZdrojReceptury => _r?.Zaznam(Material);

    public bool JeVeVzorku(byte id) => _v is null || _v.Obsahuje(id);
    public MaterialVzhleduDto MaterialDto => _k.Material(Material)!;
    public ProfilVzhleduDto ProfilKatalogu => MaterialDto.Profily[Profil];
    /// <summary>Profil, jak ho vidí náhled: katalog + návrh.</summary>
    public ProfilVzhleduDto ProfilNahledu => new(Navrh.Style ?? ProfilKatalogu.Style, Navrh.BaseColor ?? ProfilKatalogu.BaseColor,
        Navrh.GrainScalePermille ?? ProfilKatalogu.GrainScalePermille, Navrh.LayerDensityPermille ?? ProfilKatalogu.LayerDensityPermille,
        Navrh.IrregularityPermille ?? ProfilKatalogu.IrregularityPermille, Navrh.Palette ?? ProfilKatalogu.Palette, ProfilKatalogu.BaseTile);

    void Zmena(string co) { Verze++; Zmeneno?.Invoke(co); }

    /// <summary>Výběr materiálu: s knihovnou receptur (T-2b) se načte výchozí receptura materiálu (v1 z Dev), bez ní se přenese
    /// (jen materialId); profil default, návrh se zruší (patřil jinému materiálu).</summary>
    public string? VyberMaterial(byte id)
    {
        if (_k.Material(id) is null) return $"materiál {id} není v katalogu";
        if (_v != null && !_v.Obsahuje(id)) return VzorekMaterialu.Zastupny(id);
        Material = id; Profil = "default"; Navrh = new();
        Receptura = _r != null ? Vychozi(id, Receptura.Resolution) : Receptura with { MaterialId = id, VisualProfile = Profil };
        Zmena("material"); return null;
    }

    public string? VyberProfil(string profil)
    {
        if (!MaterialDto.Profily.ContainsKey(profil)) return $"materiál {Material} nemá profil '{profil}'";
        Profil = profil; Navrh = new(); Receptura = Receptura with { VisualProfile = profil };
        Zmena("profil"); return null;
    }

    public void NastavSeed(uint seed) { if (seed == Seed) return; Seed = seed; Zmena("seed"); }

    public string? NastavRozliseni(int r)
    {
        if (r < _s.RozliseniMin || r > _s.RozliseniMax) return $"rozlišení {r} mimo {_s.RozliseniMin}–{_s.RozliseniMax}";
        Receptura = Receptura with { Resolution = r }; Zmena("rozliseni"); return null;
    }

    public void VychoziReceptura() { Receptura = Vychozi(Material, Receptura.Resolution) with { VisualProfile = Profil }; Zmena("receptura"); }

    List<KrokVpmgDto> Kroky => Receptura.Kroky.ToList();
    void Kroky_(List<KrokVpmgDto> k, string co) { Receptura = Receptura with { Kroky = k }; Zmena(co); }

    public string? PrepniKrok(int i, bool zap)
    {
        if (i < 0 || i >= Receptura.Kroky.Count) return "krok mimo rozsah";
        var k = Kroky; k[i] = k[i] with { Enabled = zap }; Kroky_(k, "krok"); return null;
    }

    /// <summary>Přidá krok: jen operace z registru Dev (nezástupné); parametry s výchozími hodnotami schématu; id „s{n}“ jedinečné.</summary>
    public string? PridejKrok(string type)
    {
        var op = _s.Operace(type);
        if (op is null) return $"neznámá operace '{type}'";
        if (op.Zastupna) return $"operace '{type}' je zástupná – v registru Dev není (návrh pro backend)";
        int n = 1; while (Receptura.Kroky.Any(x => x.Id == "s" + n)) n++;
        // prázdná výchozí hodnota = Dev ji bere z profilu / rozměru → do receptury se nepíše (stejně jako receptury v1 Dev)
        var par = op.Params.Where(p => p.Vychozi != "").ToDictionary(p => p.Nazev, p => p.Vychozi, StringComparer.Ordinal);
        var k = Kroky; k.Add(new KrokVpmgDto("s" + n, type, true, par)); Kroky_(k, "krok+"); return null;
    }

    public string? OdeberKrok(int i)
    {
        if (i < 0 || i >= Receptura.Kroky.Count) return "krok mimo rozsah";
        var k = Kroky; k.RemoveAt(i); Kroky_(k, "krok-"); return null;
    }

    public string? PosunKrok(int i, int o)
    {
        int j = i + o;
        if (i < 0 || i >= Receptura.Kroky.Count || j < 0 || j >= Receptura.Kroky.Count) return "posun mimo rozsah";
        var k = Kroky; (k[i], k[j]) = (k[j], k[i]); Kroky_(k, "poradi"); return null;
    }

    public string? NastavParametrKroku(int i, string nazev, string hodnota)
    {
        if (i < 0 || i >= Receptura.Kroky.Count) return "krok mimo rozsah";
        var op = _s.Operace(Receptura.Kroky[i].Type);
        var p = op?.Params.FirstOrDefault(x => x.Nazev == nazev);
        if (p is null) return $"operace '{Receptura.Kroky[i].Type}' nemá parametr '{nazev}'";
        if (hodnota != "" && Kontrola(p, hodnota) is { } ch) return ch;
        var k = Kroky; var d = new Dictionary<string, string>(k[i].Params, StringComparer.Ordinal) { [nazev] = hodnota };
        if (hodnota == "") d.Remove(nazev); // prázdné = výchozí Dev
        k[i] = k[i] with { Params = d }; Kroky_(k, "parametr"); return null;
    }

    /// <summary>Návrh hodnoty profilu (jen náhled). Hodnota = katalog → návrh se pro ten parametr zruší.</summary>
    public string? NastavNavrh(string nazev, string hodnota)
    {
        var p = _s.Profil.FirstOrDefault(x => x.Nazev == nazev);
        if (p is null) return $"profil nemá parametr '{nazev}'";
        if (Kontrola(p, hodnota) is { } ch) return ch;
        var kat = ProfilKatalogu;
        Navrh = nazev switch
        {
            "style" => Navrh with { Style = hodnota == kat.Style ? null : hodnota },
            "baseColor" => Navrh with { BaseColor = string.Equals(hodnota, kat.BaseColor, StringComparison.OrdinalIgnoreCase) ? null : hodnota.ToLowerInvariant() },
            "grainScalePermille" => Navrh with { GrainScalePermille = int.Parse(hodnota, CultureInfo.InvariantCulture) is var g && g != kat.GrainScalePermille ? g : null },
            "layerDensityPermille" => Navrh with { LayerDensityPermille = int.Parse(hodnota, CultureInfo.InvariantCulture) is var l && l != kat.LayerDensityPermille ? l : null },
            "irregularityPermille" => Navrh with { IrregularityPermille = int.Parse(hodnota, CultureInfo.InvariantCulture) is var r && r != kat.IrregularityPermille ? r : null },
            "palette" => Navrh with { Palette = Paleta(hodnota) is var pl && string.Join(",", pl) == string.Join(",", kat.Palette ?? Array.Empty<string>()) ? null : pl },
            _ => Navrh,
        };
        Zmena("navrh"); return null;
    }

    public void ZrusNavrh() { if (Navrh.Prazdny) return; Navrh = new(); Zmena("navrh"); }

    /// <summary>Paleta z textu „#a, #b …“ (malá písmena; prázdný text = prázdná paleta → Dev použije baseColor).</summary>
    public static IReadOnlyList<string> Paleta(string h) => h.Split(new[] { ',', ' ', ';' }, StringSplitOptions.RemoveEmptyEntries).Select(x => x.ToUpperInvariant()).ToList();

    static string? Kontrola(ParametrVpmgDto p, string h) => p.Druh switch
    {
        DruhParametruVpmg.Paleta when Paleta(h) is var pl && (pl.Count > 16 || pl.Any(x => !BarvaRe.IsMatch(x))) => $"{p.Nazev}: '{h}' není seznam #RRGGBB (max 16)",
        DruhParametruVpmg.Barva when !BarvaRe.IsMatch(h) => $"{p.Nazev}: '{h}' není barva #RRGGBB",
        DruhParametruVpmg.Cele when !int.TryParse(h, NumberStyles.Integer, CultureInfo.InvariantCulture, out _) => $"{p.Nazev}: '{h}' není celé číslo",
        DruhParametruVpmg.Cele when int.Parse(h, CultureInfo.InvariantCulture) is var v && ((p.Min is { } mi && v < mi) || (p.Max is { } ma && v > ma)) => $"{p.Nazev}: {h} mimo {p.Min}–{p.Max}",
        DruhParametruVpmg.Prepinac when h is not ("true" or "false") => $"{p.Nazev}: '{h}' není true / false",
        DruhParametruVpmg.Volba when p.Moznosti.Count > 0 && !p.Moznosti.Contains(h) => $"{p.Nazev}: '{h}' není z voleb",
        _ => null,
    };

    public IReadOnlyList<string> Validace() => RecepturyVpmg.Validuj(Receptura, _s, _k);

    /// <summary>Seedy variací: stejný profil, jiný seed (deterministicky od aktuálního seedu).</summary>
    public IReadOnlyList<uint> SeedyVariaci(int n = 4) => Enumerable.Range(1, n).Select(i => unchecked(Seed + (uint)i * 7919u)).ToList();
}
