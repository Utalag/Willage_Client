using Willage.Gen.Geo2;
using Willage.Gen.Geo2.E84;
using Willage.Gen.Geologie;

namespace Willage.Gen.Testy.V8;

public enum Verdikt : byte { Zlepseni, DleKontraktu, Tolerance, Otevrene }

public enum Pricina : byte
{
    PovrchTolerance, HranicVrstvyTolerance,
    CockaObalka,
    SkarnJenKarbonaty, SkarnPasmoDelsi, SkarnDiraGeo1, SkarnVPasmuTolerance, SkarnHraniceOdhad, SkarnHostitelOkoli, SkarnJine,
    PoradiTeles, HostitelSkarn, PravidloZdroje,
    SopkaRozdil, KrasRozdil,
    Nevysvetleno,
}

/// <summary>Pro každou příčinu verdikt (viz PROP: zlepšení = měřeně porušuje GEO1 kontrakt; dle kontraktu = záměrná změna sémantiky).</summary>
public static class Verdikty
{
    public static Verdikt Z(Pricina p) => p switch
    {
        Pricina.PovrchTolerance or Pricina.HranicVrstvyTolerance or Pricina.SkarnVPasmuTolerance or Pricina.SkarnHraniceOdhad => Verdikt.Tolerance,
        Pricina.SkarnHostitelOkoli => Verdikt.DleKontraktu,
        Pricina.CockaObalka or Pricina.SkarnPasmoDelsi or Pricina.SkarnDiraGeo1 => Verdikt.Zlepseni,
        Pricina.SkarnJenKarbonaty or Pricina.PoradiTeles or Pricina.HostitelSkarn or Pricina.PravidloZdroje => Verdikt.DleKontraktu,
        _ => Verdikt.Otevrene,
    };
}

/// <summary>Údaje jedné rozdílové buňky pro klasifikaci.</summary>
public readonly record struct RozdilBunky(double X, double Y, double Z, int M1, int M2, Zdroj Z1, Zdroj Z2, double ZPov1, double ZPov2, double DHranice, int VrstvaId);

/// <summary>Společné, jen pro čtení sdílené podklady klasifikace jednoho bloku (kontext, plocha kontaktu, index čoček, karbonáty).</summary>
public sealed class PodkladyKlasifikace
{
    public const double Tau = 0.125, W0 = 1.5, A = 0.5, Ek = 0.125;
    public required IPlochaKontaktu Skarn { get; init; }
    public required IndexUtvaruE84 IndexCocek { get; init; }
    public required Utvary Utvary { get; init; }
    public required bool[] Karbonat { get; init; }
    public required int SkarnId { get; init; }
    public required KontaktniPasmo Pasmo { get; init; }
    public required ChronologieGeo2 Chron { get; init; }
    public required int IdxSkarn { get; init; }
}

public static class Klasifikator
{
    public static Pricina Urci(in RozdilBunky r, PodkladyKlasifikace p)
    {
        bool tel1 = r.Z1 is Zdroj.Cocka or Zdroj.Zila or Zdroj.Dome or Zdroj.Pipe, tel2 = r.Z2 is Zdroj.Cocka or Zdroj.Zila or Zdroj.Dome or Zdroj.Pipe;
        if (Math.Abs(r.Z - r.ZPov1) <= PodkladyKlasifikace.Tau || Math.Abs(r.Z - r.ZPov2) <= PodkladyKlasifikace.Tau) return Pricina.PovrchTolerance;
        if (r.Z1 == Zdroj.Vrstva && r.Z2 == Zdroj.Vrstva && r.DHranice <= PodkladyKlasifikace.Tau) return Pricina.HranicVrstvyTolerance;
        if ((r.Z1 == Zdroj.Cocka || r.Z2 == Zdroj.Cocka) && TestyGeo2K3.RozsireniCocky(p.IndexCocek, p.Utvary, r.X, r.Y, r.Z)) return Pricina.CockaObalka;
        bool ob1 = tel1 || r.Z1 == Zdroj.Kras, ob2 = tel2 || r.Z2 == Zdroj.Kras; // těleso nebo kras
        if (r.Z2 == Zdroj.Skarn && ob1) return HostitelSkarn(r, p);
        if (r.Z1 == Zdroj.Skarn && tel2) return r.VrstvaId >= 0 && r.VrstvaId < p.Karbonat.Length && !p.Karbonat[r.VrstvaId] ? Pricina.SkarnJenKarbonaty : Pricina.PoradiTeles;
        if (r.Z1 == Zdroj.Skarn || r.Z2 == Zdroj.Skarn) return Skarn(r, p);
        if (r.Z1 == Zdroj.Sopka || r.Z2 == Zdroj.Sopka) return Pricina.SopkaRozdil;
        if (r.Z1 == Zdroj.Kras && tel2 || tel1 && r.Z2 == Zdroj.Kras) return Pricina.PravidloZdroje;
        if (tel1 && tel2) return Pricina.PoradiTeles;
        if (ob1 != ob2) return Pricina.PravidloZdroje;
        if (r.Z1 == Zdroj.Kras || r.Z2 == Zdroj.Kras) return Pricina.KrasRozdil;
        return Pricina.Nevysvetleno;
    }

    /// <summary>GEO1 má těleso / kras (host = vrstva v bodě), GEO2 ponechá skarn (host = materiál v bodě; skarn není hostitelem tělesa). Ověří se datovým pravidlem hostitele GEO1.</summary>
    private static Pricina HostitelSkarn(in RozdilBunky r, PodkladyKlasifikace p)
    {
        string kd = r.Z1 switch { Zdroj.Cocka => "cocka", Zdroj.Zila => "zila", Zdroj.Dome => "dome", Zdroj.Pipe => "pipe", _ => "kras" };
        return p.Utvary.HostOk(kd, p.SkarnId, r.ZPov1, r.Z) ? Pricina.SkarnJine : Pricina.HostitelSkarn;
    }

    private static Pricina Skarn(in RozdilBunky r, PodkladyKlasifikace p)
    {
        bool je = p.Skarn.Nejblizsi(r.X, r.Y, r.Z, 4.0, out var b);
        if (je && b.Odhad) return Pricina.SkarnHraniceOdhad; // uznaná výjimka V5 (Jan t1043u): vykliňování vrstvy uvnitř buňky 0,25 m
        double d = je ? b.D : double.PositiveInfinity;
        double lo = PodkladyKlasifikace.W0 * (1 - PodkladyKlasifikace.A) - PodkladyKlasifikace.Ek, hi = PodkladyKlasifikace.W0 * (1 + PodkladyKlasifikace.A) + PodkladyKlasifikace.Ek;
        if (r.Z1 == Zdroj.Skarn)
        {
            if (r.VrstvaId >= 0 && r.VrstvaId < p.Karbonat.Length && !p.Karbonat[r.VrstvaId]) return Pricina.SkarnJenKarbonaty;
            if (d > hi) return Pricina.SkarnPasmoDelsi;
            if (d >= lo) return Pricina.SkarnVPasmuTolerance;
            return HostitelOkoliSelhal(r, p) ? Pricina.SkarnHostitelOkoli : Pricina.SkarnJine;
        }
        if (d < lo) return Pricina.SkarnDiraGeo1;
        if (d <= hi) return Pricina.SkarnVPasmuTolerance;
        return Pricina.SkarnJine;
    }

    /// <summary>
    /// Skarn GEO1 v jistém pásmu (d &lt; dolní mez), GEO2 ne: jediná podmínka kontaktu 2.5, která selhává, je <c>hostitel_okoli</c> v q′ = π + η·u (R5). Na okraji plochy cíle
    /// (boční hranice horniny) padne q′ o η = 0,125 m za okraj do jiné horniny. Silný test: strana, dosah a šířka pásma platí, <c>Plati</c> přesto vrací false.
    /// </summary>
    private static bool HostitelOkoliSelhal(in RozdilBunky r, PodkladyKlasifikace p)
    {
        var kp = p.Pasmo;
        if (kp.Parametry.HostitelOkoli is null) return false;
        var st = p.Chron.BodPred(p.IdxSkarn, r.X, r.Y, r.Z, r.ZPov2);
        bool vT = kp.VCili(st);
        if (kp.Parametry.Strana == StranaKontaktu.Vne && vT || kp.Parametry.Strana == StranaKontaktu.Uvnitr && !vT) return false;
        if (!kp.Nejblizsi(r.X, r.Y, r.Z, out var b) || b.D > kp.Sirka(r.X, r.Y, r.Z)) return false;
        return !kp.Plati(r.X, r.Y, r.Z, st, p.Chron, p.IdxSkarn, r.ZPov2, out _);
    }
}
