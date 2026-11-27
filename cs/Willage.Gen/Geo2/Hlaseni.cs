namespace Willage.Gen.Geo2;

public enum Zavaznost { Varovani, Chyba }

/// <summary>Jedno hlášení validace. <see cref="Kod"/> je stabilní (testy a nástroje se na něj odkazují), text je pro člověka.</summary>
public sealed record Hlaseni(Zavaznost Zavaznost, string Kod, string? Udalost, string Text)
{
    public override string ToString() => $"{(Zavaznost == Zavaznost.Chyba ? "CHYBA" : "varování")} {Kod}{(Udalost is null ? "" : $" [{Udalost}]")}: {Text}";
}

public sealed class ZpravaValidace
{
    private readonly List<Hlaseni> _h = new();
    public IReadOnlyList<Hlaseni> Hlaseni => _h;
    public bool MaChyby => _h.Any(h => h.Zavaznost == Zavaznost.Chyba);
    public IEnumerable<Hlaseni> Chyby => _h.Where(h => h.Zavaznost == Zavaznost.Chyba);
    public void Chyba(string kod, string? udalost, string text) => _h.Add(new(Zavaznost.Chyba, kod, udalost, text));
    public void Varovani(string kod, string? udalost, string text) => _h.Add(new(Zavaznost.Varovani, kod, udalost, text));
    public bool Obsahuje(string kod) => _h.Any(h => h.Kod == kod);
    public void Pridej(IEnumerable<Hlaseni> h) => _h.AddRange(h);
    public override string ToString() => string.Join("\n", _h);
}
