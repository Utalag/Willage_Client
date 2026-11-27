using System.Text.Json;

namespace Willage.Gen.Geo2;

public sealed record VysledekKompilace(ChronologieGeo2? Chronologie, ZpravaValidace Zprava)
{
    public bool Ok => Chronologie is not null;
}

/// <summary>
/// Kompilátor a validátor chronologie (kap. 1.3, 2.4, kap. 8). Pořadí v souboru nemá význam: klíč je (stáří, id ordinálně).
/// Při chybě vrací null a všechna hlášení najednou. Tenkost tvaru není chyba (O2).
/// </summary>
public static class KompilatorChronologie
{
    private static readonly HashSet<string> KliceVysledku = new(StringComparer.Ordinal) { "material", "material_z_tvaru", "mapa", "prostor", "mineralizace" };

    public static VysledekKompilace Kompiluj(SadaUdalosti sada, KatalogGeo2 katalog, ITovarnaTvaru tovarna)
    {
        var z = new ZpravaValidace();
        z.Pridej(sada.Zprava.Hlaseni);
        z.Pridej(katalog.Zprava.Hlaseni);
        var odk = new OdkazyKatalogu(katalog, z);

        var nikdy = new List<int>();
        foreach (var k in sada.Nikdy) if (odk.Material(k, null, "nikdy") is int id) nikdy.Add(id);

        // 1) záznamy: id, stáří, operace, neznámé klíče
        var info = new Dictionary<string, (int stari, bool aktivni)>(StringComparer.Ordinal);
        var platne = new List<(UdalostData u, Operace op, int stari)>();
        foreach (var u in sada.Udalosti)
        {
            string id = u.Id;
            if (id.Length == 0) { z.Chyba("ID_CHYBI", null, $"událost č. {u.Poradi} nemá id"); continue; }
            if (info.ContainsKey(id)) { z.Chyba("ID_DUPLICITNI", id, "id je v datech dvakrát"); continue; }
            foreach (var k in u.NeznameKlice) z.Chyba("NEZNAMY_KLIC", id, k);
            if (u.Stari is null || u.Stari < 0) { z.Chyba("STARI_CHYBI", id, "stari musí být celé číslo ≥ 0"); continue; }
            if (!Geo2Zaklad.ZkusOperaci(u.OperaceText, out var op)) { z.Chyba("OPERACE_NEZNAMA", id, $"operace {u.OperaceText}"); continue; }
            info[id] = (u.Stari.Value, u.Aktivni);
            if (u.SourozenciText is not (null or "unie" or "nejmensi_sdf")) z.Chyba("SOUROZENCI", id, $"sourozenci {u.SourozenciText}");
            if (u.SourozenciText == "nejmensi_sdf") z.Varovani("SOUROZENCI_PARITA", id, "nejmensi_sdf je jen pro paritu s E84 (1.4)");
            if (!u.Aktivni) continue;
            if (op == Operace.Deformuj) { z.Chyba("DEFORMACE_AZ_D", id, "aktivní Deformuj je v K1–K5 zakázaná (etapa D)"); continue; }
            platne.Add((u, op, u.Stari.Value));
        }

        // 2) klíč pořadí (1.3): shodné stáří aktivních = chyba
        platne.Sort((a, b) => a.stari != b.stari ? a.stari.CompareTo(b.stari) : string.CompareOrdinal(a.u.Id, b.u.Id));
        for (int i = 1; i < platne.Count; i++)
            if (platne[i].stari == platne[i - 1].stari)
                z.Chyba("STARI_SHODNE", platne[i].u.Id, $"stáří {platne[i].stari} má i {platne[i - 1].u.Id}");

        // 3) Uloz: právě jedna aktivní, nejstarší
        var ulozy = platne.Where(p => p.op == Operace.Uloz).ToList();
        if (ulozy.Count != 1) z.Chyba("ULOZ_POCET", null, $"aktivních Uloz je {ulozy.Count}, má být právě 1");
        else if (platne.Count > 0 && platne[0].op != Operace.Uloz) z.Chyba("ULOZ_NENI_PRVNI", ulozy[0].u.Id, "Uloz musí mít nejmenší stáří");

        // 4) pravidla, výsledek, tvar
        var cteni = new CteniPravidel(odk, z, nikdy, info);
        var indexy = new Dictionary<string, int>(StringComparer.Ordinal);
        for (int i = 0; i < platne.Count; i++) indexy[platne[i].u.Id] = i;
        var vystup = new List<KompilovanaUdalost>();
        for (int i = 0; i < platne.Count; i++)
        {
            var (u, op, stari) = platne[i];
            var pr = cteni.Cti(u, op, stari);
            var ku = Vysledek(u, op, pr, odk, z, katalog);
            object? tvar = u.TvarDruh is "kontakt" or "oblast" ? TvarVsude.Instance : tovarna.Vytvor(u);
            if (tvar is null) z.Chyba("TVAR_NEZNAMY", u.Id, $"tvar.druh {u.TvarDruh ?? "(chybí)"}");
            else if (op == Operace.Uloz && tvar is not ITvarZasobniku) z.Chyba("TVAR_TYP", u.Id, "Uloz potřebuje zásobník vrstev");
            else if (op != Operace.Uloz && tvar is not ITvar) z.Chyba("TVAR_TYP", u.Id, "tvar musí být ITvar");
            if (ku.MaterialZTvaru && tvar is not ITvarSMaterialem) z.Chyba("TVAR_BEZ_MATERIALU", u.Id, "material_z_tvaru vyžaduje tvar s materiálem");
            IKontaktniPasmo? kontakt = null;
            if (pr.MaKontakt && (kontakt = tovarna.Kontakt(u)) is null)
                z.Chyba("KONTAKT_K1B", u.Id, "kontaktní pásmo zatím není implementované (krok K1b)");
            if (op == Operace.Transformuj && pr.NahrazujeIds is not null)
            {
                var klice = ku.Mapa.Keys.ToHashSet();
                if (!klice.SetEquals(pr.NahrazujeIds)) z.Chyba("MAPA_NESEDI", u.Id, "nahrazuje se musí rovnat klíčům mapa (2.4)");
            }
            var zdroje = pr.Zdroje is null ? null : pr.Zdroje with
            {
                TelesaUdalosti = pr.Zdroje.TelesaId.Where(indexy.ContainsKey).Select(k => indexy[k]).ToHashSet(),
            };
            vystup.Add(new KompilovanaUdalost
            {
                Index = i, Id = u.Id, Stari = stari, Operace = op,
                Tvar = tvar as ITvar, Zasobnik = tvar as ITvarZasobniku,
                Nahrazuje = pr.Nahrazuje, Zdroje = zdroje, Prostor = pr.Prostor, Hloubka = pr.Hloubka, Kontakt = kontakt,
                VysledekMaterial = ku.Material, MaterialZTvaru = ku.MaterialZTvaru, Mapa = ku.Mapa, VysledekProstor = ku.Prostor,
            });
        }
        if (z.MaChyby) return new VysledekKompilace(null, z);
        return new VysledekKompilace(new ChronologieGeo2(vystup, sada.Konfigurace, katalog.Otisk), z);
    }

    private sealed record CastVysledku(int? Material, bool MaterialZTvaru, Dictionary<int, int> Mapa, TypProstoru Prostor);

    private static CastVysledku Vysledek(UdalostData u, Operace op, CteniPravidel.Vysledek pr, OdkazyKatalogu odk, ZpravaValidace z, KatalogGeo2 kat)
    {
        var v = u.Vysledek;
        int? mat = null; bool zTvaru = false; var mapa = new Dictionary<int, int>(); var prostor = TypProstoru.Neurceno;
        bool ma(string k) => v.ValueKind == JsonValueKind.Object && v.TryGetProperty(k, out _);
        if (v.ValueKind == JsonValueKind.Object)
            foreach (var x in v.EnumerateObject()) if (!KliceVysledku.Contains(x.Name)) z.Chyba("NEZNAMY_KLIC", u.Id, $"vysledek: {x.Name}");
        switch (op)
        {
            case Operace.Vnikni:
            case Operace.Vypln:
                zTvaru = ma("material_z_tvaru") && v.GetProperty("material_z_tvaru").ValueKind == JsonValueKind.True;
                if (ma("material")) mat = odk.Material(v.GetProperty("material").GetString() ?? "", u.Id, "vysledek.material");
                if (zTvaru == ma("material")) z.Chyba("VYSLEDEK_MATERIAL", u.Id, "právě jedno z vysledek.material / material_z_tvaru");
                break;
            case Operace.Odstran:
                if (!ma("prostor") || !Geo2Zaklad.ZkusTypDutiny(v.GetProperty("prostor").GetString(), out prostor))
                    z.Chyba("VYSLEDEK_PROSTOR", u.Id, "Odstran: vysledek.prostor ∈ {DutinaKras, DutinaJina}");
                break;
            case Operace.Transformuj:
                if (!ma("mapa") || v.GetProperty("mapa").ValueKind != JsonValueKind.Object) { z.Chyba("VYSLEDEK_MAPA", u.Id, "Transformuj: vysledek.mapa je povinná"); break; }
                foreach (var x in v.GetProperty("mapa").EnumerateObject())
                {
                    int? cil = odk.Material(x.Value.GetString() ?? "", u.Id, "vysledek.mapa (cíl)");
                    IEnumerable<int> zdroje = x.Name.StartsWith("skupina:", StringComparison.Ordinal)
                        ? odk.Skupina(x.Name["skupina:".Length..], u.Id, "vysledek.mapa")
                        : odk.Material(x.Name, u.Id, "vysledek.mapa") is int id ? new[] { id } : Array.Empty<int>();
                    if (cil is null) continue;
                    foreach (var s in zdroje) mapa[s] = cil.Value;
                }
                break;
        }
        return new CastVysledku(mat, zTvaru, mapa, prostor);
    }
}
