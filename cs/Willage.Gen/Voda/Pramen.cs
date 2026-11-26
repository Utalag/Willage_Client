namespace Willage.Gen.Voda;

/// <summary>Vodnik (krok 6) = trvalý zdroj v prameni toku z eroze světa; do výběru kandidátů buňky nevstupuje.</summary>
public enum DruhPramene { Vodnik = 4, Snih = 3, Kontakt = 2, Kras = 1, Vyver = 0 }

/// <summary>Pramen ze seedu: poloha sloupce (m), buňka pramene (index z), druh, jmenovitý výkon (l/s), světová buňka 32 m.</summary>
public sealed record Pramen(double X, double Y, int Kz, DruhPramene Druh, double Jmenovity, int BunkaX, int BunkaY,
    uint Priorita, int AkviferMaterial)
{
    public double Z => (Kz + 0.5) * Jadro.GeologyGridConstants.CellM;
}
