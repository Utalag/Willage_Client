using System;
using System.Linq;
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
    /// <summary>G-6: náhled vrstvy modulu M1–M3 hotový (DTO v PosledniNahled).</summary>
    [Signal] public delegate void NahledModuluHotovEventHandler(long uloha, string modul, int vrstva, ImageTexture textura);
    /// <summary>G-6: řez modulu hotový (DTO v PosledniRez, obraz řezu M3 v PosledniRezTextura, jinak null).</summary>
    [Signal] public delegate void RezModuluHotovEventHandler(long uloha, string modul, int rezim);
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
    volatile bool _ukonceno;

    public static WillageJadro? Instance { get; private set; }
    public int Cekajicich => _fronta?.Cekajicich ?? 0;
    public string? Bezi => _fronta?.Bezi;
    public int IdVlaknaFronty => _fronta?.IdVlakna ?? -1;
    /// <summary>Poslední výsledek generace (DTO, jen pro čtení na hlavním vlákně).</summary>
    public VysledekGeneraceDto? PosledniVysledek { get; private set; }

    public override void _EnterTree() => Instance = this;

    public override void _ExitTree()
    {
        _ukonceno = true;   // G-5: doručení po ukončení (zrušené úlohy při zavření okna) se zahodí – uzel už je uvolněný
        _fronta?.Dispose(); _fronta = null;
        if (Instance == this) Instance = null;
    }

    FrontaPrace Fronta()
    {
        if (_fronta is not null) return _fronta;
        _data = ProjectSettings.GlobalizePath(DataCesta); _kes = ProjectSettings.GlobalizePath(KesCesta);
        _fronta = new FrontaPrace(a => Callable.From(() => { if (!_ukonceno && IsInstanceValid(this)) a(); }).CallDeferred());
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
        return Zarad("Generuj", ct => Gen().Sluzba.Generuj(pr, ct), r => { PosledniVysledek = r; PosledniModuly = r.Moduly; EmitSignal(SignalName.PlanetaHotova, DtoNaVariant.Slovnik(r.Souhrn)); });
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

    /// <summary>G-5: poslední seznam modulů a parametry modulů jako DTO (pro C# uzly okna; signály nesou totéž jako Variant).</summary>
    public System.Collections.Generic.IReadOnlyList<ModulDto> PosledniModuly { get; private set; } = Array.Empty<ModulDto>();
    readonly System.Collections.Generic.Dictionary<string, System.Collections.Generic.IReadOnlyList<ParametrDto>> _parametry = new();
    public System.Collections.Generic.IReadOnlyList<ParametrDto> ParametryDto(string modul) => _parametry.TryGetValue(modul, out var p) ? p : Array.Empty<ParametrDto>();
    /// <summary>G-5: poslední info o planetě (seed, gen_ver, potvrzení, otisk).</summary>
    public PlanetaInfoDto? PosledniInfo { get; private set; }

    public long Moduly() => Zarad("Moduly", _ => Gen().Moduly.Seznam(), m => { PosledniModuly = m; EmitSignal(SignalName.ModulySeznam, DtoNaVariant.Pole(m)); });

    public long Parametry(string modul) => Zarad("Parametry", _ => Gen().Moduly.Parametry(modul), p => { _parametry[modul] = p; EmitSignal(SignalName.ParametryModulu, modul, DtoNaVariant.Pole(p)); });

    /// <summary>G-5: všechny parametry na výchozí hodnoty (data/v1). Signál ParametrZmenen s id „*“.</summary>
    public long Vychozi() => Zarad("Vychozi", _ => Gen().Moduly.Vychozi(),
        z => EmitSignal(SignalName.ParametrZmenen, "*", z.Prijato, z.Duvod ?? "", System.Linq.Enumerable.ToArray(z.Neplatne)));

    /// <summary>G-5: info o planetě bez změny (signál PlanetaInfo).</summary>
    public long InfoPlanety() => Zarad("Info", _ => Gen().Sluzba.Info(), Info);

    /// <summary>Nastaví parametr; po přijetí obnoví v keši parametry jeho modulu (ParametryDto), pak vyšle ParametrZmenen.</summary>
    public long Nastav(string idParametru, string hodnotaJson) =>
        Zarad("Nastav", _ =>
        {
            var z = Gen().Moduly.Nastav(idParametru, hodnotaJson);
            string modul = Gen().Moduly.Seznam().Select(m => m.Id).FirstOrDefault(m => Gen().Moduly.Parametry(m).Any(p => p.Id == idParametru)) ?? "";
            return (z, modul, modul == "" ? null : Gen().Moduly.Parametry(modul));
        }, r =>
        {
            if (r.Item3 is not null) _parametry[r.modul] = r.Item3;
            EmitSignal(SignalName.ParametrZmenen, idParametru, r.z.Prijato, r.z.Duvod ?? "", r.z.Neplatne.ToArray());
        });

    /// <summary>G-5: parametry modulu na výchozí hodnoty (na vlákně fronty z aktuální sady). Signál ParametrZmenen s id „modul:*“, pak ParametryModulu.</summary>
    public long VychoziModulu(string modul) =>
        Zarad("VychoziModulu", _ => (Gen().Moduly.VychoziModulu(modul), Gen().Moduly.Parametry(modul)), r =>
        {
            _parametry[modul] = r.Item2;
            EmitSignal(SignalName.ParametrZmenen, modul + ":*", r.Item1.Prijato, r.Item1.Duvod ?? "", r.Item1.Neplatne.ToArray());
            EmitSignal(SignalName.ParametryModulu, modul, DtoNaVariant.Pole(r.Item2));
        });

    public long Uloz(string cesta) { string c = ProjectSettings.GlobalizePath(cesta); return Zarad("Uloz", _ => Gen().Sluzba.Uloz(c), Info); }
    public long Nacti(string cesta) { string c = ProjectSettings.GlobalizePath(cesta); return Zarad("Nacti", _ => Gen().Sluzba.Nacti(c), Info); }
    public long Potvrd() => Zarad("Potvrd", _ => Gen().Sluzba.PotvrdPlanetu(), Info);

    void Info(PlanetaInfoDto i) { PosledniInfo = i; EmitSignal(SignalName.PlanetaInfo, DtoNaVariant.Slovnik(i)); }

    // ---- G-6: náhledy M1–M3 ----
    public NahledMapyDto? PosledniNahled { get; private set; }
    public RezModuluDto? PosledniRez { get; private set; }
    public ImageTexture? PosledniRezTextura { get; private set; }
    /// <summary>Materiály (id, název, barva) – naplní se s prvním náhledem nebo řezem.</summary>
    public System.Collections.Generic.IReadOnlyList<MaterialDto> MaterialyDto { get; private set; } = Array.Empty<MaterialDto>();

    /// <summary>Mapa vrstvy modulu (VrstvaNahleduDto jako int); barvy se spočtou na vlákně fronty, textura na hlavním.</summary>
    public long NahledModulu(string modul, int vrstva, int rozliseni = 256)
    {
        long id = 0;
        id = Zarad("Nahled", _ =>
        {
            var n = Gen().Nahledy.Mapa(modul, (VrstvaNahleduDto)vrstva, rozliseni); var mat = Gen().Nahledy.Materialy();
            return (n, mat, Willage.Gen.Api.Vizual.BarvyNahledu.Rgba(n, mat));
        }, r =>
        {
            PosledniNahled = r.n; MaterialyDto = r.mat;
            EmitSignal(SignalName.NahledModuluHotov, id, modul, vrstva, TexturaMapy.ZRgba(r.n.Nx, r.n.Ny, r.Item3));
        });
        return id;
    }

    /// <summary>Řez modulu úsečkou v metrech (na hranici fasády převod do Q16), krok v metrech, režim RezimRezuDto jako int.</summary>
    public long RezModulu(string modul, Vector2 odM, Vector2 doM, double krokM, int rezim = 0)
    {
        long id = 0;
        id = Zarad("Rez", _ =>
        {
            var r = Gen().Nahledy.Rez(modul, SouradniceQ16.ZMetru(odM.X, odM.Y), SouradniceQ16.ZMetru(doM.X, doM.Y), krokM, (RezimRezuDto)rezim);
            var mat = Gen().Nahledy.Materialy();
            return (r, mat, Willage.Gen.Api.Vizual.BarvyNahledu.RgbaRezu(r, mat));
        }, r =>
        {
            PosledniRez = r.r; MaterialyDto = r.mat;
            PosledniRezTextura = r.r.Nz > 0 ? TexturaMapy.ZRgba(r.r.Nx, r.r.Nz, r.Item3) : null;
            EmitSignal(SignalName.RezModuluHotov, id, modul, rezim);
        });
        return id;
    }

    /// <summary>Zruší běžící i čekající úlohy (běžící generace skončí před dalším modulem).</summary>
    public void Zrus() => _fronta?.ZrusVse();
}
