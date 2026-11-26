using System.Collections.Generic;
using System.Linq;
using Godot;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Sluzby;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>T-2: materiály katalogu Dev (ID, název, barva profilu default), filtr (výchozí = vzorek 5 materiálů, Jan 21:44; pak skupiny) a hledání.
/// Materiál mimo vzorek je šedý a označený „zástupné“ (výběr stav odmítne). Výběr → <see cref="SignalName.MaterialVybran"/>.</summary>
[GlobalClass]
public partial class SeznamMaterialu : VBoxContainer
{
    [Signal] public delegate void MaterialVybranEventHandler(int id);
    public OptionButton Filtr { get; private set; } = null!;
    public LineEdit Hledat { get; private set; } = null!;
    public ItemList Seznam { get; private set; } = null!;
    public IReadOnlyList<byte> Zobrazene => _zobrazene;
    readonly List<byte> _zobrazene = new();
    IReadOnlyList<MaterialVzhleduDto> _vse = new List<MaterialVzhleduDto>();
    List<string> _skupiny = new();
    VzorekMaterialu? _vzorek;
    public const string FiltrVzorek = "\u0001vzorek";
    byte _vybrany;
    bool _tichy;

    public override void _Ready()
    {
        Filtr = GetNode<OptionButton>("Filtr"); Hledat = GetNode<LineEdit>("Hledat"); Seznam = GetNode<ItemList>("Seznam");
        Filtr.ItemSelected += _ => Obnov();
        Hledat.TextChanged += _ => Obnov();
        Seznam.ItemSelected += i => { if (!_tichy) EmitSignal(SignalName.MaterialVybran, (int)_zobrazene[(int)i]); };
    }

    public void Napln(KatalogVzhledu k, VzorekMaterialu? vzorek = null)
    {
        _vse = k.Materialy; _vzorek = vzorek;
        _skupiny = (vzorek != null ? new List<string> { FiltrVzorek } : new List<string>()).Concat(new[] { "" }).Concat(k.Skupiny).ToList();
        Filtr.Clear();
        foreach (var s in _skupiny) Filtr.AddItem(s == FiltrVzorek ? $"vzorek ({vzorek!.Materialy.Count} materiálů)" : s == "" ? "všechny (mimo vzorek zástupné)" : s);
        Filtr.Select(0);
        Obnov();
    }

    /// <summary>Filtr: <see cref="FiltrVzorek"/>, "" = všechny, jinak skupina.</summary>
    public void FiltrSkupiny(string skupina) { Filtr.Select(System.Math.Max(0, _skupiny.IndexOf(skupina))); Obnov(); }

    void Obnov()
    {
        string sk = _skupiny.Count > 0 ? _skupiny[System.Math.Max(0, Filtr.Selected)] : "";
        string h = Hledat.Text.Trim().ToLowerInvariant();
        _tichy = true;
        Seznam.Clear(); _zobrazene.Clear();
        foreach (var m in _vse)
        {
            bool veVzorku = _vzorek?.Obsahuje(m.Id) ?? true;
            if (sk == FiltrVzorek ? !veVzorku : sk != "" && m.Skupina != sk) continue;
            if (h != "" && !m.Nazev.ToLowerInvariant().Contains(h) && !m.Key.Contains(h) && m.Id.ToString() != h) continue;
            var (r, g, b) = KatalogVzhledu.Barva(m.Profily["default"].BaseColor);
            var img = Image.CreateEmpty(14, 14, false, Image.Format.Rgba8);
            img.Fill(Color.Color8(r, g, b));
            int i = Seznam.AddItem($"{m.Id,3}  {m.Nazev}" + (veVzorku ? "" : "  (zástupné)"), ImageTexture.CreateFromImage(img));
            Seznam.SetItemTooltip(i, $"{m.Key} · {m.Skupina} · {m.IdStatus} · {m.Profily["default"].BaseColor}" + (veVzorku ? "" : "\n" + VzorekMaterialu.Zastupny(m.Id)));
            if (!veVzorku || m.IdStatus != "active") Seznam.SetItemCustomFgColor(i, new Color(0.55f, 0.55f, 0.6f));
            _zobrazene.Add(m.Id);
        }
        int idx = _zobrazene.IndexOf(_vybrany);
        if (idx >= 0) Seznam.Select(idx);
        _tichy = false;
    }

    public void Oznac(byte id)
    {
        _vybrany = id;
        _tichy = true;
        int i = _zobrazene.IndexOf(id);
        if (i >= 0) { Seznam.Select(i); Seznam.EnsureCurrentIsVisible(); } else Seznam.DeselectAll();
        _tichy = false;
    }
}
