using System;
using System.Globalization;
using Godot;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Editor;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: editor jednoho parametru generovaný z popisu schématu operací (barva → ColorPickerButton, celé s rozsahem → posuvník + SpinBox,
/// volba → OptionButton, text → LineEdit). Změnu hlásí událostí <see cref="Zmeneno"/> (název, hodnota jako text pro StavEditoru).
/// </summary>
[GlobalClass]
public partial class EditorParametruVpmg : HBoxContainer
{
    public event Action<string, string>? Zmeneno;
    public EditorParametruPopis? Popis { get; private set; }
    public Control? Ovladac { get; private set; }
    Label _nazev = null!;
    bool _tichy;

    public static EditorParametruVpmg Z(EditorParametruPopis p)
    {
        var e = new EditorParametruVpmg { Name = "Par_" + p.Nazev };
        e.Postav(p);
        return e;
    }

    void Postav(EditorParametruPopis p)
    {
        Popis = p;
        _nazev = new Label { Text = p.Nazev + (p.Jednotka != "" ? $" [{p.Jednotka}]" : ""), CustomMinimumSize = new Vector2(170, 0), TooltipText = p.Popis, MouseFilter = MouseFilterEnum.Pass };
        AddChild(_nazev);
        switch (p.Druh)
        {
            case DruhParametruVpmg.Barva:
                var cp = new ColorPickerButton { Color = Color.FromHtml(p.Hodnota), CustomMinimumSize = new Vector2(120, 24), EditAlpha = false, TooltipText = p.Popis };
                cp.ColorChanged += c => Hlas("#" + c.ToHtml(false).ToLowerInvariant());
                Ovladac = cp; AddChild(cp);
                break;
            case DruhParametruVpmg.Paleta:
            {
                // T-2b: paleta profilu – text „#a, #b“ + vzorník barev (vzorník je jen náhled, mění se textem)
                var box = new VBoxContainer();
                var le = new LineEdit { Text = p.Hodnota, CustomMinimumSize = new Vector2(240, 0), TooltipText = p.Popis, PlaceholderText = "(žádná – jen baseColor)" };
                var vz = new HBoxContainer { Name = "Vzornik" };
                le.TextSubmitted += t => Hlas(t);
                le.FocusExited += () => { if (le.Text != Popis!.Hodnota) Hlas(le.Text); };
                box.AddChild(le); box.AddChild(vz);
                Ovladac = le; AddChild(box); Vzornik(vz, p.Hodnota);
                break;
            }
            case DruhParametruVpmg.Cele when p.Hodnota == "" && p.VychoziDev != "":
            {
                // T-2b: hodnota není v receptuře → Dev použije výchozí výraz (z profilu / rozměru); zadáním čísla se přepíše
                var le = new LineEdit { Text = "", PlaceholderText = "výchozí Dev", CustomMinimumSize = new Vector2(150, 0), TooltipText = p.Popis };
                le.TextSubmitted += t => Hlas(t.Trim());
                Ovladac = le; AddChild(le);
                break;
            }
            case DruhParametruVpmg.Cele:
                var sl = new HSlider { MinValue = p.Min ?? 0, MaxValue = p.Max ?? 1000, Step = 1, Value = Cislo(p.Hodnota), CustomMinimumSize = new Vector2(150, 0), SizeFlagsVertical = SizeFlags.ShrinkCenter, TooltipText = p.Popis };
                var sb = new SpinBox { MinValue = sl.MinValue, MaxValue = sl.MaxValue, Step = 1, Value = sl.Value, CustomMinimumSize = new Vector2(90, 0) };
                sl.ValueChanged += v => { if (!_tichy) { _tichy = true; sb.Value = v; _tichy = false; Hlas(((int)v).ToString(CultureInfo.InvariantCulture)); } };
                sb.ValueChanged += v => { if (!_tichy) { _tichy = true; sl.Value = v; _tichy = false; Hlas(((int)v).ToString(CultureInfo.InvariantCulture)); } };
                Ovladac = sl; AddChild(sl); AddChild(sb);
                break;
            case DruhParametruVpmg.Volba:
                var ob = new OptionButton { TooltipText = p.Popis };
                foreach (var m in p.Moznosti) ob.AddItem(m);
                ob.Select(Math.Max(0, IndexOf(p, p.Hodnota)));
                ob.ItemSelected += i => Hlas(p.Moznosti[(int)i]);
                Ovladac = ob; AddChild(ob);
                break;
            default:
                var leT = new LineEdit { Text = p.Hodnota, CustomMinimumSize = new Vector2(150, 0), TooltipText = p.Popis };
                leT.TextSubmitted += t => Hlas(t);
                leT.FocusExited += () => { if (leT.Text != Popis!.Hodnota) Hlas(leT.Text); };
                Ovladac = leT; AddChild(leT);
                break;
        }
        if (p.BezPrekryvu) _nazev.Modulate = new Color(1f, 0.85f, 0.5f);
    }

    /// <summary>Vzorník palety: čtverečky barev z textu „#a, #b“.</summary>
    static void Vzornik(HBoxContainer vz, string h)
    {
        foreach (var c in vz.GetChildren()) c.QueueFree();
        foreach (var x in StavEditoru.Paleta(h))
            if (Color.HtmlIsValid(x)) vz.AddChild(new ColorRect { Color = Color.FromHtml(x), CustomMinimumSize = new Vector2(22, 14), TooltipText = x });
    }

    static int IndexOf(EditorParametruPopis p, string h) { for (int i = 0; i < p.Moznosti.Count; i++) if (p.Moznosti[i] == h) return i; return -1; }
    static double Cislo(string h) => double.TryParse(h, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0;

    void Hlas(string h) { if (_tichy) return; Popis = Popis! with { Hodnota = h }; Zmeneno?.Invoke(Popis.Nazev, h); }

    /// <summary>Nastaví hodnotu bez události (obnova z modelu).</summary>
    public void NastavHodnotu(string h)
    {
        _tichy = true;
        Popis = Popis! with { Hodnota = h };
        switch (Ovladac)
        {
            case ColorPickerButton cp: cp.Color = Color.FromHtml(h); break;
            case HSlider sl: sl.Value = Cislo(h); if (GetChildCount() > 2 && GetChild(2) is SpinBox sb) sb.Value = Cislo(h); break;
            case OptionButton ob: ob.Select(Math.Max(0, IndexOf(Popis, h))); break;
            case LineEdit le: le.Text = h; if (le.GetParent()?.GetNodeOrNull<HBoxContainer>("Vzornik") is { } vz) Vzornik(vz, h); break;
        }
        _tichy = false;
    }

    /// <summary>Simulace uživatele (testy): nastaví ovladač a vyvolá stejnou cestu jako ruční změna.</summary>
    public void ZadejJakoUzivatel(string h)
    {
        switch (Ovladac)
        {
            case ColorPickerButton cp: cp.Color = Color.FromHtml(h); Hlas("#" + cp.Color.ToHtml(false).ToLowerInvariant()); break;
            case HSlider sl: sl.Value = Cislo(h); break;
            case OptionButton ob: ob.Select(IndexOf(Popis!, h)); Hlas(h); break;
            case LineEdit le: le.Text = h; Hlas(h); break;
        }
    }

    /// <summary>Počet barev ve vzorníku palety (testy).</summary>
    public int BarevVzorniku => Ovladac is LineEdit le && le.GetParent()?.GetNodeOrNull<HBoxContainer>("Vzornik") is { } vz ? StavEditoru.Paleta(le.Text).Count : -1;

    /// <summary>Zvýraznění (návrh ≠ katalog, nebo „v0 nečte žádná operace“).</summary>
    public void Zvyrazni(Color c, string? tooltip = null) { _nazev.Modulate = c; if (tooltip != null) _nazev.TooltipText = tooltip; }
}
