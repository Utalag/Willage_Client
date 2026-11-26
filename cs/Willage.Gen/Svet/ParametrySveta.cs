namespace Willage.Gen.Svet;

/// <summary>Parametry biomu (1.13) – svet_fn.gd vychozi().biomy.</summary>
public sealed class Biom
{
    public double PosunM, PrevyseniM, VlnaM, Drsnost, StropDeg;
    public bool Hreben;
    public Biom(double posun, double prev, double vlna, double drs, double strop, bool hreben)
    { PosunM = posun; PrevyseniM = prev; VlnaM = vlna; Drsnost = drs; StropDeg = strop; Hreben = hreben; }
}

/// <summary>
/// Vstupní parametry světa = svet_fn.gd vychozi() (krok 2, 3, 3b) + opravy kroku 5 (přepínače, výchozí zapnuto).
/// Hodnoty a názvy odpovídají GDScriptu; opravy mají Vychozi­Puvodni() = chování GDScriptu před opravami.
/// </summary>
public sealed class ParametrySveta
{
    public long Seed = 49;
    // rozměry (rozmery.gd)
    public double BlokM = 128.0, SloupecM = 128.0, SvetMaxM = 4096.0;
    public int[] StartBlok = { 14, 14 };
    // klima
    public string Klima = "mirne";
    public double KlimaMapaRoztecM = 2048.0, KlimaMapaPrechodM = 768.0, KlimaMapaSila = 0.25;
    // biomy
    public double BiomRoztecM = 256.0, BiomPrechodM = 320.0;
    public bool BiomVelkeOblasti = false;
    public double[] Podil = { 0.35, 0.10, 0.30, 0.20, 0.05 };
    public Biom[] Biomy =
    {
        new(0.0, 3.0, 160.0, 0.40, 12.0, false),
        new(-1.5, 1.2, 120.0, 0.35, 6.0, false),
        new(5.0, 10.0, 140.0, 0.45, 25.0, false),
        new(8.0, 24.0, 360.0, 0.35, 40.0, true),
        new(2.0, 3.0, 150.0, 0.40, 10.0, false),
    };
    public int Oktav = 4;
    public double RezervaSklonu = 0.8;
    // mapa hornin
    public double HorninyRoztecM = 192.0, HorninyPrechodM = 160.0;
    public int Zastupcu = 3;
    public int[][] HorninyBiomu = { new[] { 54, 3, 52, 51 }, new[] { 12, 3, 54, 53 }, new[] { 52, 44, 45, 46, 49 }, new[] { 6, 37, 34, 41, 40, 39 }, new[] { 7, 26, 36 } };
    // masiv E87
    public double MasivM0 = 0.35, MasivM1 = 1.0, MasivZdvihM = 8.0, P87AmpM = 12.0, P87Freq = 0.008, P87DetailM = 0.75;
    public double P87Dfreq = 0.05, MasivPodilStropu = 0.4, MasivPodilDetail = 0.2;
    public double DetailMaxM = 2.0, PodhuriM = 4.0, PodhuriVlnaM = 48.0;
    // sopky
    public int Sopek = 2;
    public double SopkyRoztecM = 384.0, SopkyRoztecTol = 0.10, SopkaVyskaMinM = 20.0, SopkaVyskaMaxM = 40.0;
    public double SopkaSklonDeg = 17.0, SopkaGamma = 1.5, SopkaStropDeg = 35.0, KraterRPodil = 0.12;
    public double KraterHloubkaPodil = 0.25, SopkaRezervaM = 5.0, SopkyOkrajM = 320.0, SopkaOdOkrajeStartuM = 100.0;
    public double StropPovrchuHladkostM = 2.0;
    // geologie krok 3 / 3b
    public bool P82Vapenec = true;
    public double P82Podil = 0.5, P82PodM = 2.0;
    public bool A1Hostitele = true, A10SumHornin = true, DomPasmoSedimenty = true;
    public double SopkaPruduchRM = 2.0, SopkaSlupkaM = 5.0;
    public int SopkaLavaId = 7, SopkaPopelId = 57;
    public double PasmoSpodek = 0.32, PasmoKrystalinikum = 0.35, PasmoSedimenty = 0.25, PasmoSvrchni = 0.08;
    // klima (uplatni)
    public double KlimaKHorniny = 1.0, KlimaKVoda = 1.0;

    // ---- opravy kroku 5 (Jan 2026-11-26 8:48), výchozí zapnuto
    /// <summary>Šířka přechodu mince E82 přes šev bloků (m); 0 = původní mince po blocích (skok na švu).</summary>
    public double P82PrechodM = 32.0;

    /// <summary>Keš výšky středu útvaru s klíčem round(4·c) jako GDScript (závisí na pořadí dotazů); false = přesný klíč (Jan 9:32).</summary>
    public bool UtvaryKlicGd = false;

    /// <summary>Parametry přesně jako GDScript krok 3b (opravy vypnuté) – pro ekvivalenci.</summary>
    public static ParametrySveta Puvodni(long seed = 49) => new() { Seed = seed, P82PrechodM = 0.0, UtvaryKlicGd = true };
}
