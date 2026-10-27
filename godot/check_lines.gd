extends Node

func _ready() -> void:
	var game = get_node("/root/Game")
	for i in game.track_count():
		var track := Track.new(game.track_def(i))
		track._load_baked_line()
		if track._line_task != -2:
			push_error("Failed to load racing line for track %d" % i)
			get_tree().quit(1)
			return
		var baked := track._line.duplicate()
		var curvature := track._line_c.duplicate()
		track._make_line()
		if baked != track._line or curvature != track._line_c:
			push_error("Precomputed racing line differs for track %d" % i)
			get_tree().quit(1)
			return
		print("LINE CHECK OK ", i)
	get_tree().quit()
