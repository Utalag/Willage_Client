extends RefCounted
## Generátor V1.0, krok 2: výšky bloku 128 m (blueprintu) z funkce světa (vzor: blok96.gd, E96 – výška ve středech buněk
## přímo z funkce, bez šablon). Blok (bx, by) je ve světě na [bx · 128, (bx + 1) · 128) m. Žádná mřížka sousedů:
## každý blok i segment se ptá funkce sám, proto hranice sedí bez dorovnávání (test 1 kroku 2).

## výšky ve středech buněk o hraně krok_m: n × n, index i * n + j (i podél x)
static func stredy(svet, o: Vector2, delka_m: float, krok_m: float) -> PackedFloat64Array:
	var n := int(round(delka_m / krok_m))
	var out := PackedFloat64Array(); out.resize(n * n)
	for i in n:
		var x := o.x + (i + 0.5) * krok_m
		for j in n:
			out[i * n + j] = svet.vyska(x, o.y + (j + 0.5) * krok_m)
	return out

## výšky v rozích buněk (včetně obou okrajů): (n + 1)², index i * (n + 1) + j
static func rohy(svet, o: Vector2, delka_m: float, krok_m: float) -> PackedFloat64Array:
	var n := int(round(delka_m / krok_m)) + 1
	var out := PackedFloat64Array(); out.resize(n * n)
	for i in n:
		var x := o.x + i * krok_m
		for j in n:
			out[i * n + j] = svet.vyska(x, o.y + j * krok_m)
	return out

static func origin(svet, b: Vector2i) -> Vector2:
	return Vector2(b) * float(svet.p.rozmery.blok_m)
