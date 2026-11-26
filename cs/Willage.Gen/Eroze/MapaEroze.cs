namespace Willage.Gen.Eroze;

/// <summary>Hrubá mapa eroze planety: podklad H0, erodovaná výška H, plocha povodí A (m²), příjemce D8 (−1 = odtok), příznaky.</summary>
public sealed class MapaEroze
{
    public const byte Odtok = 1, Jezero = 2, Koryto = 4, PramenToku = 8;
    public Torus T { get; }
    public float[] H0, H, A;
    /// <summary>Krok 6b: vyplněný povrch (priority-flood) – v jezerech = hladina jezera.</summary>
    public float[] Vypln;
    public sbyte[] Prijemce;
    public byte[] Priznaky;
    public string KlicKese { get; set; } = "";

    public MapaEroze(Torus t)
    {
        T = t; H0 = new float[t.N]; H = new float[t.N]; A = new float[t.N]; Vypln = new float[t.N]; Prijemce = new sbyte[t.N]; Priznaky = new byte[t.N];
    }

    /// <summary>Hloubka eroze v uzlu (m, ≥ 0).</summary>
    public float E(int k) => H0[k] - H[k];

    /// <summary>Index příjemce uzlu k, nebo −1.</summary>
    public int Dolu(int k) => Prijemce[k] < 0 ? -1 : T.Soused(k, Prijemce[k]);

    public long PametBajtu => (long)T.N * (4 * 4 + 1 + 1);
}
