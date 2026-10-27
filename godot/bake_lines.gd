extends Node

func _ready() -> void:
	var game = get_node("/root/Game")
	var all := {}
	for i in game.track_count():
		var def: Dictionary = game.track_def(i)
		var track := Track.new(def)
		track._make_line()
		var key := String(def.id) + ("_mirror" if bool(def.get("mirror", false)) else "")
		all[key] = {"n": track.n, "step": track.step, "line": Array(track._line), "curvature": Array(track._line_c)}
		print("BAKED ", key, " ", track.n)
	var f := FileAccess.open("res://racing_lines.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "sources": {"track.gd": FileAccess.get_sha256("res://scripts/track.gd"), "game.gd": FileAccess.get_sha256("res://scripts/game.gd")}, "tracks": all}))
	f.close()
	get_tree().quit()
