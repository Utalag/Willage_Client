namespace Willage.Gen.Schema;

/// <summary>
/// G-2: ručně psaná metadata parametrů (skupina, jednotka, rozsah, volby, jen čtení). Názvy, typy a výchozí hodnoty se berou z kódu
/// reflexí (<see cref="SchemaParametru"/>); test hlídá, že každý parametr kódu má právě jednu skupinu a nic tu nepřebývá.
/// Jednotka a rozsah, které tu nejsou výslovně, se odvodí z názvu (<see cref="Odvozeni"/>) – vše je návrh k ladění.
/// </summary>
public static class MetadataParametru
{
    public sealed record Rozsah(double Min, double Max, double? Krok = null, string Zdroj = "odhad");

    /// <summary>Skupiny: zdroj → skupina → názvy (pořadí = pořadí v konfigurátoru).</summary>
    public static readonly Dictionary<string, (string skupina, string[] nazvy)[]> Skupiny = new()
    {
        ["ParametrySveta"] = new[]
        {
            ("Planeta", new[] { "Seed", "Klima" }),
            ("Rozměry", new[] { "BlokM", "SloupecM", "SvetMaxM", "StartBlok" }),
            ("Přepínače", new[] { "VseKrok06", "KlimaKrok07", "More", "Panve" }),
            ("Mapa klimatu", new[] { "KlimaMapaRoztecM", "KlimaMapaPrechodM", "KlimaMapaSila", "KlimaKHorniny", "KlimaKVoda" }),
            ("Biomy", new[] { "BiomRoztecM", "BiomPrechodM", "BiomVelkeOblasti", "Podil", "Biomy", "Oktav", "RezervaSklonu" }),
            ("Mapa hornin", new[] { "HorninyRoztecM", "HorninyPrechodM", "Zastupcu", "HorninyBiomu" }),
            ("Masiv E87", new[] { "MasivM0", "MasivM1", "MasivZdvihM", "P87AmpM", "P87Freq", "P87DetailM", "P87Dfreq", "MasivPodilStropu", "MasivPodilDetail", "DetailMaxM", "PodhuriM", "PodhuriVlnaM" }),
            ("Sopky", new[] { "Sopek", "SopkyRoztecM", "SopkyRoztecTol", "SopkaVyskaMinM", "SopkaVyskaMaxM", "SopkaSklonDeg", "SopkaGamma", "SopkaStropDeg", "KraterRPodil", "KraterHloubkaPodil", "SopkaRezervaM", "SopkyOkrajM", "SopkaOdOkrajeStartuM", "StropPovrchuHladkostM" }),
            ("Moře", new[] { "PodilMore", "OdchylkaMoreProcBodu", "HladinaMoreM", "HloubkaMoreM", "SklonKontinentu", "SklonOdPobreziM", "MorePrechod" }),
            ("Kontinenty", new[] { "PlanetaXM", "PlanetaYM", "KontinentuMin", "KontinentuMax", "KontinentVelikost", "Clenitost", "ClenitostSila", "SumVln", "WarpVln", "SumLambdaMinM", "SumLambdaMaxM", "WarpLambdaMinM", "WarpM", "MrizkaPrahuM", "MrizkaVzdalenostiM" }),
            ("Šev torusu", new[] { "RezervaSevuM", "SevPrechodM", "SevMekkySpad", "SevMekkyPasM", "SevZvlneniM", "SevZvlneniLambdaMinM", "SevZvlneniLambdaMaxM" }),
            ("Ostrovy a start", new[] { "OstrovuPocet", "OstrovPolomerM", "OstrovVyska", "StartPolomerM", "StartPrechodM", "StartRezerva" }),
            ("Pánve", new[] { "PanviPocet", "PanevPolomerM", "PanevHloubkaM" }),
            ("Vrstvy a mince E82", new[] { "P82Vapenec", "P82Podil", "P82PodM", "P82PrechodM", "PasmoSpodek", "PasmoKrystalinikum", "PasmoSedimenty", "PasmoSvrchni", "DomPasmoSedimenty" }),
            ("Útvary a šum hornin", new[] { "A1Hostitele", "A10SumHornin", "UtvaryKlicGd" }),
            ("Nitro sopky", new[] { "SopkaPruduchRM", "SopkaSlupkaM", "SopkaLavaId", "SopkaPopelId" }),
        },
        ["ParametryEroze"] = new[]
        {
            ("Planeta a mřížka", new[] { "PlanetaXM", "PlanetaYM", "KrokM", "PasProlnutiM" }),
            ("Odtok a srážky", new[] { "OdtokPodil", "Srazky", "EpsilonVyplneM" }),
            ("Stream power", new[] { "K", "M", "KrokuCasu", "DtRoku", "MaxEroseM" }),
            ("Toky a vodníci", new[] { "AKritM2", "SpecifickyOdtokLsKm2", "VodnikVahaKopcu" }),
            ("Koryto", new[] { "KorytoA", "KorytoC", "KorytoMinSirkaM", "KorytoMaxHloubkaM", "InterpolaceE" }),
        },
        ["ParametryKlimatu"] = new[]
        {
            ("Zeměpis a teplota", new[] { "StartYM", "VyskovyGradientCNaM", "HladinaMoreM", "PrechodPasmaM" }),
            ("Pásma planet", new[] { "Planety" }),
            ("Vítr a vlhkost", new[] { "DoplneniNadMoremM", "KontinentalitaM", "OrografieZesileni", "VlhkostMin", "VyhlazeniTerenuM", "VyhlazeniSrazekM" }),
            ("Oázy", new[] { "OazaZapnuta", "OazaBunkaM", "OazaPravdepodobnost", "OazaQLs", "OazaPolomerM", "OazaVeStepi" }),
            ("Dobití hladiny 7c", new[] { "HladinaKlimaZapnuta", "HladinaWPrah", "HladinaWPlna", "HladinaSuchoM", "HladinaBrehPlneM", "HladinaBrehDoM", "HladinaKorytoPlneM", "HladinaKorytoDoM", "HladinaZdrojPlneM", "HladinaZdrojDoM" }),
            ("Odtok a prameny", new[] { "OdtokReferenceMm", "PramenWMax", "PramenPravdepodobnostMax" }),
            ("Biomy", new[] { "TLedC", "TTundraC", "TTajgaC", "TTropyC", "KoppenA", "KoppenB", "PoustPodilMeze", "PMirnyDestnyMm", "PTropickyLesMm" }),
        },
        ["ParametryVody"] = new[]
        {
            ("Obecné", new[] { "Seed", "SopkaNepropustna", "HladinaSledujeErozi" }),
            ("Regionální hladina", new[] { "MrizkaHladinyM", "PolomerHladinyM", "HloubkaD0M", "ZesileniUdoliBeta", "HladinaPrechodM", "HladinaBezMorskychUzlu", "HladinaPodlahaPodil", "HladinaPodlahaM" }),
            ("Profil a artéská voda", new[] { "FilmM", "MrizkaDoplnM", "PolomerDoplnM" }),
            ("Prameny", new[] { "BunkaPramenuM", "KrokKandidatuM", "PravdepodobnostBunky", "RozestupM", "SklonKontakt", "QSnih", "QKontakt", "QKras", "QVyver", "Tlakovy" }),
            ("Průsak", new[] { "PrusakKoeficient", "PrusakTlak", "PrusakSpadMax" }),
            ("Pobřežní pás", new[] { "PrusakPobrezi", "PobrezHorizontDni", "PobrezSpad", "PobrezSpadMin", "PobrezSpadMax", "PobrezTlakDelkaM", "PobrezPorovitost", "PobrezMaxM", "PobrezOknoM" }),
        },
        ["prusak_v1.json"] = new[] { ("Koeficient průsaku", new[] { "Tabulka" }) },
    };

    /// <summary>Výslovné rozsahy („Zdroj.Nazev“); ostatní z <see cref="Odvozeni"/>.</summary>
    public static readonly Dictionary<string, Rozsah> Rozsahy = new()
    {
        ["ParametrySveta.Seed"] = new(0, 4294967295, 1, "kód: seed u32 (HashSveta)"),
        ["ParametrySveta.BlokM"] = new(128, 128, null, "kód: model V1.0 (rozmery.gd)"),
        ["ParametrySveta.SloupecM"] = new(128, 128, null, "kód: model V1.0 (rozmery.gd)"),
        ["ParametrySveta.SvetMaxM"] = new(384, 65536, 128),
        ["ParametrySveta.StartBlok"] = new(0, 255, 1),
        ["ParametrySveta.KontinentuMin"] = new(1, 8, 1), ["ParametrySveta.KontinentuMax"] = new(1, 8, 1),
        ["ParametrySveta.Oktav"] = new(1, 8, 1), ["ParametrySveta.Zastupcu"] = new(1, 6, 1), ["ParametrySveta.Sopek"] = new(0, 8, 1),
        ["ParametrySveta.OstrovuPocet"] = new(0, 20, 1), ["ParametrySveta.PanviPocet"] = new(0, 12, 1),
        ["ParametrySveta.SumVln"] = new(8, 128, 1), ["ParametrySveta.WarpVln"] = new(0, 64, 1),
        ["ParametrySveta.SopkaLavaId"] = new(0, 255, 1, "kód: MaterialId u8"), ["ParametrySveta.SopkaPopelId"] = new(0, 255, 1, "kód: MaterialId u8"),
        ["ParametrySveta.HladinaMoreM"] = new(0, 128, 0.25, "kód: sloupec 0–128 m"), ["ParametrySveta.HloubkaMoreM"] = new(0, 60, 0.25),
        ["ParametrySveta.OdchylkaMoreProcBodu"] = new(0, 20, 0.5), ["ParametrySveta.SevMekkySpad"] = new(0, 1, 0.01),
        ["ParametrySveta.SopkaSklonDeg"] = new(0, 60, 0.5), ["ParametrySveta.SopkaStropDeg"] = new(0, 70, 0.5),
        ["ParametrySveta.SopkaGamma"] = new(0.25, 4, 0.05), ["ParametrySveta.PlanetaXM"] = new(4096, 65536, 32), ["ParametrySveta.PlanetaYM"] = new(4096, 65536, 32),
        ["ParametryEroze.PlanetaXM"] = new(4096, 65536, 32), ["ParametryEroze.PlanetaYM"] = new(4096, 65536, 32), ["ParametryEroze.KrokM"] = new(8, 128, 8),
        ["ParametryEroze.K"] = new(0, 1e-3), ["ParametryEroze.M"] = new(0.1, 1, 0.05), ["ParametryEroze.KrokuCasu"] = new(0, 200, 1),
        ["ParametryEroze.EpsilonVyplneM"] = new(0, 0.1),
        ["ParametryKlimatu.StartYM"] = new(0, 65536, 32), ["ParametryKlimatu.HladinaMoreM"] = new(0, 128, 0.25, "kód: sloupec 0–128 m"),
        ["ParametryKlimatu.TLedC"] = new(-40, 40, 0.5), ["ParametryKlimatu.TTundraC"] = new(-40, 40, 0.5), ["ParametryKlimatu.TTajgaC"] = new(-40, 40, 0.5), ["ParametryKlimatu.TTropyC"] = new(-40, 40, 0.5),
        ["ParametryKlimatu.KoppenA"] = new(0, 50, 0.5), ["ParametryKlimatu.KoppenB"] = new(0, 500, 1),
        ["ParametryKlimatu.PramenWMax"] = new(0, 10, 0.05), ["ParametryKlimatu.OrografieZesileni"] = new(0, 200, 1),
        ["ParametryVody.Seed"] = new(0, 4294967295, 1, "kód: seed u32"),
        ["ParametryVody.PrusakSpadMax"] = new(0, 50, 0.1), ["ParametryVody.ZesileniUdoliBeta"] = new(0, 5, 0.05),
    };

    /// <summary>Volby pro textové parametry s pevnou množinou hodnot.</summary>
    public static readonly Dictionary<string, string[]> Volby = new()
    {
        // ParametrySveta.Klima: volby se čtou z klima_presety.csv (SchemaParametru.IdPresetuKlimatu).
        ["ParametryEroze.InterpolaceE"] = new[] { "bilinearni", "catmullrom", "bspline" },
    };

    /// <summary>Parametry, které dnes vždy přepíše jiný zdroj (konfigurátor je jen ukáže).</summary>
    public static readonly Dictionary<string, string> JenCteni = new()
    {
        ["ParametrySveta.Podil"] = "přepíše preset klimatu (klima_presety.csv) ve SvetFn",
        ["ParametrySveta.KlimaKHorniny"] = "přepíše preset klimatu (klima_presety.csv) ve SvetFn",
        ["ParametrySveta.KlimaKVoda"] = "přepíše preset klimatu (klima_presety.csv) ve SvetFn",
        ["ParametrySveta.PlanetaXM"] = "svět planety bere ParametryEroze.PlanetaXM (eroze_v1.json); má být stejné",
        ["ParametrySveta.PlanetaYM"] = "svět planety bere ParametryEroze.PlanetaYM (eroze_v1.json); má být stejné",
        ["ParametrySveta.SvetMaxM"] = "svět planety ho zvětší na planetu + pás prolnutí (ErozePlanety.SvetPlanety)",
        ["ParametrySveta.BlokM"] = "rozměr modelu V1.0 (128 m), neladí se",
        ["ParametrySveta.SloupecM"] = "rozměr modelu V1.0 (128 m), neladí se",
    };

    /// <summary>Jednotka a rozsah odvozené z názvu a výchozí hodnoty (návrh, zdroj „odhad“).</summary>
    public static class Odvozeni
    {
        public static string Jednotka(string n) =>
            n.EndsWith("CNaM") ? "°C/m" : n.EndsWith("MmRok") ? "mm/rok" : n.EndsWith("Mm") ? "mm" : n.EndsWith("LsKm2") ? "l/s/km²" : n.EndsWith("QLs") || n.StartsWith("Q") && n.Length > 1 && char.IsUpper(n[1]) ? "l/s"
            : n.EndsWith("Deg") ? "°" : n.EndsWith("Dni") ? "dny" : n.EndsWith("Roku") ? "roky" : n.EndsWith("M2") ? "m²" : n.EndsWith("ProcBodu") ? "p. b."
            : (n.EndsWith("C") && n.Length > 2 && (n.StartsWith("T") || n.Contains("OdC") || n.Contains("DoC"))) ? "°C"
            : n.EndsWith("M") && n.Length > 1 ? "m" : "–";

        public static Rozsah Rozsah(string n, object? v)
        {
            switch (v)
            {
                case int i: return new(Math.Min(0, i), Math.Max(2 * Math.Abs(i), Math.Abs(i) + 10), 1);
                case long l: return new(0, Math.Max(2 * l, 10), 1);
                case uint u: return new(0, Math.Max(2.0 * u, 10), 1);
                case double d:
                    bool podil = n.Contains("Podil") || n.Contains("Pravdepodobnost") || n.Contains("Sila") || n.Contains("Tol") || n.EndsWith("Rezerva") || n.Contains("Porovitost") || n.StartsWith("Vlhkost");
                    if (podil && d >= 0 && d <= 1) return new(0, 1, 0.01);
                    if (d < 0) return new(4 * d, -4 * d);
                    double max = d == 0 ? 1 : Math.Pow(10, Math.Ceiling(Math.Log10(4 * d)));
                    return new(0, max);
                default: return new(0, 0);
            }
        }
    }
}
