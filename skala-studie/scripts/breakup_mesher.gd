extends RefCounted
## Přístup B: kostky s geometrickým rozbitím. Mřížka zůstává vodotěsná (sousední stěny sdílejí vrcholy):
##  - vrchol mřížky se posune ke středu plných buněk kolem něj (vypouklé hrany a rohy = sražení/zkosení,
##    vhloubené kouty se mírně zaplní) + deterministický šum podle polohy vrcholu,
##  - každá viditelná stěna se rozdělí na 8 trojúhelníků (rohy, středy hran s vlastním šumem, střed),
##    střed se náhodně vysune nebo zapustí (vpadlá stěna), plochy se kreslí jako ploché fazety,
##  - praskliny, vrstvy a dutiny dodá rock.gdshader (AO z obsazenosti okolí vrcholu).

const Mat = preload("res://scripts/mat.gd")
const FACES := [
	[Vector3i(0, 1, 0), [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)]],
	[Vector3i(0, -1, 0), [Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0)]],
	[Vector3i(1, 0, 0), [Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 0)]],
	[Vector3i(-1, 0, 0), [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0)]],
]
static var round_amt := 0.38   # síla zaoblení/sražení (0 = ostré kostky)
static var jitter := 0.10      # šum vrcholů v buňkách
static var bulge := 0.10       # vysunutí/zapuštění středu stěny

static func _h(a: int, b: int, c: int, d: int) -> float:
	var v := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	v = v ^ (v >> 16)
	return float(v & 0xFFFFFF) / 16777216.0

static func _hv(a: int, b: int, c: int, d: int) -> Vector3:
	return Vector3(_h(a, b, c, d) - 0.5, _h(a, b, c, d + 101) - 0.5, _h(a, b, c, d + 202) - 0.5) * 2.0

static func build(ch, seed: int, cell: Vector3) -> ArrayMesh:
	var lat := {}   # Vector3i -> [pozice (v buňkách), ao]
	var verts := PackedVector3Array(); var cols := PackedColorArray(); var uv2s := PackedVector2Array()
	var smooth := {}  # klíč polohy -> součet normál
	var tris: Array[int] = []
	for x in ch.nx:
		for z in ch.nz:
			for y in ch.ny:
				var m: int = ch.mat_at(x, y, z)
				if m == 0:
					continue
				var base: Color = Mat.COLORS[m]
				for f in FACES:
					var n: Vector3i = f[0]
					if ch.solid(x + n.x, y + n.y, z + n.z):
						continue
					var cs: Array = f[1]
					var pts: Array[Vector3] = []
					var aos: Array[float] = []
					var ids: Array[Vector3i] = []
					for i in 4:
						var li: Vector3i = Vector3i(x, y, z) + cs[i]
						ids.append(li)
						var lv: Array = _lattice(ch, li, seed, lat)
						pts.append(lv[0]); aos.append(lv[1])
					# rohy + středy hran (šum podle hrany, sdílený se sousední stěnou)
					var ring: Array[Vector3] = []
					var rao: Array[float] = []
					for i in 4:
						var a: Vector3i = ids[i]; var b: Vector3i = ids[(i + 1) % 4]
						var lo := a if (a.x + a.y * 1000 + a.z * 1000000) < (b.x + b.y * 1000 + b.z * 1000000) else b
						var hi := b if lo == a else a
						var mid: Vector3 = (pts[i] + pts[(i + 1) % 4]) * 0.5 + _hv(lo.x * 7 + hi.x, lo.y * 7 + hi.y, lo.z * 7 + hi.z, seed + 5) * jitter * 0.6
						ring.append(pts[i]); rao.append(aos[i])
						ring.append(mid); rao.append((aos[i] + aos[(i + 1) % 4]) * 0.5)
					var cen := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
					var r := _h(x, y, z, seed * 7 + n.x * 3 + n.y * 5 + n.z * 11)
					var off := (r - 0.45) * 2.0 * bulge
					if r < 0.18:
						off = -bulge * 1.6   # vpadlá stěna
					cen += Vector3(n) * off
					var cao := (aos[0] + aos[1] + aos[2] + aos[3]) * 0.25 * (0.9 if off < 0.0 else 1.0)
					for i in 8:
						for p in [[cen, cao], [ring[i], rao[i]], [ring[(i + 1) % 8], rao[(i + 1) % 8]]]:
							var pv: Vector3 = p[0]
							var k: float = p[1] * (0.95 + 0.07 * _h(x, z, y, 9))
							verts.append(pv * cell)
							cols.append(Color(base.r * k, base.g * k, base.b * k))
							uv2s.append(Vector2(m, 1.0))
	# hladké normály (pro obrys a stíny), fazety kreslí shader
	var norms := PackedVector3Array(); norms.resize(verts.size())
	for t in range(0, verts.size(), 3):
		var fn := (verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t])
		for j in 3:
			var key := (verts[t + j] * 1000.0).round()
			smooth[key] = smooth.get(key, Vector3.ZERO) + fn
	for i in verts.size():
		var s: Vector3 = smooth[(verts[i] * 1000.0).round()]
		norms[i] = s.normalized()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols; arr[Mesh.ARRAY_TEX_UV2] = uv2s
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## vrchol mřížky: posun ke středu plných buněk (zaoblení) + šum; ao = tmavší, když je kolem hodně plných buněk
static func _lattice(ch, li: Vector3i, seed: int, lat: Dictionary) -> Array:
	if lat.has(li):
		return lat[li]
	var cnt := 0
	var cen := Vector3.ZERO
	for dx in 2:
		for dy in 2:
			for dz in 2:
				var c := Vector3i(li.x - 1 + dx, li.y - 1 + dy, li.z - 1 + dz)
				if ch.solid(c.x, c.y, c.z):
					cnt += 1
					cen += Vector3(c) + Vector3(0.5, 0.5, 0.5)
	var p := Vector3(li)
	if cnt > 0 and cnt < 8:
		cen /= cnt
		var amt := round_amt if cnt <= 4 else round_amt * 0.4
		p += (cen - p) * amt
	var j := _hv(li.x, li.y, li.z, seed) * jitter
	if li.y == 0:
		j.y = 0.0
	p += j
	var ao := 1.0 - 0.38 * clampf((cnt - 4) / 4.0, 0.0, 1.0)
	var res := [p, ao]
	lat[li] = res
	return res
