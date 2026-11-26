// ZRCADLO (jen čtení) z Utalag/Willage_Dev main, PR #14 (29bffc0):
// src/Modules/World/Willage.World.Contracts/GeologyGridConstants.cs. Neměnit zde; změny dělá Willage-backend.
namespace Willage.Gen.Jadro;

/// <summary>Jednotky geologické mřížky (z nahoru, buňka 0,25 m) – kontrakt server ↔ klient.</summary>
public static class GeologyGridConstants
{
    public const int CellEdgeMillimetres = 250;
    public const int CellsPerSegmentEdge = 32;
    public const int SegmentEdgeMillimetres = CellsPerSegmentEdge * CellEdgeMillimetres;
    public const int CellsPerColumnHeight = 512;
    public const int ColumnHeightMillimetres = CellsPerColumnHeight * CellEdgeMillimetres;
    public const int DefaultPlanetPeriodXMillimetres = 245 * ColumnHeightMillimetres;
    public const int DefaultPlanetPeriodYMillimetres = 122 * ColumnHeightMillimetres;

    // Odvozené v metrech (jen klient, ne kontrakt).
    public const double CellM = CellEdgeMillimetres / 1000.0;
    public const double ColumnM = ColumnHeightMillimetres / 1000.0;
    public const double BlockM = 128.0;
    /// <summary>Plocha stěny buňky (m²) pro propustnost 1.8.1.</summary>
    public const double CellFaceM2 = CellM * CellM;
}
