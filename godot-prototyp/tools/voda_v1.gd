extends SceneTree
## Krok 4 (V1.0): spustí C# běžce testů (scripts/cs/testy/Krok04Beh.cs) – vyžaduje Godot .NET (mono).
## --rezim=vse|det|cas --out=adresář --seed=N
func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="): return s.split("=", true, 1)[1]
	return d

func _init() -> void:
	var beh = load("res://scripts/cs/testy/Krok04Beh.cs").new()
	var chyb: int = beh.Spust(_arg("rezim", "vse"), _arg("out", "/tmp/k4"), int(_arg("seed", "49")))
	quit(1 if chyb > 0 else 0)
