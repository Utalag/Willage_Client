namespace Willage.Gen.Geologie;

public enum DruhUtvaru { Zila, Cocka, Kras, Dome, Pipe }

/// <summary>Útvar E84 jako SDF: druh, parametry P (rozložení jako utvary.gd::_make), obálka a seed.</summary>
public sealed class Utvar
{
    public DruhUtvaru K; public double[] P = Array.Empty<double>(); public double[] Box = new double[6]; public long Seed;
    public string Klic => K switch { DruhUtvaru.Zila => "zila", DruhUtvaru.Cocka => "cocka", DruhUtvaru.Kras => "kras", DruhUtvaru.Dome => "dome", _ => "pipe" };
}
