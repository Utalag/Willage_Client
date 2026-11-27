namespace Willage.Gen.Geo2;

/// <summary>Zkompilovaná událost (kap. 1.2). Neměnná, sdílená mezi vlákny.</summary>
public sealed class KompilovanaUdalost
{
    public required int Index { get; init; }
    public required string Id { get; init; }
    public required int Stari { get; init; }
    public required Operace Operace { get; init; }
    public ITvar? Tvar { get; init; }
    public ITvarZasobniku? Zasobnik { get; init; }
    public FiltrMaterialu? Nahrazuje { get; init; }
    public ZdrojeZasahu? Zdroje { get; init; }
    public IReadOnlySet<TypProstoru> Prostor { get; init; } = new HashSet<TypProstoru>();
    public Hloubka Hloubka { get; init; }
    public IKontaktniPasmo? Kontakt { get; init; }
    public int? VysledekMaterial { get; init; }
    public bool MaterialZTvaru { get; init; }
    public IReadOnlyDictionary<int, int> Mapa { get; init; } = new Dictionary<int, int>();
    public TypProstoru VysledekProstor { get; init; }
}

/// <summary>
/// Jedna chronologie GEO2 (kap. 1): události seřazené podle (stáří, id), dopředné vyhodnocení bodu bez deformací (1.6).
/// K1 prochází všechny události; index těles a kontext bloku jsou K3.
/// </summary>
public sealed class ChronologieGeo2
{
    public IReadOnlyList<KompilovanaUdalost> Udalosti { get; }
    public KonfiguraceGeo2 Konfigurace { get; }
    public long OtiskKatalogu { get; }

    public ChronologieGeo2(IReadOnlyList<KompilovanaUdalost> udalosti, KonfiguraceGeo2 konfigurace, long otiskKatalogu)
    {
        Udalosti = udalosti; Konfigurace = konfigurace; OtiskKatalogu = otiskKatalogu;
    }

    public int IndexUdalosti(string id)
    {
        for (int i = 0; i < Udalosti.Count; i++) if (Udalosti[i].Id == id) return i;
        return -1;
    }

    /// <summary>Stav bodu po všech událostech (nad povrchem <see cref="StavBodu.NadPovrchem"/>).</summary>
    public StavBodu Bod(double x, double y, double z, double zPov) => BodPred(Udalosti.Count, x, y, z, zPov);

    /// <summary>Stav bodu po událostech s indexem &lt; <paramref name="pocet"/> (prefixové vyhodnocení, kap. 2.5).</summary>
    public StavBodu BodPred(int pocet, double x, double y, double z, double zPov)
    {
        if (z > zPov) return StavBodu.NadPovrchem;
        var s = StavBodu.Neurceno;
        for (int i = 0; i < pocet; i++)
        {
            var e = Udalosti[i];
            if (!Zasah(e, x, y, z, out uint inst, out int matVrstvy, out short vrstva)) continue;
            int idx = i;
            PrefixVyhodnoceni? pred = e.Kontakt is null ? null : (px, py, pz) => BodPred(idx, px, py, pz, zPov);
            if (!PravidloCile.Povoluje(e, s, x, y, z, zPov, pred)) continue;
            s = Proved(e, s, x, y, z, inst, matVrstvy, vrstva);
        }
        return s;
    }

    private static bool Zasah(KompilovanaUdalost e, double x, double y, double z, out uint inst, out int matVrstvy, out short vrstva)
    {
        inst = 0; matVrstvy = 0; vrstva = -1;
        if (e.Operace == Operace.Uloz) return e.Zasobnik!.Vrstva(x, y, z, out matVrstvy, out vrstva);
        return e.Tvar!.Obsahuje(x, y, z, out inst);
    }

    /// <summary>Zápis stavu podle operace (kap. 3.1). Transformace mění jen materiál, geometrický původ zůstává.</summary>
    private static StavBodu Proved(KompilovanaUdalost e, in StavBodu s, double x, double y, double z, uint inst, int matVrstvy, short vrstva)
    {
        switch (e.Operace)
        {
            case Operace.Uloz:
                return new StavBodu(matVrstvy, TypProstoru.Pevne, e.Index, e.Operace, 0, vrstva, matVrstvy, -1, 0);
            case Operace.Vnikni:
            case Operace.Vypln:
            {
                int m = e.MaterialZTvaru ? ((ITvarSMaterialem)e.Tvar!).Material(x, y, z, inst) : e.VysledekMaterial!.Value;
                return new StavBodu(m, TypProstoru.Pevne, e.Index, e.Operace, inst, -1, m, -1, 0);
            }
            case Operace.Odstran:
                return new StavBodu(0, e.VysledekProstor, e.Index, e.Operace, inst, -1, 0, -1, 0);
            case Operace.Transformuj:
                if (!e.Mapa.TryGetValue(s.Material, out int nm)) return s;
                return s with { Material = nm, PosledniTransformace = e.Index, PocetTransformaci = (byte)Math.Min(255, s.PocetTransformaci + 1) };
            default:
                return s;
        }
    }
}
