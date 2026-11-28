using Willage.Gen.Geologie;

namespace Willage.Gen.Testy.V8;

/// <summary>
/// Měření kvality skarnu jednoho systému proti kontraktu 2.5 / V3 nezávisle na druhém systému: tloušťka pásma po normále
/// ∈ [w₀(1−a) − e_k, w₀(1+a) + e_k] a skarn jen v karbonátech (O1). Počítáno ve sloupcích, kde je skarn aspoň v jednom systému.
/// </summary>
public sealed class V8Kvalita
{
    public long SkarnBunek, SkarnVNekarbonatu, SkarnTlustsi, Diry, KarbonatuVPasmu, Odhad;

    public void Bunka(bool skarn, bool karbonat, bool beztelesa, double d, bool odhad)
    {
        const double lo = PodkladyKlasifikace.W0 * (1 - PodkladyKlasifikace.A) - PodkladyKlasifikace.Ek, hi = PodkladyKlasifikace.W0 * (1 + PodkladyKlasifikace.A) + PodkladyKlasifikace.Ek;
        if (skarn)
        {
            SkarnBunek++;
            if (!karbonat) { SkarnVNekarbonatu++; return; }
            if (odhad) { Odhad++; return; }
            if (d > hi) SkarnTlustsi++;
        }
        else if (karbonat && beztelesa && d < lo)
        {
            if (odhad) Odhad++; else Diry++;
        }
        if (karbonat && d <= hi && d >= lo) KarbonatuVPasmu++;
    }

    public void Slouc(V8Kvalita o) { SkarnBunek += o.SkarnBunek; SkarnVNekarbonatu += o.SkarnVNekarbonatu; SkarnTlustsi += o.SkarnTlustsi; Diry += o.Diry; KarbonatuVPasmu += o.KarbonatuVPasmu; Odhad += o.Odhad; }
}
