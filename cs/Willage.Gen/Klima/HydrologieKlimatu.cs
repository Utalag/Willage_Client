using Willage.Gen.Eroze;
using Willage.Gen.Svet;

namespace Willage.Gen.Klima;

/// <summary>
/// Dnešní voda nad mapou eroze (eroze beze změny): průtok = akumulace w·plocha po příjemcích D8 mapy. Koryto z eroze je
/// aktivní (A_k ≥ A_krit), nebo suché (pozůstatek). Tok bez koryta = A_k ≥ A_krit mimo koryto. Vodníci = hlavy aktivní sítě v kopcích.
/// </summary>
public sealed class HydrologieKlimatu
{
    public const byte Aktivni = 1, Suche = 2, BezKoryta = 4, HlavaAktivni = 8;
    public float[] AKlima { get; }
    public byte[] Stav { get; }

    HydrologieKlimatu(int n) { AKlima = new float[n]; Stav = new byte[n]; }

    /// <summary>Akumulace vah po příjemcích (Kahnovo topologické pořadí; nezávislé na výšce a vláknech).</summary>
    public static double[] Akumulace(MapaEroze m, Func<int, double> vahaBunky)
    {
        var t = m.T; var a = new double[t.N]; var darcu = new int[t.N];
        for (int k = 0; k < t.N; k++) { a[k] = vahaBunky(k) * t.Krok * t.Krok; int r = m.Dolu(k); if (r >= 0) darcu[r]++; }
        var fronta = new Queue<int>();
        for (int k = 0; k < t.N; k++) if (darcu[k] == 0) fronta.Enqueue(k);
        while (fronta.Count > 0)
        {
            int k = fronta.Dequeue(), r = m.Dolu(k);
            if (r < 0) continue;
            a[r] += a[k];
            if (--darcu[r] == 0) fronta.Enqueue(r);
        }
        return a;
    }

    public static HydrologieKlimatu Spocti(MapaEroze m, MapaKlimatu k, ParametryEroze pe)
    {
        var a = Akumulace(m, i => k.W[i]);
        var h = new HydrologieKlimatu(m.T.N);
        for (int i = 0; i < m.T.N; i++)
        {
            h.AKlima[i] = (float)a[i];
            if ((m.Priznaky[i] & MapaEroze.Odtok) != 0) continue;   // moře: koryto v moři se nehodnotí
            bool kor = (m.Priznaky[i] & MapaEroze.Koryto) != 0, akt = a[i] >= pe.AKritM2;
            if (kor) h.Stav[i] |= akt ? Aktivni : Suche;
            else if (akt) h.Stav[i] |= BezKoryta;
        }
        var darce = new bool[m.T.N];
        for (int i = 0; i < m.T.N; i++) if ((h.Stav[i] & (Aktivni | BezKoryta)) != 0 && m.Dolu(i) is int r && r >= 0) darce[r] = true;
        for (int i = 0; i < m.T.N; i++) if ((h.Stav[i] & (Aktivni | BezKoryta)) != 0 && !darce[i]) h.Stav[i] |= HlavaAktivni;
        return h;
    }

    /// <summary>Vodníci s klimatem: hlavy aktivní sítě v kopcích, Q = A_k (km²) × specifický odtok.</summary>
    public List<Vodnik> Vodnici(MapaEroze m, SvetFn svet, ParametryEroze p)
    {
        var v = new List<Vodnik>();
        for (int k = 0; k < m.T.N; k++)
        {
            if ((Stav[k] & HlavaAktivni) == 0) continue;
            var (x, y) = m.T.Poloha(k);
            if (Eroze.Vodnici.VahaKopcu(svet, x, y) < p.VodnikVahaKopcu) continue;
            double km2 = AKlima[k] / 1e6;
            v.Add(new Vodnik(k, k % m.T.Nx, k / m.T.Nx, x, y, km2 * p.SpecifickyOdtokLsKm2, km2));
        }
        return v;
    }

    public int Pocet(byte priznak) { int n = 0; foreach (var s in Stav) if ((s & priznak) != 0) n++; return n; }
}
