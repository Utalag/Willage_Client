namespace Willage.Gen.Materialy;

/// <summary>Geologické vlastnosti jednoho materiálu z katalogu (jen to, co potřebuje voda).</summary>
public sealed record Material(int Id, string Key, double? KMs, double Porovitost, string Skupina, bool Rozpustny);
