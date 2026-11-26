using System.Linq;
using Godot;
using WillagePrototyp.Jadro;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>G-5: čísla planety po přepočtu – otisky, vodníci, oázy, čas, kolik modulů se spočetlo a kolik bylo z paměti.</summary>
[GlobalClass]
public partial class Diagnostika : Label
{
    public override void _Ready()
    {
        var j = WillageJadro.Instance; if (j is null) return;
        Text = "diagnostika: planeta zatím nespočtená";
        j.PlanetaHotova += s =>
        {
            var r = j.PosledniVysledek;
            int sp = r?.Moduly.Count(m => m.Stav == Willage.Gen.Api.Dto.StavModuluDto.Spocitano) ?? 0, zp = r?.Moduly.Count(m => m.Stav == Willage.Gen.Api.Dto.StavModuluDto.ZPameti) ?? 0;
            Text = $"diagnostika\nmapa {s["OtiskMapy"]}\nklima {s["OtiskKlimatu"]}\nvodníků {s["Vodniku"]}, oáz {s["Oaz"]}\nčas {r?.Ms:F0} ms · spočteno {sp}, z paměti {zp}\nspočtené: {string.Join(", ", r?.Moduly.Where(m => m.Stav == Willage.Gen.Api.Dto.StavModuluDto.Spocitano).Select(m => m.Id) ?? Enumerable.Empty<string>())}";
        };
        j.PraceZrusena += (_, n) => Text += $"\n{n}: zrušeno";
        j.PraceSelhala += (_, n, e) => Text += $"\n{n} selhalo: {e}";
    }
}
