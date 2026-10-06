extends Node
## Entry point: menu with a live demo race behind it, starting races
## (solo, split-screen, Wi-Fi), Android back button and test modes.

var ui_root: Control
var race: Race
var menu: Menu
var last_players := 1
var _test_t := 0.0
var _test_mode := ""
var _shot_path := ""
var _shot_delay := 0.0
var _done_at := -1.0
var fps_label: Label
var _fps_time := 0.0
var _fps_frames := 0
var _fps_worst := 0.0
var _bench: PackedFloat32Array = PackedFloat32Array()
var _bench_last := 0
var _fade: ColorRect
var _air_t := 0.0
var _fade_tw: Tween
var _fading := false
var _bench_draws := 0
var _bench_prims := 0
# the championship being driven: {players, diff, round, roster, points}; empty = none
var cup := {}
var trial := false      # the last race started was a time trial
var _trial_runs := 0
var _jump_track := 0
var _items_phase := 0
var _ai_track := 0
var _ai_sum := {}
var _ai_drifts := 0
var _items_bad := 0
var _jump_bad := 0


func _ready() -> void:
	UI.init()
	ui_root = Control.new()
	ui_root.theme = UI.theme
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	menu = Menu.new()
	ui_root.add_child(menu)
	menu.start_offline.connect(func(n: int): fade_to(start_offline.bind(n)))
	menu.start_cup.connect(func(n: int): fade_to(start_cup.bind(n)))
	menu.start_trial.connect(func(): fade_to(start_trial))
	menu.quit_requested.connect(func(): get_tree().quit())
	menu.track_changed.connect(_start_demo)
	menu.quality_changed.connect(_start_demo)
	_make_fps_label()
	_make_fader()
	var ring_layer := CanvasLayer.new()
	ring_layer.layer = 55
	add_child(ring_layer)
	ring_layer.add_child(FocusRing.new())
	Net.race_started.connect(_on_net_race)
	Net.back_to_lobby.connect(_on_back_to_lobby)
	Net.session_ended.connect(_on_session_ended)
	Net.peer_left.connect(_on_peer_left)
	Net.snapshot_received.connect(_on_snapshot)
	Net.cup_points.connect(func(pts: Dictionary):
		if race != null:
			race.net_points = pts)
	var a := Game.cmd_args
	if a.has("track"):
		Game.settings.track = clampi(int(a.track), 0, Game.TRACKS.size() - 1)
	if a.has("quality"):
		Game.settings.quality = clampi(int(a.quality), 0, 2)   # not saved
	if a.has("fps"):
		Game.settings.show_fps = true
	if a.has("cursor"):
		FocusRing.shown = true   # screenshots: the gamepad cursor, moved --cursor=N steps on
	if a.has("timescale"):
		Engine.time_scale = float(a.timescale)   # slow motion for effect screenshots
	if a.has("trackinfo"):
		# heights of every track: range, steepest slope and bank, the jump
		for i in Game.TRACKS.size():
			var tr := Race.get_track(i)
			var lo := INF
			var hi := -INF
			var sl := 0.0
			var bk := 0.0
			var crest := 0.0
			for j in tr.n:
				lo = minf(lo, tr.y[j])
				hi = maxf(hi, tr.y[j])
				sl = maxf(sl, absf(tr.slope[j]))
				bk = maxf(bk, absf(tr.bank[j]))
				var c := -(tr.y[(j + 1) % tr.n] - 2.0 * tr.y[j] + tr.y[(j - 1 + tr.n) % tr.n]) / (tr.step * tr.step)
				crest = maxf(crest, c)
			# closest approach of two parts of the lap far apart along it, sharpest bend
			var gap := INF
			var bend := 0.0
			for j in range(0, tr.n, 2):
				bend = maxf(bend, absf(tr.curv[j]))
				for q in range(j + 2, tr.n, 2):
					var dd := absi(q - j)
					if mini(dd, tr.n - dd) * tr.step > 120.0:
						gap = minf(gap, Vector2(tr.x[j] - tr.x[q], tr.z[j] - tr.z[q]).length())
			# the racing line: how long it takes to make, its sharpest bend, how wide it swings
			var t0 := Time.get_ticks_usec()
			tr.line_now()
			var lc := tr.line_curv()
			var line_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var lbend := 0.0
			var swing := 0.0
			for q in tr.n:
				lbend = maxf(lbend, absf(lc[q]))
				swing = maxf(swing, absf(tr.racing_line()[q]))
			# bends long and sharp enough for a drift turbo: turning >= 90° at a radius under 44 m
			var long_bends := 0
			var q0 := 0
			while q0 < tr.n:
				var ang := 0.0
				var q := q0
				var sgn := signf(lc[q0])
				while q < q0 + tr.n and signf(lc[q % tr.n]) == sgn and absf(lc[q % tr.n]) > 1.0 / 44.0:
					ang += absf(lc[q % tr.n]) * tr.step
					q += 1
				if ang >= PI * 0.5:
					long_bends += 1
				q0 = maxi(q, q0 + 1)
			# whole bends of the centre line (one direction, tighter than r=150 m) by how far they turn
			var turns: Array = []
			q0 = 0
			while q0 < tr.n:
				var ang2 := 0.0
				var q2 := q0
				var sg2 := signf(tr.curv[q0])
				while q2 < q0 + tr.n and signf(tr.curv[q2 % tr.n]) == sg2 and absf(tr.curv[q2 % tr.n]) > 1.0 / 150.0:
					ang2 += absf(tr.curv[q2 % tr.n]) * tr.step
					q2 += 1
				if ang2 > 0.5:
					turns.append("%d°/%dm" % [int(rad_to_deg(ang2)), int((q2 - q0) * tr.step)])
				q0 = maxi(q2, q0 + 1)
			print("BENDS %s: %d long bends for a drift turbo; bends: %s" % [tr.def.id, long_bends, ", ".join(turns)])
			print("LINE %s: sharpest bend r=%.0f m (centre line r=%.0f m), swings %.1f m from the centre, made in %.0f ms" % [
				tr.def.id, 1.0 / maxf(lbend, 1e-6), 1.0 / maxf(bend, 1e-6), swing, line_ms])
			# a crest throws a kart at speed v into the air when v*v*crest > gravity
			print("TRACK %s len=%d y=%.1f..%.1f slope=%.3f bank=%.3f lift_at=%.0f m/s gap=%.0f m bend_r=%.0f m ramp at %.0f m lake=%s" % [
				tr.def.id, tr.length, lo, hi, sl, bk, sqrt(Game.GRAVITY / maxf(crest, 1e-6)), gap, 1.0 / maxf(bend, 1e-6),
				float(tr.ramp.get("i", 0)) * tr.step, str(not tr.lake.is_empty())])
		get_tree().quit()
		return
	if a.has("bench"):
		# fixed demo race, frame times measured after a warm-up
		_test_mode = "bench"
		menu.visible = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_start_demo()
		return
	if a.has("showcase"):
		# karts parked for screenshots, camera set after the race moves it
		process_priority = 100
		menu.visible = false
		_start_demo()
	if a.has("screenshot"):
		_shot_path = String(a.screenshot)
		_shot_delay = float(a.get("delay", "4"))
	if a.has("trialtest"):
		# two time trials in a row: the first saves a ghost, the second races it
		_test_mode = "trial"
		var gp := Game.ghost_path(int(Game.settings.track), int(Game.settings.diff))
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(gp))
		Game.settings.trials.erase(Game.record_key(int(Game.settings.track), int(Game.settings.diff)))
		start_trial()
		return
	if a.has("cuptest"):
		# a whole championship with the autopilot: every round must finish.
		# --cup-start=5 jumps to a later round (made-up points), --shot-round=N
		# takes the screenshot on that round's results
		_test_mode = "cup"
		start_cup(int(a.get("players", "1")))
		if a.has("cup-start"):
			var pts := 30
			for r in cup.roster:
				cup.points[int(r.driver)] = pts
				pts -= 4
			cup.round = int(a["cup-start"])
			_start_cup_round()
		return
	if a.has("aitest"):
		# the computer drivers alone on every track (the player's kart too):
		# lap times, turbos from drifts, how often they got stuck
		_test_mode = "ai"
		menu.visible = false
		Game.settings.diff = clampi(int(a.get("diff", "2")), 0, 2)   # not saved
		_ai_track = int(a.get("track", "0"))
		_start_ai_race()
		return
	if a.has("itemtest"):
		# every new item in a set-up situation, then a whole race where the
		# items are handed out in turn and the drivers use them
		_test_mode = "items"
		menu.visible = false
		start_offline(1)
		race.fast = int(a.get("fast", "8"))
		for k in race.locals:
			k.autopilot = true
		return
	if a.has("jumptest"):
		# one lap on every track, all six karts on autopilot with endless turbo
		# or star: they may only take off from the ramp
		_test_mode = "jump"
		Kart.log_takeoffs = true
		_jump_track = 0
		_start_jump_race()
		return
	if a.has("autotest"):
		_test_mode = "autotest"
		menu.visible = false
		start_offline(int(a.get("players", "1")))
		race.fast = int(a.get("fast", "6"))
		for k in race.locals:
			k.autopilot = true
		return
	if a.has("disctest"):
		_test_mode = "discovery"
		menu.visible = false
		Net.start_listening()
		return
	if a.has("nettest"):
		_test_mode = "net_" + String(a.nettest)
		Net.join_failed.connect(func(reason: String): print("JOIN FAILED: ", reason))
		menu.visible = false
		_start_demo()
		if a.nettest == "host":
			Net.host("Hostitel", 0)
			Net.cup_mode = a.has("cup")   # --cup: a championship (--cup-start=4: only the last races)
		else:
			Net.join("127.0.0.1", "Klient", 1)
		return
	if a.has("showcase"):
		return
	menu.setup_mode = String(a.get("mode", "race"))   # screenshots of the setup screen (race, cup, trial)
	show_menu(String(a.get("screen", "home")))
	if a.has("host"):
		menu._host()
		Net.set_cup_mode(a.has("cup"))
	if a.has("trial"):
		start_trial()
		race.fast = int(a.get("fast", "1"))
		if a.has("autopilot"):
			race.locals[0].autopilot = true
	elif a.has("race"):
		start_offline(int(a.get("players", "1")))
		race.fast = int(a.get("fast", "1"))
		if a.has("autopilot"):
			for k in race.locals:
				k.autopilot = true


## Black curtain over everything for switching between menu and race.
## Hidden when not fading: even see-through it would cost a full-screen blend.
func _make_fader() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.05, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP   # no clicks while it is shown
	_fade.visible = false
	layer.add_child(_fade)


## Fades to black, runs cb (e.g. starts the race) and fades back in.
func fade_to(cb: Callable) -> void:
	if _fading:
		return
	_fading = true
	var tw := _fade_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.22)
	tw.tween_callback(cb)
	tw.tween_callback(func(): _fading = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(_fade.hide)


## Fade back in from black after an instant switch.
func fade_in() -> void:
	if _fading:
		return
	var tw := _fade_tween()
	_fade.color.a = 1.0
	tw.tween_property(_fade, "color:a", 0.0, 0.4)
	tw.tween_callback(_fade.hide)


func _fade_tween() -> Tween:
	if _fade_tw != null:
		_fade_tw.kill()
	_fade.visible = true
	_fade_tw = create_tween()
	return _fade_tw


## Small FPS readout at the bottom centre, switched on in the menu or pause.
func _make_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	fps_label = UI.label("", 15, UI.PAPER, UI.bold_font)
	var bg := UI.box(Color(0.05, 0.07, 0.1, 0.7), 8, 0, Color(0, 0, 0, 0))
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	fps_label.add_theme_stylebox_override("normal", bg)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.anchor_left = 0.5
	fps_label.anchor_right = 0.5
	fps_label.anchor_top = 1.0
	fps_label.anchor_bottom = 1.0
	fps_label.offset_left = -170
	fps_label.offset_right = 170
	fps_label.offset_top = -34
	fps_label.offset_bottom = -8
	layer.add_child(fps_label)


func _update_fps(delta: float) -> void:
	fps_label.visible = bool(Game.settings.show_fps)
	if not fps_label.visible:
		return
	_fps_time += delta
	_fps_frames += 1
	_fps_worst = maxf(_fps_worst, delta)
	if _fps_time >= 0.5:
		fps_label.text = "%d FPS · %.1f ms · nejhorší %.0f ms · %s" % [
			int(round(_fps_frames / _fps_time)), _fps_time / _fps_frames * 1000.0, _fps_worst * 1000.0, Gfx.level_name()]
		_fps_time = 0.0
		_fps_frames = 0
		_fps_worst = 0.0


func show_menu(screen: String) -> void:
	_start_demo()
	menu.visible = true
	menu.show_screen(screen)


func _clear_race() -> void:
	if race != null:
		race.dispose()
		race.queue_free()
		race = null


func _new_race() -> Race:
	_clear_race()
	race = Race.new()
	ui_root.add_child(race)
	ui_root.move_child(race, 0)
	race.restart_requested.connect(func(): fade_to(_restart))
	race.menu_requested.connect(func(): fade_to(_on_race_menu))
	race.cup_next_requested.connect(func(pts: Dictionary):
		if Net.active:
			Net.next_cup_round(pts)   # the host starts the next race for everybody
		else:
			fade_to(_next_cup_round.bind(pts)))
	race.lobby_requested.connect(func(): Net.return_to_lobby())
	return race


func _start_demo() -> void:
	var roster: Array = []
	var ids := range(Game.CHARS.size())
	ids.shuffle()
	for i in ids:
		roster.append({"driver": i, "human": false, "peer": 0, "name": ""})
	_new_race().start(Race.Mode.DEMO, int(Game.settings.track), 1, roster)


func start_offline(players: int) -> void:
	cup = {}
	trial = false
	var roster := _offline_roster(players)
	menu.visible = false
	_new_race().start(Race.Mode.OFFLINE, int(Game.settings.track), int(Game.settings.diff), roster)


## A championship: every track once with the same six drivers, points
## after each race; the grid of the next race is the standings reversed.
func start_cup(players: int) -> void:
	trial = false
	var roster := _offline_roster(players)
	var pts := {}
	for r in roster:
		pts[int(r.driver)] = 0
	cup = {"players": players, "diff": int(Game.settings.diff), "round": 0, "roster": roster, "points": pts}
	_start_cup_round()


func _start_cup_round() -> void:
	menu.visible = false
	var r := _new_race()
	r.cup = cup
	r.start(Race.Mode.OFFLINE, int(cup.round), int(cup.diff), cup.roster)
	if _test_mode == "cup":
		r.fast = int(Game.cmd_args.get("fast", "8"))
		for k in r.locals:
			k.autopilot = true


## Time trial: you alone on the chosen track against the ghost of your best drive.
func start_trial() -> void:
	cup = {}
	trial = true
	last_players = 1
	menu.visible = false
	var d := int(Game.settings.driver)
	var r := _new_race()
	r.trial = true
	r.start(Race.Mode.OFFLINE, int(Game.settings.track), int(Game.settings.diff),
		[{"driver": d, "human": true, "peer": 0, "local": 0, "name": Game.player_name()}])
	if _test_mode == "trial":
		r.fast = int(Game.cmd_args.get("fast", "8"))
		r.locals[0].autopilot = true


## "Restart" from the pause menu or the results: the same race again, in a
## championship the same round; after its last race a new championship.
func _restart() -> void:
	if trial:
		start_trial()
	elif cup.is_empty():
		start_offline(last_players)
	elif race != null and race.results_shown and int(cup.round) >= Game.TRACKS.size() - 1:
		start_cup(last_players)
	else:
		_start_cup_round()


func _next_cup_round(race_points: Dictionary) -> void:
	for d in race_points:
		cup.points[d] = int(cup.points.get(d, 0)) + int(race_points[d])
	cup.round = int(cup.round) + 1
	if int(cup.round) >= Game.TRACKS.size():
		_on_race_menu()
		return
	# fewest points at the front of the grid, the leader at the back
	var order: Array = cup.roster.duplicate()
	var pos := {}
	for i in order.size():
		pos[int(order[i].driver)] = i
	order.sort_custom(func(a, b):
		var pa := int(cup.points[int(a.driver)])
		var pb := int(cup.points[int(b.driver)])
		return pa < pb if pa != pb else pos[int(a.driver)] < pos[int(b.driver)])
	cup.roster = order
	_start_cup_round()


## Six drivers: the local players at the back of the grid, the others
## (computer drivers) shuffled in front.
func _offline_roster(players: int) -> Array:
	last_players = players
	var humans: Array = []
	var d1 := int(Game.settings.driver)
	humans.append({"driver": d1, "human": true, "peer": 0, "local": 0,
		"name": Game.player_name() if players == 1 else "Hráč 1"})
	if players == 2:
		var d2 := int(Game.settings.driver2)
		if d2 == d1:
			d2 = (d1 + 1) % Game.CHARS.size()
		humans.append({"driver": d2, "human": true, "peer": 0, "local": 1, "name": "Hráč 2"})
	var used := {}
	for h in humans:
		used[h.driver] = true
	var ai: Array = []
	for i in Game.CHARS.size():
		if not used.has(i):
			ai.append({"driver": i, "human": false, "peer": 0, "name": ""})
	ai.shuffle()
	return ai.slice(0, Game.MAX_KARTS - humans.size()) + humans


func _on_net_race(track: int, diff: int, roster: Array, cupd: Dictionary) -> void:
	var me := Net.my_id()
	var r: Array = []
	for e in roster:
		var d: Dictionary = e.duplicate()
		d.local = 0 if bool(d.human) and int(d.peer) == me else -1
		r.append(d)
	menu.visible = false
	Net.stop_listening()
	var nr := _new_race()
	nr.cup = cupd
	nr.start(Race.Mode.HOST if Net.is_host else Race.Mode.CLIENT, track, diff, r)
	fade_in()   # no fade out first: the host's countdown must not wait
	if _test_mode != "":
		# each side's own kart drives itself; the client's goes through the
		# network as a player's would (controls to the host, prediction)
		for k in race.karts:
			if k.human and k.local_slot >= 0:
				k.autopilot = true
		race.fast = 1


func _on_snapshot(d: PackedFloat32Array) -> void:
	if race != null and race.mode == Race.Mode.CLIENT:
		race.apply_snapshot(d)


func _on_peer_left(id: int) -> void:
	if race != null and race.mode == Race.Mode.HOST:
		race.on_peer_left(id)


func _on_back_to_lobby() -> void:
	show_menu("lobby")
	fade_in()


func _on_session_ended(reason: String) -> void:
	show_menu("wifi")
	menu.set_status(reason)


func _on_race_menu() -> void:
	cup = {}
	if Net.active:
		Net.leave()
	show_menu("home")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if menu.visible:
			if not menu.back():
				get_tree().quit()
		else:
			Game.pause_queue = true
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if race != null:
			race.pause_from_system()


func _unhandled_input(event: InputEvent) -> void:
	if menu.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		menu.back()


# ---------------------------------------------------------------- test modes
func _process(delta: float) -> void:
	_update_fps(delta)
	if Game.cmd_args.has("pause-at") and race != null and _test_t < float(Game.cmd_args["pause-at"]) and _test_t + delta >= float(Game.cmd_args["pause-at"]):
		race.toggle_pause()   # screenshots of the pause menu
	if Game.cmd_args.has("fx") and race != null and _test_t < float(Game.cmd_args.get("fx-at", "6")) and _test_t + delta >= float(Game.cmd_args.get("fx-at", "6")):
		_show_fx(String(Game.cmd_args.fx))
	if Game.cmd_args.has("cursor") and _test_t < 1.5 and _test_t + delta >= 1.5:
		for i in int(Game.cmd_args.cursor):
			var ev := InputEventAction.new()
			ev.action = "ui_focus_next"
			ev.pressed = true
			Input.parse_input_event(ev)
	_test_t += delta
	if Game.cmd_args.has("showcase") and race != null:
		Showcase.hold(race)
	# --shot-air=0.25: take the screenshot once the first player has flown that long
	if _shot_path != "" and Game.cmd_args.has("shot-air") and race != null and not race.locals.is_empty():
		_air_t = _air_t + delta if (race.locals[0] as Kart).air else 0.0
		if _air_t >= float(Game.cmd_args["shot-air"]):
			_shot_delay = _test_t
	if _shot_path != "" and _test_t >= _shot_delay:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("SCREENSHOT ", _shot_path)
		_shot_path = ""
		if not Game.cmd_args.has("keep"):
			get_tree().quit()
	if _test_mode == "":
		return
	if int(_test_t * 2.0) != int((_test_t - delta) * 2.0) and race != null:
		var parts: Array = []
		for k in race.order:
			parts.append("%s L%d %s" % [k.ch.name, k.lap, "F" if k.finished else ""])
		print("[%s t=%.1f race=%.1f state=%s] %s" % [_test_mode, _test_t, race.race_time, race.state, ", ".join(parts)])
	if _test_mode == "bench":
		var secs := float(Game.cmd_args.get("seconds", "10"))
		# wall-clock time: on slow frames `delta` is capped to whole physics ticks
		var now := Time.get_ticks_usec()
		if _test_t > 2.0 and _bench_last > 0:
			_bench.append((now - _bench_last) / 1000000.0)
			_bench_draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			_bench_prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_bench_last = now
		if _test_t > 2.0 + secs:
			var sorted := _bench.duplicate()
			sorted.sort()
			var total := 0.0
			for d in _bench:
				total += d
			var avg := total / _bench.size()
			print("BENCH quality=%s frames=%d avg_fps=%.1f avg_ms=%.2f p95_ms=%.2f worst_ms=%.2f draw_calls=%d triangles=%d" % [
				Gfx.level_name(), _bench.size(), 1.0 / avg, avg * 1000.0,
				sorted[int(sorted.size() * 0.95)] * 1000.0, sorted[sorted.size() - 1] * 1000.0,
				_bench_draws / _bench.size(), _bench_prims / _bench.size()])
			_test_mode = ""
			get_tree().quit(0)
		return
	if _test_mode == "discovery":
		if not Net.hosts.is_empty():
			print("FOUND HOSTS ", Net.hosts)
			_test_mode = ""
			get_tree().quit(0)
		elif _test_t > 8.0:
			print("NO HOSTS FOUND")
			_test_mode = ""
			get_tree().quit(1)
		return
	if _test_mode == "trial" and race != null:
		if race.results_shown:
			if _done_at < 0.0:
				_done_at = _test_t
				print("TRIAL run %d: %s ghost=%s" % [_trial_runs + 1, Game.fmt_time(race.locals[0].finish_time),
					"yes" if not race.ghost.is_empty() else "no"])
			elif _test_t - _done_at > 1.0:
				_done_at = -1.0
				_trial_runs += 1
				if _trial_runs >= 2:
					var g := Game.load_ghost(race.track_idx, race.diff_idx)
					_finish_test(not g.is_empty() and race.ghost_shown, "time trial with ghost, best %s" % Game.fmt_time(float(g.get("t", 0.0))))
				else:
					start_trial()
		elif _test_t > float(Game.cmd_args.get("timeout", "400")):
			_finish_test(false, "timeout")
	elif _test_mode == "cup" and race != null:
		if race.results_shown and _shot_path != "" and int(Game.cmd_args.get("shot-round", "0")) == int(cup.round) + 1:
			_shot_delay = minf(_shot_delay, _test_t + 3.0)
		elif race.results_shown:
			if _done_at < 0.0:
				_done_at = _test_t
			elif _test_t - _done_at > 1.0:
				_done_at = -1.0
				var pts: Dictionary = race._cup_race_points()
				print("CUP round %d %s: %s" % [int(cup.round) + 1, race.track.def.id, str(pts)])
				if race._cup_last():
					for row in race._cup_table(pts):
						print("  %s %d" % [race.display_name(row[0]), int(row[1])])
					_finish_test(true, "championship finished, %d races" % Game.TRACKS.size())
				else:
					_next_cup_round(pts)
		elif _test_t > float(Game.cmd_args.get("timeout", "900")):
			_finish_test(false, "timeout in round %d" % (int(cup.round) + 1))
	elif _test_mode == "ai" and race != null:
		_ai_tick()
	elif _test_mode == "items" and race != null:
		_items_tick()
	elif _test_mode == "jump" and race != null:
		_jump_tick()
	elif _test_mode == "autotest" and race != null:
		if race.results_shown:
			_finish_test(true, "results shown")
		elif _test_t > float(Game.cmd_args.get("timeout", "240")):
			_finish_test(false, "timeout")
	elif _test_mode == "net_host":
		if race == null or race.mode == Race.Mode.DEMO:
			if Net.players.size() >= 2 and _test_t > 2.0:
				Net.start_race()
		elif race.results_shown:
			var all_in := true
			for k in race.karts:
				if k.human and not k.finished:
					all_in = false
			if all_in and _done_at < 0.0:
				_done_at = _test_t
			if _done_at >= 0.0 and not race.cup.is_empty() and not race._cup_last() and _test_t - _done_at > 1.5:
				_done_at = -1.0
				print("CUP host round %d done: %s" % [int(race.cup.round) + 1, str(race._cup_race_points())])
				Net.next_cup_round(race._cup_race_points())
			elif _done_at >= 0.0 and _test_t - _done_at > float(Game.cmd_args.get("linger", "5")):
				_finish_test(true, "host championship finished" if not race.cup.is_empty() else "host results, all players finished")
		if _test_t > float(Game.cmd_args.get("timeout", "300")):
			_finish_test(false, "timeout")
	elif _test_mode == "net_client":
		if race != null and race.mode == Race.Mode.CLIENT and race.results_shown and (race.cup.is_empty() or race._cup_last()):
			var me: Kart = race.locals[0]
			# the prediction of the own kart: p95 within about a metre of the host
			var rep := race.prediction_report()
			print("PREDICTION lag=%d ms: error avg %.2f p95 %.2f max %.2f m (%d), correction avg %.2f p95 %.2f max %.2f m" % [
				int(Net.fake_lag), rep.err.avg, rep.err.p95, rep.err.max, rep.err.n, rep.corr.avg, rep.corr.p95, rep.corr.max])
			print("CLIENT SAW: %s" % ", ".join(race.net_seen.keys()))
			var pred_ok: bool = rep.err.n > 100 and rep.err.p95 <= float(Game.cmd_args.get("max-err", "1.0"))
			if race.cup.is_empty():
				_finish_test(me.finished and pred_ok, "client finished place %d, prediction %s" % [race._place_of(me), "ok" if pred_ok else "too far"])
			else:
				_finish_test(me.finished and pred_ok, "client championship place %d, prediction %s" % [race._cup_place(me), "ok" if pred_ok else "too far"])
		if _test_t > float(Game.cmd_args.get("timeout", "300")):
			_finish_test(false, "timeout")


## Screenshot helper: sets off one effect next to the first local player.
func _show_fx(what: String) -> void:
	var k: Kart = race.locals[0]
	var ahead := Vector3(sin(k.heading), 0.0, cos(k.heading))
	var cam: Camera3D = race.panes[0].cam
	var front := cam.global_position - cam.global_basis.z * 9.0
	if Game.cmd_args.has("fx-pause"):
		race.paused = true   # karts stand still, the effect keeps playing
	match what:
		"explosion":
			race._explode(front.x, front.z)
		"box":
			Effects.box_shards(race.fx, front)
		"burst":
			Effects.confetti_burst(race.fx, front - Vector3(0, 2, 0))
		"confetti":
			k.finished = true
			k.finish_time = race.race_time
		"hit":
			k.hit(1.6, false)
		"boost":
			k.boost = 2.0
			k.boost_mul = 1.25
			k.drift_level = 0
			k.obs.level = int(Game.cmd_args.get("level", "3"))
		"star":
			k.star = 4.0
		"shield":
			k.shield = Game.SHIELD_TIME
		"oil":
			var node := race._oil_node()
			race.fx.add_child(node)
			var o := {"x": front.x, "y": 0.0, "z": front.z, "node": node, "owner": null, "age": 0.0}
			race._place_oil(o, race.track.project(front.x, front.z, k.idx))
			race.oils.append(o)
		"lightning":
			race._lightning(k)
		"blue":
			k.item = Game.Item.BLUE
			k.item_n = 1
			race.use_item(k)
		"icon":
			k.item = int(Game.cmd_args.get("level", "5"))
			k.item_n = 1
		"roulette":
			k.item = 0
			k.roulette = 1.3
		"banner":
			race.panes[0].hud.show_banner("POSLEDNÍ KOLO", UI.GOLD, "Kolo 2: 0:36.42")
		"pop":
			race.panes[0].hud._last_rank = k.rank + 1
		"skids":
			# an S-shaped pair of marks across the road ahead
			var side := Vector3(cos(k.heading), 0.0, -sin(k.heading))
			for i in 50:
				var w0 := sin(i * 0.14) * 6.0
				var w1 := sin((i + 1) * 0.14) * 6.0
				for sx in [-1.0, 1.0]:
					race.skids.add(k.position + ahead * (4.0 + i * 0.75) + side * (w0 + sx),
						k.position + ahead * (4.75 + i * 0.75) + side * (w1 + sx), 1.0)


func _start_ai_race() -> void:
	Game.settings.track = _ai_track
	start_offline(1)
	if Game.cmd_args.has("no-items"):
		# lap times without the luck of the item boxes
		for b in race.boxes:
			b.active = false
			b.respawn = INF
			b.node.visible = false
	race.fast = int(Game.cmd_args.get("fast", "8"))
	for k in race.locals:
		k.autopilot = true
	_test_t = 0.0


func _ai_tick() -> void:
	var done := true
	for k in race.karts:
		if not k.finished:
			done = false
	if not done and _test_t < float(Game.cmd_args.get("timeout", "200")):
		return
	var laps: Array = []
	var best := INF
	var drifts := 0
	var revs := 0
	var unfinished := 0
	for k in race.karts:
		for t in k.lap_times:
			laps.append(t)
			best = minf(best, t)
		drifts += k.drift_boosts
		revs += int(k.ai.get("revs", 0))
		if not k.finished:
			unfinished += 1
	var sum := 0.0
	for t in laps:
		sum += t
	var avg := sum / maxf(1, laps.size())
	print("AI %s %s: average lap %.2f s, best %.2f s, drift turbos %d, stuck %d, not finished %d" % [
		race.track.def.id, Game.DIFFS[int(Game.settings.diff)].name, avg, best, drifts, revs, unfinished])
	_ai_sum[race.track.def.id] = avg
	_ai_drifts += drifts
	if unfinished > 0 or revs > 2:
		_items_bad += 1
	_ai_track += 1
	if _ai_track < Game.TRACKS.size() and not Game.cmd_args.has("track"):
		_start_ai_race()
		return
	var total := 0.0
	for v in _ai_sum.values():
		total += v
	print("AI ALL TRACKS: average lap %.2f s, drift turbos %d" % [total / _ai_sum.size(), _ai_drifts])
	var ok := _items_bad == 0 and (_ai_drifts > 0 or int(Game.settings.diff) == 0)
	_finish_test(ok, "the computer drivers finish on every track without getting stuck, and drift" if ok
		else "%d tracks with trouble, %d drift turbos" % [_items_bad, _ai_drifts])


func _items_tick() -> void:
	if _items_phase == 0 and race.state == "race":
		_items_phase = 1
		_item_checks()
		Game.cmd_args["item-cycle"] = "1"
		start_offline(1)
		race.fast = int(Game.cmd_args.get("fast", "8"))
		for k in race.locals:
			k.autopilot = true
		_test_t = 0.0
	elif _items_phase == 1 and race.results_shown:
		var used: Array = []
		for it in range(1, Game.ITEM_COUNT + 1):
			var n := int(race.item_uses.get(it, 0))
			used.append("%s %d" % [Game.ITEM_NAMES[it], n])
			if n == 0:
				_items_bad += 1
		print("ITEMS USED IN THE RACE: ", ", ".join(used))
		_finish_test(_items_bad == 0, "every item works and gets used" if _items_bad == 0 else "%d problems" % _items_bad)
	elif _test_t > float(Game.cmd_args.get("timeout", "240")):
		_finish_test(false, "timeout")


## A kart standing still at track sample i, lat metres to the right, on lap 1.
func _put(k: Kart, i: int, lat: float) -> void:
	var tr := race.track
	i = posmod(i, tr.n)
	k.reset(tr.x[i] + tr.nx[i] * lat, tr.z[i] + tr.nz[i] * lat, tr.heading(i))
	k.constrain()
	k.lap = 1
	k.max_lap = 1
	k.last_s = k.s
	k.y = tr.road_y(k.idx, k.lat, k.along)


## Moves a kart to x, z and stands it on the road there.
func _move(k: Kart, px: float, pz: float) -> void:
	k.x = px
	k.z = pz
	k.idx = race.track.nearest(px, pz)   # far from where it stood: look for the road around it afresh
	k.constrain()
	k.lap = 1
	k.y = race.track.road_y(k.idx, k.lat, k.along)


func _check(name: String, ok: bool, info := "") -> void:
	print("ITEM CHECK %s: %s %s" % [name, "ok" if ok else "FAIL", info])
	if not ok:
		_items_bad += 1


func _item_checks() -> void:
	var r := race
	r.paused = true
	var K: Array = r.karts
	var dt := Game.SIM_DT
	for i in K.size():
		_put(K[i], 40 + i * 30, 0.0)
	# shield: swallows exactly one hit
	var a: Kart = K[0]
	a.item = Game.Item.SHIELD
	a.item_n = 1
	r.use_item(a)
	_check("shield up", is_equal_approx(a.shield, Game.SHIELD_TIME))
	for n in 2:
		var node := r._banana_node()
		r.fx.add_child(node)
		r.bananas.append({"x": a.x, "y": a.y, "z": a.z, "node": node, "owner": null, "age": 1.0})
		r._update_items(dt)
		if n == 0:
			_check("shield swallows a banana", a.spin <= 0.0 and a.shield <= 0.0 and r.bananas.is_empty())
			a.invuln = 0.0
		else:
			_check("next banana hits again", a.spin > 0.0)
	# oil: a puddle behind, a long skid for others, not for the owner at first, gone after 20 s
	var b: Kart = K[1]
	var c: Kart = K[2]
	b.item = Game.Item.OIL
	b.item_n = 1
	r.use_item(b)
	_check("oil dropped", r.oils.size() == 1)
	var oil: Dictionary = r.oils[0]
	var behind := Vector2(b.x - float(oil.x), b.z - float(oil.z)).dot(Vector2(sin(b.heading), cos(b.heading)))
	_check("oil lies behind the kart", behind > 2.0, "(%.1f m)" % behind)
	_move(b, oil.x, oil.z)
	_move(c, float(oil.x) + 1.0, oil.z)
	r._update_items(dt)
	_check("oil: a long skid", c.spin > 1.5, "(spin %.2f s)" % c.spin)
	_check("oil: the owner gets away", b.spin <= 0.0)
	var e: Kart = K[3]
	e.shield = Game.SHIELD_TIME
	_move(e, oil.x, oil.z)
	r._update_items(dt)
	_check("shield swallows the oil", e.spin <= 0.0 and e.shield <= 0.0)
	oil.age = r.OIL_TIME - 0.01
	r._update_items(0.02)
	_check("oil dries up after 20 s", r.oils.is_empty())
	# lightning: the others shrink, the star and a shield protect, the small can be run over
	for i in K.size():
		_put(K[i], 40 + i * 30, 0.0)
	var zap: Kart = K[0]
	K[1].star = 5.0
	K[2].shield = Game.SHIELD_TIME
	var normal_top: float = K[3].max_speed()
	zap.item = Game.Item.LIGHTNING
	zap.item_n = 1
	r.use_item(zap)
	_check("lightning spares its owner", zap.shrink <= 0.0)
	_check("star protects from the lightning", K[1].shrink <= 0.0)
	_check("shield protects from the lightning", K[2].shrink <= 0.0 and K[2].shield <= 0.0)
	var shrunk := true
	for i in range(3, K.size()):
		shrunk = shrunk and K[i].shrink > 0.0
	_check("lightning shrinks the others", shrunk)
	_check("small karts are slower", K[3].max_speed() < normal_top * 0.9, "(%.1f → %.1f)" % [normal_top, K[3].max_speed()])
	_move(K[4], zap.x + 1.0, zap.z)
	r._kart_collisions()
	_check("a small kart gets run over", K[4].spin > 0.0 and zap.spin <= 0.0)
	for k in K:
		k.update(6.1, {"steer": 0.0, "gas": false, "brake": false, "drift": false, "item": false})
	_check("karts grow back after 6 s", K[3].shrink <= 0.0)
	# blue missile: flies to the leader, the blast catches the karts next to them
	for i in K.size():
		_put(K[i], 10 + i * 12, 0.0)
	var lead: Kart = K[5]
	_put(lead, 260, 0.0)
	var near: Kart = K[4]
	_put(near, 258, 2.0)
	var far: Kart = K[3]
	_put(far, 200, 0.0)
	r._compute_ranks()
	var shooter: Kart = K[0]
	shooter.item = Game.Item.BLUE
	shooter.item_n = 1
	r.use_item(shooter)
	_check("blue missile goes for the leader", r.blues.size() == 1 and r.blues[0].target == lead)
	var t := 0.0
	while not r.blues.is_empty() and t < 20.0:
		r._update_items(dt)
		t += dt
	_check("blue missile reaches the leader", r.blues.is_empty() and lead.spin > 0.0, "(%.1f s)" % t)
	_check("its blast catches the kart next to the leader", near.spin > 0.0)
	_check("karts further away are safe", far.spin <= 0.0 and shooter.spin <= 0.0)
	# the snapshot carries the new items and states to Wi-Fi players
	var oil2 := r._oil_node()
	r.fx.add_child(oil2)
	r.oils.append({"x": lead.x, "y": lead.y, "z": lead.z, "node": oil2, "owner": null, "age": 3.0})
	K[2].shield = 4.0
	K[1].shrink = 2.0
	var d := r._pack()
	_check("snapshot has the oil", int(d[9]) == 1)
	var copy := Kart.new()
	copy.race = r
	copy.unpack(d, 14 + 2 * Kart.SNAP_FIELDS)
	var sh := copy.shield
	copy.unpack(d, 14 + 1 * Kart.SNAP_FIELDS)
	_check("snapshot has shield and size", is_equal_approx(sh, 4.0) and is_equal_approx(copy.shrink, 2.0))
	copy.free()
	r.paused = false


func _start_jump_race() -> void:
	Game.settings.track = _jump_track
	start_offline(1)
	race.fast = int(Game.cmd_args.get("fast", "8"))
	for k in race.karts:
		k.autopilot = true
	Kart.takeoffs.clear()
	_test_t = 0.0


## --jumptest: turbo for half the karts, the star for the others, until each
## has driven a whole lap; then every take-off must have been on the ramp.
func _jump_tick() -> void:
	var done := true
	for i in race.karts.size():
		var k: Kart = race.karts[i]
		if i % 2 == 0:
			k.boost = maxf(k.boost, 0.5)
			k.boost_mul = 1.25
		else:
			k.star = maxf(k.star, 0.5)
		if k.lap < 2:
			done = false
	if not done and _test_t < float(Game.cmd_args.get("timeout", "120")):
		return
	var tr := race.track
	var ramp_s := float(tr.ramp.get("i", 0)) * tr.step
	var on_ramp := 0
	for t in Kart.takeoffs:
		var d := fposmod(float(t[1]) - ramp_s + tr.length * 0.5, tr.length) - tr.length * 0.5
		if not tr.ramp.is_empty() and d >= -2.0 and d <= float(tr.ramp.len) + 3.0:
			on_ramp += 1
		else:
			_jump_bad += 1
			print("JUMP OFF RAMP %s at %.0f m (%.0f m from the ramp) speed %.1f" % [t[0], t[1], d, t[2]])
	print("JUMPS %s: %d from the ramp, %d elsewhere%s" % [tr.def.id, on_ramp, Kart.takeoffs.size() - on_ramp,
		"" if done else " (timeout before every kart finished a lap)"])
	if not done:
		_jump_bad += 1
	_jump_track += 1
	if _jump_track < Game.TRACKS.size():
		_start_jump_race()
	else:
		_finish_test(_jump_bad == 0, "take-offs only from the ramp on all %d tracks" % Game.TRACKS.size() if _jump_bad == 0
			else "%d problems" % _jump_bad)


func _finish_test(ok: bool, why: String) -> void:
	print("TEST %s: %s" % ["PASS" if ok else "FAIL", why])
	if race != null:
		for row in race.standings():
			print("  %s %s %s" % [race.display_name(row.k), Game.fmt_time(row.t), "(odhad)" if row.est else ""])
	_test_mode = ""
	if _shot_path != "":   # a pending screenshot is taken soon and quits
		_shot_delay = minf(_shot_delay, _test_t + 2.5)
		return
	get_tree().quit(0 if ok else 1)

