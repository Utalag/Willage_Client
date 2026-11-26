using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Rozhrani;
using Willage.Materialy.Api.Sluzby;

namespace Willage.Materialy.Api;

/// <summary>
/// T-1: kořen fasády editoru materiálů nad kořenem dat (godot-prototyp/data): katalog vzhledu (zrcadlo Dev, jen čtení),
/// schéma operací VPMG, pin Dev a zdroj textur (VPMG Dev mimo proces). Nic nemění v datech světa ani v katalogu.
/// </summary>
public sealed class MaterialyApi : IDisposable
{
    public string KorenDat { get; }
    public KatalogVzhledu Katalog { get; }
    public SchemaOperaciVpmg Schema { get; }
    public PinDevDto Pin { get; }
    public IZdrojVpmg Zdroj { get; }
    /// <summary>Vzorek materiálů, se kterými editor pracuje (ostatní zástupné).</summary>
    public VzorekMaterialu Vzorek { get; }

    public MaterialyApi(string korenDat, IZdrojVpmg? zdroj = null)
    {
        KorenDat = Path.GetFullPath(korenDat);
        Pin = PinDev.Nacti(KorenDat);
        Katalog = new KatalogVzhledu(Path.Combine(KorenDat, Pin.ZrcadloCesta));
        Vzorek = new VzorekMaterialu(Path.Combine(KorenDat, "vpmg", "vzorek_materialu_v0.json"), Katalog);
        Schema = new SchemaOperaciVpmg(Path.Combine(KorenDat, "vpmg", "operace_vpmg_v0.json"));
        Zdroj = zdroj ?? new ZdrojVpmgProces(Katalog.Cesta);
    }

    /// <summary>Receptura materiálu: zatím výchozí (VpmgPreview); naše uložené receptury přibudou v T-4 (zástupné).</summary>
    public RecepturaVpmgDto Receptura(byte material) => RecepturyVpmg.Vychozi(material, Schema.RozliseniVychozi);

    public void Dispose() => Zdroj.Dispose();
}
