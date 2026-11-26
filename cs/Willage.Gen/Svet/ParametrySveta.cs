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
    // krok 6b (Jan 2026-11-26 9:59): moře a mírný sklon kontinentu – mění svět, výchozí vypnuto
    public bool More = false;
    public double PlanetaXM = 31360.0, PlanetaYM = 15616.0;
    // Jan 10:03/10:12: podíl moře 30 % ± 5 p. b. ze seedu; hladina, hloubka, sklon (6b)
    public double PodilMore = 0.35, OdchylkaMoreProcBodu = 5.0, HladinaMoreM = 60.0, HloubkaMoreM = 25.0;
    public double SklonKontinentu = 0.002, SklonOdPobreziM = 1400.0;
    // krok 6c (Jan 10:25): maska pevniny z periodického šumu – kontinenty, členitost, šev, start
    public int KontinentuMin = 2, KontinentuMax = 4;
    public double KontinentVelikost = 1.0, Clenitost = 1.0, ClenitostSila = 0.12;
    public int SumVln = 48, WarpVln = 24;
    public double SumLambdaMinM = 600.0, SumLambdaMaxM = 4000.0, WarpLambdaMinM = 4000.0, WarpM = 700.0;
    public double MorePrechod = 0.04, RezervaSevuM = 512.0, SevPrechodM = 400.0, SevMekkySpad = 0.0, SevMekkyPasM = 1500.0;
    // krok 6d (Jan 10:51): ostrovy v průlivech, zvlněný okraj pásu švu, (kalibrace prahu vynechána, Jan 10:54)
    public int OstrovuPocet = 5;
    public double OstrovPolomerM = 700.0, OstrovVyska = 0.3, SevZvlneniM = 400.0, SevZvlneniLambdaMinM = 600.0, SevZvlneniLambdaMaxM = 3000.0;
    public double StartPolomerM = 400.0, StartPrechodM = 1200.0, StartRezerva = 0.05;
    public double MrizkaPrahuM = 128.0, MrizkaVzdalenostiM = 64.0;
    // Jan 10:03 (b): velké pánve pro velká jezera – přepínač, výchozí vypnuto
    public bool Panve = false;
    // krok 6c: „vše zapnuto“ (moře, sklon, pánve; eroze a vodníci přes KonfiguraceSveta); krok 6d (Jan 10:51): výchozí zapnuto
    public bool VseKrok06 = true;
    public int PanviPocet = 4;
    public double PanevPolomerM = 1500.0, PanevHloubkaM = 15.0;
    // krok 7: klima a biomy nad mapou planety (klima_v1.json). Od 7b (Jan 12:47) výchozí zapnuto (jen s VseKrok06).
    // Mění jen dnešní vodu (prameny, vodníci, oázy, aktivní koryta), mapu eroze ne (Jan 12:26: eroze je pozůstatek minulosti).
    public bool KlimaKrok07 = true;

    /// <summary>G-1: hluboká kopie (pole i biomy). SvetFn mění parametry na místě (klimatický preset), pipeline proto staví každý svět z vlastní kopie.</summary>
    public ParametrySveta Kopie()
    {
        var k = (ParametrySveta)MemberwiseClone();
        k.StartBlok = (int[])StartBlok.Clone();
        k.Podil = (double[])Podil.Clone();
        k.Biomy = Biomy.Select(b => new Biom(b.PosunM, b.PrevyseniM, b.VlnaM, b.Drsnost, b.StropDeg, b.Hreben)).ToArray();
        k.HorninyBiomu = HorninyBiomu.Select(r => (int[])r.Clone()).ToArray();
        return k;
    }

    /// <summary>Parametry přesně jako GDScript krok 3b (opravy vypnuté, bez moře a pánví kroku 6) – pro ekvivalenci.</summary>
    public static ParametrySveta Krok5(long seed = 49) => new() { Seed = seed, VseKrok06 = false };

    /// <summary>Stav po kroku 6: moře, eroze a vodníci zapnuto, klima kroku 7 vypnuto (staré otisky: voda 8e239a68c6d01be0, 92 vodníků).</summary>
    public static ParametrySveta Krok06(long seed = 49) => new() { Seed = seed, VseKrok06 = true, KlimaKrok07 = false };

    /// <summary>Parametry přesně jako GDScript krok 3b (opravy vypnuté) – pro ekvivalenci.</summary>
    public static ParametrySveta Puvodni(long seed = 49) => new() { Seed = seed, P82PrechodM = 0.0, UtvaryKlicGd = true, VseKrok06 = false };
}
