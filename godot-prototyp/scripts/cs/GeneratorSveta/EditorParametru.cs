using System;
using Godot;
using Willage.Gen.Api.Konfigurator;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-5: editor jednoho parametru (řádek konfigurátoru) postavený z PopisEditoru (Konfigurator, bez Godotu).
/// Celé/desetinné → SpinBox (+ HSlider, když schéma zná rozsah), logický → CheckButton, volba → OptionButton,
/// text → LineEdit, pole/tabulka → LineEdit s JSON (vlastní prvek je zástupný). „?“ = nápověda (zástupná, texty nejsou ve v1).
/// Změnu od uživatele pošle signálem Zmena(id, json); sám nic nepočítá.
/// </summary>
[GlobalClass]
public partial class EditorParametru : HBoxContainer
{
    [Signal] public delegate void ZmenaEventHandler(string id, string json);
    [Signal] public delegate void NapovedaEventHandler(string id, string text);

    public PopisEditoru? Popis { get; private set; }
    public string Id => Popis?.Parametr.Id ?? "";
    /// <summary>Hlavní ovládací prvek (SpinBox, CheckButton, OptionButton, LineEdit).</summary>
    public Control? Prvek { get; private set; }
    public HSlider? Posuvnik { get; private set; }
    public string? PosledniOdeslany { get; private set; }
    bool _tahne;
    int _desetin = 6;

    /// <summary>Počet desetinných míst čísla (přes decimal: 315.36 → 2, 1e-5 → 5), nejvýš 10.</summary>
    static int Desetin(double x)
    {
        if (x == 0 || !double.IsFinite(x) || Math.Abs(x) > 7e27) return 0;
        return Math.Min(10, (decimal.GetBits((decimal)x)[3] >> 16) & 0xFF);
    }

    /// <summary>Hodnota prvku zaokrouhlená na desetiny kroku – Range ukládá min + n·krok, takže 315.36 by bylo 315.36000000000001.</summary>
    double Zaokrouhli(double v) => Math.Round(v, _desetin);

    public void Nastav(PopisEditoru p)
    {
        Popis = p; Name = "E_" + p.Parametr.Id.Replace('.', '_');
        PosledniOdeslany = p.Parametr.Hodnota;
        foreach (var c in GetChildren()) { RemoveChild(c); c.QueueFree(); }
        var l = new Label { Text = p.Popisek, CustomMinimumSize = new Vector2(250, 0), TooltipText = p.Parametr.Id + (string.IsNullOrEmpty(p.Parametr.Poznamka) ? "" : "\n" + p.Parametr.Poznamka), MouseFilter = MouseFilterEnum.Pass, ClipText = true };
        AddChild(l);
        string h = p.Parametr.Hodnota;
        switch (p.Druh)
        {
            case DruhEditoru.Cele:
            case DruhEditoru.Desetinne:
                // krok ze schématu; bez kroku (0) krok podle zápisu hodnoty a minima, aspoň 3 desetiny (SpinBox ukazuje tolik desetin, kolik má krok)
                double hv = Konfigurator.Cislo(h);
                double krok = p.Krok > 0 ? p.Krok : p.Druh == DruhEditoru.Cele ? 1 : Math.Pow(10, -Math.Max(3, Math.Max(Desetin(hv), p.Posuvnik ? Desetin(p.Min) : 0)));
                _desetin = Desetin(krok);
                var sb = new SpinBox { Step = krok, MinValue = p.Posuvnik ? p.Min : -1e12, MaxValue = p.Posuvnik ? p.Max : 1e12, AllowGreater = !p.Posuvnik, AllowLesser = !p.Posuvnik,
                    CustomMinimumSize = new Vector2(120, 0), SelectAllOnFocus = true };
                if (p.Druh == DruhEditoru.Cele) sb.Rounded = true;
                if (p.Posuvnik)
                {
                    Posuvnik = new HSlider { MinValue = p.Min, MaxValue = p.Max, Step = krok, CustomMinimumSize = new Vector2(150, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill, SizeFlagsVertical = SizeFlags.ShrinkCenter };
                    Posuvnik.SetValueNoSignal(hv);
                    Posuvnik.DragStarted += () => _tahne = true;
                    Posuvnik.DragEnded += zmena => { _tahne = false; if (zmena) Odesli(Zaokrouhli(Posuvnik.Value)); };
                    Posuvnik.ValueChanged += v => { sb.SetValueNoSignal(v); if (!_tahne) Odesli(Zaokrouhli(v)); };
                    AddChild(Posuvnik);
                }
                sb.SetValueNoSignal(hv);
                sb.ValueChanged += v => { Posuvnik?.SetValueNoSignal(v); Odesli(Zaokrouhli(v)); };
                Prvek = sb; break;
            case DruhEditoru.Prepinac:
                var cb = new CheckButton(); cb.SetPressedNoSignal(Konfigurator.Logicka(h)); cb.Toggled += v => Odesli(v); Prvek = cb; break;
            case DruhEditoru.Volba:
                var ob = new OptionButton(); string akt = Konfigurator.Retezec(h);
                for (int i = 0; i < (p.Parametr.Volby?.Count ?? 0); i++) { ob.AddItem(p.Parametr.Volby![i], i); if (p.Parametr.Volby[i] == akt) ob.Selected = i; }
                ob.ItemSelected += i => Odesli(ob.GetItemText((int)i)); Prvek = ob; break;
            case DruhEditoru.Text:
                var te = new LineEdit { Text = Konfigurator.Retezec(h), CustomMinimumSize = new Vector2(200, 0) }; te.TextSubmitted += t => Odesli(t); Prvek = te; break;
            default:
                var je = new LineEdit { Text = h, CustomMinimumSize = new Vector2(260, 0), SizeFlagsHorizontal = SizeFlags.ExpandFill, TooltipText = p.PoznamkaEditoru ?? "" };
                je.TextSubmitted += t => Odesli(t); Prvek = je;
                break;
        }
        if (Prvek.SizeFlagsHorizontal == SizeFlags.Fill && Posuvnik is null) Prvek.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        AddChild(Prvek);
        if (p.PoznamkaEditoru is not null) AddChild(new Label { Text = "zástupný editor", TooltipText = p.PoznamkaEditoru, MouseFilter = MouseFilterEnum.Pass, Modulate = new Color(1, 0.75f, 0.75f) });
        var n = new Button { Text = "?", TooltipText = p.Napoveda, Modulate = p.NapovedaZastupna ? new Color(1, 0.75f, 0.75f) : Colors.White };
        n.Pressed += () => EmitSignal(SignalName.Napoveda, Id, p.Napoveda);
        AddChild(n);
        Zamkni(p.Zamceny, p.DuvodZamceni);
    }

    void Zamkni(bool z, string duvod)
    {
        switch (Prvek)
        {
            case SpinBox s: s.Editable = !z; break;
            case LineEdit le: le.Editable = !z; break;
            case BaseButton b: b.Disabled = z; break;
        }
        if (Posuvnik is not null) Posuvnik.Editable = !z;
        if (z) { Prvek!.TooltipText = duvod; Modulate = new Color(0.8f, 0.8f, 0.8f); }
    }

    public bool Zamceny => Popis?.Zamceny ?? true;

    /// <summary>Aktuální hodnota editoru jako JSON (stejný převod jako při odeslání).</summary>
    public string HodnotaJson() => Popis is null || Prvek is null ? "null" : Konfigurator.NaJson(Popis.Druh, Prvek switch
    {
        SpinBox s => (object)Zaokrouhli(s.Value),
        CheckButton c => c.ButtonPressed,
        OptionButton o => o.GetItemText(o.Selected),
        LineEdit le => le.Text,
        _ => "null",
    });

    /// <summary>Simulace uživatele (testy): nastaví prvek, jako by hodnotu zadal uživatel (vyšle Zmena).</summary>
    public void ZadejJakoUzivatel(Variant v)
    {
        if (Zamceny) return;   // zamčený prvek uživatel nezmění (Editable = false / Disabled)
        switch (Prvek)
        {
            case SpinBox s: s.Value = v.AsDouble(); break;
            case CheckButton c: c.ButtonPressed = v.AsBool(); break;
            case OptionButton o: for (int i = 0; i < o.ItemCount; i++) if (o.GetItemText(i) == v.AsString()) { o.Select(i); Odesli(v.AsString()); } break;
            case LineEdit le: le.Text = v.AsString(); Odesli(le.Text); break;
        }
    }

    void Odesli(object v)
    {
        if (Popis is null || Popis.Zamceny) return;
        string j;
        try { j = Konfigurator.NaJson(Popis.Druh, v); }
        catch (FormatException e) { Oznac(false, e.Message); return; }
        if (j == PosledniOdeslany) return;
        PosledniOdeslany = j;
        EmitSignal(SignalName.Zmena, Id, j);
    }

    /// <summary>Výsledek Nastav z jádra: odmítnuto → červeně s důvodem.</summary>
    public void Oznac(bool prijato, string duvod)
    {
        Modulate = prijato ? (Zamceny ? new Color(0.8f, 0.8f, 0.8f) : Colors.White) : new Color(1, 0.55f, 0.55f);
        if (Prvek is not null && !prijato) Prvek.TooltipText = duvod;
    }
}
