extends SceneTree
## Krok 5: kouřový test fasády VodaV1 v Godotu – C# geologie (nastav) proti mostu do GDScriptu (nastav_gd, opravy se mostu netýkají).
## Hladina v 25 bodech mimo pás švu a mimo sopky musí být bitově stejná; prameny bloku 13,13 z C#.
func _init() -> void:
	var cs = load("res://scripts/cs/most/VodaV1.cs").new()
	var gd = load("res://scripts/cs/most/VodaV1.cs").new()
	var t := Time.get_ticks_usec()
	cs.Nastav(49)
	gd.NastavGd(49)
	var shod := 0; var n := 0
	for i in 5:
		for j in 5:
			var x := 1792.0 + 40.0 + i * 12.3; var y := 1792.0 + 40.0 + j * 11.7
			n += 1
			if cs.Hladina(x, y) == gd.Hladina(x, y): shod += 1
	print("hladina C# = GDScript: %d / %d" % [shod, n])
	var pr = cs.PramenyBloku(13, 13)
	print("prameny bloku 13,13 (C#): %d" % pr.size())
	for p in pr: print("  ", p)
	print("ms ", (Time.get_ticks_usec() - t) / 1000.0)
	quit(0 if shod == n else 1)
