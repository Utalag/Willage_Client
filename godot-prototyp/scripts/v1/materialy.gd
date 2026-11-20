extends RefCounted
## Generátor V1.0, krok 1: jedna tabulka materiálů, jedno číselné id (docs/sjednoceni 1.6).
## Zdroj: res://data/materialy_v1.csv (kopie docs/sjednoceni/materialy.csv). Hodnoty „–“ = nevztahuje se (NAN),
## „~“ a „[~]“ = odhad (číslo se bere, příznak odhad se drží zvlášť).

const CESTA := "res://data/materialy_v1.csv"
const CISELNE := ["propustnost_0_1", "K_m_s", "propustnost_l_s_herni", "porovitost", "odpor_povrchu_res", "hustota_kg_m3"]

## jedna položka: { id, nazev, skupina, <číselné sloupce> (float nebo NAN), odhad: [sloupce], barva: Color, radek: {...} }
static func _cislo(s: String) -> Array:
	var t := s.strip_edges()
	var odhad := t.contains("~")
	t = t.replace("[~]", "").replace("~", "").strip_edges()
	if t.is_empty() or t == "–" or t == "-": return [NAN, odhad]
	t = t.split(" ")[0]
	if not t.is_valid_float(): return [NAN, odhad]
	return [float(t), odhad]

static func nacti(cesta := CESTA) -> Dictionary:
	var f := FileAccess.open(cesta, FileAccess.READ)
	if f == null: return {"chyba": "nelze otevřít " + cesta}
	var hlava := f.get_csv_line()
	var podle_id := {}
	var chyby: Array = []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < hlava.size(): continue
		var d := {}
		for i in hlava.size(): d[hlava[i]] = r[i]
		if not String(d.id).is_valid_int():
			chyby.append("id není číslo: " + String(d.id)); continue
		var id := int(d.id)
		if podle_id.has(id): chyby.append("duplicitní id %d" % id)
		var m := {"id": id, "nazev": d.nazev_cs, "skupina": d.skupina, "odhad": [], "radek": d}
		for k in CISELNE:
			var c := _cislo(String(d[k]))
			m[k] = c[0]
			if c[1]: m.odhad.append(k)
		m["barva"] = Color.html(d.barva_hex) if Color.html_is_valid(d.barva_hex) else Color(0, 0, 0, 0)
		podle_id[id] = m
	var ids := podle_id.keys()
	ids.sort()
	return {"podle_id": podle_id, "ids": ids, "chyby": chyby}

## propustnost 0–1 podle E61: (log10 K + 9) / 6, oříznuto na 0–1
static func perm_z_k(k: float) -> float:
	return clampf((log(k) / log(10.0) + 9.0) / 6.0, 0.0, 1.0)
