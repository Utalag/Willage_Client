using Willage.Gen.Api.Dto;

namespace Willage.Gen.Api.Sluzby;

/// <summary>Zástupné (C, okno 2): vizuální data – prázdné, dokud nevznikne vizuální jádro (plán 05, část C).</summary>
public sealed class ZastupnaVizualniData : IVizualniData
{
    public IReadOnlyList<GrafickyBlokDto> BlokyOkna(OblastQ16 oblast) => Array.Empty<GrafickyBlokDto>();
    public IReadOnlyList<string> VariantyModelu() => new[] { "plochý blok", "okraj ostrova", "svah", "vykopaná jáma", "přechod", "pod vodou" };
}

/// <summary>Zástupné (U-1, fáze 3): úpravy s regiony se zatím neukládají.</summary>
public sealed class ZastupneUpravyRegionu : IUpravyRegionu
{
    public IReadOnlyList<UpravaRegionuDto> Seznam() => Array.Empty<UpravaRegionuDto>();
    public ZastupnyVysledekDto Pridej(UpravaRegionuDto u) => new(true, "zástupné (U-1): úpravy s regiony přijdou ve fázi 3, nic se neuložilo");
}
