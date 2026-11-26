using System;
using System.Threading;
using Godot;
using Willage.Gen.Api;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Fronta;
using Willage.Gen.Data;
using WillagePrototyp.Jadro.Adaptery;

namespace WillagePrototyp.Jadro;

/// <summary>
/// G-4: Godot jádro generátoru (autoload „WillageJadro“). Drží fasádu GeneratorSveta a jednu frontu práce na pozadí.
/// Všechna volání fasády jdou přes frontu (fasáda není vláknově bezpečná); metody vrací id úlohy hned, výsledek přijde signálem
/// na hlavním vlákně (CallDeferred). Logika tu není – jen fronta, převod DTO → Variant / Texture a signály.
/// Fasáda se vytvoří líně v první úloze, takže autoload hru nezdrží.
/// </summary>
[GlobalClass]
public partial class WillageJadro : Node
{
    [Signal] public delegate void ModulHotovEventHandler(string id, string nazev, string stav, double ms);
    [Signal] public delegate void PlanetaHotovaEventHandler(Godot.Collections.Dictionary souhrn);
    [Signal] public delegate void OtiskyHotoveEventHandler(Godot.Collections.Dictionary otisky);
    [Signal] public delegate void MapaHotovaEventHandler(long uloha, int vrstva, ImageTexture textura);
    [Signal] public delegate void ModulySeznamEventHandler(Godot.Collections.Array moduly);
    [Signal] public delegate void ParametryModuluEventHandler(string modul, Godot.Collections.Array parametry);
    [Signal] public delegate void ParametrZmenenEventHandler(string id, bool prijato, string duvod, string[] neplatne);
    [Signal] public delegate void PlanetaInfoEventHandler(Godot.Collections.Dictionary info);
    [Signal] public delegate void PraceSelhalaEventHandler(long uloha, string nazev, string chyba);
    [Signal] public delegate void PraceZrusenaEventHandler(long uloha, string nazev);
    /// <summary>Zástupné: hlídání změn katalogů (okno 2 uloží vzhled → okno 1 se dozví) přijde s oknem 2; dnes se nevysílá.</summary>
    [Signal] public delegate void KatalogZmenenEventHandler(string cesta);

    /// <summary>Složka keše mapy eroze (WGER); res:// a user:// se převedou.</summary>
    [Export] public string KesCesta { get; set; } = "user://kes_eroze";
    [Export] public int Vlaken { get; set; } = 8;
    /// <summary>Kořen dat generátoru.</summary>
    [Export] public string DataCesta { get; set; } = "res://data";

    FrontaPrace? _fronta;
    GeneratorSveta? _gen;   // jen na vlákně fronty
    string _data = "", _kes = "";

    public static WillageJadro? Instance { get; private set; }
    public int Cekajicich => _fronta?.Cekajicich ?? 0;
    public string? Bezi => _fronta?.Bezi;
    public int IdVlaknaFronty => _fronta?.IdVlakna ?? -1;
    /// <summary>Poslední výsledek generace (DTO, jen pro čtení na hlavním vlákně).</summary>
    public VysledekGeneraceDto? PosledniVysledek { get; private set; }

    public override void _EnterTree() => Instance = this;

    public override void _ExitTree()
    {
        _fronta?.Dispose(); _fronta = null;
        if (Instance == this) Instance = null;
    }

    FrontaPrace Fronta()
    {
        if (_fronta is not null) return _fronta;
        _data = ProjectSettings.GlobalizePath(DataCesta); _kes = ProjectSettings.GlobalizePath(KesCesta);
        _fronta = new FrontaPrace(a => Callable.From(a).CallDeferred());
        return _fronta;
    }

    GeneratorSveta Gen() => _gen ??= new GeneratorSveta(new DataSveta(_data), _kes, Vlaken);

    long Zarad<T>(string nazev, Func<CancellationToken, T> prace, Action<T> hotovo) =>
        Fronta().Zarad(nazev, ct => prace(ct), (id, konec, v, e) =>
        {
            switch (konec)
            {
                case KonecUlohy.Hotovo: hotovo((T)v!); break;
                case KonecUlohy.Zruseno: EmitSignal(SignalName.PraceZrusena, id, nazev); break;
                default: GD.PushWarning($"WillageJadro: {nazev} selhalo: {e?.GetType().Name}: {e?.Message}"); EmitSignal(SignalName.PraceSelhala, id, nazev, e?.Message ?? "?"); break;
            }
        });

    sealed class PrubehModulu : IProgress<ModulDto>
    {
        readonly WillageJadro _j; readonly FrontaPrace _f;
        public PrubehModulu(WillageJadro j, FrontaPrace f) { _j = j; _f = f; }
        public void Report(ModulDto m) => _f.Dorucit(() => _j.EmitSignal(SignalName.ModulHotov, m.Id, m.Nazev, m.Stav.ToString(), m.Ms));
    }

    /// <summary>Vygeneruje planetu (přepočte neplatné moduly). Signály: ModulHotov po modulech, PlanetaHotova.</summary>
    public long Generuj()
    {
        var f = Fronta(); var pr = new PrubehModulu(this, f);
        return Zarad("Generuj", ct => Gen().Sluzba.Generuj(pr, ct), r => { PosledniVysledek = r; EmitSignal(SignalName.PlanetaHotova, DtoNaVariant.Slovnik(r.Souhrn)); });
    }

    public long Otisky(int bx = 14, int by = 14) =>
        Zarad("Otisky", _ => Gen().Sluzba.Otisky(bx, by), o => EmitSignal(SignalName.OtiskyHotove, DtoNaVariant.Slovnik(o)));

    /// <summary>Mapa vrstvy (VrstvaMapyDto jako int) zmenšená f×; textura se vytvoří na hlavním vlákně.</summary>
    public long Mapa(int vrstva, int zmenseni = 1)
    {
        long id = 0;
        id = Zarad("Mapa", _ => Willage.Gen.Api.Vizual.BarvyVrstev.Zmensi(Gen().Dotazy.Mapa((VrstvaMapyDto)vrstva), zmenseni),
            m => EmitSignal(SignalName.MapaHotova, id, vrstva, TexturaMapy.Textura(m)));
        return id;
    }

    public long Moduly() => Zarad("Moduly", _ => Gen().Moduly.Seznam(), m => EmitSignal(SignalName.ModulySeznam, DtoNaVariant.Pole(m)));

    public long Parametry(string modul) => Zarad("Parametry", _ => Gen().Moduly.Parametry(modul), p => EmitSignal(SignalName.ParametryModulu, modul, DtoNaVariant.Pole(p)));

    public long Nastav(string idParametru, string hodnotaJson) =>
        Zarad("Nastav", _ => Gen().Moduly.Nastav(idParametru, hodnotaJson),
            z => EmitSignal(SignalName.ParametrZmenen, idParametru, z.Prijato, z.Duvod ?? "", System.Linq.Enumerable.ToArray(z.Neplatne)));

    public long Uloz(string cesta) { string c = ProjectSettings.GlobalizePath(cesta); return Zarad("Uloz", _ => Gen().Sluzba.Uloz(c), Info); }
    public long Nacti(string cesta) { string c = ProjectSettings.GlobalizePath(cesta); return Zarad("Nacti", _ => Gen().Sluzba.Nacti(c), Info); }
    public long Potvrd() => Zarad("Potvrd", _ => Gen().Sluzba.PotvrdPlanetu(), Info);

    void Info(PlanetaInfoDto i) => EmitSignal(SignalName.PlanetaInfo, DtoNaVariant.Slovnik(i));

    /// <summary>Zruší běžící i čekající úlohy (běžící generace skončí před dalším modulem).</summary>
    public void Zrus() => _fronta?.ZrusVse();
}
