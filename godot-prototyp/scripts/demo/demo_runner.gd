extends Node
## Scéna demo.tscn: screenshoty, měření a nástroje mimo hlavní hru. Přepínače se nezměnily – main.tscn na tuto scénu
## při nich sám přesměruje, takže `godot --path . -- --demo` funguje jako dřív; přímo: `godot --path . res://demo.tscn -- --demo`.
## Herní dema instancují main.tscn a přidají svůj skript jako dítě uzlu Main (skript ho najde přes get_parent()).

const SCENE := "res://demo.tscn"
const MAIN_SCENE := "res://main.tscn"
const BlockGen = preload("res://scripts/block_gen.gd")
const Vectors = preload("res://scripts/vectors.gd")

## přepínač -> skript dema (první shoda vyhrává, pořadí jako dřív v main.gd)
const MODES := [
	[["--genv3-shots", "--genv3-bench"], "res://scripts/demo/genv3_demo.gd"],       # gen-v3 v prototypu: snímky 41_* / měření
	[["--flow-shots", "--flow-bench"], "res://scripts/demo/flow_demo.gd"],          # tok vody po kopání: snímky 42_* / měření
	[["--e66-shots", "--e66-bench"], "res://scripts/demo/e66_demo.gd"],             # E66 terén a voda ze studie: snímky 66_* / měření
	[["--skryti-shots", "--skryti-bench"], "res://scripts/demo/skryti_demo.gd"],    # skrytí podzemí na bocích a řezech
	[["--napojeni-shots", "--napojeni-bench"], "res://scripts/demo/napojeni_demo.gd"],  # povrch louka/písek/voda
	[["--grass-shots", "--grass-bench"], "res://scripts/demo/grass_demo.gd"],       # tráva C
	[["--demo", "--video"], "res://scripts/demo/main_demo.gd"],                     # hlavní demo 01–22, video
]
const TOOLS := ["--res-test", "--export-vectors"]

## je na příkazové řádce přepínač dema nebo nástroje?
static func wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in TOOLS:
		if a in args:
			return true
	for e in MODES:
		for a in e[0]:
			if a in args:
				return true
	return false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	BlockGen.apply_cli()   # -- --gen=proto|v3 (výchozí v3)
	if "--res-test" in args:
		# EXPERIMENT: srovnání rozlišení bloku (scripts/res_test.gd); hra se nespustí
		get_tree().root.add_child.call_deferred(load("res://scripts/res_test.gd").new())
		return
	if "--export-vectors" in args:
		Vectors.export_to(ProjectSettings.globalize_path("res://vectors/vectors.json"))
		Vectors.export_veg(ProjectSettings.globalize_path("res://vectors/veg_vectors.json"))
		Vectors.export_gen3(ProjectSettings.globalize_path("res://vectors/gen_v3_vectors.json"))
		get_tree().quit()
		return
	var main: Node = load(MAIN_SCENE).instantiate()
	add_child(main)   # Main._ready sestaví ostrov jako ve hře
	for e in MODES:
		for a in e[0]:
			if a in args:
				main.add_child(load(e[1]).new())
				return
	push_warning("demo.tscn: žádný přepínač dema (%s), běží jen hra" % ", ".join(TOOLS))
