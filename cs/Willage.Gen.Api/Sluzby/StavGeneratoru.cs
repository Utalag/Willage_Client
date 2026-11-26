using Willage.Gen.Api.Dto;
using Willage.Gen.Data;
using Willage.Gen.Katalogy;
using Willage.Gen.Pipeline;
using Willage.Gen.Pipeline.Moduly;
using Willage.Gen.Schema;

namespace Willage.Gen.Api.Sluzby;

/// <summary>
/// Sdílený stav fasády (jedna planeta v paměti): data, pipeline se zástupnými moduly, schéma a sada parametrů, poslední běh,
/// potvrzení. Služby (IModuly, ISluzbaSveta, …) jsou tenké třídy nad tímto stavem. Není vláknově bezpečný – volající (Godot jádro G-4)
/// serializuje přístup do jedné fronty.
/// </summary>
public sealed class StavGeneratoru
{
    public DataSveta Data { get; }
    public PipelineSveta Pipeline { get; }
    public SchemaParametru Schema { get; }
    public SadaParametru Sada { get; set; }
    public VysledekBehu? Posledni { get; private set; }
    public double PosledniMs { get; private set; }
    public bool Potvrzena { get; set; }
    public string? Kes { get; }
    public int Vlaken { get; }

    public StavGeneratoru(DataSveta d, string? kes = null, int vlaken = 8)
    {
        Data = d; Kes = kes; Vlaken = vlaken;
        Pipeline = new PipelineSveta(d, ModulySveta.GrafSeZastupnymi());
        Schema = SchemaParametru.Sestav(d);
        Sada = SadaParametru.ZDat(d);
    }

    public ManifestKatalogu Manifest() => ManifestKatalogu.Spocti(Data);

    /// <summary>Klíče modulů pro aktuální sadu (bez výpočtu).</summary>
    public IReadOnlyDictionary<string, string> Klice()
    {
        var (p, n) = Sada.Sestav(); Pipeline.Nastaveni = n;
        return Pipeline.Klice(p);
    }

    public VysledekBehu Spust(IProgress<ModulDto>? prubeh = null, CancellationToken zruseni = default)
    {
        var (p, n) = Sada.Sestav(); Pipeline.Nastaveni = n;
        var sw = System.Diagnostics.Stopwatch.StartNew();
        var zast = Pipeline.Graf.Poradi.OfType<ZastupnyModul>().ToDictionary(m => m.Id);
        Action<StavModulu>? po = prubeh is null ? null : st =>
        {
            var m = Pipeline.Graf.Poradi.First(x => x.Id == st.Id); zast.TryGetValue(st.Id, out var z);
            prubeh.Report(new ModulDto(m.Id, m.Nazev, m.VerzeAlgoritmu, m.Zavislosti, m.Soubory, z is not null, z?.Popis, st.Klic,
                z is not null ? StavModuluDto.Zastupny : st.ZPameti ? StavModuluDto.ZPameti : StavModuluDto.Spocitano, st.Ms));
        };
        Posledni = Pipeline.Spust(p, Kes, Vlaken, po, zruseni);
        PosledniMs = sw.Elapsed.TotalMilliseconds;
        return Posledni;
    }

    public VysledekBehu Hotovo() => Posledni ?? throw new InvalidOperationException("planeta ještě není vygenerovaná (zavolej Generuj)");

    public static string Klic(IReadOnlyDictionary<string, string> k, string id) => k.TryGetValue(id, out var v) ? v : "";

    /// <summary>Moduly s klíčem a stavem: Spocitano / ZPameti podle posledního běhu, Ceka když se klíč od běhu změnil, Zastupny.</summary>
    public IReadOnlyList<ModulDto> Moduly()
    {
        var kl = Klice();
        var beh = Posledni?.Moduly.ToDictionary(m => m.Id);
        return Pipeline.Graf.Poradi.Select(m =>
        {
            var z = m as ZastupnyModul;
            StavModuluDto st; double ms = 0;
            if (z is not null) st = StavModuluDto.Zastupny;
            else if (beh is null || !beh.TryGetValue(m.Id, out var b)) st = StavModuluDto.Ceka;
            else if (b.Klic != kl[m.Id]) st = StavModuluDto.Ceka;
            else { st = b.ZPameti ? StavModuluDto.ZPameti : StavModuluDto.Spocitano; ms = b.Ms; }
            return new ModulDto(m.Id, m.Nazev, m.VerzeAlgoritmu, m.Zavislosti, m.Soubory, z is not null, z?.Popis, kl[m.Id], st, ms);
        }).ToList();
    }

    public VysledekGeneraceDto Generuj(IProgress<ModulDto>? prubeh = null, CancellationToken zruseni = default)
    {
        var r = Spust(prubeh, zruseni);
        var s = r.Vystup<VystupPlanety>(M7VystupPlanety.Id_).Souhrn;
        return new VysledekGeneraceDto(Moduly(), new SouhrnPlanetyDto(s.OtiskMapy, s.OtiskKlimatu, s.Vodniku, s.Oaz, s.ManifestSouhrn), PosledniMs);
    }
}
