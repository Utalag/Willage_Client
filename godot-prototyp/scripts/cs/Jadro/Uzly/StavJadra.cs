using Godot;

namespace WillagePrototyp.Jadro.Uzly;

/// <summary>G-4: řádek stavu jádra (fronta, běžící úloha, poslední modul) – uzel do scény, jen zobrazuje signály jádra.</summary>
[GlobalClass]
public partial class StavJadra : Label
{
    string _posledni = "-";

    public override void _Ready()
    {
        var j = WillageJadro.Instance; if (j is null) { Text = "jádro: není autoload WillageJadro"; return; }
        j.ModulHotov += (id, nazev, stav, ms) => _posledni = $"{id} {stav} {ms:F0} ms";
        j.PlanetaHotova += s => _posledni = $"planeta hotová, mapa {s["OtiskMapy"]}";
        j.PraceZrusena += (id, n) => _posledni = $"{n} zrušeno";
        j.PraceSelhala += (id, n, e) => _posledni = $"{n} selhalo: {e}";
    }

    public override void _Process(double delta)
    {
        var j = WillageJadro.Instance; if (j is null) return;
        Text = $"fronta {j.Cekajicich}, běží {j.Bezi ?? "-"}, poslední: {_posledni}";
    }
}
