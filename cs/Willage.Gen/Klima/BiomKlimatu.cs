namespace Willage.Gen.Klima;

/// <summary>Klimatický biom (druhá osa vedle reliéfních biomů MapaBiomu).</summary>
public enum BiomKlimatu : byte
{
    More = 0, Led = 1, Tundra = 2, Tajga = 3, MirnyLes = 4, Step = 5, Poust = 6, Savana = 7, MirnyDestnyLes = 8, TropickyDestnyLes = 9,
}

/// <summary>Whittaker (teplota × srážky) s Köppenovou mezí suchosti: poušť P &lt; 0,5·P_mez, step P &lt; P_mez, P_mez = 20·T + 140 mm.</summary>
public static class KlasifikaceBiomu
{
    public static readonly string[] NazevCs = { "moře", "led", "tundra", "tajga", "mírný les", "step", "poušť", "savana", "mírný deštný les", "tropický deštný les" };

    public static BiomKlimatu Urci(double t, double p, bool more, ParametryKlimatu k)
    {
        if (more) return BiomKlimatu.More;
        if (t < k.TLedC) return BiomKlimatu.Led;
        if (t < k.TTundraC) return BiomKlimatu.Tundra;
        double mez = k.KoppenA * t + k.KoppenB;
        if (p < k.PoustPodilMeze * mez) return BiomKlimatu.Poust;
        if (p < mez) return BiomKlimatu.Step;
        if (t < k.TTajgaC) return BiomKlimatu.Tajga;
        if (t < k.TTropyC) return p >= k.PMirnyDestnyMm ? BiomKlimatu.MirnyDestnyLes : BiomKlimatu.MirnyLes;
        return p >= k.PTropickyLesMm ? BiomKlimatu.TropickyDestnyLes : BiomKlimatu.Savana;
    }
}
