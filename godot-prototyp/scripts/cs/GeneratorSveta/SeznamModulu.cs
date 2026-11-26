using System.Linq;
using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>G-5: seznam modulů M0–M7 + zástupné M6d, M8, M9 se stavem (spočteno / z paměti / čeká / zástupný) a časem; výběr modulu.</summary>
[GlobalClass]
public partial class SeznamModulu : ItemList
{
    [Signal] public delegate void ModulVybranEventHandler(string id);

    public string Vybrany { get; private set; } = "";

    public override void _Ready()
    {
        var j = WillageJadro.Instance; if (j is null) return;
        j.ModulySeznam += _ => Obnov(j);
        ItemSelected += i => { Vybrany = (string)GetItemMetadata((int)i); EmitSignal(SignalName.ModulVybran, Vybrany); };
    }

    void Obnov(WillageJadro j)
    {
        Clear();
        foreach (var m in j.PosledniModuly)
        {
            string st = m.Stav.ToString();
            int i = AddItem($"{m.Id}  {m.Nazev} · {StavyModulu.Text(st)}{(m.Ms > 0 ? $" · {m.Ms:F0} ms" : "")}");
            SetItemMetadata(i, m.Id); SetItemCustomFgColor(i, StavyModulu.Barva(st));
            SetItemTooltip(i, $"{m.Id} {m.Nazev}\nklíč {m.Klic}\nzávisí na {string.Join(", ", m.Zavislosti)}\nsoubory {string.Join(", ", m.Soubory)}{(m.Zastupny ? "\nzástupný: " + m.Popis : "")}");
            if (m.Id == Vybrany) Select(i);
        }
    }

    /// <summary>Vybere modul (jako klik uživatele).</summary>
    public void Vyber(string id)
    {
        for (int i = 0; i < ItemCount; i++)
            if ((string)GetItemMetadata(i) == id) { Select(i); Vybrany = id; EmitSignal(SignalName.ModulVybran, id); return; }
    }

    public string StavPolozky(string id) => Enumerable.Range(0, ItemCount).Where(i => (string)GetItemMetadata(i) == id).Select(GetItemText).FirstOrDefault() ?? "";
}
