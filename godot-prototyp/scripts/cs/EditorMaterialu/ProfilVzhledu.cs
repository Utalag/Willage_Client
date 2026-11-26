using System.Collections.Generic;
using System.Linq;
using Godot;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Sluzby;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: visualProfiles materiálu (style, baseColor, zrno / vrstvy / nepravidelnost ‰). Hodnoty z katalogu Dev; úprava je NÁVRH jen pro náhled
/// (katalog ani zrcadlo se nemění, uložení návrhu až T-4). Parametr, který žádný zapnutý krok nečte, je šedý („nečte žádná zapnutá operace“).
/// </summary>
[GlobalClass]
public partial class ProfilVzhledu : VBoxContainer
{
    public OptionButton Profily { get; private set; } = null!;
    public VBoxContainer Editory { get; private set; } = null!;
    public Label StavNavrhu { get; private set; } = null!;
    public Button ZrusitNavrh { get; private set; } = null!;
    public readonly Dictionary<string, EditorParametruVpmg> PodleNazvu = new();
    StavEditoru _st = null!;
    SchemaOperaciVpmg _s = null!;
    List<string> _profily = new();

    public override void _Ready()
    {
        Profily = GetNode<OptionButton>("Hlava/Profily"); Editory = GetNode<VBoxContainer>("Editory");
        StavNavrhu = GetNode<Label>("Hlava/StavNavrhu"); ZrusitNavrh = GetNode<Button>("Hlava/ZrusitNavrh");
        Profily.ItemSelected += i => _st.VyberProfil(_profily[(int)i]);
        ZrusitNavrh.Pressed += () => _st.ZrusNavrh();
    }

    public void Pripoj(StavEditoru st, SchemaOperaciVpmg s) { _st = st; _s = s; }

    /// <summary>Postaví editory znovu (jiný materiál / profil / zrušený návrh).</summary>
    public void Postav()
    {
        _profily = _st.MaterialDto.Profily.Keys.ToList();
        Profily.Clear();
        foreach (var p in _profily) Profily.AddItem(p);
        Profily.Select(_profily.IndexOf(_st.Profil));
        foreach (var c in Editory.GetChildren()) { Editory.RemoveChild(c); c.QueueFree(); }
        PodleNazvu.Clear();
        foreach (var p in PopisKonfiguratoruReceptury.Profil(_st.ProfilNahledu, _s))
        {
            var e = EditorParametruVpmg.Z(p);
            e.Zmeneno += (n, h) => { var ch = _st.NastavNavrh(n, h); if (ch != null) StavNavrhu.Text = ch; };
            Editory.AddChild(e);
            PodleNazvu[p.Nazev] = e;
        }
        Obnov();
    }

    /// <summary>Obnoví zvýraznění a stav návrhu bez přestavby editorů.</summary>
    public void Obnov()
    {
        var cteny = PopisKonfiguratoruReceptury.CtenyProfil(_st.Receptura, _s);
        var kat = PopisKonfiguratoruReceptury.Profil(_st.ProfilKatalogu, _s).ToDictionary(x => x.Nazev, x => x.Hodnota);
        var nah = PopisKonfiguratoruReceptury.Profil(_st.ProfilNahledu, _s).ToDictionary(x => x.Nazev, x => x.Hodnota);
        foreach (var (n, e) in PodleNazvu)
        {
            bool navrh = kat[n] != nah[n];
            e.Zvyrazni(navrh ? new Color(1f, 0.85f, 0.4f) : cteny.Contains(n) ? Colors.White : new Color(0.55f, 0.55f, 0.6f),
                (navrh ? $"NÁVRH (jen náhled): {nah[n]}, katalog {kat[n]}. " : $"katalog: {kat[n]}. ") + (cteny.Contains(n) ? "Čte ho zapnutý krok receptury." : "nečte ho žádná zapnutá operace receptury."));
        }
        StavNavrhu.Text = _st.Navrh.Prazdny ? "profil = katalog Dev" : "NÁVRH jen pro náhled (katalog beze změny, uložení T-4)";
        StavNavrhu.Modulate = _st.Navrh.Prazdny ? new Color(0.75f, 0.75f, 0.8f) : new Color(1f, 0.85f, 0.4f);
        ZrusitNavrh.Disabled = _st.Navrh.Prazdny;
    }
}
