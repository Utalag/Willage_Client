using System;
using System.Collections.Generic;
using Godot;
using Willage.Gen.Materialy;
using Willage.Gen.Voda;

namespace WillagePrototyp.Most;

/// <summary>
/// Fasáda kroku 4 pro GDScript hru a nástroje: load("res://scripts/cs/most/VodaV1.cs").new() → nastav(seed) → hladina(x, y), prameny_bloku(bx, by).
/// Drží jen PodzemniVodaFn; žádná logika vody tady není.
/// </summary>
[GlobalClass]
public partial class VodaV1 : RefCounted
{
    public PodzemniVodaFn? Fn { get; private set; }
    public GeologieGd? Geo { get; private set; }

    public static PodzemniVodaFn Vytvor(GeologieGd geo, ParametryVody? p = null)
    {
        var kat = KatalogMaterialu.ZeSouboru(ProjectSettings.GlobalizePath("res://data/v1/materials-catalog-v1.json"));
        p ??= ParametryVody.ZJson(Godot.FileAccess.GetFileAsString("res://data/v1/voda_v1.json"));
        return new PodzemniVodaFn(geo, kat, p);
    }

    public void Nastav(int seed)
    {
        Geo = new GeologieGd(seed);
        var p = ParametryVody.ZJson(Godot.FileAccess.GetFileAsString("res://data/v1/voda_v1.json")) with { Seed = (uint)seed };
        Fn = Vytvor(Geo, p);
    }

    public double Hladina(double x, double y) => Fn!.Hladina.Hladina(x, y);

    public Godot.Collections.Array<Godot.Collections.Dictionary> PramenyBloku(int bx, int by)
    {
        var a = new Godot.Collections.Array<Godot.Collections.Dictionary>();
        foreach (var s in Fn!.Prameny.VOblasti(bx * 128.0, by * 128.0, bx * 128.0 + 128, by * 128.0 + 128))
            a.Add(new Godot.Collections.Dictionary { { "x", s.X }, { "y", s.Y }, { "z", s.Z }, { "druh", s.Druh.ToString() },
                { "jmenovity_l_s", s.Jmenovity }, { "vykon_l_s", Fn.Vykon(s).Vykon } });
        return a;
    }
}
