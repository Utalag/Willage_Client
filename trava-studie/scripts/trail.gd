extends RefCounted
## Stopa rozhrnutí: malá float textura nad oběma záhony. Do pixelu se při průchodu zapíše
## R = čas otisku, GB = směr odhrnutí (od postavičky), A = síla (1 uprostřed, 0 na okraji).
## Útlum se NEpočítá na CPU: shader z (čas − R) sám spočítá návrat, takže se každý snímek
## přepisují jen pixely pod postavičkou (≈ 2 × 100 px) a nahraje se textura (O(1) práce na CPU navíc).

var img: Image
var tex: ImageTexture
var origin: Vector2
var size: Vector2
var px: float
var w: int
var h: int

func _init(p_origin: Vector2, p_size: Vector2, p_px: float) -> void:
	origin = p_origin
	size = p_size
	px = p_px
	w = int(ceil(size.x * px))
	h = int(ceil(size.y * px))
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBAF)
	img.fill(Color(-100.0, 0.0, 0.0, 0.0))
	tex = ImageTexture.create_from_image(img)

func rect() -> Vector4:
	return Vector4(origin.x, origin.y, float(w) / px, float(h) / px)

## efekt v čase t podle stejného vzorce jako shader (pro rozhodnutí, zda přepsat starší otisk)
static func effect(c: Color, t: float, hold: float, rec: float) -> float:
	var dt := maxf(t - c.r, 0.0)
	var x := clampf((dt - hold) / rec, 0.0, 1.0)
	return c.a * (1.0 - smoothstep(0.0, 1.0, x))

func stamp(pos: Vector2, move_dir: Vector2, radius: float, t: float, hold: float, rec: float) -> void:
	var cx := (pos.x - origin.x) * px
	var cy := (pos.y - origin.y) * px
	var rp := radius * px
	for y in range(maxi(0, int(cy - rp)), mini(h, int(cy + rp) + 2)):
		for x in range(maxi(0, int(cx - rp)), mini(w, int(cx + rp) + 2)):
			var wpos := origin + Vector2(x + 0.5, y + 0.5) / px
			var d := wpos - pos
			var dl := d.length()
			if dl > radius:
				continue
			var s := 1.0 - smoothstep(0.55, 1.0, dl / radius)
			var old := img.get_pixel(x, y)
			if s < effect(old, t, hold, rec):
				continue
			# směr: od středu ven; pod samotnou postavičkou převažuje směr chůze
			var away := d / maxf(dl, 1e-4)
			var dir := (away * smoothstep(0.0, 0.35, dl / radius) + move_dir * 0.35).normalized()
			img.set_pixel(x, y, Color(t, dir.x, dir.y, s))

func upload() -> void:
	tex.update(img)
