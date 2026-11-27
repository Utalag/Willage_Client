using Willage.Gen.Geo2;

namespace Willage.Gen.Testy;

/// <summary>
/// GEO2 K6: rozhraní modifikátorů <see cref="IDeformace"/> (1.8), bez vyhodnocení. V1 odmítnutí aktivní deformace, neaktivní nemění
/// výsledek; testovací posun (jen zde) ověří, že typy rozhraní do sebe zapadají (úsek = afinní obraz sloupce, inverze bodu).
/// </summary>
public static class TestyGeo2K6
{
    private const string Z = """{"id":"z","stari":0,"operace":"Uloz","tvar":{"druh":"test_vrstvy","vrstvy":[{"do_z":10,"material":"granite"},{"do_z":100,"material":"cave_limestone"}]}}""";
    private const string F = """{"id":"f","stari":5,"operace":"Deformuj","aktivni":AKT,"tvar":{"druh":"rovina_zlomu"}}""";

    public static void Spust(string data)
    {
        var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        Validace(kat);
        TvarRozhrani();
    }

    private static void Validace(KatalogGeo2 kat)
    {
        T.Sekce("GEO2 K6: V1 – aktivní Deformuj odmítnuta, neaktivní nemění Bod ani běhy");
        var a = TestyGeo2K1.K("[" + Z + "," + F.Replace("AKT", "true") + "]", kat);
        T.Je(!a.Ok && a.Zprava.Obsahuje("DEFORMACE_AZ_D"), "aktivní Deformuj → DEFORMACE_AZ_D");
        var n = TestyGeo2K1.K("[" + Z + "," + F.Replace("AKT", "false") + "]", kat);
        var bez = TestyGeo2K1.K("[" + Z + "]", kat);
        T.Je(n.Ok && bez.Ok, $"neaktivní Deformuj projde validací ({n.Zprava})");
        if (!n.Ok || !bez.Ok) return;
        var rnd = new Random(66); int ruzne = 0; var b1 = new List<Beh>(); var b2 = new List<Beh>();
        for (int i = 0; i < 2000; i++)
        {
            double x = rnd.NextDouble() * 100, y = rnd.NextDouble() * 100, z = rnd.NextDouble() * 100;
            if (n.Chronologie!.Vzorek(x, y, z, 100) != bez.Chronologie!.Vzorek(x, y, z, 100)) ruzne++;
            if (i % 20 == 0)
            {
                SloupecGeo2.Behy(n.Chronologie, x, y, 100, 100, b1); SloupecGeo2.Behy(bez.Chronologie, x, y, 100, 100, b2);
                if (!b1.SequenceEqual(b2)) ruzne++;
            }
        }
        T.Je(ruzne == 0, $"neaktivní Deformuj: Bod a běhy stejné jako bez ní (rozdílů {ruzne})");
    }

    /// <summary>Testovací posun (zlom jako translace v obálce) – jen ověření tvaru rozhraní, ne implementace etapy D.</summary>
    private sealed class PosunTest : IDeformace
    {
        public int Stari => 5;
        public ObalkaOsova Obalka => new(0, 0, 0, 10, 10, 100);
        private readonly AfinniZobrazeni _inv = AfinniZobrazeni.Identita with { Tx = -1.5, Tz = 2.0 };
        public bool Inverze(ref double x, ref double y, ref double z)
        {
            if (!Obalka.Obsahuje(x, y, z)) return true;
            (x, y, z) = _inv.Pouzij(x, y, z); return true;
        }
        public bool UsekySloupce(in Primka p, List<UsekDeformace> useky)
        {
            useky.Clear();
            if (p.Ox < 0 || p.Ox > 10 || p.Oy < 0 || p.Oy > 10) { useky.Add(new(0, 100, p, AfinniZobrazeni.Identita)); return true; }
            useky.Add(new(0, 100, _inv.Pouzij(p), _inv)); return true;
        }
    }

    private static void TvarRozhrani()
    {
        T.Sekce("GEO2 K6: tvar rozhraní IDeformace (testovací posun)");
        IDeformace d = new PosunTest(); var u = new List<UsekDeformace>();
        var p = Primka.Svisla(3, 4);
        T.Je(d.UsekySloupce(p, u) && u.Count == 1, "afinní deformace vydá úseky (ne NeAfinni)");
        double x = 3, y = 4, z = 37; bool presne = d.Inverze(ref x, ref y, ref z);
        var s = u[0].Starsi; double t = 37;
        T.Je(presne && Math.Abs(s.Ox + t * s.Dx - x) < 1e-12 && Math.Abs(s.Oy + t * s.Dy - y) < 1e-12 && Math.Abs(s.Oz + t * s.Dz - z) < 1e-12,
            "bod úseku ve starších souřadnicích = inverze bodu sloupce (stejný parametr t)");
        T.Je(u[0].Zobrazeni.Pouzij(3, 4, 37) == (x, y, z), "zobrazení úseku = inverze");
        double qx = 50, qy = 50, qz = 5; d.Inverze(ref qx, ref qy, ref qz);
        T.Je(qx == 50 && qy == 50 && qz == 5, "mimo obálku je deformace identita");
    }
}
