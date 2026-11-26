using Willage.Gen.Eroze;

namespace Willage.Gen.Klima;

/// <summary>
/// Krok 7: klima na hrubé mřížce mapy eroze (32 m): šířka, teplota, srážky (mm/rok) se stínem, odtok podle Turca,
/// váha odtoku w = R / R_ref (1 = dnešních 10 l/s/km²) a klimatický biom. Počítá se z hotové mapy (erodovaná výška, moře);
/// mapu eroze nemění (Jan 12:26: eroze je pozůstatek minulosti).
/// </summary>
public sealed class MapaKlimatu
{
    public Torus T { get; }
    public float[] Teplota, Srazky, W;
    public BiomKlimatu[] Biom;
    public KlimaRadku[] Radky;
    public Zemepis Zemepis { get; }
    public string Klic { get; set; } = "";

    MapaKlimatu(Torus t, Zemepis z)
    {
        T = t; Zemepis = z; Teplota = new float[t.N]; Srazky = new float[t.N]; W = new float[t.N]; Biom = new BiomKlimatu[t.N]; Radky = new KlimaRadku[t.Ny];
    }

    public static MapaKlimatu Spocti(MapaEroze m, ParametryKlimatu p, KlimaPlanety k, int vlaken = 8)
    {
        var t = m.T; var z = new Zemepis(p, k, t.Ny * t.Krok);
        var mk = new MapaKlimatu(t, z);
        var more = new bool[t.N]; var h = new double[t.N];
        for (int i = 0; i < t.N; i++) { more[i] = (m.Priznaky[i] & MapaEroze.Odtok) != 0; h[i] = Math.Max(m.H[i], p.HladinaMoreM); }
        int rT = (int)Math.Round(p.VyhlazeniTerenuM / t.Krok), rP = (int)Math.Round(p.VyhlazeniSrazekM / t.Krok);
        var hs = Vyhlazeni.Box(h, t.Nx, t.Ny, rT, rT);
        var praw = new double[t.N];
        var po = new ParallelOptions { MaxDegreeOfParallelism = vlaken };
        Parallel.For(0, t.Ny, po, j =>
        {
            var kr = z.Radek(j * t.Krok); mk.Radky[j] = kr;
            int o = j * t.Nx; var rz = new double[t.Nx]; var rv = new double[t.Nx];
            double wz = kr.PodilZapadu;
            if (wz > 0) Klima.Srazky.Radek(hs.AsSpan(o, t.Nx), more.AsSpan(o, t.Nx), 1, t.Krok, p, rz);
            if (wz < 1) Klima.Srazky.Radek(hs.AsSpan(o, t.Nx), more.AsSpan(o, t.Nx), -1, t.Krok, p, rv);
            double pb = kr.SrazkyMm;
            for (int i = 0; i < t.Nx; i++) praw[o + i] = pb * (wz * rz[i] + (1 - wz) * rv[i]);
        });
        var ps = Vyhlazeni.Box(praw, t.Nx, t.Ny, rP, rP);
        Parallel.For(0, t.Ny, po, j =>
        {
            var kr = mk.Radky[j];
            for (int i = 0; i < t.Nx; i++)
            {
                int q = j * t.Nx + i;
                double te = z.Teplota(kr.TC, m.H[q]), pr = ps[q];
                mk.Teplota[q] = (float)te; mk.Srazky[q] = (float)pr;
                mk.W[q] = more[q] ? 0f : (float)(Odtok.OdtokMm(pr, te) / p.OdtokReferenceMm);
                mk.Biom[q] = KlasifikaceBiomu.Urci(te, pr, more[q], p);
            }
        });
        return mk;
    }

    /// <summary>Otisk polí klimatu (FNV-1a 64).</summary>
    public string Otisk()
    {
        ulong hsh = 14695981039346656037UL;
        void B(ReadOnlySpan<byte> s) { foreach (var b in s) { hsh ^= b; hsh *= 1099511628211UL; } }
        foreach (var a in new[] { Teplota, Srazky, W }) B(System.Runtime.InteropServices.MemoryMarshal.AsBytes(a.AsSpan()));
        B(System.Runtime.InteropServices.MemoryMarshal.AsBytes(Biom.AsSpan()));
        return hsh.ToString("x16");
    }

    /// <summary>Klíč klimatu = SHA-256(klíč mapy eroze | kanonické parametry klimatu | planeta). Klíč eroze se nemění.</summary>
    public static string KlicKlimatu(string klicEroze, ParametryKlimatu p, string planeta) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes("krok07-klima-v1|" + klicEroze + "|" + p.Kanonicky(planeta)))).ToLowerInvariant();
}
