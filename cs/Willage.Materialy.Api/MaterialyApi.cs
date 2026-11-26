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
    /// <summary>T-2b: výchozí receptury (data/vpmg/receptury, kopie receptur v1 z Dev).</summary>
    public KnihovnaReceptur Receptury { get; }

    public MaterialyApi(string korenDat, IZdrojVpmg? zdroj = null)
    {
        KorenDat = Path.GetFullPath(korenDat);
        Pin = PinDev.Nacti(KorenDat);
        Katalog = new KatalogVzhledu(Path.Combine(KorenDat, Pin.ZrcadloCesta));
        Vzorek = new VzorekMaterialu(Path.Combine(KorenDat, "vpmg", "vzorek_materialu_v0.json"), Katalog);
        Schema = new SchemaOperaciVpmg(Path.Combine(KorenDat, "vpmg", "operace_vpmg_v1.json"), Path.Combine(KorenDat, "vpmg", "operace_dev_v1.json"));
        Receptury = new KnihovnaReceptur(Path.Combine(KorenDat, "vpmg", "receptury"));
        Zdroj = zdroj ?? new ZdrojVpmgProces(Katalog.Cesta);
    }

    /// <summary>Receptura materiálu: v1 z knihovny (vzorek), jinak v0; ukládání vlastních receptur až T-4 (zástupné).</summary>
    public RecepturaVpmgDto Receptura(byte material) => Receptury.Vychozi(material);

    public void Dispose() => Zdroj.Dispose();
}
