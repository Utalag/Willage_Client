using Willage.Gen.Eroze;
using Willage.Gen.Jadro;

namespace Willage.Gen.Klima;

/// <summary>
/// Oázy / artéské prameny (Jan 12:47): trvalé zdroje vody v pouštích. Buňky OazaBunkaM, existence a výkon z hashe seedu;
/// v buňce se vybere pouštní uzel (volitelně step) s nejnižším povrchem (pánev = vývěr podzemní vody), ne moře ani jezero.
/// Oáza je vodník s jmenovitým výkonem (napojí se přes VodniciVeSvete) a okolí OazaPolomerM dostane biom oáza.
/// </summary>
public static class Oazy
{
    private const int SaltExist = 0x0A51, SaltQ = 0x0A52;

    public static List<Vodnik> Najdi(MapaEroze m, MapaKlimatu mk, ParametryKlimatu p, long seed)
    {
        var v = new List<Vodnik>();
        if (!p.OazaZapnuta || p.OazaPravdepodobnost <= 0) return v;
        var t = m.T; uint sd = unchecked((uint)seed); double b = p.OazaBunkaM;
        int cx0 = (int)Math.Ceiling(t.Nx * t.Krok / b), cy0 = (int)Math.Ceiling(t.Ny * t.Krok / b);
        bool Pousten(int k) => mk.Biom[k] == BiomKlimatu.Poust || (p.OazaVeStepi && mk.Biom[k] == BiomKlimatu.Step);
        for (int cy = 0; cy < cy0; cy++)
        for (int cx = 0; cx < cx0; cx++)
        {
            double u = GeologyHash.Unit(GeologyHash.HashInt3(cx, cy, SaltExist, sd));
            if (u >= p.OazaPravdepodobnost) continue;                       // rychlé vyřazení (horní mez pravděpodobnosti)
            int i0 = (int)Math.Ceiling(cx * b / t.Krok), i1 = Math.Min(t.Nx, (int)Math.Ceiling((cx + 1) * b / t.Krok));
            int j0 = (int)Math.Ceiling(cy * b / t.Krok), j1 = Math.Min(t.Ny, (int)Math.Ceiling((cy + 1) * b / t.Krok));
            int best = -1, nKand = 0, nVse = 0; float hb = float.MaxValue;
            for (int j = j0; j < j1; j++)
            for (int i = i0; i < i1; i++)
            {
                int k = j * t.Nx + i; nVse++;
                if ((m.Priznaky[k] & (MapaEroze.Odtok | MapaEroze.Jezero)) != 0 || !Pousten(k)) continue;
                nKand++;
                if (m.H[k] < hb) { hb = m.H[k]; best = k; }
            }
            // pravděpodobnost úměrná podílu pouště v buňce → hustota oáz ~ plocha pouště (úplná poušť = OazaPravdepodobnost)
            if (best < 0 || u >= p.OazaPravdepodobnost * nKand / Math.Max(1, nVse)) continue;
            double q = p.OazaQLs * (0.5 + GeologyHash.Unit(GeologyHash.HashInt3(cx, cy, SaltQ, sd)));
            var (x, y) = t.Poloha(best);
            v.Add(new Vodnik(best, best % t.Nx, best / t.Nx, x, y, q, q / 10.0));
        }
        return v;
    }

    /// <summary>Okolí oáz v mapě biomů přepíše pouštní (stepní) uzly na biom oáza.</summary>
    public static int Prekryj(MapaKlimatu mk, List<Vodnik> oazy, ParametryKlimatu p)
    {
        var t = mk.T; int r = (int)Math.Ceiling(p.OazaPolomerM / t.Krok), n = 0;
        foreach (var o in oazy)
            for (int dj = -r; dj <= r; dj++)
            for (int di = -r; di <= r; di++)
            {
                if ((di * di + dj * dj) * t.Krok * t.Krok > p.OazaPolomerM * p.OazaPolomerM) continue;
                int k = t.K(o.I + di, o.J + dj);
                if (mk.Biom[k] == BiomKlimatu.Poust || (p.OazaVeStepi && mk.Biom[k] == BiomKlimatu.Step)) { mk.Biom[k] = BiomKlimatu.Oaza; n++; }
            }
        return n;
    }
}
