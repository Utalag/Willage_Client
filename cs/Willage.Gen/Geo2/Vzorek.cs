using System.Runtime.InteropServices;

namespace Willage.Gen.Geo2;

/// <summary>
/// Vzorek 3.1: kompaktní výstup GEO2 v bodě (nic dalšího se neukládá). 0xFFFF = žádná událost / transformace;
/// <c>HostitelPuvodu</c>: 0 = těleso vniklo do dutiny, 0xFFFF = u Uloz žádný. Id materiálů a událostí musí být &lt; 0xFFFF.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public readonly record struct Vzorek(
    ushort Material, TypProstoru Typ,
    ushort GeoUdalost, uint GeoInstance, short Vrstva, ushort MaterialPuvodu,
    ushort HostitelPuvodu, TypProstoru TypHostitele,
    ushort PosledniTransformace, byte PocetTransformaci, PriznakyVzorku Priznaky)
{
    public const ushort Zadna = 0xFFFF;
    public static readonly int Velikost = Marshal.SizeOf<Vzorek>();

    private static ushort U(int v) => v < 0 ? Zadna : v >= Zadna ? throw new OverflowException($"id {v} ≥ 0xFFFF") : (ushort)v;
    private static int I(ushort v) => v == Zadna ? -1 : v;

    public static Vzorek Z(in StavBodu s) => new(
        U(s.Material), s.Typ, U(s.GeoUdalost), s.GeoInstance, s.Vrstva, U(s.MaterialPuvodu),
        U(s.HostitelPuvodu), s.TypHostitele, U(s.PosledniTransformace), s.PocetTransformaci, s.Priznaky);

    /// <summary>Zpět na pracovní stav; druh operace geometrického původu doplní chronologie.</summary>
    public StavBodu NaStav(Operace geoOperace) => new(
        Material, Typ, I(GeoUdalost), geoOperace, GeoInstance, Vrstva, MaterialPuvodu,
        I(PosledniTransformace), PocetTransformaci, I(HostitelPuvodu), TypHostitele, Priznaky);

    public bool JePevne => Typ == TypProstoru.Pevne;
    /// <summary>Volný prostor pod povrchem: dutina nebo výkop (voda ho může zaplnit). Vzduch nad povrchem sem nepatří.</summary>
    public bool JeVolnyProstor => Typ is TypProstoru.DutinaKras or TypProstoru.DutinaJina or TypProstoru.Vykopano;
}
