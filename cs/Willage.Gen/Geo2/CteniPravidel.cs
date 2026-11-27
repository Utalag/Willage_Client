using System.Text.Json;

namespace Willage.Gen.Geo2;

/// <summary>Převod odkazů z dat na id katalogu s hlášením (kap. 8: vyřazená bez náhrady = chyba, s náhradou = varování).</summary>
internal sealed class OdkazyKatalogu
{
    private readonly KatalogGeo2 _k;
    private readonly ZpravaValidace _z;
    public OdkazyKatalogu(KatalogGeo2 k, ZpravaValidace z) { _k = k; _z = z; }
    public int MaxId => _k.MaxId;

    public int? Material(string klic, string? udalost, string kde)
    {
        var m = _k.PodleKlice(klic);
        if (m is null) { _z.Chyba("MATERIAL_NEZNAMY", udalost, $"{kde}: {klic}"); return null; }
        if (m.Stav == StavMaterialu.Aktivni) return m.Id;
        var a = _k.Aktivni(m.Id);
        if (a is null) { _z.Chyba("MATERIAL_VYRAZENY_BEZ_NAHRADY", udalost, $"{kde}: {klic} je vyřazená a nemá platnou náhradu"); return null; }
        _z.Varovani("MATERIAL_PRESMEROVAN", udalost, $"{kde}: vyřazená {klic} → {a.Klic}");
        return a.Id;
    }

    public IEnumerable<int> Skupina(string s, string? udalost, string kde)
    {
        if (!_k.ZnamaSkupina(s)) { _z.Chyba("SKUPINA_NEZNAMA", udalost, $"{kde}: {s}"); return Array.Empty<int>(); }
        return _k.IdSkupiny(s);
    }
}

/// <summary>Čtení a validace pravidel jedné události podle tabulky 2.4. Výsledek jsou zkompilované části nebo hlášení.</summary>
internal sealed class CteniPravidel
{
    private static readonly HashSet<string> KlicePravidel = new(StringComparer.Ordinal) { "nahrazuje", "ignoruj_nikdy", "zdroje", "prostor", "hloubka", "kontakt" };
    private static readonly HashSet<string> KliceNahrazuje = new(StringComparer.Ordinal) { "materialy", "skupiny", "krome" };
    private static readonly HashSet<string> KliceZdroje = new(StringComparer.Ordinal) { "vrstvy", "telesa", "transformace" };
    private static readonly HashSet<string> KliceKontakt = new(StringComparer.Ordinal) { "cil", "strana", "sirka_m", "modulace", "hostitel_okoli" };

    private readonly OdkazyKatalogu _o;
    private readonly ZpravaValidace _z;
    private readonly IReadOnlyList<int> _nikdy;
    private readonly IReadOnlyDictionary<string, (int stari, bool aktivni)> _udalosti;

    public CteniPravidel(OdkazyKatalogu o, ZpravaValidace z, IReadOnlyList<int> nikdy, IReadOnlyDictionary<string, (int, bool)> udalosti)
    { _o = o; _z = z; _nikdy = nikdy; _udalosti = udalosti; }

    public sealed record Vysledek(FiltrMaterialu? Nahrazuje, HashSet<int>? NahrazujeIds, ZdrojeZasahu? Zdroje, HashSet<TypProstoru> Prostor,
        Hloubka Hloubka, bool MaKontakt, List<string> OdkazyNaUdalosti)
    {
        public ParametryKontaktu? Kontakt { get; init; }
    }

    public Vysledek Cti(UdalostData u, Operace op, int stari)
    {
        var p = u.Pravidla;
        bool ma(string k) => p.ValueKind == JsonValueKind.Object && p.TryGetProperty(k, out _);
        var odkazy = new List<string>();
        if (p.ValueKind is not (JsonValueKind.Undefined or JsonValueKind.Object)) _z.Chyba("PRAVIDLA_TYP", u.Id, "pravidla musí být objekt");
        if (p.ValueKind == JsonValueKind.Object)
            foreach (var x in p.EnumerateObject()) if (!KlicePravidel.Contains(x.Name)) _z.Chyba("NEZNAMY_KLIC", u.Id, $"pravidla: {x.Name}");

        void Zakaz(string k, string kod = "PRAVIDLO_ZAKAZANO") { if (ma(k)) _z.Chyba(kod, u.Id, $"{op}: pravidlo {k} je zakázané (2.4)"); }
        void Povinne(string k, string kod) { if (!ma(k)) _z.Chyba(kod, u.Id, $"{op}: pravidlo {k} je povinné (2.4)"); }

        switch (op)
        {
            case Operace.Uloz:
                foreach (var k in KlicePravidel) Zakaz(k);
                return new Vysledek(null, null, null, new(), default, false, odkazy);
            case Operace.Odstran:
                Povinne("nahrazuje", "NAHRAZUJE_POVINNE"); Zakaz("prostor");
                break;
            case Operace.Vypln:
                Zakaz("nahrazuje"); Zakaz("zdroje"); Zakaz("ignoruj_nikdy"); Povinne("prostor", "PROSTOR_POVINNY");
                break;
            case Operace.Transformuj:
                Povinne("nahrazuje", "NAHRAZUJE_POVINNE"); Zakaz("prostor");
                break;
        }

        bool ign = ma("ignoruj_nikdy") && p.GetProperty("ignoruj_nikdy").ValueKind == JsonValueKind.True;
        FiltrMaterialu? nahr = null; HashSet<int>? nahrIds = null;
        if (op is Operace.Vnikni or Operace.Odstran or Operace.Transformuj)
        {
            if (ma("nahrazuje")) (nahr, nahrIds) = CtiFiltr(p.GetProperty("nahrazuje"), u.Id, "nahrazuje", ign);
            else nahr = new FiltrMaterialu(true, Array.Empty<int>(), Array.Empty<int>(), _nikdy, ign, _o.MaxId); // Vnikni: "*" − nikdy
        }

        ZdrojeZasahu? zdr = null;
        if (op is Operace.Vnikni or Operace.Odstran or Operace.Transformuj)
            zdr = CtiZdroje(ma("zdroje") ? p.GetProperty("zdroje") : default, u.Id, op, stari, odkazy);

        var prostor = new HashSet<TypProstoru>();
        if (ma("prostor"))
        {
            var pa = p.GetProperty("prostor");
            if (pa.ValueKind != JsonValueKind.Array) _z.Chyba("PROSTOR_TYP", u.Id, "prostor musí být pole");
            else foreach (var e in pa.EnumerateArray())
            {
                var s = e.GetString();
                if (s is "NadPovrchem" or "Vykopano") _z.Chyba("PROSTOR_ZAKAZANY", u.Id, $"{s} nesmí být v pravidle prostor");
                else if (Geo2Zaklad.ZkusTypDutiny(s, out var t)) prostor.Add(t);
                else _z.Chyba("PROSTOR_NEZNAMY", u.Id, $"neznámý typ prostoru {s}");
            }
            if (op == Operace.Vypln && prostor.Count == 0) _z.Chyba("PROSTOR_POVINNY", u.Id, "Vypln: prostor musí být neprázdný");
        }

        var hl = default(Hloubka);
        if (ma("hloubka")) hl = CtiHloubku(p.GetProperty("hloubka"), u.Id);
        if (op == Operace.Odstran && hl.MinM is null) _z.Chyba("HLOUBKA_POVINNA", u.Id, "Odstran: hloubka.min_m je povinná (2.4)");

        bool kont = false; ParametryKontaktu? kontakt = null;
        if (ma("kontakt")) { kont = true; kontakt = CtiKontakt(p.GetProperty("kontakt"), u.Id, stari, odkazy); }

        return new Vysledek(nahr, nahrIds, zdr, prostor, hl, kont, odkazy) { Kontakt = kontakt };
    }

    public (FiltrMaterialu, HashSet<int>) CtiFiltr(JsonElement e, string udalost, string kde, bool ignorujNikdy)
    {
        var ano = new HashSet<int>(); var krome = new HashSet<int>(); bool vse = false;
        if (e.ValueKind == JsonValueKind.String && e.GetString() == "*") vse = true;
        else if (e.ValueKind == JsonValueKind.Object)
        {
            foreach (var x in e.EnumerateObject())
            {
                if (!KliceNahrazuje.Contains(x.Name)) { _z.Chyba("NEZNAMY_KLIC", udalost, $"{kde}: {x.Name}"); continue; }
                foreach (var v in x.Value.EnumerateArray())
                {
                    var s = v.GetString() ?? "";
                    var cil = x.Name == "krome" ? krome : ano;
                    if (x.Name == "skupiny") foreach (var id in _o.Skupina(s, udalost, kde)) cil.Add(id);
                    else if (_o.Material(s, udalost, kde) is int id) cil.Add(id);
                }
            }
            if (ano.Count == 0) _z.Varovani("NAHRAZUJE_PRAZDNE", udalost, $"{kde}: filtr nepovolí žádný materiál");
        }
        else _z.Chyba("NAHRAZUJE_TYP", udalost, $"{kde}: očekáváno \"*\" nebo objekt");
        return (new FiltrMaterialu(vse, ano, krome, _nikdy, ignorujNikdy, _o.MaxId), ano);
    }

    private ZdrojeZasahu CtiZdroje(JsonElement e, string udalost, Operace op, int stari, List<string> odkazy)
    {
        bool vrstvyVse = true; HashSet<int>? vrstvyMat = null;
        var rezim = RezimTeles.Zadna; var telesa = new HashSet<string>();
        bool transf = op != Operace.Transformuj; // výchozí 2.4: Vnikni ano, Odstran ano, Transformuj ne
        if (e.ValueKind == JsonValueKind.Object)
        {
            foreach (var x in e.EnumerateObject()) if (!KliceZdroje.Contains(x.Name)) _z.Chyba("NEZNAMY_KLIC", udalost, $"zdroje: {x.Name}");
            if (e.TryGetProperty("vrstvy", out var v))
            {
                if (v.ValueKind is JsonValueKind.True or JsonValueKind.False) vrstvyVse = v.ValueKind == JsonValueKind.True;
                else if (v.ValueKind == JsonValueKind.Array)
                {
                    vrstvyVse = false; vrstvyMat = new();
                    foreach (var k in v.EnumerateArray()) if (_o.Material(k.GetString() ?? "", udalost, "zdroje.vrstvy") is int id) vrstvyMat.Add(id);
                }
                else _z.Chyba("ZDROJE_TYP", udalost, "zdroje.vrstvy: bool nebo pole materiálů");
            }
            if (e.TryGetProperty("telesa", out var t))
            {
                if (t.ValueKind == JsonValueKind.String && t.GetString() == "zadna") rezim = RezimTeles.Zadna;
                else if (t.ValueKind == JsonValueKind.String && t.GetString() == "starsi") rezim = RezimTeles.Starsi;
                else if (t.ValueKind == JsonValueKind.Array)
                {
                    rezim = RezimTeles.Vycet;
                    foreach (var x in t.EnumerateArray()) if (OdkazNaStarsi(x.GetString() ?? "", udalost, stari, "zdroje.telesa")) { telesa.Add(x.GetString()!); odkazy.Add(x.GetString()!); }
                }
                else _z.Chyba("ZDROJE_TYP", udalost, "zdroje.telesa: \"zadna\", \"starsi\" nebo pole id");
            }
            if (e.TryGetProperty("transformace", out var tr))
            {
                if (tr.ValueKind is JsonValueKind.True or JsonValueKind.False) transf = tr.ValueKind == JsonValueKind.True;
                else _z.Chyba("ZDROJE_TYP", udalost, "zdroje.transformace: bool");
            }
        }
        // id událostí se na indexy převedou až po seřazení (KompilatorChronologie)
        return new ZdrojeZasahu(vrstvyVse, vrstvyMat, rezim, new HashSet<int>(), transf) { TelesaId = telesa };
    }

    /// <summary>Odkaz na jinou událost: musí existovat a být starší. Neaktivní se vypustí s varováním.</summary>
    public bool OdkazNaStarsi(string id, string udalost, int stari, string kde)
    {
        if (!_udalosti.TryGetValue(id, out var u)) { _z.Chyba("ODKAZ_NEZNAMY", udalost, $"{kde}: událost {id} neexistuje"); return false; }
        if (!u.aktivni) { _z.Varovani("ODKAZ_NEAKTIVNI", udalost, $"{kde}: {id} je neaktivní, odkaz se vypouští"); return false; }
        if (u.stari >= stari) { _z.Chyba("ODKAZ_NENI_STARSI", udalost, $"{kde}: {id} (stáří {u.stari}) není starší než {stari}"); return false; }
        return true;
    }

    private Hloubka CtiHloubku(JsonElement e, string udalost)
    {
        double? Cislo(string k)
        {
            if (!e.TryGetProperty(k, out var v)) return null;
            if (v.ValueKind != JsonValueKind.Number || v.GetDouble() < 0) { _z.Chyba("HLOUBKA_TYP", udalost, $"hloubka.{k} musí být číslo ≥ 0"); return null; }
            return v.GetDouble();
        }
        foreach (var x in e.EnumerateObject()) if (x.Name is not ("min_m" or "max_m")) _z.Chyba("NEZNAMY_KLIC", udalost, $"hloubka: {x.Name}");
        var h = new Hloubka(Cislo("min_m"), Cislo("max_m"));
        if (h.MinM > h.MaxM) _z.Chyba("HLOUBKA_ROZSAH", udalost, "hloubka.min_m > max_m");
        return h;
    }

    /// <summary>Kontrola a čtení kontaktu (2.5). Při chybě null (hlášení je v ZpravaValidace).</summary>
    private ParametryKontaktu? CtiKontakt(JsonElement e, string udalost, int stari, List<string> odkazy)
    {
        if (e.ValueKind != JsonValueKind.Object) { _z.Chyba("KONTAKT_TYP", udalost, "kontakt musí být objekt"); return null; }
        int chyb0 = _z.PocetChyb;
        var cilVrstvy = new HashSet<int>(); var cilUdalosti = new List<string>();
        var hostAno = new List<int>(); bool maHost = false; double eta = 0.125, amp = 0, frek = 0, sirka = 0;
        foreach (var x in e.EnumerateObject()) if (!KliceKontakt.Contains(x.Name)) _z.Chyba("NEZNAMY_KLIC", udalost, $"kontakt: {x.Name}");
        if (!e.TryGetProperty("cil", out var cil) || cil.ValueKind != JsonValueKind.Object) _z.Chyba("KONTAKT_CIL", udalost, "kontakt.cil chybí");
        else
        {
            int n = 0;
            foreach (var x in cil.EnumerateObject())
            {
                if (x.Name == "vrstvy") foreach (var k in x.Value.EnumerateArray()) { if (_o.Material(k.GetString() ?? "", udalost, "kontakt.cil.vrstvy") is int cv) { n++; cilVrstvy.Add(cv); } }
                else if (x.Name == "udalosti") foreach (var k in x.Value.EnumerateArray()) { if (OdkazNaStarsi(k.GetString() ?? "", udalost, stari, "kontakt.cil.udalosti")) { n++; odkazy.Add(k.GetString()!); cilUdalosti.Add(k.GetString()!); } }
                else _z.Chyba("NEZNAMY_KLIC", udalost, $"kontakt.cil: {x.Name}");
            }
            if (n == 0) _z.Chyba("KONTAKT_CIL", udalost, "kontakt.cil nemá žádný platný cíl");
        }
        string str = e.TryGetProperty("strana", out var s) ? s.GetString() ?? "" : "";
        if (str is not ("vne" or "uvnitr" or "obe")) _z.Chyba("KONTAKT_STRANA", udalost, $"kontakt.strana: {str}");
        if (!e.TryGetProperty("sirka_m", out var w) || w.ValueKind != JsonValueKind.Number || w.GetDouble() <= 0) _z.Chyba("KONTAKT_SIRKA", udalost, "kontakt.sirka_m > 0 [m]");
        else sirka = w.GetDouble();
        if (e.TryGetProperty("modulace", out var mo))
        {
            foreach (var x in mo.EnumerateObject())
            {
                if (x.Name == "amp_rel") { var a = x.Value.GetDouble(); amp = a; if (a < 0 || a >= 1) _z.Chyba("KONTAKT_MODULACE", udalost, "modulace.amp_rel ∈ [0, 1)"); }
                else if (x.Name == "frekvence_1_m") { frek = x.Value.GetDouble(); if (frek < 0) _z.Chyba("KONTAKT_MODULACE", udalost, "modulace.frekvence_1_m ≥ 0 [1/m]"); }
                else _z.Chyba("NEZNAMY_KLIC", udalost, $"kontakt.modulace: {x.Name}");
            }
        }
        if (e.TryGetProperty("hostitel_okoli", out var ho))
        {
            maHost = true;
            foreach (var x in ho.EnumerateObject())
            {
                if (x.Name == "materialy") { foreach (var k in x.Value.EnumerateArray()) if (_o.Material(k.GetString() ?? "", udalost, "hostitel_okoli") is int hm) hostAno.Add(hm); }
                else if (x.Name == "skupiny") { foreach (var k in x.Value.EnumerateArray()) hostAno.AddRange(_o.Skupina(k.GetString() ?? "", udalost, "hostitel_okoli")); }
                else if (x.Name == "hloubka_vzorku_m") { eta = x.Value.GetDouble(); if (eta <= 0) _z.Chyba("KONTAKT_ETA", udalost, "hloubka_vzorku_m > 0 [m]"); }
                else _z.Chyba("NEZNAMY_KLIC", udalost, $"hostitel_okoli: {x.Name}");
            }
        }
        if (_z.PocetChyb != chyb0) return null;
        var strana = str switch { "vne" => StranaKontaktu.Vne, "uvnitr" => StranaKontaktu.Uvnitr, _ => StranaKontaktu.Obe };
        var host = maHost ? new FiltrMaterialu(false, hostAno, Array.Empty<int>(), Array.Empty<int>(), true, _o.MaxId) : null;
        return new ParametryKontaktu(cilVrstvy, cilUdalosti, strana, sirka, amp, frek, host, eta);
    }
}
