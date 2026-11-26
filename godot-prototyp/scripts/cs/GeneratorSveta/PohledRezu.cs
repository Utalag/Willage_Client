using System;
using System.Linq;
using Godot;
using Willage.Gen.Api.Dto;
using Willage.Gen.Api.Sluzby;
using WillagePrototyp.Jadro;
using WillagePrototyp.Jadro.Uzly;

namespace WillagePrototyp.OknoGeneratoru;

/// <summary>
/// G-6: řez úsečkou pro M1–M3 (nahrazuje zástupný panel G-5). M1/M2 profil povrchu, M3 svislý řez materiálů po 0,25 m s izolací
/// (vše / jen vrstvy / jen útvary) a materiálem pod kurzorem. Úsečku dodá NahledModulu (dva kliky). M4–M6: zástupné (řez s hladinou – G-7).
/// </summary>
[GlobalClass]
public partial class PohledRezu : VBoxContainer
{
    /// <summary>Nejvíc vzorků řezu (delší úsečka → větší krok).</summary>
    [Export] public int MaxVzorku { get; set; } = 512;

    public string Modul { get; private set; } = "";
    public RezimRezuDto Rezim { get; private set; } = RezimRezuDto.Vse;
    public int PrijatychRezu { get; private set; }
    public ProfilRezu Plocha { get; private set; } = null!;
    public Label Kurzor { get; private set; } = null!;
    OptionButton _rezim = null!;
    Label _titulek = null!;
    ZastupnyPanel _zastupny = null!;
    Vector2 _od, _do;
    long _uloha = -1;

    public override void _Ready()
    {
        _titulek = GetNode<Label>("Titulek"); _rezim = GetNode<OptionButton>("Rezim"); Plocha = GetNode<ProfilRezu>("Plocha");
        Kurzor = GetNode<Label>("Kurzor"); _zastupny = GetNode<ZastupnyPanel>("Zastupny");
        foreach (var r in new[] { "vše", "jen vrstvy (izolace)", "jen útvary + nitro sopek (izolace)" }) _rezim.AddItem(r);
        _rezim.ItemSelected += i => NastavRezim((int)i);
        Plocha.GuiInput += e => { if (e is InputEventMouseMotion m) Kurzor.Text = Popis(m.Position); };
        var j = WillageJadro.Instance; if (j is null) return;
        j.RezModuluHotov += (id, m, rz) =>
        {
            if (id != _uloha) return;
            Plocha.Rez = j.PosledniRez; Plocha.Obraz = j.PosledniRezTextura; Plocha.QueueRedraw(); PrijatychRezu++;
            var r = j.PosledniRez!;
            _titulek.Text = $"Řez {m}: ({r.Od.XM:0.#}, {r.Od.YM:0.#}) → ({r.Do.XM:0.#}, {r.Do.YM:0.#}) m, {r.Nx} vzorků po {r.KrokM:0.###} m{(r.Nz > 0 ? $" × {r.Nz} buněk" : "")} · {r.Ms:F0} ms";
        };
        j.PlanetaHotova += _ => { if (Aktivni) Pozadej(); };
    }

    public bool Aktivni => NahledyModuluApi.ModulySNahledem.Contains(Modul);

    public void NastavModul(string modul)
    {
        Modul = modul;
        bool a = Aktivni;
        Plocha.Visible = a; Kurzor.Visible = a; _rezim.Visible = a && modul == "M3"; _zastupny.Visible = !a;
        _titulek.Text = a ? $"Řez {modul}" : "Řez";
        Plocha.Rez = null; Plocha.Obraz = null; Plocha.QueueRedraw();
        if (modul != "M3") { Rezim = RezimRezuDto.Vse; _rezim.Select(0); }
    }

    public void NastavUsecku(Vector2 odM, Vector2 doM) { _od = odM; _do = doM; if (Aktivni) Pozadej(); }

    /// <summary>Izolace řezu M3 (0 vše, 1 jen vrstvy, 2 jen útvary).</summary>
    public void NastavRezim(int r) { Rezim = (RezimRezuDto)Math.Clamp(r, 0, 2); _rezim.Select((int)Rezim); if (Aktivni) Pozadej(); }

    /// <summary>Krok řezu: M3 po buňce 0,25 m, dokud se vejde do MaxVzorku; jinak délka / MaxVzorku.</summary>
    public double Krok(double delkaM) => Modul == "M3" && delkaM / 0.25 <= MaxVzorku ? 0.25 : Math.Max(0.25, delkaM / MaxVzorku);

    void Pozadej()
    {
        var j = WillageJadro.Instance; if (j is null || j.PosledniVysledek is null || _od == _do) return;
        _uloha = j.RezModulu(Modul, _od, _do, Krok(_od.DistanceTo(_do)), (int)Rezim);
    }

    /// <summary>Text pod kurzorem: poloha, výška; M3 materiál buňky (id, název, skupina); M1/M2 povrch.</summary>
    public string Popis(Vector2 p)
    {
        var j = WillageJadro.Instance; var r = Plocha.Rez; if (j is null || r is null) return "";
        var (ix, z) = Plocha.Pod(p);
        double t = (ix + 0.5) * r.KrokM;
        double d = Math.Sqrt(Math.Pow(r.Do.XM - r.Od.XM, 2) + Math.Pow(r.Do.YM - r.Od.YM, 2));
        double x = r.Od.XM + (d == 0 ? 0 : t * (r.Do.XM - r.Od.XM) / d), y = r.Od.YM + (d == 0 ? 0 : t * (r.Do.YM - r.Od.YM) / d);
        string s = $"x {x:0.##} m, y {y:0.##} m, z {z:0.##} m · povrch {r.PovrchM[ix]:0.##} m";
        if (r.PovrchM1 is double[] p1) s += $" (M1 {p1[ix]:0.##} m)";
        if (r.Nz > 0)
        {
            int iz = Math.Clamp((int)(z / r.KrokZM), 0, r.Nz - 1);
            byte id = r.Material(ix, iz);
            var m = j.MaterialyDto.FirstOrDefault(q => q.Id == id);
            s += $" · materiál {id} {m?.Nazev ?? "?"}{(m is null ? "" : $" ({m.Skupina})")}";
        }
        return s;
    }
}
