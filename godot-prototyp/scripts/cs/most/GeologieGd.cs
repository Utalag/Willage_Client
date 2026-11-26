using System;
using System.Diagnostics;
using Godot;
using Willage.Gen.Geologie;

namespace WillagePrototyp.Most;

/// <summary>
/// Most C# → GDScript funkce světa kroků 1–3 (svet_fn.gd, geo_vrstvy.gd). Jediné místo, které zná GDScript;
/// po portu geologie do C# se nahradí implementací IGeologie bez Godotu. Měří čas strávený v GDScriptu.
/// </summary>
public sealed class GeologieGd : IGeologie
{
    private readonly GodotObject _svet;
    private readonly GodotObject _geo;
    private readonly Stopwatch _sw = new();
    public long VolaniPovrch, VolaniSloupec, VolaniBod;
    public double MsVGdscriptu => _sw.Elapsed.TotalMilliseconds;

    public GeologieGd(int seed)
    {
        var skript = GD.Load<GDScript>("res://scripts/v1/svet_fn.gd");
        var par = new Godot.Collections.Dictionary { { "seed", seed } };
        _svet = skript.New(par).AsGodotObject();
        _geo = _svet.Get("geo").AsGodotObject();
    }

    public double Povrch(double x, double y) { VolaniPovrch++; _sw.Start(); var v = _svet.Call("vyska", x, y).AsDouble(); _sw.Stop(); return v; }

    public byte[] Sloupec(double x, double y)
    {
        VolaniSloupec++; _sw.Start();
        var a = _geo.Call("vypln_sloupec", x, y, 0.25, 128.0).AsByteArray();
        _sw.Stop(); return a;
    }

    public int MaterialPovrchu(double x, double y)
    {
        VolaniBod++; _sw.Start();
        double p = _svet.Call("vyska", x, y).AsDouble();
        int m = _svet.Call("bod", x, y, Math.Floor((p - 1e-9) / 0.25) * 0.25 + 0.125).AsInt32();
        _sw.Stop(); return m;
    }

    public double VyskaTvar(double x, double y) => _svet.Call("vyska_tvar", x, y).AsDouble();
    public bool Mince82(double x, double y) => _geo.Call("mince82", x, y).AsBool();
}
