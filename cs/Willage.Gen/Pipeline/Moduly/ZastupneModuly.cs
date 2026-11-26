namespace Willage.Gen.Pipeline.Moduly;

/// <summary>Výstup zástupného modulu: nic nepočítá, jen ohlásí, že funkce čeká (Jan 17:39: postupně, čekající věci jako zástupné).</summary>
public sealed record ZastupnyVystup(string Id, string Nazev, string Popis);

/// <summary>
/// G-3: zástupný (placeholder) modul – průchozí, verze 0, bez parametrů a souborů. Drží místo v grafu, v seznamu modulů fasády
/// a v okně generátoru, aby se UI a soubory stavěly rovnou na finální tvar. Až se funkce implementuje, nahradí ho skutečný modul.
/// </summary>
public abstract class ZastupnyModul : ModulZaklad
{
    public const string Oznaceni = "zástupný";
    public override int VerzeAlgoritmu => 0;
    public abstract string Popis { get; }
    public override string Parametry(KontextBehu k) => Oznaceni;
    public override object Spust(KontextBehu k) => new ZastupnyVystup(Id, Nazev, Popis);
}

/// <summary>Krok 7d – nasycená zóna podzemní vody (zástupný, ← M6).</summary>
public sealed class M6dNasycenaZona : ZastupnyModul
{
    public const string Id_ = "M6d";
    public override string Id => Id_;
    public override string Nazev => "Nasycená zóna 7d (zástupný)";
    public override IReadOnlyList<string> Zavislosti => new[] { M6VodaAPrusak.Id_ };
    public override string Popis => "krok 7d: nasycená zóna pod hladinou podzemní vody – čeká na návrh";
}

/// <summary>M8 povrchové jevy (zástupný, ← M7).</summary>
public sealed class M8PovrchoveJevy : ZastupnyModul
{
    public const string Id_ = "M8";
    public override string Id => Id_;
    public override string Nazev => "Povrchové jevy (zástupný)";
    public override IReadOnlyList<string> Zavislosti => new[] { M7VystupPlanety.Id_ };
    public override string Popis => "M8: povrchové jevy (sníh, led, bahno, …) – čeká na návrh";
}

/// <summary>M9 vegetace (zástupný, ← M8).</summary>
public sealed class M9Vegetace : ZastupnyModul
{
    public const string Id_ = "M9";
    public override string Id => Id_;
    public override string Nazev => "Vegetace (zástupný)";
    public override IReadOnlyList<string> Zavislosti => new[] { M8PovrchoveJevy.Id_ };
    public override string Popis => "M9: vegetace podle biomu a vody – čeká na návrh";
}
