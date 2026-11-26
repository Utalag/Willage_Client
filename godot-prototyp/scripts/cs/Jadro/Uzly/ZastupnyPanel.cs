using Godot;

namespace WillagePrototyp.Jadro.Uzly;

/// <summary>
/// G-4: zástupný panel (placeholder) pro čekající funkce – v okně generátoru drží místo, aby se rozvržení stavělo na finální tvar.
/// Text je vždy označený „zástupný“. Funkce: 7d, M8, M9, U-1, U-2, nápověda (Jan 17:39).
/// </summary>
[GlobalClass]
public partial class ZastupnyPanel : Label
{
    public static readonly string[] Znamé = { "7d nasycená zóna", "M8 povrchové jevy", "M9 vegetace", "U-1 regionální úpravy", "U-2 částečný přepočet", "nápověda parametrů" };

    private string _funkce = "";
    [Export] public string Funkce { get => _funkce; set { _funkce = value; Text = Popis(value); } }

    public static string Popis(string f) => $"zástupný: {f} – čeká na návrh";

    public override void _Ready() { Text = Popis(_funkce); Modulate = new Color(1, 0.75f, 0.75f); }
}
