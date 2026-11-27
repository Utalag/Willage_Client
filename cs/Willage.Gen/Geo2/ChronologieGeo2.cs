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
/// K1 prochází všechny události; index těles a kontext bloku jsou K3. Kontakt (2.5) čte prefix přes <see cref="BodPred"/>.
/// </summary>
public sealed class ChronologieGeo2
{
    public IReadOnlyList<KompilovanaUdalost> Udalosti { get; }
    public KonfiguraceGeo2 Konfigurace { get; }
    public long OtiskKatalogu { get; }

    /// <summary>Konečný povrch pro bod v jiném sloupci (q′ kontaktu), nebo null = povrch volajícího bodu.</summary>
    public Func<double, double, double>? Povrch { get; }

    public ChronologieGeo2(IReadOnlyList<KompilovanaUdalost> udalosti, KonfiguraceGeo2 konfigurace, long otiskKatalogu,
        Func<double, double, double>? povrch = null)
    {
        Udalosti = udalosti; Konfigurace = konfigurace; OtiskKatalogu = otiskKatalogu; Povrch = povrch;
    }

    /// <summary>Stav bodu po všech událostech; povrch z <see cref="Povrch"/> (musí být zadaný).</summary>
    public StavBodu Bod(double x, double y, double z) => BodPred(Udalosti.Count, x, y, z, Povrch!(x, y));

    public int IndexUdalosti(string id)
    {
        for (int i = 0; i < Udalosti.Count; i++) if (Udalosti[i].Id == id) return i;
        return -1;
    }

    /// <summary>Stav bodu po všech událostech (nad povrchem <see cref="StavBodu.NadPovrchem"/>).</summary>
    public StavBodu Bod(double x, double y, double z, double zPov) => BodPred(Udalosti.Count, x, y, z, zPov);

    /// <summary>Stav bodu po událostech s indexem &lt; <paramref name="pocet"/> (prefixové vyhodnocení, kap. 2.5).</summary>
    public StavBodu BodPred(int pocet, double x, double y, double z, double zPov) => Pruchod(pocet, x, y, z, zPov, null);

    /// <summary>Vzorek 3.1 v bodě (povrch z <see cref="Povrch"/>).</summary>
    public Vzorek Vzorek(double x, double y, double z) => Geo2.Vzorek.Z(Bod(x, y, z));

    /// <summary>Vzorek 3.1 v bodě se zadaným povrchem sloupce.</summary>
    public Vzorek Vzorek(double x, double y, double z, double zPov) => Geo2.Vzorek.Z(BodPred(Udalosti.Count, x, y, z, zPov));

    /// <summary>
    /// Historie(p) (3.2, volitelné): všechny zásahy stejným průchodem jako <see cref="Bod(double, double, double, double)"/>,
    /// nic se neukládá. Invariant: <c>StavPo</c> posledního kroku == Bod (bez zásahu = Neurceno / NadPovrchem, prázdný seznam).
    /// </summary>
    public List<KrokHistorie> Historie(double x, double y, double z, double zPov)
    {
        var h = new List<KrokHistorie>();
        Pruchod(Udalosti.Count, x, y, z, zPov, h);
        return h;
    }

    private StavBodu Pruchod(int pocet, double x, double y, double z, double zPov, List<KrokHistorie>? historie)
    {
        if (z > zPov) return StavBodu.NadPovrchem;
        var s = StavBodu.Neurceno;
        for (int i = 0; i < pocet; i++)
        {
            var e = Udalosti[i];
            if (!Zasah(e, x, y, z, out uint inst, out int matVrstvy, out short vrstva)) continue;
            if (!PravidloCile.Povoluje(e, s, x, y, z, zPov, this, out bool odhad)) continue;
            var po = Proved(e, s, x, y, z, inst, matVrstvy, vrstva, odhad);
            historie?.Add(new KrokHistorie(i, e.Id, inst, e.Operace, s, po));
            s = po;
        }
        return s;
    }

    private static bool Zasah(KompilovanaUdalost e, double x, double y, double z, out uint inst, out int matVrstvy, out short vrstva)
    {
        inst = 0; matVrstvy = 0; vrstva = -1;
        if (e.Operace == Operace.Uloz) return e.Zasobnik!.Vrstva(x, y, z, out matVrstvy, out vrstva);
        return e.Tvar!.Obsahuje(x, y, z, out inst);
    }

    /// <summary>
    /// Zápis stavu podle tabulky 3.1. Geometrické operace nastaví původ, hostitele a vynulují transformace i příznaky;
    /// Transformuj mění jen materiál, počítadlo a poslední transformaci (příznak odhadu kontaktu přidá).
    /// </summary>
    private static StavBodu Proved(KompilovanaUdalost e, in StavBodu s, double x, double y, double z, uint inst, int matVrstvy, short vrstva, bool odhad)
    {
        switch (e.Operace)
        {
            case Operace.Uloz:
                return new StavBodu(matVrstvy, TypProstoru.Pevne, e.Index, e.Operace, 0, vrstva, matVrstvy, -1, 0,
                    HostitelPuvodu: -1, TypHostitele: TypProstoru.Neurceno);
            case Operace.Vnikni:
            {
                int m = e.MaterialZTvaru ? ((ITvarSMaterialem)e.Tvar!).Material(x, y, z, inst) : e.VysledekMaterial!.Value;
                return new StavBodu(m, TypProstoru.Pevne, e.Index, e.Operace, inst, -1, m, -1, 0,
                    HostitelPuvodu: s.Typ == TypProstoru.Pevne ? s.Material : 0, TypHostitele: s.Typ);
            }
            case Operace.Vypln:
            {
                int m = e.MaterialZTvaru ? ((ITvarSMaterialem)e.Tvar!).Material(x, y, z, inst) : e.VysledekMaterial!.Value;
                return new StavBodu(m, TypProstoru.Pevne, e.Index, e.Operace, inst, -1, m, -1, 0, HostitelPuvodu: 0, TypHostitele: s.Typ);
            }
            case Operace.Odstran:
                return new StavBodu(0, e.VysledekProstor, e.Index, e.Operace, inst, -1, 0, -1, 0,
                    HostitelPuvodu: s.Material, TypHostitele: TypProstoru.Pevne);
            case Operace.Transformuj:
                if (!e.Mapa.TryGetValue(s.Material, out int nm)) return s;
                return s with
                {
                    Material = nm, PosledniTransformace = e.Index, PocetTransformaci = (byte)Math.Min(255, s.PocetTransformaci + 1),
                    Priznaky = odhad ? s.Priznaky | PriznakyVzorku.HraniceOdhad : s.Priznaky,
                };
            default:
                return s;
        }
    }
}

/// <summary>Jeden zásah v <see cref="ChronologieGeo2.Historie"/> (3.2): událost, instance, operace, stav před a po.</summary>
public readonly record struct KrokHistorie(int Index, string Udalost, uint Instance, Operace Operace, StavBodu Pred, StavBodu Po)
{
    public int MaterialPred => Pred.Material;
    public int MaterialPo => Po.Material;
    public TypProstoru TypPred => Pred.Typ;
    public TypProstoru TypPo => Po.Typ;
}
