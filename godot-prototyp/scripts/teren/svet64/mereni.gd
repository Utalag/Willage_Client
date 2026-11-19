extends RefCounted
## KOPIE z blueprint-studie/scripts/svet64/mereni.gd (E66, tools/port_studie.py): změněné jen cesty preload / data / výstupy.
## E50 měření: čas na stěnu a paměť procesu (RSS a peak z /proc/self/status; Godot statická paměť zvlášť).

static func ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0

## {rss_mb, peak_mb, godot_mb} – VmRSS, VmHWM (peak RSS od startu), OS.get_static_memory_usage
static func mem() -> Dictionary:
	var out := []
	OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], out)
	var r := {"rss_mb": 0.0, "peak_mb": 0.0, "godot_mb": OS.get_static_memory_usage() / 1048576.0}
	for line in String(out[0] if not out.is_empty() else "").split("\n"):
		if line.begins_with("VmRSS:"): r.rss_mb = float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
		if line.begins_with("VmHWM:"): r.peak_mb = float(line.split(":")[1].strip_edges().split(" ")[0]) / 1024.0
	return r

static func stats(v: Array) -> Dictionary:
	var a := v.duplicate(); a.sort()
	if a.is_empty(): return {"min": 0.0, "med": 0.0, "max": 0.0, "sum": 0.0}
	var s := 0.0
	for x in a: s += float(x)
	return {"min": float(a[0]), "med": float(a[a.size() / 2]), "max": float(a[-1]), "sum": s}
