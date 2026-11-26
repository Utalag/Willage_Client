using System.Linq;
using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-7: tabulka pásem klimatu M5 (plán 05: vlastní prvek konfigurátoru). Řádek = zapnuté pásmo od rovníku k pólu: podíl, teploty hran, K srážek,
/// vítr, změřené T / P / w a hlavní biom na pevnině pásma. Jen čtení: úprava pásem přímo v tabulce je zástupná (tooltip), pásma se dnes mění
/// parametry ParametryKlimatu v konfigurátoru.
/// </summary>
[GlobalClass]
public partial class TabulkaPasem : Tree
{
    public int Radku { get; private set; }
    long _uloha = -1;
    static readonly string[] Sloupce = { "pásmo", "podíl", "T hran °C", "K", "vítr", "pevnina", "T °C", "P mm", "w", "hlavní biom" };

    public override void _Ready()
    {
        TooltipText = "tabulka pásem M5 (jen čtení) · zástupný: úprava pásem přímo v tabulce – čeká na návrh";
        Columns = Sloupce.Length; ColumnTitlesVisible = true; HideRoot = true; SelectMode = SelectModeEnum.Row;
        for (int i = 0; i < Sloupce.Length; i++) { SetColumnTitle(i, Sloupce[i]); SetColumnExpand(i, i == 0 || i == 9); }
        var j = WillageJadro.Instance; if (j is null) return;
        j.TabulkaPasemHotova += (id, _) => { if (id == _uloha) Napln(); };
        j.PlanetaHotova += _ => { if (Visible) Obnov(); };
    }

    public void Obnov() { var j = WillageJadro.Instance; if (j?.PosledniVysledek is not null) _uloha = j.TabulkaPasem(); }

    void Napln()
    {
        Clear(); var root = CreateItem(); Radku = 0;
        foreach (var p in WillageJadro.Instance!.PosledniTabulkaPasem)
        {
            var it = CreateItem(root);
            string[] h =
            {
                p.Nazev, $"{p.Podil:0.##}", $"{p.TOdC:0.#}→{p.TDoC:0.#}", $"{p.SrazkyK:0.##}", p.Vitr >= 0 ? "Z→" : "←V", $"{100 * p.PodilPevniny:0} %",
                $"{p.TPrumerC:0.0}", $"{p.PPrumerMm:0}", $"{p.WPrumer:0.00}", $"{p.HlavniBiom} {100 * p.PodilHlavnihoBiomu:0} %",
            };
            for (int i = 0; i < h.Length; i++) it.SetText(i, h[i]);
            it.SetTooltipText(0, $"u {p.UOd:0.###}…{p.UDo:0.###} půlperiody (0 rovník, 0,5 pól)");
            Radku++;
        }
    }
}
