using Willage.Gen.Svet;

namespace Willage.Gen.Testy.Vykon;

/// <summary>Měřené bloky 128 m (kategorie z PODKLADY 2.7; stejné jako V8 na větvi <c>geo2-v8-rozdily</c>: <c>TestyGeo2V8.Kategorie</c>).</summary>
public static class VykonBloky
{
    public static List<(string Kategorie, double X, double Y)> Seznam(SvetFn s)
    {
        var l = new List<(string, double, double)>
        {
            ("náhodné", 1024, 512), ("náhodné", 3000, 2000), ("náhodné", 0, 0), ("náhodné", 2048, 1024), ("náhodné", 512, 3072),
            ("šev mince x = 1920", 1856, 1024), ("šev mince x = 2048", 1984, 2560),
            ("hornatina / strmé", 1664, 1728), ("hornatina / strmé", 3904, 1344),
        };
        var ss = s.Sopky.Seznam;
        if (ss.Count > 0)
        {
            var q = ss[0];
            l.Add(("svah sopky", Math.Floor(q.X + 0.4 * q.R - 64), Math.Floor(q.Y - 64)));
            l.Add(("okraj sopky", Math.Floor(q.X + q.R - 96), Math.Floor(q.Y - 64)));
        }
        return l;
    }
}
