using System;
using Godot;
using Willage.Materialy.Api.Dto;

namespace WillagePrototyp.EditorMaterialu;

/// <summary>
/// T-2: horní lišta okna 2 – commit Willage_Dev (pin), SHA zrcadla katalogu, golden VPMG, stav nástroje, Validovat.
/// Diff / Uložit recepturu / Export návrhu jsou zástupné (T-4) a jasně označené.
/// </summary>
[GlobalClass]
public partial class HorniListaMaterialu : HBoxContainer
{
    [Signal] public delegate void ValidovatEventHandler();
    public Label Pin { get; private set; } = null!;
    public Label Golden { get; private set; } = null!;
    public Label Vpmg { get; private set; } = null!;
    public Button Validovat_ { get; private set; } = null!;

    public override void _Ready()
    {
        Pin = GetNode<Label>("Pin"); Golden = GetNode<Label>("Golden"); Vpmg = GetNode<Label>("Vpmg");
        Validovat_ = GetNode<Button>("Validovat");
        Validovat_.Pressed += () => EmitSignal(SignalName.Validovat);
        foreach (var n in new[] { "Diff", "Ulozit", "Export" })
        {
            var b = GetNode<Button>(n);
            b.Disabled = true;
            b.TooltipText = "zástupné: " + b.Text + " – krok T-4 (uložení receptur do data/vpmg/receptury, návrh pro backend)";
        }
    }

    public void NastavPin(PinDevDto p)
    {
        Pin.Text = $"Dev {p.Commit[..7]} · zrcadlo {p.ZrcadloSha[..8]}";
        Pin.TooltipText = $"{p.Repo} {p.Commit} – {p.Popis}\nzrcadlo {p.ZrcadloCesta} SHA {p.ZrcadloSha}\nkatalog Dev SHA {p.KatalogDevSha} (liší se koncovým \\n)";
        Pin.MouseFilter = MouseFilterEnum.Pass;
    }

    public void NastavKontrolu(InfoVpmgDto? i, (uint Ocekavany, uint Spocteny)? g, KontrolaZrcadlaDto? z)
    {
        if (i is not { Dostupny: true })
        {
            Vpmg.Text = "VPMG: " + (i?.Popis ?? "…");
            Vpmg.Modulate = new Color(1, 0.75f, 0.75f);
            Golden.Text = "golden: zástupné";
            return;
        }
        Vpmg.Text = $"VPMG mimo proces (.NET {i.Runtime}) · operace {string.Join(", ", i.Operace)}";
        Vpmg.Modulate = Colors.White;
        bool ok = g is { } gg && gg.Ocekavany == gg.Spocteny;
        Golden.Text = g is { } x ? $"golden {x.Spocteny} {(ok ? "= Dev" : "≠ Dev " + x.Ocekavany)}" + (z is { } zz ? $" · zrcadlo {(zz.BajtyBezKonce && zz.Zaznamy ? "= Dev" : "≠ Dev")}" : "") : "golden …";
        Golden.Modulate = ok ? new Color(0.7f, 1, 0.7f) : new Color(1, 0.6f, 0.6f);
    }
}
