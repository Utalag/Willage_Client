extends RefCounted
## Klimatické presety (docs/sjednoceni 1.15): tabulka upraví vstupy generátoru
## a nese, které reliéfní biomy se v podnebí vyskytnou a s jakou vahou.
## Načte se na začátku kroku 2, před mapou biomů a reliéfem.
## Povrchové jevy (písek, led, sníh, výpar, zamrzání) patří až do kroku 8 po vodě.
## Zdroj: res://data/klima_presety.csv (konvence jako materialy_v1.csv).

const CESTA := "res://data/klima_presety.csv"
const NASOBITELE := ["k_prevyseni", "k_vlna", "k_drsnost", "k_masiv_amp", "k_masiv_zdvih", "k_podhuri", "k_horniny", "k_voda"]
const PODILY := ["podil_nizina", "podil_mokrad", "podil_pahorkatina", "podil_hornatina", "podil_sopecna"]

static func nacti(cesta := CESTA) -> Dictionary:
	var f := FileAccess.open(cesta, FileAccess.READ)
	if f == null: return {"chyba": "nelze otevřít " + cesta}
	var hlava: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.is_empty() or String(r[0]).strip_edges().is_empty(): continue
		if String(r[0]).strip_edges().begins_with("#"): continue
		hlava = r
		break
	if hlava.is_empty(): return {"chyba": "chybí hlavička v " + cesta}
	var podle_id := {}
	var ids: Array = []
	var chyby: Array = []
	while not f.eof_reached():
		var r2 := f.get_csv_line()
		if r2.is_empty() or String(r2[0]).strip_edges().is_empty(): continue
		if String(r2[0]).strip_edges().begins_with("#"): continue
		if r2.size() < hlava.size():
			chyby.append("krátký řádek: " + String(r2[0])); continue
		var d := {}
		for i in hlava.size(): d[hlava[i]] = r2[i]
		var id := String(d.id).strip_edges()
		if id.is_empty(): continue
		if podle_id.has(id): chyby.append("duplicitní id " + id)
		var m := {"id": id, "nazev": String(d.get("nazev_cs", id)), "priklad": int(d.get("priklad", "0")) != 0, "radek": d}
		for k in NASOBITELE:
			m[k] = _cislo(String(d.get(k, "1")))
		m["d_posun_m"] = _cislo(String(d.get("d_posun_m", "0")))
		var pod: Array = []
		for k in PODILY:
			pod.append(_cislo(String(d.get(k, "0"))))
		m["podil"] = pod
		m["poznamka"] = String(d.get("poznamka", ""))
		podle_id[id] = m
		if not ids.has(id): ids.append(id)
	return {"podle_id": podle_id, "ids": ids, "chyby": chyby}

static func _cislo(s: String) -> float:
	var t := s.strip_edges()
	if t.is_empty() or t == "–" or t == "-": return 0.0
	t = t.split(" ")[0]
	if not t.is_valid_float(): return 0.0
	return float(t)

## Upraví parametry světa podle presetu (násobitele / posun / podíly reliéfních biomů).
## k_voda a k_horniny se jen uloží; v kroku 2 se do výšky nepromítají (voda a geologie později).
static func uplatni(p: Dictionary, preset: Dictionary) -> void:
	var bi: Array = p.biomy
	var k_prev := float(preset.k_prevyseni)
	var k_vlna := float(preset.k_vlna)
	var k_drs := float(preset.k_drsnost)
	var d_pos := float(preset.d_posun_m)
	for t in bi.size():
		var b: Dictionary = bi[t]
		b.posun_m = float(b.posun_m) + d_pos
		b.prevyseni_m = float(b.prevyseni_m) * k_prev
		b.vlna_m = float(b.vlna_m) * k_vlna
		b.drsnost = float(b.drsnost) * k_drs
		bi[t] = b
	p.podil = preset.podil.duplicate()
	p.p87_amp_m = float(p.p87_amp_m) * float(preset.k_masiv_amp)
	p.masiv_zdvih_m = float(p.masiv_zdvih_m) * float(preset.k_masiv_zdvih)
	p.podhuri_m = float(p.podhuri_m) * float(preset.k_podhuri)
	p.klima_k_voda = float(preset.k_voda)
	p.klima_k_horniny = float(preset.k_horniny)
	p.klima_id = String(preset.id)
	p.klima_nazev = String(preset.nazev)
	p.klima_priklad = bool(preset.priklad)
