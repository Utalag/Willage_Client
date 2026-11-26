using Godot;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>G-5: texty a barvy stavu modulu (StavModuluDto jako text ze signálů jádra) – sdílí SeznamModulu a RetezPrepoctu.</summary>
public static class StavyModulu
{
    public static string Text(string stav) => stav switch
    {
        "Spocitano" => "spočteno",
        "ZPameti" => "z paměti",
        "Ceka" => "čeká",
        "Zastupny" => "zástupný",
        "Bezi" => "počítá…",
        _ => stav,
    };

    public static Color Barva(string stav) => stav switch
    {
        "Spocitano" => new Color(0.55f, 0.95f, 0.55f),
        "ZPameti" => new Color(0.6f, 0.8f, 1f),
        "Ceka" => new Color(1f, 0.85f, 0.4f),
        "Zastupny" => new Color(1f, 0.6f, 0.6f),
        "Bezi" => new Color(1f, 1f, 1f),
        _ => new Color(0.8f, 0.8f, 0.8f),
    };
}
