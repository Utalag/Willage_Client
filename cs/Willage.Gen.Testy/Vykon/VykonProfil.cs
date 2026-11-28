using Willage.Gen.Data;
using Willage.Gen.Geo2;
using Willage.Gen.Geologie;
using Willage.Gen.Svet;

namespace Willage.Gen.Testy.Vykon;

/// <summary>Jedna cesta na jednom bloku opakovaně (pro <c>dotnet-trace</c>): <c>--jen=GEO2PROFIL --blok=ox,oy --cesta=geo1|k3|geo2 [--opak=2]</c>.</summary>
public static class VykonProfil
{
    public static void Spust(string data, double ox, double oy, string cesta, int opak, double krokXy, int vlaken)
    {
        T.Sekce($"GEO2 profil: blok ({ox}, {oy}), cesta {cesta}, {opak}× , krok {krokXy} m, {vlaken} vláken");
        var d = DataSveta.Najdi(AppContext.BaseDirectory); var kat = KatalogGeo2.ZeSouboru(Path.Combine(data, "materials-catalog-v1.json"));
        var g = new GeologieCs(new ParametrySveta(), d);
        var c = cesta switch { "geo1" => Cesta.Geo1, "k3" => Cesta.K3, _ => Cesta.Geo2Vychozi };
        for (int i = 0; i < opak; i++)
        {
            var (k, s, soucet) = VykonCesty.Spust(c, g, kat, d, ox, oy, krokXy, vlaken);
            Console.WriteLine($"  průchod {i}: kontext {k:F2} s, sloupce {s:F2} s, součet {soucet:X}");
        }
    }
}
