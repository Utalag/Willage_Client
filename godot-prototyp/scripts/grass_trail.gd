@tool
extends RefCounted
## Stopa rozhrnutí (ze studie trava-studie/scripts/trail.gd): float textura, pixel = R čas otisku, GB směr, A síla.
## Návrat trávy počítá shader z (čas − R), CPU přepisuje jen pixely pod postavičkou.
## Navíc oproti studii: okno pevné velikosti se posouvá za postavičkou (follow), takže stopa nemusí pokrýt celý ostrov.

var img: Image
var tex: ImageTexture
var origin: Vector2
var size: Vector2
var px: float
var w: int
var h: int
var dirty := false

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

## posune okno, když se bod přiblíží okraji (vnitřní čtvrtina); vrátí true, když se okno posunulo
func follow(p: Vector2) -> bool:
	var c := origin + size * 0.5
	if absf(p.x - c.x) < size.x * 0.25 and absf(p.y - c.y) < size.y * 0.25:
		return false
	var dx := int(round((p.x - c.x) * px))
	var dy := int(round((p.y - c.y) * px))
	var ni := Image.create_empty(w, h, false, Image.FORMAT_RGBAF)
	ni.fill(Color(-100.0, 0.0, 0.0, 0.0))
	ni.blit_rect(img, Rect2i(dx, dy, w, h), Vector2i.ZERO)
	img = ni
	origin += Vector2(dx, dy) / px
	dirty = true
	return true

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
			if s < effect(img.get_pixel(x, y), t, hold, rec):
				continue
			var away := d / maxf(dl, 1e-4)
			var dir := (away * smoothstep(0.0, 0.35, dl / radius) + move_dir * 0.35).normalized()
			img.set_pixel(x, y, Color(t, dir.x, dir.y, s))
			dirty = true

func upload() -> void:
	if dirty:
		tex.update(img)
		dirty = false
