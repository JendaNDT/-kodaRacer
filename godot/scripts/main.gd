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
var battle := false     # the last race started was a balloon battle
var _trial_runs := 0
var _jump_track := 0
var _items_phase := 0
var _ai_track := 0
var _cut_phase := 0
var _ai_sum := {}
var _ai_drifts := 0
var _items_bad := 0
var _jump_bad := 0
var _tilt_phase := 0
var _tilt_at := 0.0
var _hap_phase := 0
var _hap_at := 0.0
var _hap_off := []       # [buzzes before vibrations went off, buzzes when they came on again]
var _hap_asked_off := 0  # events while they were off
var _bt_runs: Array = []      # --battletest: [arena, difficulty] still to drive
var _bt_watch := {}           # kart -> {x, z, t, n}: where it was 5 s ago, windows without moving
var _bt_left := {}            # karts seen outside the arena or inside something solid
var _bt_stuck := {}           # karts stuck for 10 s
var _bt_done_at := -1.0
var _bt_air := {}             # kart -> was in the air (counting take-offs from the ramps)
var _bt_jumps := 0
var _bt_rows: Array = []
var _net_end := {}            # Wi-Fi battle test: {ok, why, t} once the battle is done, before leaving
var _net_left := {}           # Wi-Fi battle test, host: kart -> {t, out, balloons, x, z, dist} of a player who left


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
	menu.start_battle.connect(func(n: int): fade_to(start_battle.bind(n)))
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
	if a.has("mirror"):
		Game.settings.mirror = true      # the mirrored tracks (tests, screenshots; not saved)
	if a.has("unlock"):
		Game.save_off = true             # screenshots: --unlock=secret,mirror,paint1_0 (nothing saved)
		for key in String(a.unlock).split(",", false):
			Game.settings.unlocks[key] = true
	if a.has("driver"):
		Game.settings.driver = clampi(int(a.driver), 0, Game.CHARS.size() - 1)   # not saved
	if a.has("paint"):
		Game.settings.paints[str(Game.settings.driver)] = int(a.paint)
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
			# the shortcut: how long, how much road it skips, how close it comes to other parts of the track
			if tr.cut.is_empty():
				print("CUT %s: none" % tr.def.id)
			else:
				var clear := INF
				for q in int(tr.cut.m):
					for jj in tr.n:
						if tr._arc(jj, int(tr.cut.a)) > 50.0 and tr._arc(jj, int(tr.cut.b)) > 50.0:
							clear = minf(clear, Vector2(float(tr.cut.x[q]) - tr.x[jj], float(tr.cut.z[q]) - tr.z[jj]).length())
				print("CUT %s: %s, %.0f m instead of %.0f m of road (%.0f %%), from %.0f m to %.0f m of the lap, other road at least %.0f m away" % [
					tr.def.id, tr.cut.kind, float(tr.cut.len), float(tr.cut.arc_span), 100.0 * float(tr.cut.len) / float(tr.cut.arc_span),
					float(tr.cut.arc_a), fposmod(float(tr.cut.arc_a) + float(tr.cut.arc_span), tr.length), clear])
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
	if a.has("cutcal"):
		# finds each shortcut's slowdown on every difficulty so that it loses
		# about 6 % to the road without a turbo (to put into Game.TRACKS)
		menu.visible = false
		Game.settings.driver = 0         # Turbo Tonda, balanced (not saved)
		for ti in Game.TRACKS.size():
			Game.settings.track = ti
			var found: Array[String] = []
			for d in Game.DIFFS.size():
				var lo := 0.2
				var hi := 0.95
				var road := _cut_run(ti, "road", 0.0, d)
				for it in 8:
					var mid := (lo + hi) * 0.5
					var tc := _cut_run(ti, "cut", mid, d)
					if tc > road * 1.06:
						lo = mid
					else:
						hi = mid
				found.append("%.2f" % ((lo + hi) * 0.5))
			print("CUTCAL \"%s\": slow [%s]" % [Game.TRACKS[ti].id, ", ".join(found)])
		get_tree().quit()
		return
	if a.has("soaktest"):
		# race → results → menu again and again (as a player would), the
		# memory used after each round: it must not keep growing
		_test_mode = "soak"
		menu.visible = false
		_soak_race()
		return
	if a.has("unlocktest"):
		# rewards from made-up championships and time trials, the secret
		# driver and paints in a race, every mirrored track checked against
		# the original, the developer's ghosts and the Collection screen
		_test_mode = "unlock"
		menu.visible = false
		_unlock_checks()
		_finish_test(_items_bad == 0, "unlocks work" if _items_bad == 0 else "%d problems" % _items_bad)
		return
	if a.has("devghosts"):
		# records the developer's ghost for every track and difficulty into
		# res://ghosts (kept with the game): the autopilot at its very best
		menu.visible = false
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ghosts"))
		for ti in Game.TRACKS.size():
			for d in Game.DIFFS.size():
				_dev_ghost_run(ti, d)
		get_tree().quit()
		return
	if a.has("cuttest"):
		# every track: the stretch with the shortcut driven by road, by the
		# shortcut without and with a turbo and with the star, then a race in
		# which everybody takes the shortcut every lap
		_test_mode = "cut"
		menu.visible = false
		Game.settings.driver = 0         # Turbo Tonda, as when the slowdowns were measured (not saved)
		_cut_checks()
		Game.settings.diff = 1           # the race: Normal, whatever was saved (not saved)
		Game.cmd_args["cut-always"] = "1"
		_ai_track = 0
		_start_ai_race()
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
	if a.has("tilttest"):
		# made-up sensor readings (straight, a little, a lot, past full lock,
		# the phone turned over) must become the right steering, with the dead
		# zone, smoothing and levelling; then a race on a "phone" held askew:
		# straight after the countdown, steering right when tilted right
		_test_mode = "tilt"
		menu.visible = false
		_tilt_checks()
		Game.cmd_args["touch"] = "1"         # the phone's controls on a computer
		Game.settings.steer = 1              # not saved
		Game.settings.tilt_sens = 1
		Game.tilt = Tilt.new()
		Game.fake_gravity = _held(12.0, 40.0)
		start_offline(1)
		_test_t = 0.0
		return
	if a.has("battletest"):
		# the battle's rules in set-up situations, then battles with only the
		# computer driving, in both arenas on every difficulty: each must end
		# with a winner within 3 minutes, nobody may leave the arena or get
		# stuck, and every hit that lands costs exactly one balloon
		_test_mode = "battle"
		menu.visible = false
		_battle_rule_checks()
		for ai in Game.ARENAS.size():
			for d in Game.DIFFS.size():
				if (not a.has("arena") or int(a.arena) == ai) and (not a.has("diff") or int(a.diff) == d):
					_bt_runs.append([ai, d])
		_next_battle_run()
		return
	if a.has("hapticstest"):
		# a whole race with the autopilot; the buzzes are written into a list
		# instead of the phone. Every kind of event must buzz, never two within
		# Haptics.GAP for the same player, and nothing while vibrations are
		# off (the second lap)
		_test_mode = "haptics"
		menu.visible = false
		Haptics.log_on = true
		Game.settings.vibrate = true         # not saved
		Game.settings.diff = 2               # Těžká: the computer drifts (not saved)
		start_offline(int(a.get("players", "1")))
		race.fast = int(a.get("fast", "8"))
		for k in race.locals:
			k.autopilot = true
		Haptics.reset_log()
		_test_t = 0.0
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
			Net.host("Hostitel", 0, Game.paint_of(0))
			Net.cup_mode = a.has("cup")   # --cup: a championship (--cup-start=4: only the last races)
			if a.has("battle"):           # --battle --arena=N: the balloon battle (Etapa I)
				Net.battle_mode = true
				Net.arena = clampi(int(a.get("arena", "0")), 0, Game.ARENAS.size() - 1)
		else:
			Net.join("127.0.0.1", "Klient", 1, Game.paint_of(1))
			Haptics.log_on = true            # what the client's player felt, printed at the end
		return
	if a.has("showcase"):
		return
	menu.setup_mode = String(a.get("mode", "race"))   # screenshots of the setup screen (race, cup, trial)
	show_menu(String(a.get("screen", "home")))
	if a.has("host"):
		menu._host()
		Net.set_cup_mode(a.has("cup"))
		if a.has("lobby-battle"):   # screenshots of the lobby set to the battle
			Net.set_arena(int(a.get("arena", "0")))
			Net.set_mode(2)
	if a.has("trial"):
		start_trial()
		race.fast = int(a.get("fast", "1"))
		if a.has("autopilot"):
			race.locals[0].autopilot = true
	elif a.has("battle"):
		# --battle --arena=N: screenshots and trying it out
		if a.has("arena"):
			Game.settings.arena = clampi(int(a.arena), 0, Game.ARENAS.size() - 1)
		start_battle(int(a.get("players", "1")))
		race.fast = int(a.get("fast", "1"))
		if a.has("autopilot"):
			for k in race.locals:
				k.autopilot = true
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
	var ids := Game.open_drivers()
	ids.shuffle()
	for i in ids.slice(0, Game.MAX_KARTS):
		roster.append({"driver": i, "human": false, "peer": 0, "name": ""})
	_new_race().start(Race.Mode.DEMO, int(Game.settings.track), 1, roster)


func start_offline(players: int) -> void:
	cup = {}
	trial = false
	battle = false
	var roster := _offline_roster(players)
	menu.visible = false
	_new_race().start(Race.Mode.OFFLINE, Game.race_track(int(Game.settings.track), bool(Game.settings.mirror)),
		int(Game.settings.diff), roster)


## A championship: every track once with the same six drivers, points
## after each race; the grid of the next race is the standings reversed.
func start_cup(players: int) -> void:
	trial = false
	battle = false
	var roster := _offline_roster(players)
	var pts := {}
	for r in roster:
		pts[int(r.driver)] = 0
	cup = {"players": players, "diff": int(Game.settings.diff), "round": 0, "roster": roster, "points": pts,
		"mirror": bool(Game.settings.mirror)}
	_start_cup_round()


func _start_cup_round() -> void:
	menu.visible = false
	var r := _new_race()
	r.cup = cup
	r.start(Race.Mode.OFFLINE, Game.race_track(int(cup.round), bool(cup.get("mirror", false))), int(cup.diff), cup.roster)
	if _test_mode == "cup":
		r.fast = int(Game.cmd_args.get("fast", "8"))
		for k in r.locals:
			k.autopilot = true


## Time trial: you alone on the chosen track against the ghost of your best drive.
func start_trial() -> void:
	cup = {}
	trial = true
	battle = false
	last_players = 1
	menu.visible = false
	var d := int(Game.settings.driver)
	var r := _new_race()
	r.trial = true
	r.start(Race.Mode.OFFLINE, Game.race_track(int(Game.settings.track), bool(Game.settings.mirror)), int(Game.settings.diff),
		[{"driver": d, "paint": Game.paint_of(d), "human": true, "peer": 0, "local": 0, "name": Game.player_name()}])
	if _test_mode == "trial":
		r.fast = int(Game.cmd_args.get("fast", "8"))
		r.locals[0].autopilot = true


## The balloon battle in the chosen arena: six karts, the local players
## among them (Etapa H).
func start_battle(players: int) -> void:
	cup = {}
	trial = false
	battle = true
	var roster := _offline_roster(players)
	menu.visible = false
	var r := _new_race()
	r.battle_mode = true
	r.start(Race.Mode.OFFLINE, int(Game.settings.arena), int(Game.settings.diff), roster)


## "Restart" from the pause menu or the results: the same race again, in a
## championship the same round; after its last race a new championship.
func _restart() -> void:
	if battle:
		start_battle(last_players)
	elif trial:
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
	humans.append({"driver": d1, "paint": Game.paint_of(d1), "human": true, "peer": 0, "local": 0,
		"name": Game.player_name() if players == 1 else "Hráč 1"})
	if players == 2:
		var d2 := int(Game.settings.driver2)
		if d2 == d1 or not Game.driver_open(d2):
			d2 = Game.free_driver([d1])
		humans.append({"driver": d2, "paint": Game.paint_of(d2), "human": true, "peer": 0, "local": 1, "name": "Hráč 2"})
	var used := {}
	for h in humans:
		used[h.driver] = true
	# seven drivers once the secret one is won, six of them race
	var ai: Array = []
	for i in Game.open_drivers():
		if not used.has(i):
			ai.append({"driver": i, "human": false, "peer": 0, "name": ""})
	ai.shuffle()
	return ai.slice(0, Game.MAX_KARTS - humans.size()) + humans


func _on_net_race(track: int, diff: int, roster: Array, cupd: Dictionary, bt := false) -> void:
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
	nr.battle_mode = bt   # then `track` is the arena
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
		if _test_mode == "net_host" and race.battle != null:
			for k: Kart in race.karts:
				if k.peer == id:
					_net_left[k] = {"t": race.race_time, "out": k.out, "balloons": k.balloons, "x": k.x, "z": k.z, "dist": 0.0}
					print("HOST: %s left the battle at %.1f s%s" % [race.display_name(k), race.race_time,
						" (already out)" if k.out else ", the computer drives on"])
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
var _soak_n := 0
var _soak_phase := ""
var _soak_t := 0.0
var _soak_log: Array = []


func _soak_race() -> void:
	_soak_phase = "race"
	_soak_t = 0.0
	if _soak_n % 2 == 1 and race != null:
		_restart()                       # "Jet znovu" from the results
	else:
		start_offline(1)
	race.fast = int(Game.cmd_args.get("fast", "8"))
	for k in race.locals:
		k.autopilot = true


func _soak_mem(tag: String) -> void:
	var vm := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var tm := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var bm := Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0
	var row := "SOAK %d %-6s video %.1f MB, textures %.1f MB, buffers %.1f MB, objects %d, nodes %d, resources %d, orphans %d" % [
		_soak_n, tag, vm, tm, bm, Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
	print(row)
	_soak_log.append([tag, vm])


func _soak_tick(delta: float) -> void:
	_soak_t += delta
	match _soak_phase:
		"race":
			# --soak-shot=N: a screenshot in the middle of race N (--soak-shot-menu=N: in the menu after it)
			if _shot_path != "" and int(Game.cmd_args.get("soak-shot", "-1")) == _soak_n and _soak_t > 8.0 \
					and _shot_delay > _test_t + 1.0:
				_soak_mem("shot")
				_shot_delay = _test_t
			if race != null and race.results_shown and _soak_t > 3.0:
				_soak_mem("race")
				_soak_t = 0.0
				if _soak_n % 2 == 1:
					_soak_phase = "menu"
					_on_race_menu()
				else:
					_soak_n += 1
					_soak_race()
			elif _soak_t > 240.0:
				_finish_test(false, "race %d did not finish" % _soak_n)
		"menu":
			if _shot_path != "" and int(Game.cmd_args.get("soak-shot-menu", "-1")) == _soak_n and _soak_t > 2.5 \
					and _shot_delay > _test_t + 1.0:
				_shot_delay = _test_t
			if _soak_t > 3.0:
				_soak_mem("menu")
				_soak_n += 1
				if _soak_n >= int(Game.cmd_args.get("rounds", "8")):
					var first := 0.0
					var last := 0.0
					for r in _soak_log:
						if r[0] == "menu":
							if first == 0.0:
								first = r[1]
							last = r[1]
					_finish_test(last - first < 40.0, "video memory in the menu %.0f → %.0f MB" % [first, last])
				else:
					menu.visible = false
					_soak_race()


func _process(delta: float) -> void:
	_update_fps(delta)
	if _test_mode == "soak":
		_soak_tick(delta)
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
	# --shot-cut=0.8: once the first player has been on the shortcut that long;
	# --shot-sign: as the first player comes up to the sign before it
	if _shot_path != "" and race != null and not race.locals.is_empty() and race.track != null and not race.track.cut.is_empty():
		var lk: Kart = race.locals[0]
		if Game.cmd_args.has("shot-cut"):
			_air_t = _air_t + delta if lk.on_cut else 0.0
			if _air_t >= float(Game.cmd_args["shot-cut"]):
				_shot_delay = _test_t
		var to_cut := (int(race.track.cut.a) - lk.idx + race.track.n) % race.track.n
		if Game.cmd_args.has("shot-sign") and lk.lap >= 1 and to_cut >= 24 and to_cut <= 30 and _shot_delay > _test_t + 1.0:
			_shot_delay = _test_t
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
	elif _test_mode == "cut" and race != null:
		_cut_race_tick()
	elif _test_mode == "ai" and race != null:
		_ai_tick()
	elif _test_mode == "items" and race != null:
		_items_tick()
	elif _test_mode == "jump" and race != null:
		_jump_tick()
	elif _test_mode == "battle" and race != null:
		_battle_tick()
	elif _test_mode == "tilt" and race != null:
		_tilt_tick()
	elif _test_mode == "haptics" and race != null:
		_haptics_tick()
	elif _test_mode == "autotest" and race != null:
		if race.results_shown:
			_finish_test(true, "results shown")
		elif _test_t > float(Game.cmd_args.get("timeout", "240")):
			_finish_test(false, "timeout")
	elif _test_mode == "net_host":
		if not _net_end.is_empty():
			# everybody sent back to the lobby: give the message time to arrive
			if _test_t - float(_net_end.t) > 3.0:
				_finish_test(bool(_net_end.ok), String(_net_end.why))
		elif race == null or race.mode == Race.Mode.DEMO:
			if Net.players.size() >= int(Game.cmd_args.get("wait-players", "2")) and _test_t > 2.0:
				Net.start_race()
		elif race.battle != null:
			_net_battle_host()
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
	elif _test_mode == "net_client" and (not _net_end.is_empty() or race != null and race.battle != null):
		_net_battle_client()
	elif _test_mode == "net_client":
		if race != null and race.mode == Race.Mode.CLIENT and race.results_shown and (race.cup.is_empty() or race._cup_last()):
			var me: Kart = race.locals[0]
			# the prediction of the own kart: p95 within about a metre of the host
			var rep := race.prediction_report()
			print("PREDICTION lag=%d ms: error avg %.2f p95 %.2f max %.2f m (%d), correction avg %.2f p95 %.2f max %.2f m" % [
				int(Net.fake_lag), rep.err.avg, rep.err.p95, rep.err.max, rep.err.n, rep.corr.avg, rep.corr.p95, rep.corr.max])
			print("CLIENT SAW: %s" % ", ".join(race.net_seen.keys()))
			var felt := {}
			for b in Haptics.buzzes:
				felt[b[2]] = int(felt.get(b[2], 0)) + 1
			print("CLIENT FELT: %s, events %s" % [str(felt), str(Haptics.asked)])
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


## One drive through the stretch with the shortcut on track ti, alone:
## "road", "cut", "cut+turbo" or "cut+star"; slow > 0 overrides the
## shortcut's slowdown. Returns the time.
func _unlock_checks() -> void:
	Game.save_off = true
	Game.settings.unlocks = {}
	Game.settings.cups = {}
	Game.settings.trials = {}
	Game.settings.paints = {}
	Game.settings.mirror = false
	var S := Game.SECRET
	_check("at first the secret driver is locked", not Game.driver_open(S) and Game.open_drivers().size() == 6)
	_check("at first only the own paints", not Game.paint_open(2, 1) and Game.paint_open(2, 0) and Game.paint_of(2) == 0)
	var won := Game.award_cup([2], 0, 3)
	_check("bronze on Easy: second paint of that driver", won == ["paint1_2"], str(won))
	_check("  … and nothing else", not Game.unlocked("mirror") and not Game.paint_open(2, 2) and not Game.paint_open(0, 1))
	won = Game.award_cup([0], 0, 1)
	_check("gold on Easy: no mirrored tracks yet", won == ["paint1_0"], str(won))
	won = Game.award_cup([0], 1, 1)
	_check("gold on Normal: mirrored tracks", won == ["mirror"], str(won))
	won = Game.award_cup([1], 2, 4)
	_check("4th place on Hard: nothing", won.is_empty(), str(won))
	won = Game.award_cup([4], 2, 1)
	_check("gold on Hard: paints of that driver and the secret driver",
		won == ["paint1_4", "paint2_4", "secret"], str(won))
	_check("  … he can be picked now", Game.driver_open(S) and Game.open_drivers().size() == 7)
	_check("the same cup again wins nothing new", Game.award_cup([4], 2, 1).is_empty())
	_check("best cups kept per difficulty", Game.cup_best(0) == 1 and Game.cup_best(1) == 1 and Game.cup_best(2) == 1)
	Game.set_paint(4, 2)
	_check("the chosen paint", Game.paint_of(4) == 2 and Game.look(4, 2).color == Game.GOLD_PAINT[0])
	Game.set_paint(3, 2)
	_check("a paint not won falls back to the own one", Game.paint_of(3) == 0)
	# rosters: six drivers, all different, the secret one only once won
	var bad := 0
	for it in 40:
		Game.settings.driver = it % 7
		for players in [1, 2]:
			var ro := _offline_roster(players)
			var ids := {}
			for e in ro:
				ids[int(e.driver)] = true
				if not Game.driver_open(int(e.driver)):
					bad += 1
			if ro.size() != Game.MAX_KARTS or ids.size() != Game.MAX_KARTS:
				bad += 1
	_check("rosters: 6 different drivers out of 7", bad == 0, "(%d bad)" % bad)
	var seen := {}
	for it in 60:
		Game.settings.driver = 0
		for e in _offline_roster(1):
			seen[int(e.driver)] = true
	_check("the secret driver also races as a computer driver", seen.has(S))
	# mirrored tracks: the same road flipped left to right, shortcut and ramp included
	for t in Game.TRACKS.size():
		var a := Race.get_track(t)
		var m := Race.get_track(t + Game.TRACKS.size())
		var worst := 0.0
		for i in a.n:
			worst = maxf(worst, absf(m.x[i] + a.x[i]) + absf(m.z[i] - a.z[i]) + absf(m.y[i] - a.y[i]))
		var cw := 0.0
		if a.cut.is_empty() or m.cut.is_empty() or int(a.cut.m) != int(m.cut.m):
			cw = INF
		else:
			for k in int(a.cut.m):
				cw = maxf(cw, absf(float(m.cut.x[k]) + float(a.cut.x[k])) + absf(float(m.cut.z[k]) - float(a.cut.z[k])))
		_check("%s mirrored: the same road flipped" % a.def.id, m.n == a.n and worst < 0.05 and
			int(m.ramp.get("i", -1)) == int(a.ramp.get("i", -1)) and m.lake.is_empty() == a.lake.is_empty(),
			"(off by %.3f m)" % worst)
		_check("%s mirrored: the shortcut flipped" % a.def.id, cw < 0.05, "(off by %.3f m)" % cw)
		var step := _cut_surface_step(m)
		_check("%s mirrored: no take-off on the shortcut" % a.def.id, float(step[0]) < Kart.STEP_DROP * 0.6,
			"(drops %.2f m)" % float(step[0]))
		_check("%s mirrored: own records" % a.def.id, Game.record_key(t, 1) != Game.record_key(t + Game.TRACKS.size(), 1)
			and Game.ghost_path(t, 1) != Game.ghost_path(t + Game.TRACKS.size(), 1))
		# the developer's ghost on every difficulty, flipped on the mirrored track
		for d in Game.DIFFS.size():
			var g := Game.dev_ghost(t, d)
			var gm := Game.dev_ghost(t + Game.TRACKS.size(), d)
			var ok := not g.is_empty() and not gm.is_empty() and float(g.t) > 30.0 and (g.laps as Array).size() == Game.LAPS
			if ok:
				var gd: PackedFloat32Array = g.data
				var md: PackedFloat32Array = gm.data
				ok = gd.size() == md.size() and absf(md[61] + gd[61]) < 0.001 and absf(md[63] - gd[63]) < 0.001
			_check("%s %s: developer's ghost" % [a.def.id, Game.DIFFS[d].name], ok and Game.dev_limit(t, d) > float(g.get("t", 0.0)),
				"(%s, limit %s)" % [Game.fmt_time(float(g.get("t", 0.0))), Game.fmt_time(Game.dev_limit(t, d))])
	# time trials: under the limit on five tracks is not enough, on all six it is
	for t in Game.TRACKS.size() - 1:
		Game.settings.trials[Game.record_key(t, 1)] = Game.dev_limit(t, 1) - 0.5
	_check("time trials under the limit on 5 tracks: no ghost yet", Game.award_trial().is_empty())
	Game.settings.trials[Game.record_key(5, 2)] = Game.dev_limit(5, 2) + 1.0
	_check("  … over the limit on the 6th: still no ghost", Game.award_trial().is_empty())
	Game.settings.trials[Game.record_key(5, 0)] = Game.dev_limit(5, 0) - 0.1
	_check("  … under it on the 6th (another difficulty): the developer's ghost", Game.award_trial() == ["dev"])
	# a race on a mirrored track with the secret driver in gold
	Game.settings.driver = S
	Game.set_paint(S, 2)
	Game.settings.unlocks["paint2_%d" % S] = true
	Game.settings.mirror = true
	Game.settings.track = 2
	start_offline(1)
	var r := race
	r.paused = true
	var me: Kart = r.locals[0]
	_check("race on the mirrored track", r.track_idx == 2 + Game.TRACKS.size() and r.track.def.get("mirror", false))
	_check("the secret driver in gold", me.driver == S and me.paint == 2 and me.ch.color == Game.GOLD_PAINT[0])
	for k in r.karts:
		k.autopilot = true
	r._go()
	var t0 := me.progress()
	for i in int(25.0 / Game.SIM_DT):
		r._step(Game.SIM_DT)
	var moved := 1e9
	for k in r.karts:
		moved = minf(moved, k.progress() - t0)
	_check("everybody drives on the mirrored track", moved > 250.0, "(slowest %.0f m in 25 s)" % moved)
	# a time trial with the developer's ghost
	Game.settings.unlocks["dev"] = true
	start_trial()
	_check("time trial: the developer's ghost is out", race.dev_node != null and not race.dev.is_empty())
	# the Collection screen with everything won
	menu.show_screen("collection")
	_check("Collection screen", menu.content.get_child_count() > 5)
	menu.show_screen("setup")
	_check("race setup with mirrored tracks and paints", menu.content.get_child_count() > 5)


func _dev_ghost_run(ti: int, d: int) -> void:
	Game.settings.track = ti
	Game.settings.diff = d
	Game.settings.mirror = false
	Game.settings.driver = 0
	seed(4321)
	start_trial()
	var r := race
	r.paused = true
	var k: Kart = r.locals[0]
	k.autopilot = true
	k.ai.skill = 1.0
	r._go()
	var t := 0.0
	while not k.finished and t < 400.0:
		r._step(Game.SIM_DT)
		t += Game.SIM_DT
	var path := "res://ghosts/dev_%s_%d.dat" % [Game.TRACKS[ti].id, d]
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var({"t": k.finish_time, "laps": k.lap_times.duplicate(), "driver": 0, "paint": 2, "data": r.rec})
	f.close()
	print("DEVGHOST %s %s: %s (limit %s)" % [Game.TRACKS[ti].id, Game.DIFFS[d].name, Game.fmt_time(k.finish_time),
		Game.fmt_time(Game.dev_limit(ti, d))])


func _cut_run(ti: int, how: String, slow: float, diff: int) -> float:
	Game.settings.track = ti
	Game.settings.diff = diff            # not saved
	seed(1234)                           # the same luck every time (from the start): comparable times
	start_offline(1)
	var r := race
	r.paused = true
	r._go()
	seed(1234)
	var k: Kart = r.locals[0]
	for o in r.karts:
		if o != k:
			o.visible = false
	r.karts = [k]
	r.order = [k]
	for b in r.boxes:
		b.active = false
		b.respawn = INF
	var tr := r.track
	if tr.cut.is_empty():
		return INF
	tr.line_now()                        # the autopilot on the racing line from the first metre
	var keep: float = tr.cut.slow[diff]
	if slow > 0.0:
		tr.cut.slow[diff] = slow
	var a := int(tr.cut.a)
	_put(k, a - 50, 0.0)
	k.speed = k.max_speed() * 0.95
	k.autopilot = true
	k.ai.cut_go = 0
	k.ai.cut_force = -1 if how == "road" else 1
	k.cut_uses = 0
	k.item = Game.Item.TURBO if how == "cut+turbo" else 0
	k.item_n = 1 if how == "cut+turbo" else 0
	k.star = 0.0
	var goal := k.progress() + 100.0 + float(tr.cut.arc_span) + 40.0
	var t := 0.0
	var starred := false
	while k.progress() < goal and t < 60.0:
		if how == "cut+star" and k.on_cut and not starred:
			k.star = 7.0                 # the star from the moment the path starts
			starred = true
		r._step(Game.SIM_DT)
		t += Game.SIM_DT
	tr.cut.slow[diff] = keep
	var used := k.cut_uses > 0
	if (how == "road" and used) or (how != "road" and not used) or k.lap != 1:
		_check("%s %s %s" % [tr.def.id, Game.DIFFS[diff].name, how], false, "(shortcut used %d times, lap %d)" % [k.cut_uses, k.lap])
	return t


func _cut_checks() -> void:
	for ti in Game.TRACKS.size():
		var tr := Race.get_track(ti)
		if tr.cut.is_empty():
			_check("%s has a shortcut" % tr.def.id, false)
			continue
		var step := _cut_surface_step(tr)
		_check("%s: no take-off on the shortcut, even with the star" % tr.def.id, float(step[0]) < Kart.STEP_DROP * 0.6,
			"(drops %.2f m at most, %.0f m along the path, %.1f m from its middle)" % step)
		for d in Game.DIFFS.size():      # every difficulty: the karts' speed changes the balance
			var times := {}
			for how in ["road", "cut", "cut+turbo", "cut+star"]:
				times[how] = _cut_run(ti, how, 0.0, d)
			var id := "%s %s" % [tr.def.id, Game.DIFFS[d].name]
			print("CUT %s: road %.2f s, shortcut %.2f s, with a turbo %.2f s, with the star %.2f s" % [
				id, times.road, times.cut, times["cut+turbo"], times["cut+star"]])
			_check("%s: the shortcut alone does not pay" % id, times.cut > times.road * 0.97)
			_check("%s: with a turbo it does" % id, times["cut+turbo"] < times.road)
			_check("%s: with the star it does" % id, times["cut+star"] < times.road)


## Drives the whole path at full speed with the star (every 1 m across it) the
## way Kart._vertical does and returns how far the ground fell away below the
## kart in one tick at worst [m, along, across]: STEP_DROP or more throws it into the air.
func _cut_surface_step(tr: Track) -> Array:
	var worst := [0.0, 0.0, 0.0]
	var m: int = tr.cut.m
	var total: float = tr.cut.len
	var dt := Game.SIM_DT
	var ds := 62.0 * dt
	var off := -Track.CUT_W + 0.5
	while off <= Track.CUT_W - 0.5:
		var y := NAN
		var vy := 0.0
		var along := 0.0
		while along <= total:
			var k := clampi(tr.cut.s.bsearch(along), 1, m - 1)
			var f := (along - float(tr.cut.s[k - 1])) / maxf(float(tr.cut.s[k]) - float(tr.cut.s[k - 1]), 0.01)
			var px := lerpf(tr.cut.x[k - 1], tr.cut.x[k], f) - lerpf(tr.cut.tz[k - 1], tr.cut.tz[k], f) * off
			var pz := lerpf(tr.cut.z[k - 1], tr.cut.z[k], f) + lerpf(tr.cut.tx[k - 1], tr.cut.tx[k], f) * off
			var pc := tr.cut_project(px, pz, k)
			var gy := tr.cut_ground(px, pz, int(pc[0]), float(pc[2]))
			if not is_nan(y):
				var drop := y + vy * dt - Kart.STICK * Game.GRAVITY * dt * dt - gy
				if drop > float(worst[0]):
					worst = [drop, along, off]
				vy = clampf((gy - y) / dt, -30.0, 30.0)
			y = gy
			along += ds
		off += 1.0
	return worst


## --cuttest, second part: a race on each track with everybody on the shortcut every lap.
func _cut_race_tick() -> void:
	var done := true
	for k in race.karts:
		if not k.finished:
			done = false
	if not done and _test_t < 200.0:
		return
	for k in race.karts:
		_check("%s %s: 3 laps, the shortcut every lap" % [race.track.def.id, k.ch.name],
			k.finished and k.lap_times.size() >= Game.LAPS and k.cut_uses >= Game.LAPS,
			"(laps %d, shortcut %d times)" % [k.lap_times.size(), k.cut_uses])
	_ai_track += 1
	if _ai_track < Game.TRACKS.size():
		_start_ai_race()
		return
	_finish_test(_items_bad == 0, "shortcuts work on every track" if _items_bad == 0 else "%d problems" % _items_bad)


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


# ---------------------------------------------------------------- --nettest --battle
## Everything both sides must agree on once the battle is over: each kart's
## balloons, pops and whether it is out, every pop (whose balloon, by whom)
## and the winner. The host and the client print it, CI compares the lines.
func _battle_state(r: Race) -> String:
	var ks: Array = []
	for k: Kart in r.karts:
		ks.append("%d:%d:%d:%s" % [k.driver, k.balloons, k.pops, "out" if k.out else "in"])
	var ps: Array = []
	for pp: Array in r.battle.pops:
		var by: Kart = pp[2]
		ps.append("%d<%s" % [(pp[1] as Kart).driver, str(by.driver) if by != null else "-"])
	var w: Kart = r.battle.winner()
	return "karts %s | pops %s | winner %s" % [" ".join(ks), " ".join(ps), str(w.driver) if w != null else "-"]


## The rules hold in what this side saw: every kart lost one balloon for each
## pop on it, popped as many as the pops say, and is out exactly when it has
## none left. Empty when all is well.
func _battle_consistent(r: Race) -> String:
	for k: Kart in r.karts:
		var lost := 0
		var popped := 0
		for pp: Array in r.battle.pops:
			if pp[1] == k:
				lost += 1
			elif pp[2] == k:
				popped += 1
		if k.balloons != maxi(0, Game.BALLOONS - lost):
			return "%s has %d balloons after %d pops" % [r.display_name(k), k.balloons, lost]
		if k.pops != popped:
			return "%s popped %d, the pops say %d" % [r.display_name(k), k.pops, popped]
		if k.out != (k.balloons <= 0):
			return "%s is %s with %d balloons" % [r.display_name(k), "out" if k.out else "in", k.balloons]
	return ""


## Host: the battle to its end; a player who left was taken over by the
## computer (or stayed out); then everybody back to the lobby.
func _net_battle_host() -> void:
	var r := race
	for k: Kart in _net_left:
		var e: Dictionary = _net_left[k]
		if not k.out:
			e.dist = float(e.dist) + Vector2(k.x - float(e.x), k.z - float(e.z)).length()
		e.x = k.x
		e.z = k.z
	if r.results_shown and _done_at < 0.0:
		_done_at = _test_t
	if _done_at >= 0.0 and _test_t - _done_at > float(Game.cmd_args.get("linger", "5")):
		_done_at = -1.0
		print("BATTLE STATE: %s" % _battle_state(r))
		var bad := _battle_consistent(r)
		if r.battle.pops.is_empty() or r.battle.outs.is_empty():
			bad = "no balloon popped or nobody out"
		for k: Kart in _net_left:
			var e: Dictionary = _net_left[k]
			var ok_k: bool = not k.human and k.peer == 0 and (k.out if bool(e.out) else float(e.dist) > 10.0)
			print("HOST TAKEOVER: %s left at %.1f s %s, then %s: %s" % [r.display_name(k), float(e.t),
				"already out" if bool(e.out) else "with %d balloons" % int(e.balloons),
				"stayed out" if bool(e.out) else "the computer drove %.0f m%s" % [float(e.dist), ", out at the end" if k.out else ""],
				"ok" if ok_k else "FAIL"])
			if not ok_k:
				bad = "%s was not taken over" % r.display_name(k)
		var want_left := int(Game.cmd_args.get("wait-players", "2")) - 2
		if _net_left.size() < want_left:
			bad = "the player who should leave did not"
		var w: Kart = r.battle.winner()
		Net.return_to_lobby()
		_net_end = {"ok": bad == "", "t": _test_t,
			"why": "host battle over, %d pops, %d out, winner %s, back to the lobby" % [r.battle.pops.size(), r.battle.outs.size(),
				r.display_name(w) if w != null else "-"] if bad == "" else bad}
	if _test_t > float(Game.cmd_args.get("timeout", "300")):
		_finish_test(false, "timeout")


## Client: what the host decided arrived (the same balloons, pops and
## knock-outs), its own kart predicted well enough, then back in the lobby.
## With --leave-at=S it leaves in the middle of the battle instead.
func _net_battle_client() -> void:
	var r := race
	if _net_end.is_empty() and r != null and r.battle != null and r.mode == Race.Mode.CLIENT:
		var leave_at := float(Game.cmd_args.get("leave-at", "-1"))
		var me: Kart = r.locals[0]
		if leave_at >= 0.0 and r.state == "race" and r.race_time >= leave_at:
			print("CLIENT LEAVES the battle at %.1f s with %d balloons" % [r.race_time, me.balloons])
			Net.leave()
			_finish_test(true, "left in the middle of the battle")
			return
		if r.results_shown:
			var rep := r.prediction_report()
			print("PREDICTION lag=%d ms: error avg %.2f p95 %.2f max %.2f m (%d), correction avg %.2f p95 %.2f max %.2f m" % [
				int(Net.fake_lag), rep.err.avg, rep.err.p95, rep.err.max, rep.err.n, rep.corr.avg, rep.corr.p95, rep.corr.max])
			print("CLIENT SAW: %s" % ", ".join(r.net_seen.keys()))
			var felt := {}
			for b in Haptics.buzzes:
				felt[b[2]] = int(felt.get(b[2], 0)) + 1
			print("CLIENT FELT: %s, events %s" % [str(felt), str(Haptics.asked)])
			print("BATTLE STATE: %s" % _battle_state(r))
			var pred_ok: bool = rep.err.n > 100 and rep.err.p95 <= float(Game.cmd_args.get("max-err", "1.0"))
			var bad := _battle_consistent(r)
			if not r.battle.over:
				bad = "the battle is not over"
			elif r.battle.pops.is_empty() or r.battle.outs.is_empty():
				bad = "no pop or knock-out arrived"
			elif not pred_ok:
				bad = "prediction too far"
			_net_end = {"ok": bad == "", "t": _test_t, "why": "client battle place %d, %d balloons, popped %d, prediction ok" % [
				r.battle.standings().find(me) + 1, me.balloons, me.pops] if bad == "" else bad}
	elif not _net_end.is_empty() and not Net.in_race and menu.visible and menu.screen == "lobby":
		_finish_test(bool(_net_end.ok), String(_net_end.why) + ", back in the lobby")
	if _test_t > float(Game.cmd_args.get("timeout", "300")):
		_finish_test(false, "timeout" + (" waiting for the lobby" if not _net_end.is_empty() else ""))


# ---------------------------------------------------------------- --battletest
func _bt_check(name: String, ok: bool, info := "") -> void:
	print("BATTLE CHECK %s: %s %s" % [name, "ok" if ok else "FAIL", info])
	if not ok:
		_items_bad += 1


## A battle on Náměstí stopped at the start, every kart parked where the
## check wants it.
func _bt_setup() -> Race:
	Game.settings.arena = 0
	start_battle(1)
	var r := race
	r.paused = true
	r.state = "race"
	r.countdown = 0.0
	# everybody out of the way first, on the far side
	for i in r.karts.size():
		(r.karts[i] as Kart).reset(35.0 + (i % 3) * 7.0, -10.0 + (i / 3) * 14.0, PI)
	return r


func _bt_steps(r: Race, k: Kart, secs: float) -> void:
	var idle := {"steer": 0.0, "gas": false, "brake": false, "drift": false, "item": false}
	for i in int(secs / Game.SIM_DT):
		k.update(Game.SIM_DT, idle)


func _battle_rule_checks() -> void:
	var r := _bt_setup()
	var K: Array = r.karts
	var b: Battle = r.battle
	var dt := Game.SIM_DT
	var A: Kart = K[0]
	var B: Kart = K[1]
	var C: Kart = K[2]
	var D: Kart = K[3]
	var E: Kart = K[4]
	var F: Kart = K[5]
	_bt_check("everybody starts with %d balloons" % Game.BALLOONS, K.all(func(k): return k.balloons == Game.BALLOONS))
	# a missile takes a balloon (the nearest rival in front is the target)
	A.reset(-30.0, -25.0, 0.0)
	B.reset(-30.0, 0.0, 0.0)
	C.reset(-30.0, -40.0, 0.0)          # behind A: not the target
	_bt_check("missile target: the nearest rival in front", b.missile_target(A) == B)
	A.item = Game.Item.MISSILE
	A.item_n = 1
	r.use_item(A)
	for i in 300:
		r._update_items(dt)
		if r.missiles.is_empty():
			break
	_bt_check("a missile takes a balloon", B.balloons == 2 and A.pops == 1 and r.hits_landed == 1,
		"(B %d balloons, A popped %d)" % [B.balloons, A.pops])
	# protection: nothing more for 2 s, then the next hit counts again
	var node := r._banana_node()
	r.fx.add_child(node)
	r.bananas.append({"x": B.x, "y": B.y, "z": B.z, "node": node, "owner": C, "age": 1.0})
	r._update_items(dt)
	_bt_check("no balloon lost while protected", B.balloons == 2 and C.pops == 0, "(invuln %.2f s)" % B.invuln)
	_bt_check("protected for at least %d s" % int(Game.BATTLE_GUARD), B.invuln >= Game.BATTLE_GUARD - 0.01)
	_bt_steps(r, B, B.invuln + 0.05)
	var node2 := r._banana_node()
	r.fx.add_child(node2)
	r.bananas.append({"x": B.x, "y": B.y, "z": B.z, "node": node2, "owner": C, "age": 1.0})
	r._update_items(dt)
	_bt_check("after the protection a banana takes one", B.balloons == 1 and C.pops == 1)
	# the last balloon: out of the battle
	_bt_steps(r, B, B.invuln + 0.05)
	var at := Vector3(B.x, B.y, B.z)
	r.hit_kart(B, 1.1, false, C)
	_bt_check("the last balloon: out", B.out and B.finished and B.balloons == 0 and b.outs == [B] and C.pops == 2)
	_bt_check("out of the arena", not r.arena.inside(B.x, B.z) and B.out_at.distance_to(at) < 0.01)
	# the lightning only shrinks; running over a shrunk kart costs it a balloon
	D.reset(30.0, 30.0, 0.0)
	D.item = Game.Item.LIGHTNING
	D.item_n = 1
	var before := r.hits_landed
	r.use_item(D)
	_bt_check("the lightning takes no balloon", r.hits_landed == before and A.balloons == 3 and A.shrink > 0.0 and D.shrink <= 0.0)
	A.reset(30.0, 30.0, PI)
	A.shrink = Game.SHRINK_TIME
	D.reset(30.0, 31.0, 0.0)
	r._kart_collisions()
	_bt_check("running over a shrunk kart costs it a balloon", A.balloons == 2 and D.pops == 1)
	# a kart with the star pushes a balloon off
	E.reset(-20.0, 40.0, 0.0)
	F.reset(-20.0, 41.0, PI)
	E.star = 5.0
	r._kart_collisions()
	_bt_check("the star pushes a balloon off", F.balloons == 2 and E.pops == 1)
	# the blue missile goes for whoever has the most balloons
	C.balloons = 3
	D.balloons = 2
	E.balloons = 2
	_bt_check("blue missile: the most balloons", b.blue_target(E) == C, "(%s)" % (b.blue_target(E).ch.name if b.blue_target(E) != null else "nobody"))
	_bt_check("every hit cost exactly one balloon", r.hits_landed == b.pops.size())
	# time is up: most balloons first, then most popped, then those out (last out first)
	A.balloons = 2; A.pops = 1
	C.balloons = 3; C.pops = 0
	D.balloons = 2; D.pops = 3
	E.balloons = 1; E.pops = 4
	F.balloons = 2; F.pops = 0
	r.race_time = Game.BATTLE_TIME
	b.tick()
	var rows := b.standings()
	_bt_check("3 minutes: the battle ends", b.over and b.winner() == C)
	_bt_check("3 minutes: places by balloons, then by balloons popped", rows == [C, D, A, F, E, B],
		"(%s)" % ", ".join(rows.map(func(k): return "%s %d/%d" % [k.ch.name, k.balloons, k.pops])))
	# one kart left: it wins, the others by when they went out
	r = _bt_setup()
	K = r.karts
	b = r.battle
	for i in [3, 1, 4, 0, 2]:
		var k: Kart = K[i]
		k.balloons = 1
		r.hit_kart(k, 1.1, false, K[5])
	_bt_check("one left: it wins", b.over and b.winner() == K[5] and K[5].pops == 5)
	_bt_check("one left: the last one out is second", b.standings() == [K[5], K[2], K[0], K[4], K[1], K[3]])
	# a win on Hard gives the winning driver the battle paint (nothing saved)
	var was_off := Game.save_off
	Game.save_off = true
	var keep: Dictionary = Game.settings.unlocks.duplicate()
	var keep_b: Dictionary = Game.settings.battles.duplicate()
	Game.settings.unlocks.erase("paint3_4")
	var none := Game.award_battle([4], 1)
	var got := Game.award_battle([4], 2)
	_bt_check("a win on Hard: the battle paint", none.is_empty() and got == ["paint3_4"] and Game.paint_open(4, 3)
		and Game.look(4, 3).color == Game.BATTLE_PAINT[0] and Game.unlock_name("paint3_4").ends_with("bitevní lak"))
	Game.settings.unlocks = keep
	Game.settings.battles = keep_b
	Game.save_off = was_off
	r.paused = false


func _next_battle_run() -> void:
	if _bt_runs.is_empty():
		for row in _bt_rows:
			print(row)
		_finish_test(_items_bad == 0, "battles end with a winner, karts stay in, every hit costs one balloon" if _items_bad == 0
			else "%d problems" % _items_bad)
		return
	var run: Array = _bt_runs.pop_front()
	Game.settings.arena = int(run[0])
	Game.settings.diff = int(run[1])          # not saved
	start_battle(1)
	race.fast = int(Game.cmd_args.get("fast", "8"))
	for k in race.locals:
		k.autopilot = true
	_bt_watch = {}
	_bt_left = {}
	_bt_stuck = {}
	_bt_air = {}
	_bt_jumps = 0
	_bt_done_at = -1.0
	_test_t = 0.0


func _battle_tick() -> void:
	var r := race
	var b: Battle = r.battle
	if b == null:
		return
	if r.state == "race" and not b.over:
		for k: Kart in r.karts:
			if k.out:
				continue
			if k.air and not _bt_air.get(k, false):
				_bt_jumps += 1
			_bt_air[k] = k.air
			var sp := r.arena.space(k.x, k.z, k.y - 0.3)      # the same as Arena.constrain
			if (not r.arena.inside(k.x, k.z) or sp < Game.KART_R - 0.35) and not _bt_left.has(k):
				_bt_left[k] = true
				print("BATTLE LEFT %s at %.1f, %.1f (%.2f m from the nearest solid)" % [k.ch.name, k.x, k.z, sp])
			var w: Dictionary = _bt_watch.get(k, {})
			if w.is_empty() or r.race_time - float(w.t) >= 5.0:
				var n := 0
				if not w.is_empty():
					var moved := Vector2(k.x - float(w.x), k.z - float(w.z)).length()
					n = int(w.n) + 1 if moved < 3.0 else 0
					if n >= 2 and not _bt_stuck.has(k):
						_bt_stuck[k] = true
						print("BATTLE STUCK %s at %.1f, %.1f" % [k.ch.name, k.x, k.z])
				_bt_watch[k] = {"x": k.x, "z": k.z, "t": r.race_time, "n": n}
	var lost := 0
	for k: Kart in r.karts:
		lost += Game.BALLOONS - k.balloons
	if b.over and _bt_done_at < 0.0:
		_bt_done_at = _test_t
		var how := "one left" if b.alive().size() <= 1 else "time up"
		var ok := b.winner() != null and b.end_time <= Game.BATTLE_TIME + 0.05 and _bt_left.is_empty() and _bt_stuck.is_empty() \
			and lost == b.pops.size() and r.hits_landed == b.pops.size()
		if not ok:
			_items_bad += 1
		var used := []
		for it in range(1, Game.ITEM_COUNT + 1):
			if int(r.item_uses.get(it, 0)) > 0:
				used.append("%s %d" % [Game.ITEM_NAMES[it], int(r.item_uses[it])])
		_bt_rows.append("BATTLE %s %s: %s after %.0f s, winner %s with %d, %d balloons popped (hits %d), left the arena %d, stuck %d, jumps %d %s; items: %s" % [
			Game.ARENAS[int(Game.settings.arena)].id, Game.DIFFS[int(Game.settings.diff)].name, how, b.end_time,
			b.winner().ch.name, b.winner().balloons, b.pops.size(), r.hits_landed, _bt_left.size(), _bt_stuck.size(),
			_bt_jumps, "ok" if ok else "FAIL", ", ".join(used)])
		print(_bt_rows[-1])
	if _bt_done_at >= 0.0 and _test_t - _bt_done_at > 1.0:
		_next_battle_run()
	elif _test_t > float(Game.cmd_args.get("timeout", "90")):
		_items_bad += 1
		print("BATTLE TIMEOUT in %s %s at %.0f s" % [Game.ARENAS[int(Game.settings.arena)].id, Game.DIFFS[int(Game.settings.diff)].name, r.race_time])
		_next_battle_run()


## Gravity in the screen's frame (as Godot gives it) for a phone tilted back
## `back` degrees from upright and turned `deg` degrees to the right like a wheel.
static func _held(deg: float, back := 0.0) -> Vector3:
	var along := 9.81 * cos(deg_to_rad(back))     # the part along the screen
	var r := deg_to_rad(deg)
	return Vector3(along * sin(r), -along * cos(r), -9.81 * sin(deg_to_rad(back)))


static func _settle(t: Tilt, g: Vector3, secs := 1.0) -> void:
	for i in int(secs * 60.0):
		t.feed(g, 1.0 / 60.0)


func _tilt_check(name: String, ok: bool, info := "") -> void:
	print("TILT CHECK %s: %s %s" % [name, "ok" if ok else "FAIL", info])
	if not ok:
		_items_bad += 1


func _tilt_checks() -> void:
	var t := Tilt.new()
	_tilt_check("no sensor: no steering", t.steer(1) == 0.0 and not t.have)
	t.feed(Vector3.ZERO, 1.0 / 60.0)
	_tilt_check("zero reading ignored", not t.have)
	# held straight, tilted back as people hold a phone
	t = Tilt.new()
	_settle(t, _held(0.0, 40.0))
	_tilt_check("straight", t.steer(1) == 0.0, "%.3f" % t.steer(1))
	_settle(t, _held(Tilt.DEAD - 0.5, 0.0))
	_tilt_check("dead zone", t.steer(1) == 0.0, "%.3f" % t.steer(1))
	# upright the wheel angle is exact: full lock at FULL, half way between DEAD and FULL
	for s in Tilt.FULL.size():
		var full: float = Tilt.FULL[s]
		_settle(t, _held(full, 0.0))
		var at_full := t.steer(s)
		_settle(t, _held((Tilt.DEAD + full) * 0.5, 0.0))
		var half := t.steer(s)
		_settle(t, _held(-full - 5.0, 0.0))
		var past := t.steer(s)
		_tilt_check("%s: full lock at %.0f°" % [Tilt.NAMES[s], full], at_full > 0.995 and absf(half - 0.5) < 0.02 and past == -1.0,
			"full %.3f half %.3f past-left %.3f" % [at_full, half, past])
	# held back 45°: a little, a lot, past full lock, both ways alike
	var little := 0.0
	var lot := 0.0
	_settle(t, _held(8.0, 45.0))
	little = t.steer(1)
	_settle(t, _held(18.0, 45.0))
	lot = t.steer(1)
	_settle(t, _held(-18.0, 45.0))
	var lot_left := t.steer(1)
	_settle(t, _held(45.0, 45.0))
	var over := t.steer(1)
	_tilt_check("a little / a lot / past full lock", little > 0.05 and little < 0.4 and lot > 0.5 and lot < 0.9 and over == 1.0,
		"8° %.3f, 18° %.3f, 45° %.3f" % [little, lot, over])
	_tilt_check("left like right", absf(lot + lot_left) < 0.001, "%.3f / %.3f" % [lot, lot_left])
	var sens: Array = []
	for s in Tilt.FULL.size():
		_settle(t, _held(15.0, 30.0))
		sens.append(t.steer(s))
	_tilt_check("Jemná < Střední < Ostrá", sens[0] < sens[1] and sens[1] < sens[2], str(sens))
	# held nearly flat: the edge that dips still steers, no jump to full lock
	t = Tilt.new()
	_settle(t, _held(0.0, 88.0))
	var flat0 := t.steer(1)
	_settle(t, Vector3(9.81 * sin(deg_to_rad(6.0)), 0.0, -9.81 * cos(deg_to_rad(6.0))))
	var flat6 := t.steer(1)
	_tilt_check("nearly flat", flat0 == 0.0 and flat6 > 0.1 and flat6 < 0.8, "straight %.3f, right edge 6° down %.3f" % [flat0, flat6])
	# the axes half a turn behind the display (phone turned over to the other
	# landscape side without Android telling Godot): turned back here
	var right := _held(15.0, 40.0)
	var t_ok := Tilt.new()
	_settle(t_ok, right)
	t = Tilt.new()
	_settle(t, Vector3(-right.x, -right.y, right.z))
	var turned := t.steer(1)
	_settle(t, right)                     # Godot caught up with the display again
	var back_again := t.steer(1)
	_tilt_check("phone turned over", absf(turned - t_ok.steer(1)) < 0.001 and absf(back_again - t_ok.steer(1)) < 0.001,
		"right turn %.3f, stale axes %.3f, axes caught up %.3f" % [t_ok.steer(1), turned, back_again])
	# smoothing: one shaky reading barely moves the wheel, a real turn gets there quickly
	t = Tilt.new()
	_settle(t, _held(0.0, 40.0))
	t.feed(_held(25.0, 40.0), 1.0 / 60.0)
	var shake := t.steer(1)
	_settle(t, _held(0.0, 40.0), 0.5)
	_settle(t, _held(20.0, 0.0), 0.2)
	var quick := t.steer(1)
	_settle(t, _held(20.0, 0.0))
	var final := t.steer(1)
	_tilt_check("smoothing", shake < 0.25 and quick > 0.9 * final, "one shaky frame %.3f, after 0.2 s %.3f of %.3f" % [shake, quick, final])
	# levelling: held askew, then that is straight
	t = Tilt.new()
	_settle(t, _held(10.0, 40.0))
	var askew := t.steer(1)
	t.level()
	_settle(t, _held(10.0, 40.0), Tilt.LEVEL_TIME + 0.1)
	var leveled := t.steer(1)
	_settle(t, _held(25.0, 40.0))
	var more := t.steer(1)
	_settle(t, _held(-5.0, 40.0))
	var less := t.steer(1)
	_tilt_check("levelling", askew > 0.2 and leveled == 0.0 and more > 0.3 and less < -0.3,
		"askew %.3f, levelled %.3f, 15° more %.3f, 15° less %.3f" % [askew, leveled, more, less])
	# the controls: tilting steers the first player only with the phone's controls on
	Game.set_local_players(1)
	Game.touch.active = true
	Game.tilt = Tilt.new()
	_settle(Game.tilt, _held(20.0, 0.0))
	Game.settings.steer = 0
	var wheel_mode := float(Game.read_input(0).steer)
	Game.settings.steer = 1
	var tilt_mode := float(Game.read_input(0).steer)
	_tilt_check("controls", wheel_mode == 0.0 and absf(tilt_mode - Game.tilt.steer(int(Game.settings.tilt_sens))) < 0.001 and tilt_mode > 0.5,
		"wheel chosen %.3f, tilting chosen %.3f" % [wheel_mode, tilt_mode])
	Game.touch.active = false


## --tilttest, the race: the phone held 12° askew is straight once the
## countdown has levelled it, tilted 15° further right the kart turns right.
func _tilt_tick() -> void:
	var k: Kart = race.locals[0]
	if _tilt_phase == 0 and race.state == "race" and race.race_time > 1.0 and not Game.tilt.levelling():
		_tilt_phase = 1
		var st := float(Game.read_input(0).steer)
		_tilt_check("race: straight after the countdown", race.tilt_leveled and st == 0.0 and race.touch_ctl != null,
			"steer %.3f (phone held %.1f° askew, straight at %.1f°)" % [st, Game.tilt.angle, Game.tilt.zero])
		Game.fake_gravity = _held(27.0, 40.0)
		_tilt_at = _test_t
	elif _tilt_phase == 1 and _test_t - _tilt_at > 0.6:
		_tilt_phase = 2
		var st := float(Game.read_input(0).steer)
		_tilt_check("race: tilted right steers right", st > 0.3 and k.steer > 0.2, "input %.3f, kart %.3f" % [st, k.steer])
		_finish_test(_items_bad == 0, "tilting steers" if _items_bad == 0 else "%d problems" % _items_bad)
	elif _test_t > float(Game.cmd_args.get("timeout", "60")):
		_finish_test(false, "timeout")


## --hapticstest: knocks the test sets up itself (a hit, the lightning, the
## barrier, a drop from 6 m, a drift to purple sparks with the keys) and
## whatever the race brings (turbos, other karts, the finish). Vibrations are
## off for the whole second lap.
func _haptics_tick() -> void:
	var r := race
	var lead: Kart = r.locals[0]
	if r.results_shown:
		if _hap_at <= 0.0:
			_hap_at = _test_t
		elif _test_t - _hap_at > 1.0:            # the second buzz of the finish
			_haptics_checks()
		return
	if r.state != "race":
		return
	var t := r.race_time
	if _hap_phase == 0 and t > 5.0:
		var ok := true
		for k in r.locals:
			ok = (k.spin > 0.0 or k.hit(1.2, false)) and ok
		if ok:
			print("HAPTIC set up: a hit at %.1f s" % t)
			_hap_phase = 1
	elif _hap_phase == 1 and t > 10.0:
		var other: Kart = null
		for k in r.karts:
			if k.local_slot < 0:
				other = k
		r._lightning(other)
		print("HAPTIC set up: the lightning at %.1f s" % t)
		_hap_phase = 2
	elif _hap_phase == 2 and t > 16.0:
		for k in r.locals:
			_into_barrier(k)
		print("HAPTIC set up: into the barrier at %.1f s" % t)
		_hap_phase = 3
	elif _hap_phase == 3 and t > 22.0:
		var ok := true
		for k in r.locals:
			ok = not k.air and ok
		if ok:
			for k in r.locals:
				k.air = true
				k.air_t = 0.0
				k.vy = 0.0
				k.y += 6.0
			print("HAPTIC set up: a drop from 6 m at %.1f s" % t)
			_hap_phase = 4
	elif _hap_phase == 4 and t > 27.0:
		# a drift with the keys towards the wider side of the road, until the
		# sparks change colour (a drift always turns, so soon after it would
		# reach the barrier), then the turbo
		_hap_keys(true)
		_hap_at = t
		for k in r.locals:
			print("HAPTIC set up: a drift with the keys at %.1f s, speed %.0f, %.1f m from the middle" % [t, k.speed, k.lat])
		_hap_phase = 5
	elif _hap_phase == 5:
		var done := true
		for k in r.locals:
			done = done and k.drift_level >= 1
		if done or t > _hap_at + 1.5:
			for k in r.locals:
				print("HAPTIC drift: sparks level %d after %.2f s" % [k.drift_level, t - _hap_at])
			_hap_keys(false)
			_hap_phase = 6
	elif _hap_phase == 6 and lead.lap == 2:
		_hap_off = [Haptics.buzzes.size()]
		_hap_asked_off = -_asked_total()
		Game.settings.vibrate = false
		print("HAPTIC vibrations off at %.1f s" % t)
		_hap_at = t
		_hap_phase = 7
	elif _hap_phase == 7 and t > _hap_at + 4.0:
		for k in r.locals:
			k.hit(1.0, false)
		print("HAPTIC set up: a hit with vibrations off at %.1f s" % t)
		_hap_phase = 8
	elif _hap_phase == 8 and lead.lap == 3:
		_hap_off.append(Haptics.buzzes.size())
		_hap_asked_off += _asked_total()
		Game.settings.vibrate = true
		print("HAPTIC vibrations on again at %.1f s" % t)
		_hap_at = 0.0
		_hap_phase = 9
	if _test_t > float(Game.cmd_args.get("timeout", "300")):
		_finish_test(false, "timeout in phase %d" % _hap_phase)


## The local players hold gas, drift and left or right (towards the wider
## side of the road) on the keyboard (true), or let the autopilot drive
## again (false).
func _hap_keys(down: bool) -> void:
	var maps: Array = [Game.KEYS_SOLO] if race.locals.size() == 1 else [Game.KEYS_P1, Game.KEYS_P2]
	var tr := race.track
	for i in race.locals.size():
		var k: Kart = race.locals[i]
		k.autopilot = not down
		# steering right turns the heading down, so the kart's right is heading - 90°
		var th := tr.heading(k.idx)
		var plus_right := -cos(th) * tr.nx[k.idx] + sin(th) * tr.nz[k.idx] > 0.0
		var side := "left" if (k.lat > 0.0) == plus_right else "right"
		var other := "right" if side == "left" else "left"
		Game.key_down[maps[i].gas[0]] = down
		Game.key_down[maps[i].drift[0]] = down
		Game.key_down[maps[i][side][0]] = down
		Game.key_down[maps[i][other][0]] = false


func _asked_total() -> int:
	var n := 0
	for kind in Haptics.asked:
		n += int(Haptics.asked[kind])
	return n


## Puts kart k next to the barrier on its right, heading into it at 45°.
func _into_barrier(k: Kart) -> void:
	var tr := race.track
	var i := k.idx
	var lim := Game.BAR - Game.KART_R - 0.3
	k.x = tr.x[i] + tr.nx[i] * lim
	k.z = tr.z[i] + tr.nz[i] * lim
	var th := tr.heading(i)
	var f := Vector2(sin(th), cos(th)) + Vector2(tr.nx[i], tr.nz[i])
	k.heading = atan2(f.x, f.y)
	k.speed = maxf(k.speed, 20.0)
	k.bump_cd = 0.0


func _haptics_checks() -> void:
	var B: Array = Haptics.buzzes
	var kinds := {}
	var gaps := [INF, INF]
	var last := [-INF, -INF]
	var land: Array = []
	for i in B.size():
		var b: Array = B[i]
		var slot := int(b[1])
		kinds["%s/%d" % [b[2], slot]] = int(kinds.get("%s/%d" % [b[2], slot], 0)) + 1
		gaps[slot] = minf(gaps[slot], float(b[0]) - float(last[slot]))
		last[slot] = float(b[0])
		if b[2] == "land":
			land.append("%.2f" % float(b[4]))
	var asked: Array = []
	for kind in Haptics.KINDS:
		asked.append("%s %d" % [kind, int(Haptics.asked.get(kind, 0))])
	print("HAPTIC events: ", ", ".join(asked))
	print("HAPTIC buzzes: %d %s" % [B.size(), str(kinds)])
	print("HAPTIC landings (strength): ", ", ".join(land))
	var bad: Array = []
	for slot in race.locals.size():
		for kind in Haptics.KINDS:
			var need := 2 if kind == "finish" else 1      # the finish buzzes twice
			if int(kinds.get("%s/%d" % [kind, slot], 0)) < need:
				bad.append("player %d never felt %s" % [slot + 1, kind])
		if gaps[slot] < Haptics.GAP - 0.0001:
			bad.append("player %d: two buzzes %.3f s apart" % [slot + 1, gaps[slot]])
		print("HAPTIC player %d: shortest gap %.3f s" % [slot + 1, gaps[slot]])
	if _hap_off.size() < 2:
		bad.append("the second lap never came")
	else:
		print("HAPTIC with vibrations off: %d events, %d buzzes" % [_hap_asked_off, int(_hap_off[1]) - int(_hap_off[0])])
		if int(_hap_off[1]) != int(_hap_off[0]):
			bad.append("buzzed with vibrations off")
		if _hap_asked_off < 3:
			bad.append("too few events with vibrations off to tell")
	for b in bad:
		print("HAPTIC FAIL ", b)
	_finish_test(bad.is_empty(), "every event buzzes, never too often, nothing when off" if bad.is_empty() else "%d problems" % bad.size())


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

