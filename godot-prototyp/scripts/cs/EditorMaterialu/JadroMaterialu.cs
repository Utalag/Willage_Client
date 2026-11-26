using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Willage.Gen.Api.Fronta;
using Willage.Materialy.Api;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Editor;
using Willage.Materialy.Api.Rozhrani;
using Willage.Materialy.Api.Sluzby;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: jádro okna Editor materiálů – fasáda <see cref="MaterialyApi"/> (katalog vzhledu, schéma, VPMG Dev mimo proces), stav editoru
/// a fronta práce G-4 (<see cref="FrontaPrace"/>, znovu použitá) pro VPMG na pozadí. Výsledek na cíl („hlavni“, „var0“…) doručí
/// signálem <see cref="SignalName.TexturaHotova"/> na hlavním vlákně; zastaralé výsledky (novější požadavek na stejný cíl) zahodí.
/// Nezávislé na jádru generátoru světa (samostatné okno, Jan 15:58).
/// </summary>
[GlobalClass]
public partial class JadroMaterialu : Node
{
    [Signal] public delegate void TexturaHotovaEventHandler(string cil);
    [Signal] public delegate void KontrolaHotovaEventHandler();

    /// <summary>Kořen dat (godot-prototyp/data).</summary>
    [Export] public string KorenDat { get; set; } = "res://data";
    /// <summary>Bez nástroje VPMG (zkouška zástupného stavu); také volba příkazové řádky --bez-vpmg.</summary>
    [Export] public bool BezVpmg { get; set; }

    public MaterialyApi Api { get; private set; } = null!;
    public StavEditoru Stav { get; private set; } = null!;
    public InfoVpmgDto? Info { get; private set; }
    public (uint Ocekavany, uint Spocteny)? GoldenVysledek { get; private set; }
    public KontrolaZrcadlaDto? Zrcadlo { get; private set; }
    public readonly Dictionary<string, TexturaVpmgDto> Posledni = new();
    public int Hotovych { get; private set; }
    public int Zahozenych { get; private set; }
    public int Cekajicich => _fronta?.Cekajicich ?? 0;

    sealed record Kontrola(InfoVpmgDto Info, (uint Ocekavany, uint Spocteny)? Golden, KontrolaZrcadlaDto? Zrcadlo);
    FrontaPrace? _fronta;
    readonly Dictionary<string, long> _generace = new();

    public void Spust()
    {
        if (Api != null) return;
        bool bez = BezVpmg || OS.GetCmdlineUserArgs().Contains("--bez-vpmg");
        string koren = ProjectSettings.GlobalizePath(KorenDat);
        var pin = PinDev.Nacti(koren);
        IZdrojVpmg? zdroj = bez ? new ZdrojVpmgProces(System.IO.Path.Combine(koren, pin.ZrcadloCesta), "/neexistuje/Willage.Vpmg.Nastroj.dll") : null;
        Api = new MaterialyApi(koren, zdroj);
        Stav = new StavEditoru(Api.Katalog, Api.Schema, Api.Vzorek);
        _fronta = new FrontaPrace(a => Callable.From(a).CallDeferred(), "JadroMaterialu");
        // kontrola na pozadí: info nástroje, golden Dev, zrcadlo = Dev
        _fronta.Zarad("kontrola", _ =>
        {
            var i = Api.Zdroj.Info();
            return i.Dostupny ? new Kontrola(i, Api.Zdroj.Golden(), Api.Zdroj.KontrolaZrcadla(Api.Katalog.Cesta)) : new Kontrola(i, null, null);
        }, (_, k, v, e) =>
        {
            if (v is Kontrola t) { Info = t.Info; GoldenVysledek = t.Golden; Zrcadlo = t.Zrcadlo; }
            else Info = new InfoVpmgDto(false, "zástupné: kontrola selhala – " + e?.Message, "", "", 0, Array.Empty<string>(), "");
            EmitSignal(SignalName.KontrolaHotova);
        });
    }

    /// <summary>Zařadí VPMG pro cíl; starší nedokončený požadavek na stejný cíl se po doběhnutí zahodí.</summary>
    public void Pozadej(string cil, RecepturaVpmgDto r, uint seed, NavrhProfiluDto? navrh)
    {
        long g = _generace[cil] = (_generace.TryGetValue(cil, out var x) ? x : 0) + 1;
        _fronta!.Zarad("vpmg " + cil, _ => Api.Zdroj.Spust(r, seed, navrh), (_, k, v, e) =>
        {
            if (_generace[cil] != g) { Zahozenych++; return; }
            Posledni[cil] = v as TexturaVpmgDto ?? new TexturaVpmgDto(false, e?.Message ?? k.ToString(), r.Resolution, r.Resolution, "", 0, Array.Empty<byte>(), 0, 0);
            Hotovych++;
            EmitSignal(SignalName.TexturaHotova, cil);
        });
    }

    public override void _ExitTree()
    {
        _fronta?.Dispose();
        Api?.Dispose();
    }
}
