using System.Collections.Generic;
using Godot;
using Willage.Materialy.Api.Dto;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: okno 2 – Editor materiálů / generátor textur terénu (samostatná scéna, ne součást generátoru světa). Kořen jen propojuje uzly:
/// <see cref="JadroMaterialu"/>, <see cref="HorniListaMaterialu"/>, <see cref="SeznamMaterialu"/>, <see cref="ProfilVzhledu"/>,
/// <see cref="FyzikaJenCteni"/>, <see cref="KonfiguratorReceptury"/>, <see cref="NahledTexturyVpmg"/>, <see cref="VariaceSeedu"/>;
/// zástupné: přednastavení, vrstvy a řez, mřížka variant modelů (T-3). Mění jen vzhled v náhledu – nikdy ID materiálu ani fyziku.
/// Spuštění: Godot_mono --path godot-prototyp res://nastroje/EditorMaterialu.tscn [-- --bez-vpmg]
/// </summary>
[GlobalClass]
public partial class EditorMaterialuOkno : Control
{
    public JadroMaterialu Jadro { get; private set; } = null!;
    public HorniListaMaterialu Lista { get; private set; } = null!;
    public SeznamMaterialu Seznam { get; private set; } = null!;
    public ProfilVzhledu Profil { get; private set; } = null!;
    public FyzikaJenCteni Fyzika { get; private set; } = null!;
    public KonfiguratorReceptury Konfigurator { get; private set; } = null!;
    public NahledTexturyVpmg Nahled { get; private set; } = null!;
    public OptionButton Dlazdice { get; private set; } = null!;
    public Label InfoNahledu { get; private set; } = null!;
    public Label Titulek { get; private set; } = null!;
    public VariaceSeedu Variace { get; private set; } = null!;
    readonly HashSet<string> _zmeny = new();
    bool _obnovaNaplanovana;
    IReadOnlyList<uint> _seedyVariaci = new List<uint>();

    public override void _Ready()
    {
        Jadro = GetNode<JadroMaterialu>("Jadro");
        Lista = GetNode<HorniListaMaterialu>("Svislo/HorniLista");
        Seznam = GetNode<SeznamMaterialu>("Svislo/Telo/SeznamMaterialu");
        Profil = GetNode<ProfilVzhledu>("Svislo/Telo/Stred/Obsah/ProfilVzhledu");
        Konfigurator = GetNode<KonfiguratorReceptury>("Svislo/Telo/Stred/Obsah/KonfiguratorReceptury");
        Fyzika = GetNode<FyzikaJenCteni>("Svislo/Telo/Stred/Obsah/FyzikaJenCteni");
        Titulek = GetNode<Label>("Svislo/Telo/Prava/Titulek");
        Nahled = GetNode<NahledTexturyVpmg>("Svislo/Telo/Prava/NahledRadek/Nahled");
        Dlazdice = GetNode<OptionButton>("Svislo/Telo/Prava/NahledRadek/Boky/Dlazdice");
        InfoNahledu = GetNode<Label>("Svislo/Telo/Prava/NahledRadek/Boky/InfoNahledu");
        Variace = GetNode<VariaceSeedu>("Svislo/Telo/Prava/VariaceSeedu");

        Jadro.Spust();
        var st = Jadro.Stav;
        Lista.NastavPin(Jadro.Api.Pin);
        Lista.NastavKontrolu(null, null, null);
        Seznam.Napln(Jadro.Api.Katalog, Jadro.Api.Vzorek);
        Profil.Pripoj(st, Jadro.Api.Schema);
        Konfigurator.Pripoj(st, Jadro.Api.Schema);
        for (int i = 1; i <= 3; i++) Dlazdice.AddItem($"dlaždice {i}×{i}");
        Dlazdice.Select(1); Nahled.Dlazdice = 2;
        Dlazdice.ItemSelected += i => { Nahled.Dlazdice = (int)i + 1; if (Nahled.Posledni is { } t) Nahled.Zobraz(t); };

        Seznam.MaterialVybran += id =>
        {
            if (st.VyberMaterial((byte)id) is { } ch) { Seznam.Oznac(st.Material); Titulek.Text = ch; Titulek.Modulate = new Color(1, 0.75f, 0.75f); }
        };
        Lista.Validovat += () => Konfigurator.ObnovValidaci();
        Jadro.KontrolaHotova += () => Lista.NastavKontrolu(Jadro.Info, Jadro.GoldenVysledek, Jadro.Zrcadlo);
        Jadro.TexturaHotova += PrijmiTexturu;
        st.Zmeneno += co => { _zmeny.Add(co); if (!_obnovaNaplanovana) { _obnovaNaplanovana = true; CallDeferred(MethodName.Obnov); } };

        _zmeny.Add("material");
        Obnov();
    }

    /// <summary>Obnoví uzly podle druhu změny a pošle požadavky VPMG (hlavní náhled + variace).</summary>
    void Obnov()
    {
        _obnovaNaplanovana = false;
        var st = Jadro.Stav;
        bool material = _zmeny.Contains("material") || _zmeny.Contains("profil");
        bool kroky = material || _zmeny.Overlaps(new[] { "krok+", "krok-", "poradi", "receptura", "rozliseni" });
        bool navrhZrusen = _zmeny.Contains("navrh") && st.Navrh.Prazdny;
        _zmeny.Clear();
        if (material) { Seznam.Oznac(st.Material); Fyzika.Zobraz(st.MaterialDto); }
        if (material || navrhZrusen) Profil.Postav(); else Profil.Obnov();
        if (kroky) Konfigurator.Postav(); else Konfigurator.ObnovValidaci();
        var m = st.MaterialDto;
        Titulek.Modulate = Colors.White;
        Titulek.Text = $"{m.Id} · {m.Nazev} ({m.Key}) · skupina {m.Skupina} · profil {st.Profil}" + (st.Navrh.Prazdny ? "" : " · NÁVRH");
        Jadro.Pozadej("hlavni", st.Receptura, st.Seed, st.Navrh);
        _seedyVariaci = st.SeedyVariaci(Variace.Pocet);
        for (int i = 0; i < _seedyVariaci.Count; i++) Jadro.Pozadej("var" + i, st.Receptura, _seedyVariaci[i], st.Navrh);
    }

    /// <summary>T-2b: když náhled = výchozí receptura v1 + seed goldenu bez návrhu, porovná checksum s goldenem Dev.</summary>
    string Golden(Willage.Materialy.Api.Dto.TexturaVpmgDto t)
    {
        var st = Jadro.Stav;
        if (st.ZdrojReceptury is not { } z || !st.Navrh.Prazdny || st.Seed != z.GoldenSeed || st.Receptura.Resolution != z.GoldenRozliseni
            || Willage.Materialy.Api.Sluzby.RecepturyVpmg.DoJson(st.Receptura) != Willage.Materialy.Api.Sluzby.RecepturyVpmg.DoJson(z.Receptura)) return "";
        return t.Checksum == z.GoldenChecksum ? $"\ngolden v1 Dev {z.GoldenChecksum} ✓" : $"\nROZDÍL od goldenu v1 Dev {z.GoldenChecksum}";
    }

    void PrijmiTexturu(string cil)
    {
        var t = Jadro.Posledni[cil];
        if (cil == "hlavni")
        {
            Nahled.Zobraz(t);
            InfoNahledu.Text = t.Zastupna ? t.Chyba ?? "zástupné"
                : t.Ok ? $"{t.Sirka}×{t.Vyska} px · vrstva {t.Vrstva}\nchecksum {t.Checksum}\nVPMG {t.MsNastroj:F2} ms · celkem {t.MsCelkem:F1} ms\nseed {Jadro.Stav.Seed}" + (Jadro.Stav.Navrh.Prazdny ? "" : "\nNÁVRH profilu (jen náhled)") + Golden(t)
                : "chyba VPMG: " + t.Chyba;
            InfoNahledu.Modulate = t.Ok ? Colors.White : new Color(1, 0.7f, 0.7f);
        }
        else if (cil.StartsWith("var") && int.TryParse(cil[3..], out int i) && i < _seedyVariaci.Count)
            Variace.Zobraz(i, _seedyVariaci[i], t);
    }
}
