using Willage.Gen.Geologie;

namespace Willage.Gen.Geo2.E84;

/// <summary>
/// Průniky přímky s tělesy E84 (K4, 2.8) odvozené přímo z <see cref="Utvary.Sdf"/>:
/// <list type="bullet">
/// <item>čočka, dóm, komín (větev elipsoidu, SDF &lt; 0 ⇔ Σ((q·e_i)/r_i)² &lt; 1): přesná tětiva, V = O.</item>
/// <item>žíla: SDF &lt; 0 ⇒ a² + b² &lt; 1 ∧ |s| &lt; t₀ + amp (|šum| ≤ 1): O = eliptický válec ∩ deska, V = ∅.</item>
/// <item>kras (Fast): SDF &lt; 0 ⇒ KrasD ≤ 2,165·A ⇒ kapsle s poloměrem max(r₀, r₁) + δ nebo komora s osami (1 + δ/r_min)·r, δ = 2,165·A; V = ∅.
///   Bez Fast: celá obálka.</item>
/// </list>
/// </summary>
public static class PrimkaE84
{
    /// <summary>Druh se SDF bez šumu (elipsoid): tětiva je přesná.</summary>
    public static bool JeElipsoid(DruhUtvaru d) => d is DruhUtvaru.Cocka or DruhUtvaru.Dome or DruhUtvaru.Pipe;

    /// <summary>Přesná tětiva elipsoidu (pro čočku, dóm, komín).</summary>
    public static bool Tetiva(Utvar f, in Primka p, double zvetseni, out double t0, out double t1)
    {
        var P = f.P;
        return PrunikyPrimky.Elipsoid(p, P[0], P[1], P[2], P.AsSpan(3, 9), P[12] + zvetseni, P[13] + zvetseni, P[14] + zvetseni, 1, out t0, out t1);
    }

    /// <summary>Nejisté intervaly O šumového tělesa (žíla, kras) na přímce; přidá do <paramref name="cil"/> (může se překrývat).</summary>
    public static void Nejiste(Utvar f, in Primka p, bool fast, List<(double A, double B)> cil)
    {
        var P = f.P;
        switch (f.K)
        {
            case DruhUtvaru.Zila:
                if (PrunikyPrimky.Valec(p, P[0], P[1], P[2], P[6], P[7], P[8], P[13], P[9], P[10], P[11], P[14], out var c0, out var c1)
                    && PrunikyPrimky.Deska(p, P[0], P[1], P[2], P[3], P[4], P[5], P[12] + P[15], out var d0, out var d1)
                    && PrunikyPrimky.Prunik(c0, c1, d0, d1, out var a, out var b)) cil.Add((a, b));
                return;
            case DruhUtvaru.Kras when fast:
            {
                double dl = 2.165 * P[27];
                for (int i = 0; i < 5; i++)
                {
                    int o = i * 4;
                    if (PrunikyPrimky.Kapsle(p, P[o], P[o + 1], P[o + 2], P[o + 4], P[o + 5], P[o + 6], Math.Max(P[o + 3], P[o + 7]) + dl, out var k0, out var k1))
                        cil.Add((k0, k1));
                }
                double rmin = Math.Min(P[24], Math.Min(P[25], P[26])), sk = 1 + dl / rmin;
                ReadOnlySpan<double> osy = stackalloc double[] { 1, 0, 0, 0, 1, 0, 0, 0, 1 };
                if (PrunikyPrimky.Elipsoid(p, P[8], P[9], P[10], osy, P[24], P[25], P[26], sk, out var e0, out var e1)) cil.Add((e0, e1));
                return;
            }
            default:
                cil.Add((double.NegativeInfinity, double.PositiveInfinity)); // bez analytické závorky: celé (ořízne obálka)
                return;
        }
    }
}
