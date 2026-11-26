using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-5: horní lišta okna 1 – planeta (seed, gen_ver, otisk, potvrzení) a příkazy: Přepočítat vše, Zrušit, Výchozí vše,
/// Potvrdit planetu (zamkne parametry a uloží WPLN), Uložit / Načíst WPLN. Tlačítka jsou ve scéně, tady jen napojení na jádro.
/// </summary>
[GlobalClass]
public partial class HorniLista : HBoxContainer
{
    /// <summary>Načtení WPLN zařazeno do fronty (okno pak obnoví seznam a konfigurátor).</summary>
    [Signal] public delegate void NacitaniPlanetyEventHandler();
    public Label Info { get; private set; } = null!;
    public LineEdit Cesta { get; private set; } = null!;

    public override void _Ready()
    {
        Info = GetNode<Label>("Info"); Cesta = GetNode<LineEdit>("Cesta");
        var j = WillageJadro.Instance; if (j is null) { Info.Text = "jádro chybí"; return; }
        GetNode<Button>("PrepocitatVse").Pressed += () => j.Generuj();
        GetNode<Button>("Zrusit").Pressed += j.Zrus;
        GetNode<Button>("VychoziVse").Pressed += () => j.Vychozi();
        GetNode<Button>("Potvrdit").Pressed += () => { j.Potvrd(); j.Uloz(Cesta.Text); };
        GetNode<Button>("Ulozit").Pressed += () => j.Uloz(Cesta.Text);
        GetNode<Button>("Nacti").Pressed += () => { j.Nacti(Cesta.Text); EmitSignal(SignalName.NacitaniPlanety); };
        j.PlanetaInfo += i =>
        {
            string otisk = (string)i["OtiskPlanety"];
            Info.Text = $"seed {i["Seed"]} · {i["GenVer"]} · otisk {(otisk.Length > 12 ? otisk[..12] : otisk)} · {((bool)i["Potvrzena"] ? "POTVRZENÁ" : "nepotvrzená")} · {i["Kompatibilita"]}";
            GetNode<Button>("Potvrdit").Disabled = (bool)i["Potvrzena"];
            GetNode<Button>("VychoziVse").Disabled = (bool)i["Potvrzena"];
        };
    }
}
