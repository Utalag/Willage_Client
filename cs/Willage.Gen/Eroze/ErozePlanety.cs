using Willage.Gen.Data;
using Willage.Gen.Svet;

namespace Willage.Gen.Eroze;

/// <summary>Sestavení eroze planety: funkce světa přes celý torus, výpočet nebo načtení z keše, napojení do světa (přepínač).</summary>
public static class ErozePlanety
{
    /// <summary>Parametry světa pro planetu: svět musí pokrýt Px, Py i pás prolnutí (jinak stejné jako p).</summary>
    /// <summary>Krok 6b: ladicí parametry moře a pánví z data/v1/more_v1.json (Jan 10:11).</summary>
    /// G-2: soubor přepíše jen pole, která v p ještě mají výchozí hodnotu C# – moře jde nastavit i v ParametrySveta (dřív soubor přepsal vše).
    public static ParametrySveta NactiMore(ParametrySveta p, DataSveta d) =>
        File.Exists(d.MoreV1) ? ParametryMore.ZJson(File.ReadAllText(d.MoreV1)).UplatniNaVychozi(p) : p;

    public static SvetFn SvetPlanety(ParametrySveta p, DataSveta d, ParametryEroze pe)
    {
        NactiMore(p, d);
        p.PlanetaXM = pe.PlanetaXM; p.PlanetaYM = pe.PlanetaYM;
        p.SvetMaxM = Math.Max(p.SvetMaxM, Math.Max(pe.PlanetaXM, pe.PlanetaYM) + pe.PasProlnutiM);
        return new SvetFn(p, d);
    }

    public static PeriodickyPodklad Podklad(SvetFn s, ParametryEroze pe) => new(s, pe.PlanetaXM, pe.PlanetaYM, pe.PasProlnutiM);

    /// <summary>Klíč keše mapy pro daný svět (moře je součástí klíče, bez moře beze změny proti kroku 6).</summary>
    public static string Klic(SvetFn s, DataSveta d, ParametryEroze pe) => SouborMapy.KlicKese(s.Sd, pe, s.More is null ? d.SouborySveta.Where(f => f != d.MoreV1) : d.SouborySveta, (s.More?.Kanonicky() ?? "") + (s.Panve?.Kanonicky() ?? ""));

    /// <summary>Načte mapu ze složky keše podle klíče, jinak spočte a uloží. kes = null → bez ukládání.</summary>
    public static MapaEroze Mapa(SvetFn s, DataSveta d, ParametryEroze pe, string? kes, int vlaken)
    {
        string klic = Klic(s, d, pe);
        string? cesta = kes is null ? null : Path.Combine(kes, $"eroze_{klic[..16]}.wger");
        if (cesta is not null && SouborMapy.Nacti(cesta, klic) is { } m) return m;
        m = VypocetEroze.Spocti(Podklad(s, pe), pe, vlaken, out _);
        m.KlicKese = klic;
        if (cesta is not null) { Directory.CreateDirectory(kes!); SouborMapy.Uloz(cesta, m, s.Sd); }
        return m;
    }
}
