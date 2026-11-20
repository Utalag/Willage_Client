extends RefCounted
## E91: průhlednost překážek v izometrii (studie, příznak p91_pruhlednost, výchozí VYPNUTO).
## Shadery na disku se nemění: při zapnutí se z každého ShaderMaterialu ve scéně vyrobí kopie shaderu
## s vloženým kódem (uniformy p91_*), při vypnutí se vrátí původní shader.
## Režimy (uniform p91_mode):
##   0 nic
##   1 A válec: fragment ve válci kolem paprsku postava → kamera se zahodí sítem 4 × 4 (dither), měkký okraj
##   2 B řez: fragment nad výškou p91_cut_y (v kruhu p91_cut_r kolem postavy) se zahodí
##   3 A + B
## Odvrácené stěny (vnitřek hory odhalený ořezem) se při p91_mode > 0 kreslí plochou barvou víka p91_cap.
## C (řez sítí na CPU) a C2 (skrytí celých bloků) nepotřebují shader: island.set_slice() a MeshInstance3D.visible.

const P := {
	"p91_pruhlednost": false,
	"p91_r": 3.0,          # poloměr válce (jednotky scény, buňka = 1 vodorovně, 0,5 svisle)
	"p91_soft": 1.25,      # měkký okraj válce
	"p91_margin": 0.4,     # od středu postavy k  kameře se do 0,4 nic nezahazuje (poloměr kapsle 0,35)
	"p91_floor": 0.2,      # pod nohama + tolik se válcem nic nezahazuje (zem pod postavou zůstane)
	"p91_ceil": 1.25,      # řez B: nad nohama postavy + tolik
	"p91_cut_r": 10.0,     # řez B: poloměr kruhu (velké číslo = všude)
	"p91_dither": true,
}

const MARK := "// E91 pruhlednost"

static var _orig := {}     # ShaderMaterial -> původní Shader
static var _cache := {}    # původní Shader -> upravený Shader
static var mats: Array[ShaderMaterial] = []

static func uniforms_code(dither: bool) -> String:
	var s := MARK + " (vloženo za běhu)\n"
	s += "uniform int p91_mode = 0;\n"
	s += "uniform vec3 p91_char = vec3(0.0);\n"        # nohy postavy (svět)
	s += "uniform float p91_char_h = 1.8;\n"
	s += "uniform vec3 p91_to_cam = vec3(0.0, 0.57, 0.82);\n"
	s += "uniform float p91_r = 3.0;\n"
	s += "uniform float p91_soft = 1.25;\n"
	s += "uniform float p91_margin = 0.4;\n"
	s += "uniform float p91_floor = 0.2;\n"
	s += "uniform float p91_cut_y = 100000.0;\n"
	s += "uniform float p91_cut_r = 100000.0;\n"
	s += "uniform vec3 p91_cap = vec3(0.30, 0.25, 0.22);\n"
	s += "float p91_keep(vec3 w, vec2 fc) {\n"
	s += "\tfloat drop = 0.0;\n"
	s += "\tif ((p91_mode & 1) != 0 && w.y > p91_char.y + p91_floor) {\n"
	s += "\t\tvec3 c = p91_char + vec3(0.0, p91_char_h * 0.5, 0.0);\n"
	s += "\t\tvec3 p = w - c;\n"
	s += "\t\tfloat al = dot(p, p91_to_cam);\n"
	s += "\t\tfloat pr = length(p - p91_to_cam * al);\n"
	s += "\t\tdrop = (1.0 - smoothstep(p91_r - p91_soft, p91_r, pr)) * smoothstep(p91_margin, p91_margin + 0.4, al);\n"
	s += "\t}\n"
	s += "\tif ((p91_mode & 2) != 0 && w.y > p91_cut_y && length(w.xz - p91_char.xz) < p91_cut_r) drop = 1.0;\n"
	if dither:
		s += "\tint ix = int(mod(fc.x, 4.0)); int iy = int(mod(fc.y, 4.0));\n"
		s += "\tconst float b[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);\n"
		s += "\treturn drop > (b[iy * 4 + ix] + 0.5) / 16.0 ? 0.0 : 1.0;\n"
	else:
		s += "\treturn drop > 0.5 ? 0.0 : 1.0;\n"
	s += "}\n"
	return s

## kód shaderu s vloženým ořezem; null = shader nelze upravit (ne spatial / bez fragment())
static func patch_code(code: String, dither: bool) -> String:
	if code.find(MARK) >= 0 or code.find("shader_type spatial") < 0:
		return ""
	var fi := code.find("void fragment()")
	if fi < 0:
		return ""
	var ob := code.find("{", fi)
	var depth := 0
	var cb := -1
	for i in range(ob, code.length()):
		var ch := code[i]
		if ch == "{": depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				cb = i; break
	if cb < 0:
		return ""
	var head := "\n\tif (p91_mode > 0 && p91_keep((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, FRAGCOORD.xy) < 0.5) discard;\n"
	var tail := "\n\tif (p91_mode > 0 && !FRONT_FACING) { ALBEDO = p91_cap; }\n"
	var out := code.substr(0, fi) + uniforms_code(dither) + code.substr(fi, ob + 1 - fi) + head
	out += code.substr(ob + 1, cb - ob - 1) + tail + code.substr(cb)
	# odvrácené stěny musí jít vidět (víko); obrysy s cull_front nechat
	var rm := out.find("render_mode")
	if rm >= 0:
		var eol := out.find(";", rm)
		var line := out.substr(rm, eol - rm)
		if line.find("cull_") < 0:
			out = out.substr(0, eol) + ", cull_disabled" + out.substr(eol)
	else:
		var st := out.find(";", out.find("shader_type")) + 1
		out = out.substr(0, st) + "\nrender_mode cull_disabled;" + out.substr(st)
	return out

static func _patched(sh: Shader, dither: bool) -> Shader:
	if _cache.has(sh):
		return _cache[sh]
	var code := patch_code(sh.code, dither)
	var ns: Shader = null
	if code != "":
		ns = Shader.new()
		ns.code = code
	_cache[sh] = ns
	return ns

static func _collect(n: Node, out: Dictionary, skip: Array) -> void:
	if n in skip:
		return
	if n is GeometryInstance3D:
		var arr := [n.material_override, n.material_overlay]
		if n is MeshInstance3D:
			for i in n.get_surface_override_material_count():
				arr.append(n.get_surface_override_material(i))
			if n.mesh:
				for i in n.mesh.get_surface_count():
					arr.append(n.mesh.surface_get_material(i))
		if n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			for i in n.multimesh.mesh.get_surface_count():
				arr.append(n.multimesh.mesh.surface_get_material(i))
		for m in arr:
			while m != null:
				if m is ShaderMaterial and m.shader:
					out[m] = true
				m = m.next_pass if m is Material else null
	for c in n.get_children():
		_collect(c, out, skip)

## zapne: všechny ShaderMaterialy pod root (mimo skip) dostanou upravený shader; vrací počet materiálů
static func enable(root: Node, skip: Array = [], dither := true) -> int:
	var found := {}
	_collect(root, found, skip)
	var n := 0
	for m in found:
		if _orig.has(m):
			continue
		var ps := _patched(m.shader, dither)
		if ps == null:
			continue
		_orig[m] = m.shader
		m.shader = ps
		mats.append(m)
		n += 1
	return n

static func disable() -> void:
	for m in mats:
		if _orig.has(m):
			m.set_shader_parameter("p91_mode", 0)
			m.shader = _orig[m]
	_orig.clear()
	mats.clear()

## nastaví uniformy všem upraveným materiálům
static func set_params(mode: int, feet: Vector3, to_cam: Vector3, prm: Dictionary) -> void:
	for m in mats:
		m.set_shader_parameter("p91_mode", mode)
		m.set_shader_parameter("p91_char", feet)
		m.set_shader_parameter("p91_to_cam", to_cam.normalized())
		m.set_shader_parameter("p91_r", prm.get("p91_r", P.p91_r))
		m.set_shader_parameter("p91_soft", prm.get("p91_soft", P.p91_soft))
		m.set_shader_parameter("p91_margin", prm.get("p91_margin", P.p91_margin))
		m.set_shader_parameter("p91_floor", prm.get("p91_floor", P.p91_floor))
		m.set_shader_parameter("p91_cut_y", feet.y + prm.get("p91_ceil", P.p91_ceil) if mode & 2 else 100000.0)
		m.set_shader_parameter("p91_cut_r", prm.get("p91_cut_r", P.p91_cut_r))

## postava je v podzemí, když nad hlavou je pevný sloupec (výška terénu > hlava); hm_at(x, z) -> výška ve scéně
static func underground(feet: Vector3, char_h: float, hm_at: Callable) -> bool:
	return float(hm_at.call(feet.x, feet.z)) > feet.y + char_h + 0.01

## C2: bloky, jejichž obal paprsek postava → kamera protne nad úrovní nohou (krok 0,25)
static func blocks_on_ray(feet: Vector3, char_h: float, to_cam: Vector3, slots: Array, bs: int, top: float, own: Vector2i) -> Array:
	var out := {}
	var c := feet + Vector3(0, char_h * 0.5, 0)
	var d := to_cam.normalized()
	var t := 1.0
	while t < 200.0:
		var q := c + d * t
		if q.y > top:
			break
		var s := Vector2i(floori(q.x / bs), floori(q.z / bs))
		if s != own and s in slots:
			out[s] = true
		t += 0.25
	return out.keys()
