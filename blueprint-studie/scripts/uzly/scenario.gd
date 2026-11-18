extends Node
## Uzel Scenario: ukázkový sled vložení. Režimy (za --): --shots (snímky 45_blueprint_*), --test (testy bez okna),
## bez přepínače = sled po snímcích s ukazatelem průběhu (okno / editor).

const Mat = preload("res://scripts/kopie/mat.gd")
const SC = preload("res://scripts/bp/scenario_data.gd")
const PL = preload("res://scripts/bp/pipeline.gd")
const T = preload("res://scripts/bp/tests.gd")
const NV = preload("res://scripts/bp/naive.gd")
const BP = preload("res://scripts/bp/blueprint.gd")

@export var svet: NodePath
@export var placer: NodePath
@export var views: NodePath
@export var preview: NodePath
@export var ui: NodePath
@export var rig: NodePath

@onready var S = get_node(svet)
@onready var P = get_node(placer)
@onready var V = get_node(views)
@onready var G = get_node(preview)
@onready var U = get_node(ui)
@onready var C = get_node(rig)

func run() -> void:
	P.progress.connect(U.on_progress)
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		print("\n".join(T.run_all(S.params, ProjectSettings.globalize_path("res://shots/bench.txt"))))
		get_tree().quit(); return
	if "--horniny" in args or "--horniny-test" in args:
		await get_node("../ScenarioHorniny").run()
		get_tree().quit(); return
	if "--shots" in args:
		await shots()
		get_tree().quit(); return
	for e in SC.sequence():
		await place(e[0], e[1])
	iso("Hotovo: 5 blueprintů")

func place(slot: Vector2i, bp: Dictionary) -> Dictionary:
	P.start(slot, bp)
	var rec: Dictionary = await P.finished
	V.clear(); V.show_blocks(S.world.slots)
	return rec

func _bp_text(bp: Dictionary) -> String:
	var m := []
	for k in bp.minerals:
		m.append("%s %d" % [Mat.NAMES[k], bp.minerals[k]])
	return "%s (seed %d): %s, rarita z minerálů %.0f b." % [bp.shape, bp.seed, ", ".join(m), BP.rarity_points(bp)]

func iso(text: String) -> void:
	C.frame(Vector3(24, 14, 24), 62)
	U.say(text)

func snap(name: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://shots/45_blueprint_%s.png" % name)
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", name)

func shots() -> void:
	S.params = preload("res://scripts/bp/params.gd").v1(S.params)
	var seq := SC.sequence()
	var t0 := Time.get_ticks_msec()
	await place(seq[0][0], seq[0][1])
	await place(seq[1][0], seq[1][1])
	# náhled svahu v mezeře: nejdřív šablona, pak dorovnané okraje
	var ctx := PL.new_ctx(S.world, seq[2][0], seq[2][1], S.params)
	for st in PL.preview_steps(ctx):
		st[1].call()
	G.show_ghost(ctx, true)
	C.frame(Vector3(24, 14, 24), 42)
	U.say("Náhled blueprintu ve slotu (1,1) mezi dvěma bloky – ŠABLONA bez dorovnání\n" + _bp_text(seq[2][1]) + "\nokraje šablony nesedí na sousedy (skok až %d buněk)" % _max_jump(ctx, true))
	await snap("nahled_sablona")
	G.show_ghost(ctx, false)
	var nch := 0
	for i in 256: nch += ctx.changed[i]
	U.say("Náhled po dorovnání okrajů (pás %d buněk od sousedů, oranžově změněné sloupce: %d, vnitřek beze změny)\n" % [S.params.band, nch] + _bp_text(seq[2][1]) + "\nskok povrchu na švu %d buněk" % _max_jump(ctx, false))
	await snap("nahled")
	G.clear()
	# potvrzení: vložení po snímcích s ukazatelem, snímek v půlce
	S.params.budget_ms = 0.5
	P.start(seq[2][0], seq[2][1])
	while true:
		var a = await P.progress
		if a[0] >= 0.45:
			break
	P.paused = true
	U.say("Potvrzeno: blok se usazuje (výpočet běží po snímcích, hra nezamrzne)\n" + _bp_text(seq[2][1]))
	await snap("prubeh")
	P.paused = false
	await P.finished
	S.params.budget_ms = 6.0
	V.clear(); V.show_blocks(S.world.slots)
	await place(seq[3][0], seq[3][1])
	await place(seq[4][0], seq[4][1])
	var chunked: String = S.world.hash()
	var sync: String = T.build(S.params).hash()
	var htxt := "hash po snímcích %s, naráz %s → %s" % [chunked.left(12), sync.left(12), "STEJNÉ" if chunked == sync else "RŮZNÉ!"]
	print(htxt)
	FileAccess.open(ProjectSettings.globalize_path("res://shots/hash_snimky.txt"), FileAccess.WRITE).store_string(htxt + "\n")
	var lines := []
	for s in S.world.order:
		var r: Dictionary = S.world.slots[s]
		lines.append("%d. %s %s" % [r.order + 1, str(s), r.bp.shape])
	iso("5 blueprintů na mřížce 3 × 3 (pořadí: %s)\nvrstvy sousedů pokračují do nových bloků, minerály přesně, voda vsáknutá (gen-v3)\n%s" % [", ".join(lines), htxt])
	await snap("iso")
	# řez řadou y = 1 (švy (0,1)|(1,1)|(2,1)) – blueprint nahoře, nezávislé gen-v3 dole
	V.clear()
	V.show_blocks(S.world.slots, {"cut_axis": "y", "cut": 8, "keep": func(s): return s.y == 1})
	C.frame(Vector3(24, 15, 24), 36, Vector3(0.15, 0.3, 1.0))
	U.say("Řez řadou bloků (0,1) | (1,1) | (2,1) v y = 8: vrstvy čedič–žula–vápenec–jíl–písek procházejí švy;\nmezi kopcem a loukou je svah vložený do mezery\ntyrkys = měď v žule, červená = železo, oranžová = ložiskový jíl, fialově mokrá hlína, modře mokrý písek (vsáknutá voda)")
	await snap("rez_x")
	var nv := {}
	for s in S.world.slots:
		nv[s] = NV.block(S.world.slots[s])
	V.clear()
	V.show_blocks(S.world.slots, {"cut_axis": "y", "cut": 8, "keep": func(s): return s.y == 1, "lift": 0.0, "wet": false})
	V.show_blocks(nv, {"cut_axis": "y", "cut": 8, "keep": func(s): return s.y == 1, "lift": -32.0})
	C.frame(Vector3(24, -1, 24), 66, Vector3(0.12, 0.25, 1.0))
	U.say("Srovnání řezu y = 8, stejný povrch i stejné počty materiálů:\nNAHOŘE blueprint (vrstvy navázané na sousedy) · DOLE nezávislé bloky gen-v3 (vrstvy na švech skáčou)")
	await snap("rez_srovnani")
	V.clear()
	V.show_blocks(S.world.slots, {"cut_axis": "x", "cut": 8, "keep": func(s): return s.x == 1})
	C.frame(Vector3(24, 15, 16), 34, Vector3(1.0, 0.3, 0.12))
	U.say("Řez bloky (1,1) svah VLEVO | (1,0) prohlubeň VPRAVO v x = 8: vrstvy pokračují přes šev,\nprohlubeň uřízne horní vrstvy; modře jezírko z vsakování gen-v3, tmavě fialově nasycená hlína")
	await snap("rez_y")
	print("snímky hotové za %d ms" % (Time.get_ticks_msec() - t0))

func _max_jump(ctx: Dictionary, raw: bool) -> int:
	const SD = preload("res://scripts/bp/sides.gd")
	var hm: PackedInt32Array = ctx.hm_raw if raw else ctx.hm
	var mx := 0
	for d in 4:
		var nb = S.world.neighbour(ctx.slot, d)
		if nb == null: continue
		for t in 16:
			var o := SD.own(d, t); var q := SD.nb(d, t)
			mx = maxi(mx, absi(hm[o.x * 16 + o.y] - nb.hm[q.x * 16 + q.y]))
	return mx
