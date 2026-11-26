using System.Text.Json;

namespace Willage.Gen.Voda;

/// <summary>Parametry kroku 4 (data/v1/voda_v1.json); výchozí hodnoty = PROP krok04.</summary>
public sealed record ParametryVody
{
    public uint Seed { get; init; } = 49;
    // regionální hladina
    public double MrizkaHladinyM { get; init; } = 8.0;
    public double PolomerHladinyM { get; init; } = 48.0;
    public double HloubkaD0M { get; init; } = 1.5;
    public double ZesileniUdoliBeta { get; init; } = 1.0;
    // profil sloupce
    public double FilmM { get; init; } = 0.5;
    // artéská voda
    public double MrizkaDoplnM { get; init; } = 8.0;
    public double PolomerDoplnM { get; init; } = 192.0;
    // prameny
    public double BunkaPramenuM { get; init; } = 24.0;   // Jan 2026-11-26 9:32: 24 m / 0,6 (dříve 32 m)
    public double KrokKandidatuM { get; init; } = 2.0;
    public double PravdepodobnostBunky { get; init; } = 0.6;
    public double RozestupM { get; init; } = 8.0;
    public double SklonKontakt { get; init; } = 0.5;
    public double QSnih { get; init; } = 4.0;
    public double QKontakt { get; init; } = 1.5;
    public double QKras { get; init; } = 5.0;
    public double QVyver { get; init; } = 1.0;
    public bool Tlakovy { get; init; } = false;
    // krok 5 (Jan 2026-11-26, rozhodnutí 3): nitro sopky (průduch, láva, popel) je pro vodu těsnění; false = krok 4
    public bool SopkaNepropustna { get; init; } = true;
    // krok 6b: hladina se počítá z povrchu před erozí a sníží se o hrubou erozi (koryto pak hladinu odkryje); bez eroze beze změny
    public bool HladinaSledujeErozi { get; init; } = true;

    // krok 6e/6f (Jan 11:15, 11:33–11:34): u moře = hladina moře; plynulý přechod do vnitrozemí na této vzdálenosti od břehu (m, výchozí 5); 0 = vypnuto
    public double HladinaPrechodM { get; init; } = 5.0;

    // koeficient průsaku (těsnost materiálu 0–255, data prusak_v1.json): výchozí vypnuto; ovlivní jen průsak do uzavřených prostor
    public bool PrusakKoeficient { get; init; } = false;

    // pobřežní pás z koeficientu průsaku (prusak-pobrezi-prop.md): výchozí vypnuto = konstanta HladinaPrechodM
    public bool PrusakPobrezi { get; init; } = false;
    /// <summary>Časový horizont průsaku mořské vody do vnitrozemí (dny); šířka pásu = dosah za tuto dobu.</summary>
    public double PobrezHorizontDni { get; init; } = 30.0;
    /// <summary>Stálý spád (bezrozměrný) pro Darcyho rychlost v = K·i/n, když je <see cref="PrusakTlak"/> vypnutý.</summary>
    public double PobrezSpad { get; init; } = 0.05;
    /// <summary>
    /// Tlak (rozdíl hydraulické výšky): průsak roste se spádem. Dutina: spád = (H − hladina) / tloušťka stěny (nejvýš <see cref="PrusakSpadMax"/>)
    /// místo poměru výšek. Pobřeží: i = |hladina ze spádu terénu − hladina moře| / <see cref="PobrezTlakDelkaM"/>, v mezích
    /// <see cref="PobrezSpadMin"/>…<see cref="PobrezSpadMax"/>. Vypnuto = starý model (stálý <see cref="PobrezSpad"/>, poměr výšek).
    /// </summary>
    public bool PrusakTlak { get; init; } = true;
    public double PrusakSpadMax { get; init; } = 10.0;
    public double PobrezSpadMin { get; init; } = 0.01;
    public double PobrezSpadMax { get; init; } = 0.5;
    /// <summary>Délka (m), na které se rozdíl hladin „projeví“ jako spád u pobřeží.</summary>
    public double PobrezTlakDelkaM { get; init; } = 100.0;
    /// <summary>Porozita, když ji katalog u materiálu nemá.</summary>
    public double PobrezPorovitost { get; init; } = 0.3;
    /// <summary>Strop šířky pásu (m); současně dosah hledání břehu, proto ≤ ~30 m.</summary>
    public double PobrezMaxM { get; init; } = 16.0;
    /// <summary>Hloubka pod povrchem u břehu (m), ve které se hledá nejpropustnější vrstva.</summary>
    public double PobrezOknoM { get; init; } = 2.0;

    public static ParametryVody ZJson(string json) =>
        JsonSerializer.Deserialize<ParametryVody>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
}
