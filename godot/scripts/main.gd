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
var _fade_tw: Tween
var _fading := false
var _bench_draws := 0
var _bench_prims := 0


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
	menu.quit_requested.connect(func(): get_tree().quit())
	menu.track_changed.connect(_start_demo)
	menu.quality_changed.connect(_start_demo)
	_make_fps_label()
	_make_fader()
	Net.race_started.connect(_on_net_race)
	Net.back_to_lobby.connect(_on_back_to_lobby)
	Net.session_ended.connect(_on_session_ended)
	Net.peer_left.connect(_on_peer_left)
	Net.snapshot_received.connect(_on_snapshot)
	var a := Game.cmd_args
	if a.has("track"):
		Game.settings.track = clampi(int(a.track), 0, Game.TRACKS.size() - 1)
	if a.has("quality"):
		Game.settings.quality = clampi(int(a.quality), 0, 2)   # not saved
	if a.has("fps"):
		Game.settings.show_fps = true
	if a.has("timescale"):
		Engine.time_scale = float(a.timescale)   # slow motion for effect screenshots
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
		else:
			Net.join("127.0.0.1", "Klient", 1)
		return
	if a.has("showcase"):
		return
	show_menu(String(a.get("screen", "home")))
	if a.has("host"):
		menu._host()
	if a.has("race"):
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
	race.restart_requested.connect(func(): fade_to(start_offline.bind(last_players)))
	race.menu_requested.connect(func(): fade_to(_on_race_menu))
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
	var roster := ai.slice(0, Game.MAX_KARTS - humans.size()) + humans
	menu.visible = false
	_new_race().start(Race.Mode.OFFLINE, int(Game.settings.track), int(Game.settings.diff), roster)


func _on_net_race(track: int, diff: int, roster: Array) -> void:
	var me := Net.my_id()
	var r: Array = []
	for e in roster:
		var d: Dictionary = e.duplicate()
		d.local = 0 if bool(d.human) and int(d.peer) == me else -1
		r.append(d)
	menu.visible = false
	Net.stop_listening()
	_new_race().start(Race.Mode.HOST if Net.is_host else Race.Mode.CLIENT, track, diff, r)
	fade_in()   # no fade out first: the host's countdown must not wait
	if _test_mode != "":
		for k in race.karts:
			if k.human:
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
	_test_t += delta
	if Game.cmd_args.has("showcase") and race != null:
		Showcase.hold(race)
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
	if _test_mode == "autotest" and race != null:
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
			if _done_at >= 0.0 and _test_t - _done_at > float(Game.cmd_args.get("linger", "5")):
				_finish_test(true, "host results, all players finished")
		if _test_t > float(Game.cmd_args.get("timeout", "300")):
			_finish_test(false, "timeout")
	elif _test_mode == "net_client":
		if race != null and race.mode == Race.Mode.CLIENT and race.results_shown:
			var me: Kart = race.locals[0]
			_finish_test(me.finished, "client finished place %d" % race._place_of(me))
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

