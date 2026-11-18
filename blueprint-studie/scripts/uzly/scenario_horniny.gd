extends Node
## Uzel ScenarioHorniny: geologie v2 (tabulka pořadí hornin), snímky 46_horniny_*.png s legendou.
## Spouští Scenario při --horniny; vkládání běží přes Placer (po snímcích, s ukazatelem průběhu).

const SC = preload("res://scripts/bp/scenario_horniny.gd")
const HR = preload("res://scripts/bp/horniny.gd")
const T = preload("res://scripts/bp/tests_horniny.gd")
const Mesher = preload("res://scripts/kopie/mesher.gd")

@export var svet: NodePath
@export var placer: NodePath
@export var views: NodePath
@export var ui: NodePath
@export var rig: NodePath
@export var legend: NodePath

@onready var S = get_node(svet)
@onready var P = get_node(placer)
@onready var V = get_node(views)
@onready var U = get_node(ui)
@onready var C = get_node(rig)
@onready var LG = get_node(legend)

func run() -> void:
	Mesher.PALETTE = HR.palette()
	S.params.geo = "v2"
	for e in SC.sequence():
		P.start(e[0], e[1])
		await P.finished
	var hc: String = S.world.hash()
	var hs: String = T.build(S.params).hash()
	var htxt := "hash po snímcích %s / naráz %s → %s" % [hc.left(12), hs.left(12), "STEJNÉ" if hc == hs else "RŮZNÉ!"]
	print(htxt)
	FileAccess.open(ProjectSettings.globalize_path("res://shots/hash_horniny.txt"), FileAccess.WRITE).store_string(htxt + "\n")
	# iso
	V.clear(); V.show_blocks(S.world.slots, {"wet": false})
	C.frame(Vector3(24, 18, 24), 64)
	U.say("Geologie v2: 8 blueprintů (hora vyzdvižená, prohlubeň, sopka | kopec, svah, louka | hora zvrásněná, kopec)\nhorniny podle tabulky pořadí 0–63 (Gemini pro Jana), %d aktivních vrstev\n%s" % [HR.all_layers(S.params).size(), htxt])
	LG.clear()
	await snap("iso")
	await cut("nizina", "y", 8, func(s): return s.y == 1, Vector3(24, 16, 24), 46,
		"Mírné kopce a nížina: (0,1) kopec | (1,1) svah | (2,1) louka, řez y = 8\nvrstvy zhruba kopírují povrch, hluboko skoro rovně\nbílý solný dóm na švu vlevo, tmavě zelený kimberlitový komín vpravo")
	var ypk := peak_y(Vector2i(0, 0))
	await cut("hora_vyzdvizena", "y", ypk, func(s): return s == Vector2i(0, 0) or s == Vector2i(1, 0), Vector3(16, 16, 8), 40,
		"Hora vyzdvižená (0,0) | prohlubeň (1,0), řez vrcholem (y = %d)\n" % ypk + "jádro z hluboké horniny až k vrcholu prorazí hlínu\na sedimenty, ty zbydou jen na úpatí; sníh nahoře;\npod prohlubní se vrstvy prohýbají")
	var ypz := peak_y(Vector2i(1, 2))
	await cut("hora_zvrasnena", "y", ypz, func(s): return s == Vector2i(1, 2) or s == Vector2i(2, 2), Vector3(32, 16, 40), 40,
		"Hora zvrásněná (1,2) | kopec (2,2), řez vrcholem (y = %d)\n" % ypz + "antiklinála: všechny vrstvy se klenou nahoru celé,\nhlubší vrstvy méně; nahoře horské horniny a sníh")
	await cut("sopka", "y", 8, func(s): return s == Vector2i(2, 0), Vector3(40, 16, 8), 38,
		"Sopka (2,0), řez y = 8 kráterem\nvrstvy se ke kráteru strmě zvedají a sbíhají,\nuprostřed sopouch (vulkanický kanál) až ke dnu kráteru")
	# rezervoár (kopec (2,2), VODA 60) a jeskyně (svah (1,1), VZDUCH 90): v bloku nejvýš jedna dutina (Jan 17:38)
	for sl in [Vector2i(2, 2), Vector2i(1, 1)]:
		var rr: Dictionary = S.world.slots[sl]
		for cv in rr.rep.cavities:
			if cv.centre == null: continue
			var yc := clampi(int((cv.centre.y - sl.y * 8.0) / 0.5), 0, 15)
			var zc: float = cv.centre.z
			var ctr := Vector3(sl.x * 16 + 8, zc, sl.y * 16 + 8)
			if cv.mat == 250:
				await cut("rezervoar", "y", yc, func(s): return s == sl, ctr, 22,
					"Kopec (2,2): VODA 60 v seznamu materiálů, řez y = %d\n" % yc + "jediná dutina bloku = podzemní rezervoár (modře):\nv nepropustné hornině, stěny, dno i strop ≥ 0,5 m, plný vody", S.world.slots, "_rezervoar", true)
			else:
				await cut("jeskyne", "y", yc, func(s): return s == sl, ctr, 22,
					"Svah (1,1): VZDUCH 90 v seznamu materiálů, řez y = %d\n" % yc + "jediná dutina bloku = jeskyně: v pevné hornině ≥ 2 m\npod povrchem, nosný strop ≥ 1 m, přednostně v karbonátu", S.world.slots, "_jeskyne", true)
	# klín (Jan 16:46/16:49): levý blok 1,2,4,5,6,7, pravý (nový) 1,3,5,6,7
	var wk = T.build(S.params, SC.klin_sequence())
	await cut("klin", "y", 8, func(s): return true, Vector3(16, 17, 88), 15,
		"Klín: levý blok vrstvy 1,2,4,5,6,7 | pravý (nový) 1,3,5,6,7, řez y = 8\n1 hlub. vápenec, 2 prachovec, 3 slepenec, 4 sádrovec,\n5 dolomit, 6 jíl. břidlice, 7 křem. pískovec;\n2 a 4 pokračují přes šev a vyklíní se, 3 naroste od švu", wk.slots, "_klin_rez")
	LG.clear()

func peak_y(slot: Vector2i) -> int:
	var hh: PackedInt32Array = S.world.slots[slot].hm
	var yp := 8; var best := -1
	for i in 256:
		if hh[i] > best: best = hh[i]; yp = i % 16
	return yp

func cut(name: String, axis: String, at: int, keep: Callable, center: Vector3, size: float, text: String, slots = null, file := "", wet := false) -> void:
	if slots == null: slots = S.world.slots
	V.clear()
	V.show_blocks(slots, {"cut_axis": axis, "cut": at, "keep": keep, "wet": wet})
	var ids := {}
	for s in slots:
		if not keep.call(s): continue
		var cells: PackedByteArray = slots[s].cells
		for c in cells.size():
			var x := c / 1024; var y := (c / 64) % 16
			if (axis == "y" and y == at) or (axis == "x" and x == at):
				ids[cells[c]] = true
	LG.show_ids(ids.keys())
	C.frame(center + Vector3(size * 0.28, 0, 0), size, Vector3(0.15, 0.3, 1.0) if axis == "y" else Vector3(1.0, 0.3, 0.15))
	U.say(text)
	await snap("rez_" + name, file)

func snap(name: String, file := "") -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var fn := ("res://shots/%s.png" % file) if file != "" else ("res://shots/46_horniny_%s.png" % name)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(fn))
	print("shot ", name)
