using Willage.Gen.Api.Dto;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Planeta;
using Willage.Gen.Schema;
using Willage.Gen.Voda;

namespace Willage.Gen.Api.Sluzby;

/// <summary>ISluzbaSveta: generace, otisky, WPLN a potvrzení.</summary>
public sealed class SluzbaSvetaApi : ISluzbaSveta
{
    readonly StavGeneratoru _s;
    public SluzbaSvetaApi(StavGeneratoru s) => _s = s;

    public VysledekGeneraceDto Generuj() => _s.Generuj();

    public OtiskyPlanetyDto Otisky(int bx = 14, int by = 14)
    {
        var r = _s.Posledni ?? _s.Spust();
        var v = r.Vystup<VystupVody>(M6VodaAPrusak.Id_);
        var s = r.Vystup<VystupPlanety>(M7VystupPlanety.Id_);
        var blok = s.Svet.Voda(v.Katalog, v.Parametry, v.PrusakJson).Blok(bx, by, 2.0, true);   // jako nástroj „klima otisky“ (VodaBlok: mřížka 2 m, profily)
        return new OtiskyPlanetyDto(s.Souhrn.OtiskMapy, s.Souhrn.OtiskKlimatu, s.Souhrn.Vodniku, OtiskVody.Blok(blok), bx, by, blok.Prameny.Count);
    }

    /// <summary>Obsah planety z aktuálního stavu (sada, klíče, manifest).</summary>
    public PlanetaV1 Planeta()
    {
        var man = _s.Manifest();
        var kl = _s.Klice();
        return new PlanetaV1
        {
            Seed = _s.Sada.Sestav().svet.Seed, ManifestSouhrn = man.Souhrn, Manifest = man.Polozky, SadaJson = _s.Sada.ToJson(_s.Schema),
            Klice = _s.Pipeline.Graf.Poradi.Select(m => new KeyValuePair<string, string>(m.Id, kl[m.Id])).ToList(), Potvrzena = _s.Potvrzena,
        };
    }

    public PlanetaInfoDto Uloz(string cesta)
    {
        var p = Planeta();
        SouborPlanety.Uloz(cesta, p);
        return Info(p);
    }

    public PlanetaInfoDto Nacti(string cesta)
    {
        var p = SouborPlanety.Nacti(cesta);
        if (p.GenVer != Pipeline.KlicModulu.GenVer) throw new InvalidDataException($"planeta je z generátoru {p.GenVer}, tento je {Pipeline.KlicModulu.GenVer}");
        _s.Sada = SadaParametru.ZJson(p.SadaJson, _s.Schema, SadaParametru.ZDat(_s.Data));
        _s.Potvrzena = p.Potvrzena;
        return Info(p);
    }

    public PlanetaInfoDto PotvrdPlanetu() { _s.Potvrzena = true; return Info(Planeta()); }

    public PlanetaInfoDto Info() => Info(Planeta());

    /// <summary>Info s rozdíly dat (manifest planety × aktuální) a moduly, jejichž klíč se od uložení změnil.</summary>
    PlanetaInfoDto Info(PlanetaV1 p)
    {
        var kl = _s.Klice();
        var neplatne = p.Klice.Where(k => StavGeneratoru.Klic(kl, k.Key) != k.Value).Select(k => k.Key).ToList();
        return new PlanetaInfoDto(p.GenVer, p.Seed, p.Potvrzena, p.ManifestSouhrn, SouborPlanety.RozdilyDat(p, _s.Manifest()), neplatne, p.Upravy.Count);
    }
}
