namespace Willage.Gen.Api.Dto;

/// <summary>
/// Sloupec geologie po buňkách 0,25 m odspodu. G-3 review (bod 4): <c>Bunky</c> = 2 B na buňku jako Dev <c>ShellCellPayload</c>
/// (bajt 0 = MaterialId u8, bajt 1 = varianta; varianta je zatím vždy 0, význam řeší jiná vrstva). Vzduch = materiál 0.
/// Vzorkování: vodorovně přesně v bodě <c>Poloha</c> (pro sloupec buňky předej střed buňky, SouradniceQ16.StredBunky = min. roh + 0,125 m);
/// svisle ve středu buňky, z = (i + 0,5) · 0,25 m. PovrchM = double metry nad dnem sloupce.
/// </summary>
public sealed record SloupecDto(SouradniceQ16 Poloha, double PovrchM, byte[] Bunky)
{
    public const int BajtuNaBunku = 2;
    public int Pocet => Bunky.Length / BajtuNaBunku;
    public byte Material(int i) => Bunky[BajtuNaBunku * i];
    public byte Varianta(int i) => Bunky[BajtuNaBunku * i + 1];

    public static byte[] Zabal(ReadOnlySpan<byte> materialy)
    {
        var b = new byte[materialy.Length * BajtuNaBunku];
        for (int i = 0; i < materialy.Length; i++) b[BajtuNaBunku * i] = materialy[i];
        return b;
    }
}

/// <summary>
/// Bod povrchu: výška, materiál povrchu (MaterialId u8, G-3 review bod 5), moře, klima (null bez klimatu).
/// Pozor: klient používá id 57 pro sopečný popel (ParametrySveta.SopkaPopelId) – koliduje s rozsahem id 57–74 v katalogu Dev;
/// zdokumentováno, nepřečíslováno (rozhodne se při sjednocení katalogu).
/// </summary>
public sealed record BodDto(SouradniceQ16 Poloha, double PovrchM, byte MaterialPovrchu, bool More, double? TeplotaC, double? SrazkyMm, string? Biom);

/// <summary>
/// Řez povrchem mezi dvěma body (vzorky po krokM). Jednotky (G-3 review): vodorovné polohy jsou Q16, PovrchM a KrokM jsou
/// double metry (výška nad dnem sloupce 0–128 m, krok vzorku) – převod do Q16 dělá volající (SouradniceQ16.JednotekNaMetr).
/// </summary>
public sealed record RezDto(SouradniceQ16 Od, SouradniceQ16 Do, double KrokM, double[] PovrchM);

public enum VrstvaMapyDto { Vyska, Eroze, Teplota, Srazky, Biom }

/// <summary>
/// Mapa vrstvy na hrubé mřížce planety (nx × ny, řádky po y, hodnoty float): mapa eroze / klimatu po KrokM metrech (dnes 32 m),
/// **ne buňky 0,25 m**. KrokM a hodnoty výšky jsou double/float metry (G-3 review: zdokumentováno, nepřevádí se).
/// </summary>
public sealed record MapaDto(VrstvaMapyDto Vrstva, int Nx, int Ny, double KrokM, float[] Hodnoty);
