class_name Race
extends Control
## One race (or the menu's demo race): world, karts, AI, items, cameras,
## split-screen views, HUD, pause and results.
## Offline and host run the simulation; a network client only renders the
## snapshots it receives from the host and sends its controls back.

signal restart_requested
signal menu_requested
signal lobby_requested
signal cup_next_requested(points: Dictionary)

enum Mode { DEMO, OFFLINE, HOST, CLIENT }

static var _tracks := {}
static var _worlds := {}

var mode: int = Mode.DEMO
var track: Track
var track_idx := 0
var diff_idx := 1
var diff: Dictionary
var world: Node3D
var atm: Dictionary
var ts: Dictionary
var holder: Node
var fx: Node3D
var skids: SkidMarks
var boxes: Array = []
var karts: Array = []
var order: Array = []
var locals: Array = []
var bananas: Array = []
var missiles: Array = []
var blues: Array = []           # blue missiles flying along the track to the leader
var oils: Array = []            # oil puddles
var item_uses := {}             # item -> how many times used (tests)
var net_seen := {}              # Wi-Fi client: which new items came in snapshots (tests)
var zap_t := 0.0                # the lightning's white flash over the screen
var zap_rect: ColorRect
var _cycle := 0
const OIL_TIME := 20.0
const OIL_R := 2.4
const BLUE_SPEED := 85.0
const BLUE_BLAST := 7.0
const DRIFT_IN := 0.24          # the computer starts a drift where the bend turns this fast (× turn rate)
const DRIFT_ANGLE := 1.6        # and only in bends turning at least this far (rad): shorter ones give no turbo
const AI_YAW := 0.8             # how fast (× turn rate) the computer reckons a kart turns at speed         # the blue missile's blast hits everyone this close to the leader
var explosions: Array = []
var explosion_id := 0
var seen_explosion := 0
var state := "countdown"
var countdown := 0.0
var shown_count := 99
var race_time := 0.0
var time := 0.0
var fast := 1
var paused := false
var tick := 0
var item_seq := 0
# Wi-Fi client: its own kart is simulated here at once from its controls
# (prediction); each snapshot from the host replaces that kart's state, the
# controls the host has not used yet are simulated again on top of it
var in_frame := 0               # number of the last control message sent
var hist := {}                  # frame -> [controls, x, y, z] predicted after it
var replaying := false
var pred_err := PackedFloat32Array()   # prediction vs host at the same frame (m)
var pred_corr := PackedFloat32Array()  # how far each snapshot moved the kart (m)
var render_scale := 1.0
var demo_focus: Kart
var demo_switch := 0.0
var all_done_t := -1.0
var results_shown := false
var results_refresh := 0.0
var podium: Array = []          # KartShow on the 1st, 2nd and 3rd step
var podium_t := -1.0
var confetti_t := 0.0
var split_bar: Control
var music_fast := false

var view_layer: Control
var overlay: Control
var panes: Array = []
var touch_ctl: Control
var pause_panel: Control
var results_panel: Control
var results_body: VBoxContainer
var cup := {}                   # set by Main for a championship round: {round, points, diff}
var cup_body: VBoxContainer
var cup_next: Button
var net_points := {}            # Wi-Fi client: this race's points as the host counts them
var trial := false              # time trial: alone, no item boxes, three turbos, against a ghost
var ghost := {}                 # the best drive on this track: {t, laps, driver, data}
var ghost_node: Node3D
var ghost_i := 0
var ghost_idx := 0
var ghost_shown := false        # the ghost was out on the track (tests check it)
var dev := {}                   # the developer's ghost (Etapa F), once won
var dev_node: Node3D
var dev_i := 0
var dev_idx := -1
var dev_shown := false
var unlocked_now: Array = []    # rewards won by this race, shown with the results (Etapa F)
var trial_prev := 0.0           # the record before this drive (0 = none)
var rec := PackedFloat32Array() # this drive: every GHOST_DT seconds t, x, y, z, yaw, in the air
var rec_next := 0.0
const GHOST_DT := 0.1
const GHOST_F := 6


static func get_track(i: int) -> Track:
	if not _tracks.has(i):
		_tracks[i] = Track.new(Game.track_def(i))
		(_tracks[i] as Track).prepare_line()   # the computer drivers' racing line, in the background
	return _tracks[i]


## Worlds are cached per track and quality level (scenery density depends
## on it), so "race again" starts at once. Building another one drops every
## cached world that is not on screen: with six tracks they would fill a
## phone's memory.
static func get_world(i: int) -> Dictionary:
	var key := "%d_%d" % [i, Gfx.level()]
	if not _worlds.has(key):
		for k in _worlds.keys():
			var root: Node3D = _worlds[k].root
			if root.get_parent() == null:
				root.queue_free()
				_worlds.erase(k)
		_worlds[key] = WorldBuilder.build(get_track(i))
	return _worlds[key]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder = Node.new()
	add_child(holder)
	view_layer = Control.new()
	view_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	# the lightning's flash; hidden when not flashing (a full-screen blend costs)
	zap_rect = ColorRect.new()
	zap_rect.color = Color(0.9, 0.95, 1.0, 0.0)
	zap_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zap_rect.visible = false
	add_child(zap_rect)


## roster: Array of {driver, human, peer, name, local} in grid order (index 0 = front row).
func start(p_mode: int, p_track: int, p_diff: int, roster: Array) -> void:
	mode = p_mode
	track_idx = p_track
	diff_idx = p_diff
	diff = Game.DIFFS[p_diff]
	track = get_track(p_track)
	var w := get_world(p_track)
	world = w.root
	boxes = w.boxes
	atm = w.atm
	ts = w.trackside
	Atmosphere.apply_quality(atm)
	Kart.apply_quality()
	if world.get_parent() != null:
		world.get_parent().remove_child(world)
	holder.add_child(world)
	for b in boxes:
		b.active = not trial
		b.respawn = INF if trial else 0.0
		b.scale = 1.0
		b.node.visible = not trial
		b.node.scale = Vector3.ONE
	fx = Node3D.new()
	holder.add_child(fx)
	skids = SkidMarks.new()
	fx.add_child(skids)
	render_scale = Gfx.render_scale()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var k := Kart.new()
		k.setup(self, int(r.driver), int(r.get("paint", 0)))
		holder.add_child(k)
		k.human = bool(r.get("human", false))
		k.peer = int(r.get("peer", 0))
		k.player_name = String(r.get("name", ""))
		k.local_slot = int(r.get("local", -1))
		var gp := _grid_pos(i)
		k.reset(gp.x, gp.y, gp.z)
		k.ai = {"lane": (-1.0 if i % 2 == 1 else 1.0) * (0.12 + randf() * 0.33) * Game.HW, "phase": randf() * 10.0,
			"t": 0.0, "rb": 1.0, "stuck": 0.0, "rev": 0.0, "item_t": 1.0, "last_seq": 0, "gas_at": -1.0, "dev": 0.0, "plan": {},
			"skill": (0.93 if p_mode == Mode.DEMO else float(diff.ai)) + (randf() - 0.5) * 0.035}
		karts.append(k)
	var loc: Array = []
	for k in karts:
		if k.local_slot >= 0:
			loc.append(k)
	loc.sort_custom(func(a, b): return a.local_slot < b.local_slot)
	locals = loc
	var multi_human := 0
	for k in karts:
		if k.human:
			multi_human += 1
	for k in karts:
		if k.human and multi_human > 1:
			k.set_name_tag(k.player_name)
	order = karts.duplicate()
	_compute_ranks()
	if mode == Mode.DEMO:
		state = "demo"
		demo_focus = karts[0]
	else:
		state = "countdown"
		countdown = 3.6
	for k in karts:
		_reset_obs(k)
	_make_views()
	Game.set_local_players(maxi(1, locals.size()))
	if trial:
		_start_trial()
	if not cup.is_empty():
		get_tree().create_timer(0.5).timeout.connect(_cup_banner)
	Sfx.music(mode != Mode.DEMO, false)
	if mode == Mode.CLIENT:              # the Wi-Fi test checks these arrived
		if Game.is_mirror(track_idx):
			net_seen["zrcadlo"] = true
		for k in karts:
			if k.paint > 0:
				net_seen["lak"] = true


## Remove the cached world before this race is freed so it can be reused.
## A finished championship saves its result here, whichever way you leave.
func dispose() -> void:
	if results_shown and _cup_last() and not locals.is_empty():
		_save_cup()
	if world != null and world.get_parent() == holder:
		holder.remove_child(world)
	for i in 2:
		Sfx.engine(i, 0.0, false)
	Game.touch.active = false


func _grid_pos(slot: int) -> Vector3:
	var n := track.n
	var row := slot / 2
	var col := slot % 2
	var back := 7.0 + row * 6.0 + (3.0 if col == 1 else 0.0)
	var i := (n - int(round(back / track.step))) % n
	var la := (-1.0 if col == 1 else 1.0) * Game.HW * 0.4
	return Vector3(track.x[i] + track.nx[i] * la, track.z[i] + track.nz[i] * la, track.heading(i))


# ================================================================== views
func _make_views() -> void:
	var count := maxi(1, locals.size())
	for i in count:
		var pane := Control.new()
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_layer.add_child(pane)
		pane.anchor_left = 0.0
		pane.anchor_right = 1.0
		pane.anchor_top = 0.0 if count == 1 else 0.5 * i
		pane.anchor_bottom = 1.0 if count == 1 else 0.5 * (i + 1)
		pane.offset_left = 0
		pane.offset_right = 0
		pane.offset_top = 2 if (count == 2 and i == 1) else 0
		pane.offset_bottom = -2 if (count == 2 and i == 0) else 0
		var vp := SubViewport.new()
		vp.msaa_3d = Gfx.msaa()
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.size = Vector2i(640, 360)
		vp.audio_listener_enable_3d = false
		pane.add_child(vp)
		var tex := TextureRect.new()
		tex.texture = vp.get_texture()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pane.add_child(tex)
		var cam := Camera3D.new()
		cam.near = 0.5
		cam.far = 1500.0
		cam.fov = 72.0
		cam.cull_mask = 0xFFFFF & ~(1 << (10 + i))
		vp.add_child(cam)
		cam.current = true
		var p := {"root": pane, "vp": vp, "cam": cam, "kart": locals[i] if i < locals.size() else null,
			"yaw": 0.0, "fov": 72.0, "shake": 0.0, "hud": null, "snapped": false, "lines": null, "cy": 0.0}
		if mode != Mode.DEMO and p.kart != null:
			var sl := SpeedLines.new()
			pane.add_child(sl)
			sl.setup(p.kart)
			p.lines = sl
			var hud := Hud.new()
			pane.add_child(hud)
			hud.setup(self, p.kart, count > 1)
			p.hud = hud
		panes.append(p)
	if count == 2:
		var bar := ColorRect.new()
		split_bar = bar
		bar.color = UI.INK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.5
		bar.anchor_bottom = 0.5
		bar.offset_top = -2
		bar.offset_bottom = 2
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view_layer.add_child(bar)
	if mode != Mode.DEMO and locals.size() == 1 and (Game.is_mobile() or Game.cmd_args.has("touch")):
		touch_ctl = TouchControls.new()
		overlay.add_child(touch_ctl)
		Game.touch.active = true


## Re-reads the quality level for things that can change mid-race
## (scenery density, particle counts and snow follow from the next race).
func apply_quality() -> void:
	render_scale = Gfx.render_scale()
	for p in panes:
		p.vp.msaa_3d = Gfx.msaa()
	Atmosphere.apply_quality(atm)
	Kart.apply_quality()
	for k in karts:
		k.blob.visible = not Gfx.shadows()


func shake(slot: int, amount: float) -> void:
	if slot >= 0 and slot < panes.size():
		panes[slot].shake = maxf(panes[slot].shake, amount)


func _ear(px: float, pz: float) -> float:
	var best := 0.0
	for p in panes:
		var c: Camera3D = p.cam
		var d := Vector2(px - c.global_position.x, pz - c.global_position.z).length()
		best = maxf(best, clampf(1.0 - d / 90.0, 0.0, 1.0))
	return best


func sound_at(name: String, px: float, pz: float, local := false, vol := 1.0) -> void:
	var v := 1.0 if local else _ear(px, pz)
	if v > 0.05:
		Sfx.play(name, v * vol)


func burst(pos: Vector3, color: Color, amount: int, speed: float, additive := true, size := 0.7, life := 0.6) -> void:
	var p := CPUParticles3D.new()
	p.mesh = Kart.particle_mesh(size, additive)
	p.amount = Gfx.amount(amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -8, 0)
	p.color = color
	p.color_ramp = Kart.fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


# ================================================================== simulation
func _physics_process(_delta: float) -> void:
	if karts.is_empty():
		return
	if mode == Mode.CLIENT:
		_client_tick()
		return
	if paused:
		return
	for k in karts:
		k.begin_tick()
	for i in 2 * fast:
		_step(Game.SIM_DT)
	tick += 1
	if mode == Mode.HOST and tick % 2 == 0:
		Net.send_snapshot(_pack())


func _step(dt: float) -> void:
	time += dt
	if state == "countdown":
		var prev := countdown
		countdown -= dt
		for k in karts:
			if k.human:
				var inp := _human_input(k)
				if inp.gas and float(k.ai.gas_at) < 0.0:
					k.ai.gas_at = countdown
				if not inp.gas:
					k.ai.gas_at = -1.0
		if countdown <= 0.0 and prev > 0.0:
			_go()
		return
	if state == "race":
		race_time += dt
	for k in karts:
		var inp: Dictionary
		if k.human and not k.finished and not k.autopilot:
			inp = _human_input(k)
		else:
			inp = _ai_input(k, dt)
		k.update(dt, inp)
	_kart_collisions()
	for k in karts:
		k.constrain()
	if trial and state == "race" and race_time >= rec_next and not locals[0].finished:
		_record(locals[0])
	_update_items(dt)
	_compute_ranks()
	for k in karts:
		if k.human and not k.finished and state == "race":
			var fwd := cos(Game.wrap_angle(k.heading - k.way_heading()))
			if fwd < -0.2 and absf(k.speed) > 3.0:
				k.wrong_t += dt
			else:
				k.wrong_t = 0.0


func _go() -> void:
	state = "race"
	if trial:
		for k in locals:
			k.item = Game.Item.TURBO   # three turbos to spend where they help most
			k.item_n = 3
	for k in karts:
		k.lap_start = 0.0
		if k.human:
			var ga: float = k.ai.gas_at
			if ga > 0.1 and ga < 1.05:
				k.boost = 1.1
				k.boost_mul = 1.3
		elif randf() < float(diff.get("start", 0.3)) + float(Game.PERSONA[k.driver].start):
			k.boost = 0.8
			k.boost_mul = 1.25


func _human_input(k: Kart) -> Dictionary:
	if k.local_slot >= 0:
		return Game.read_input(k.local_slot)
	var ni = Net.inputs.get(k.peer)
	if ni == null:
		return {"steer": 0.0, "gas": false, "brake": false, "drift": false, "item": false}
	var btn: int = ni.buttons
	k.ack = int(ni.get("frame", 0))
	var item: bool = int(ni.seq) != int(k.ai.last_seq)
	k.ai.last_seq = int(ni.seq)
	return {"steer": float(ni.steer), "gas": btn & 1 != 0, "brake": btn & 2 != 0, "drift": btn & 4 != 0, "item": item}


func on_lap(k: Kart, dir: int) -> void:
	if mode == Mode.CLIENT:
		return   # laps and the finish come from the host
	k.lap += dir
	if dir < 0 or k.lap <= k.max_lap:
		return
	k.max_lap = k.lap
	if mode == Mode.DEMO:
		if k.lap > Game.LAPS:
			k.lap = 1
			k.max_lap = 1
		return
	if k.lap >= 2:
		k.last_lap = race_time - k.lap_start
		k.lap_times.append(k.last_lap)
		k.lap_start = race_time
	if k.lap > Game.LAPS and not k.finished:
		k.finished = true
		k.finish_time = race_time
		k.autopilot = true


func on_bump(k: Kart, loss: float) -> void:
	if replaying:
		return
	sound_at("bump", k.x, k.z, k.local_slot >= 0, clampf(loss * 1.5, 0.3, 1.0))
	if k.local_slot >= 0:
		shake(k.local_slot, 0.25 * loss)


func _compute_ranks() -> void:
	var arr := karts.duplicate()
	arr.sort_custom(_rank_cmp)
	for i in arr.size():
		arr[i].rank = i + 1
	order = arr


static func _rank_cmp(a: Kart, b: Kart) -> bool:
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished != b.finished:
		return a.finished
	return a.progress() > b.progress()


func _kart_collisions() -> void:
	var mn := Game.KART_R * 2.0 * 0.95
	for i in karts.size():
		for j in range(i + 1, karts.size()):
			var a: Kart = karts[i]
			var b: Kart = karts[j]
			var dx := b.x - a.x
			var dz := b.z - a.z
			var d2 := dx * dx + dz * dz
			if d2 >= mn * mn or d2 < 1e-6 or absf(a.y - b.y) > 1.6:
				continue
			var d := sqrt(d2)
			var nx := dx / d
			var nz := dz / d
			var ov := mn - d
			var wa: float = float(b.ch.weight) / (float(a.ch.weight) + float(b.ch.weight))
			a.x -= nx * ov * wa
			a.z -= nz * ov * wa
			b.x += nx * ov * (1.0 - wa)
			b.z += nz * ov * (1.0 - wa)
			if a.star > 0.0 and b.star <= 0.0:
				b.hit(1.0, false)
			elif b.star > 0.0 and a.star <= 0.0:
				a.hit(1.0, false)
			elif a.shrink > 0.0 and b.shrink <= 0.0:
				a.hit(1.0, false)   # a kart made small by the lightning is run over
			elif b.shrink > 0.0 and a.shrink <= 0.0:
				b.hit(1.0, false)
			if sin(a.heading) * nx + cos(a.heading) * nz > 0.5:
				a.speed *= 0.97
			if -(sin(b.heading) * nx + cos(b.heading) * nz) > 0.5:
				b.speed *= 0.97
			if (a.local_slot >= 0 or b.local_slot >= 0) and a.bump_cd <= 0.0 and b.bump_cd <= 0.0:
				a.bump_cd = 0.35
				b.bump_cd = 0.35
				Sfx.play("bump", 0.5)


# ---------------------------------------------------------------- AI
func _ai_input(k: Kart, dt: float) -> Dictionary:
	var tr := track
	var n := tr.n
	var ai: Dictionary = k.ai
	var per: Dictionary = Game.PERSONA[k.driver]
	var base: Dictionary = Game.BASE
	ai.t += dt
	var out := {"steer": 0.0, "gas": true, "brake": false, "drift": false, "item": false}
	if ai.rev > 0.0:
		ai.rev -= dt
		out.gas = false
		out.brake = true
		var jr := (k.idx + 8) % n
		out.steer = clampf(Game.wrap_angle(atan2(tr.x[jr] - k.x, tr.z[jr] - k.z) - k.heading) * 2.0, -1.0, 1.0)
		return out
	if not tr.cut.is_empty() and _ai_cut(k, out):
		_ai_items_and_tricks(k, out, 0.0, false, dt)
		return out
	var line := tr.racing_line()
	var lc := tr.line_curv()
	var look := 4 + int(absf(k.speed) * 0.22)
	var j := (k.idx + look) % n
	# ---- where to drive: the racing line, a little wander, aside for karts and hazards
	var want := float(line[j]) + sin(ai.t * 0.3 + ai.phase) * float(per.wander) * Game.HW
	var my_p := k.progress()
	for o in karts:
		if o == k or o.finished:
			continue
		var gap: float = o.progress() - my_p
		if gap > 0.0 and gap < 12.0 and absf(o.lat - want) < 2.8 and o.speed < k.speed + 2.0:
			# someone slower ahead on our line: pass on the side with more road
			want = o.lat - 4.0 if o.lat > float(line[j]) else o.lat + 4.0
		elif absf(gap) < 2.5 and absf(o.lat - k.lat) < 6.0 and float(per.aggr) > 0.0 and o.spin <= 0.0:
			# a rival right beside us: the rough ones lean on them
			want = lerpf(want, o.lat, 0.5 * float(per.aggr))
	var wide := _plan_drift(k, look)
	if not is_nan(wide):
		want = wide                     # out to the edge before a bend we will drift through
	for b in bananas:
		want = _dodge(k, b.x, b.z, want, 2.0, 35.0)
	for b in oils:
		want = _dodge(k, b.x, b.z, want, OIL_R + 1.0, 40.0)
	want = clampf(want, -Game.HW * 0.85, Game.HW * 0.85)
	ai.dev = move_toward(float(ai.dev), want - float(line[j]), 7.0 * dt)
	var lane := clampf(float(line[j]) + float(ai.dev), -Game.HW * 0.85, Game.HW * 0.85)
	var tx := tr.x[j] + tr.nx[j] * lane
	var tz := tr.z[j] + tr.nz[j] * lane
	var dif := Game.wrap_angle(atan2(tx - k.x, tz - k.z) - k.heading)
	out.steer = clampf(-dif * 2.4, -1.0, 1.0)
	# ---- how fast: as fast as the bends of the line ahead allow, braking in time
	var mx := k.max_speed()
	var turn := float(base.turn) * float(k.ch.handling)
	var yaw := turn * (1.0 if k.drift_active else AI_YAW)   # how fast the kart can turn at speed
	var decel := float(base.brake) * 0.6 * float(per.corner)
	var allowed: float = ai.get("allowed", INF)
	ai.tick = int(ai.get("tick", 0)) + 1
	if int(ai.tick) % 3 == 0 or k.drift_active:   # every third step is plenty
		allowed = INF
		for s in range(1, 40, 2):
			var c := absf(float(lc[(k.idx + s) % n]))
			if c < 1e-4:
				continue
			var vc := yaw / c * float(per.corner)
			allowed = minf(allowed, sqrt(vc * vc + 2.0 * decel * maxf(0.0, s * tr.step - k.along)))
		ai.allowed = allowed
	var straight := allowed > mx * 1.3
	var rb_t := 1.0
	if mode != Mode.DEMO and not k.human:
		var best := -INF
		for h in karts:
			if h.human and not h.finished:
				best = maxf(best, h.progress())
		if best > -INF:
			var d := my_p - best
			rb_t = 1.08 if d < -60.0 else (1.03 if d < -20.0 else (0.94 if d > 140.0 else (0.97 if d > 60.0 else 1.0)))
			rb_t = 1.0 + (rb_t - 1.0) * float(diff.get("band", 1.0))   # gentler on the harder levels
	ai.rb = lerpf(ai.rb, rb_t, clampf(dt * 0.6, 0.0, 1.0))
	var target: float = minf(mx * float(ai.skill) * float(ai.rb) * (float(per.straight) if straight else 1.0), allowed)
	out.gas = k.speed < target
	out.brake = k.speed > target + 3.0
	if absf(dif) > 1.3:
		out.gas = k.speed < 12.0
	# ---- drift through long bends for a turbo on the way out
	_ai_drift(k, out, dif, lc, turn, mx)
	if absf(k.speed) < 2.0 and k.spin <= 0.0 and state != "countdown":
		ai.stuck += dt
	else:
		ai.stuck = 0.0
	if ai.stuck > 1.3:
		ai.stuck = 0.0
		ai.rev = 0.9
		ai.revs = int(ai.get("revs", 0)) + 1
	_ai_items_and_tricks(k, out, dif, straight, dt)
	if k.human and Game.cmd_args.has("fxtest"):
		# screenshots only: the autopilot drifts through corners
		var want_drift: bool = absf(float(out.steer)) > 0.12 and k.speed > k.max_speed() * 0.5
		if want_drift and not k.drift_active:
			out.steer = signf(float(out.steer)) * maxf(absf(float(out.steer)), 0.3)
		out.drift = want_drift or (k.drift_active and absf(float(out.steer)) > 0.04)
	return out


## Items at the right moment (the impatient ones at once) and tricks in the air.
func _ai_items_and_tricks(k: Kart, out: Dictionary, dif: float, straight: bool, dt: float) -> void:
	var ai: Dictionary = k.ai
	var per: Dictionary = Game.PERSONA[k.driver]
	if int(ai.get("cut_go", 0)) == 1 and k.item == Game.Item.TURBO and not k.on_cut:
		return                           # the turbo is kept for the shortcut
	if k.item != 0 and k.roulette <= 0.0:
		ai.item_t -= dt
		if ai.item_t <= 0.0:
			var use := _ai_item(k, dif, straight)
			if float(per.patience) <= 0.0 or ai.item_t < -9.0 * float(per.patience):
				use = true
			if use:
				out.item = true
				ai.item_t = 0.6 + randf() * 1.5
	# most flights get a trick (turbo on landing); better drivers try more often
	if k.air and k.air_t > 0.12 and not k.tricked:
		out.drift = fposmod(float(k.driver * 7 + k.lap * 3), 10.0) < 10.0 * float(ai.skill) - 2.0


## The shortcut: whether to take it is decided once on the way to it (only
## with a turbo or the star, more often on the harder levels); then the
## path is followed and a held turbo is fired on it. False when the usual
## driving applies.
func _ai_cut(k: Kart, out: Dictionary) -> bool:
	var ai: Dictionary = k.ai
	var tr := track
	var c: Dictionary = tr.cut
	var m: int = c.m
	var ci := k.cut_i
	if not k.on_cut:
		var to_a := (int(c.a) - k.idx + tr.n) % tr.n
		var past := (k.idx - int(c.a) + tr.n) % tr.n     # the path leaves the road gradually after sample a
		if past > 40 and to_a > 45:
			ai.cut_go = 0
			return false
		if int(ai.get("cut_go", 0)) == 0:
			var equipped := k.boost > 0.6 or k.star > 1.5 or k.item == Game.Item.TURBO
			var p: float = [0.25, 0.6, 0.9][diff_idx] if equipped else 0.0
			var force := int(ai.get("cut_force", 0))
			if Game.cmd_args.has("cut-always"):
				force = 1
			ai.cut_go = force if force != 0 else (1 if randf() < p else -1)
		if int(ai.cut_go) != 1:
			return false
		if past > 40 and to_a > 6:
			# over to the side the path leaves from
			var jr := (k.idx + 4 + int(absf(k.speed) * 0.22)) % tr.n
			var lane := float(c.sa) * Game.HW * 0.6
			_ai_aim(k, out, Vector2(tr.x[jr] + tr.nx[jr] * lane, tr.z[jr] + tr.nz[jr] * lane), INF)
			return true
		ci = int(tr.cut_project(k.x, k.z, -1)[0])
	# along the path: aim ahead on it, slow enough for its bends
	var j := mini(ci + 3 + int(absf(k.speed) * 0.15), m - 1)
	var target := Vector2(float(c.x[j]), float(c.z[j]))
	if j == m - 1:
		var b := (int(c.b) + 6) % tr.n
		target = Vector2(tr.x[b], tr.z[b])
	var turn := float(Game.BASE.turn) * float(k.ch.handling) * float(c.grip) * 0.7
	var slow_for := INF
	var bendy := 0.0
	for s in range(2, 40, 3):
		var i0 := mini(ci + s, m - 3)
		var cv := absf(Game.wrap_angle(atan2(float(c.tx[i0 + 2]), float(c.tz[i0 + 2])) - atan2(float(c.tx[i0]), float(c.tz[i0])))) / 4.0
		bendy = maxf(bendy, cv)
		if cv > 1e-4 and s < 24:
			var vc := turn / cv
			slow_for = minf(slow_for, sqrt(vc * vc + 2.0 * 25.0 * maxf(0.0, s * 2.0 - 4.0)))
	# a held turbo: once well on the path, lined up, with a straight-ish stretch ahead
	if k.on_cut and k.item == Game.Item.TURBO and k.roulette <= 0.0 and k.boost <= 0.2 and ci > 12 and ci < m - 30 \
			and bendy < 0.012 and absf(Game.wrap_angle(k.heading - tr.cut_heading(ci))) < 0.15 and absf(k.lat) < 2.0:
		out.item = true
	_ai_aim(k, out, target, slow_for)
	return true


## Steers at a point and keeps under a speed.
func _ai_aim(k: Kart, out: Dictionary, target: Vector2, top: float) -> void:
	var dif := Game.wrap_angle(atan2(target.x - k.x, target.y - k.z) - k.heading)
	out.steer = clampf(-dif * 2.4, -1.0, 1.0)
	out.gas = (absf(dif) < 1.3 or k.speed < 12.0) and k.speed < top
	out.brake = k.speed > top + 4.0


## Moves the wanted lane aside for a banana or puddle on it ahead.
func _dodge(k: Kart, hx: float, hz: float, want: float, r: float, range_m: float) -> float:
	var dx := hx - k.x
	var dz := hz - k.z
	if dx * dx + dz * dz > range_m * range_m:
		return want
	var tr := track
	var pj := tr.project(hx, hz, k.idx)
	var ahead: float = ((int(pj[0]) - k.idx + tr.n) % tr.n) * tr.step
	if ahead > 2.0 and ahead < range_m and absf(float(pj[1]) - want) < r + 1.5:
		return float(pj[1]) + (-(r + 3.0) if float(pj[1]) > 0.0 else r + 3.0)
	return want


## Drifting: a drift pays only when it lasts (about 100° of turning for the
## first turbo), so it starts at the outside going into a long bend (how
## often depends on the level and the driver), follows the bend as tightly
## as needed and is let go as the bend ends or at the inside edge.
func _ai_drift(k: Kart, out: Dictionary, dif: float, lc: PackedFloat32Array, turn: float, mx: float) -> void:
	var ai: Dictionary = k.ai
	var tr := track
	var n := tr.n
	if not k.drift_active:
		var plan: Dictionary = ai.get("plan", {})
		if plan.is_empty() or not plan.go or k.air or k.offroad or k.spin > 0.0 or k.speed < mx * 0.55:
			return
		var sg: float = plan.sg
		var into := (k.idx - int(plan.i) + n) % n      # samples past the start of the bend
		if into > n / 2:
			return                       # not there yet
		if into > 12:
			ai.plan = {}                 # missed it
			return
		if absf(float(tr.curv[(k.idx + 2) % n])) * k.speed >= turn * DRIFT_IN and k.lat * sg > 2.0:
			ai.plan = {}
			out.drift = true
			out.steer = -sg * maxf(absf(float(out.steer)), 0.5)
		return
	# in the drift: turn as little as the bend allows (a long drift charges more),
	# harder only when the outside edge comes close
	var dd := k.drift_dir
	var sgd := -dd                      # the way the bend turns
	var c := float(tr.curv[(k.idx + 3) % n])
	var outside := k.lat * sgd           # metres towards the outside of the bend
	var need := c * k.speed * sgd + maxf(0.0, outside - (Game.HW - 3.0)) * 0.35
	var tight := clampf((need / turn - 0.5) / 0.62, 0.0, 1.0)
	out.steer = dd * (2.0 * tight - 1.0)
	out.drift = true
	var ending := true
	for s in range(2, 8):
		var cc := float(tr.curv[(k.idx + s) % n])
		if signf(cc) == sgd and absf(cc) * k.speed > turn * DRIFT_IN * 0.6:
			ending = false
	var inside := -outside > Game.HW - 0.3          # reached the inside kerb
	if ending or (inside and need < turn * 0.5):
		out.drift = false


## A long bend coming up: decide once whether to drift through it (by level
## and driver) and, if so, return the lane at its outside edge to get there
## in time; NAN when there is nothing to prepare for.
func _plan_drift(k: Kart, look: int) -> float:
	var ai: Dictionary = k.ai
	var tr := track
	var n := tr.n
	var plan: Dictionary = ai.get("plan", {})
	if plan.is_empty():
		if k.drift_active:
			return NAN
		for s in range(4, 22, 2):
			var i := (k.idx + s) % n
			if absf(float(tr.curv[i])) < 1.0 / 150.0 or absf(float(tr.curv[(i - 2 + n) % n])) >= 1.0 / 150.0:
				continue                 # not where a bend begins
			var bend := _bend_ahead((i - 3 + n) % n)
			if float(bend[0]) >= DRIFT_ANGLE:
				var p := clampf(float(diff.get("drift", 0.5)) * float(Game.PERSONA[k.driver].drift), 0.0, 1.0)
				plan = {"i": i, "sg": float(bend[1]), "go": randf() < p}
				ai.plan = plan
				break
	if plan.is_empty() or not plan.go:
		if not plan.is_empty() and (k.idx - int(plan.i) + n) % n < n / 2 and (k.idx - int(plan.i) + n) % n > 12:
			ai.plan = {}
		return NAN
	return float(plan.sg) * (Game.HW - 1.5)


## The bend of the centre line starting at sample i: [how far it turns (rad), which way].
func _bend_ahead(i: int) -> Array:
	var tr := track
	var n := tr.n
	var sg := signf(tr.curv[(i + 3) % n])
	var ang := 0.0
	for s in range(3, 120):
		var c := float(tr.curv[(i + s) % n])
		if signf(c) != sg or absf(c) < 1.0 / 150.0:
			break
		ang += absf(c) * tr.step
	return [ang, sg]


## Whether to use the held item now.
func _ai_item(k: Kart, dif: float, straight: bool) -> bool:
	match k.item:
		Game.Item.TURBO:
			# on a straight, or to get off the grass quickly
			return (straight and absf(dif) < 0.2) or (k.offroad and absf(dif) < 0.5)
		Game.Item.STAR:
			# when falling behind, or to get out of a missile's way
			return k.rank >= 4 or _threatened(k) or k.spin > 0.0
		Game.Item.MISSILE:
			var ah: Kart = order[k.rank - 2] if k.rank >= 2 else null
			if ah == null:
				return false
			var ang := Game.wrap_angle(atan2(ah.x - k.x, ah.z - k.z) - k.heading)
			return ah.progress() - k.progress() < 70.0 and absf(ang) < 0.5
		Game.Item.BANANA, Game.Item.OIL:
			# kept behind as protection: dropped when someone is right behind, or to catch a missile
			var bh: Kart = order[k.rank] if k.rank < order.size() else null
			return (bh != null and k.progress() - bh.progress() < 15.0) or _threatened(k)
		Game.Item.BLUE, Game.Item.LIGHTNING:
			return true
		Game.Item.SHIELD:
			return k.shield <= 0.0 and (_threatened(k) or randf() < 0.004)
	return false


# ---------------------------------------------------------------- items
## The draw depends on the place: defensive items at the front, stronger
## ones at the back; the blue missile only for the last places, the
## lightning only for the last two.
func give_item(k: Kart) -> void:
	k.ai.item_t = 0.8 + randf() * 2.5
	if Game.cmd_args.has("item-cycle"):
		# tests: every item in turn
		_cycle += 1
		k.item = 1 + _cycle % Game.ITEM_COUNT
		k.item_n = 1
		return
	var p := clampf((k.rank - 1.0) / (karts.size() - 1.0), 0.0, 1.0)
	var mid := 1.0 - absf(2.0 * p - 1.0)
	var last_two := k.rank >= karts.size() - 1 and karts.size() > 2
	var w := [
		[Game.Item.BANANA, 1, lerpf(44, 4, p)], [Game.Item.OIL, 1, lerpf(20, 2, p)], [Game.Item.TURBO, 1, lerpf(24, 18, p)],
		[Game.Item.SHIELD, 1, 3.0 + 14.0 * mid], [Game.Item.MISSILE, 1, lerpf(9, 22, p)],
		[Game.Item.TURBO, 3, lerpf(0, 20, p)], [Game.Item.STAR, 1, lerpf(0, 13, p)],
		[Game.Item.BLUE, 1, 9.0 * smoothstep(0.55, 1.0, p)], [Game.Item.LIGHTNING, 1, 4.0 if last_two else 0.0],
	]
	var sum := 0.0
	for e in w:
		sum += e[2]
	var r := randf() * sum
	k.item = Game.Item.TURBO
	k.item_n = 1
	for e in w:
		r -= e[2]
		if r <= 0.0:
			k.item = e[0]
			k.item_n = e[1]
			break
	k.ai.item_t = 0.8 + randf() * 2.5


func use_item(k: Kart) -> void:
	if k.item == Game.Item.TURBO:
		k.boost = maxf(k.boost, 1.3)
		k.boost_mul = 1.4
	elif k.item == Game.Item.BANANA:
		_drop_banana(k)
	elif k.item == Game.Item.MISSILE:
		_fire_missile(k)
	elif k.item == Game.Item.STAR:
		k.star = 7.0
	elif k.item == Game.Item.BLUE:
		_fire_blue(k)
	elif k.item == Game.Item.OIL:
		_drop_oil(k)
	elif k.item == Game.Item.LIGHTNING:
		_lightning(k)
	elif k.item == Game.Item.SHIELD:
		k.shield = Game.SHIELD_TIME
	item_uses[k.item] = int(item_uses.get(k.item, 0)) + 1
	k.item_n -= 1
	if k.item_n <= 0:
		k.item = 0
		k.item_n = 0


func _banana_node() -> Node3D:
	var g := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd43b")
	mat.roughness = 0.4
	for i in 3:
		var c := CapsuleMesh.new()
		c.radius = 0.17
		c.height = 0.62
		c.radial_segments = 8
		c.rings = 2
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		var a := (i - 1) * 0.55
		mi.position = Vector3(sin(a) * 0.38, 0.38 - cos(a) * 0.38 + 0.2, 0)
		mi.rotation.z = a + PI / 2.0
		g.add_child(mi)
	return g


func _missile_node(blue := false) -> Node3D:
	var g := Node3D.new()
	if blue:
		g.scale = Vector3.ONE * 1.35
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("2f6fe8") if blue else Color("e63946")
	if blue:
		red.emission_enabled = true
		red.emission = Color(0.2, 0.45, 1.0)
		red.emission_energy_multiplier = 0.6
	red.roughness = 0.3
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f5f5f5")
	var body := CylinderMesh.new()
	body.top_radius = 0.32
	body.bottom_radius = 0.32
	body.height = 1.4
	body.radial_segments = 10
	var b := MeshInstance3D.new()
	b.mesh = body
	b.material_override = red
	b.rotation.x = PI / 2.0
	g.add_child(b)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.32
	cone.height = 0.6
	cone.radial_segments = 10
	var c := MeshInstance3D.new()
	c.mesh = cone
	c.material_override = white
	c.rotation.x = PI / 2.0
	c.position.z = 1.0
	g.add_child(c)
	for dims in [Vector3(1.0, 0.06, 0.36), Vector3(0.06, 1.0, 0.36)]:
		var fm := BoxMesh.new()
		fm.size = dims
		var f := MeshInstance3D.new()
		f.mesh = fm
		f.material_override = white
		f.position.z = -0.6
		g.add_child(f)
	var trail := CPUParticles3D.new()
	trail.mesh = Kart.particle_mesh(0.7, true)
	trail.amount = Gfx.amount(30)
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.direction = Vector3(0, 0, -1)
	trail.spread = 10.0
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 2.0
	trail.gravity = Vector3.ZERO
	trail.color = Color(0.4, 0.7, 1.0) if blue else Color(1.0, 0.55, 0.15)
	trail.color_ramp = Kart.fade_ramp()
	trail.position.z = -1.0
	trail.emitting = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(trail)
	# glowing exhaust flame
	var flame := MeshInstance3D.new()
	flame.mesh = Kart._shared().flame
	flame.material_override = Kart._shared().flamem
	flame.rotation.x = -PI / 2.0
	flame.position.z = -1.15
	flame.scale = Vector3(1.2, 0.8, 1.2)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(flame)
	return g


func _drop_banana(k: Kart) -> void:
	var px := k.x - sin(k.heading) * 2.9
	var pz := k.z - cos(k.heading) * 2.9
	var pj := track.project(px, pz, k.idx)
	var la: float = pj[1]
	if absf(la) > Game.BAR - 1.5 and track.cut_at(px, pz).is_empty():
		var d := absf(la) - (Game.BAR - 1.5)
		var sg := signf(la)
		px -= track.nx[pj[0]] * sg * d
		pz -= track.nz[pj[0]] * sg * d
	var py := track.ground(px, pz, k.idx)
	var node := _banana_node()
	node.position = Vector3(px, py + 0.25, pz)
	node.rotation.y = randf() * TAU
	fx.add_child(node)
	bananas.append({"x": px, "y": py, "z": pz, "node": node, "owner": k, "age": 0.0})
	if bananas.size() > 24:
		var old: Dictionary = bananas.pop_front()
		old.node.queue_free()
	sound_at("drop", k.x, k.z, k.local_slot >= 0)


func _fire_missile(k: Kart) -> void:
	var target: Kart = order[k.rank - 2] if k.rank >= 2 else null
	var px := k.x + sin(k.heading) * 2.8
	var pz := k.z + cos(k.heading) * 2.8
	var py := track.ground(px, pz, k.idx) + 0.9
	var node := _missile_node()
	node.position = Vector3(px, py, pz)
	fx.add_child(node)
	missiles.append({"x": px, "y": py, "z": pz, "h": k.heading, "v": maxf(k.speed + 26.0, 64.0), "owner": k, "target": target,
		"life": 9.0, "age": 0.0, "idx": k.idx, "node": node})
	sound_at("missile", k.x, k.z, k.local_slot >= 0)


## A missile or the blue missile flying at this kart (the computer then raises its shield).
func _threatened(k: Kart) -> bool:
	for m in missiles:
		if m.get("target") == k and Vector2(float(m.x) - k.x, float(m.z) - k.z).length() < 70.0:
			return true
	for b in blues:
		if b.get("target") == k:   # a Wi-Fi client does not know the targets
			return true
	return false


## Blue missile: flies high along the track to whoever leads and blows up
## over them, catching the karts close by too.
func _fire_blue(k: Kart) -> void:
	var target: Kart = order[0] if order[0] != k else (order[1] if order.size() > 1 else null)
	var node := _missile_node(true)
	fx.add_child(node)
	var b := {"x": k.x, "y": k.y + 1.5, "z": k.z, "h": k.heading, "prog": k.progress() + 3.0, "owner": k,
		"target": target, "life": 30.0, "dive": 0.0, "node": node}
	blues.append(b)
	_place_blue(b)
	sound_at("blue", k.x, k.z, k.local_slot >= 0)


## The blue missile's place `prog` metres along the race, high over the road.
func _place_blue(b: Dictionary) -> void:
	var tr := track
	var s := fposmod(float(b.prog), tr.length)
	var i := int(s / tr.step) % tr.n
	var j := (i + 1) % tr.n
	var u := clampf((s - i * tr.step) / tr.step, 0.0, 1.0)
	var nx := lerpf(tr.x[i], tr.x[j], u)
	var nz := lerpf(tr.z[i], tr.z[j], u)
	if absf(nx - float(b.x)) + absf(nz - float(b.z)) > 0.001:
		b.h = atan2(nx - float(b.x), nz - float(b.z))
	b.x = nx
	b.z = nz
	b.y = lerpf(tr.y[i], tr.y[j], u) + 4.0


func _drop_oil(k: Kart) -> void:
	var px := k.x - sin(k.heading) * 4.2
	var pz := k.z - cos(k.heading) * 4.2
	var pj := track.project(px, pz, k.idx)
	var la: float = pj[1]
	if absf(la) > Game.HW and track.cut_at(px, pz).is_empty():
		var d := absf(la) - Game.HW
		var sg := signf(la)
		px -= track.nx[pj[0]] * sg * d
		pz -= track.nz[pj[0]] * sg * d
		pj = track.project(px, pz, pj[0])
	var node := _oil_node()
	fx.add_child(node)
	var o := {"x": px, "y": 0.0, "z": pz, "node": node, "owner": k, "age": 0.0}
	_place_oil(o, pj)
	oils.append(o)
	if oils.size() > 8:
		var old: Dictionary = oils.pop_front()
		old.node.queue_free()
	sound_at("oil", k.x, k.z, k.local_slot >= 0)


## Lies flat on the road, tilted with its slope and bank.
func _place_oil(o: Dictionary, pj: Array) -> void:
	o.y = track.road_y(pj[0], pj[1], pj[2], false)
	var up := track.normal(pj[0], pj[1], pj[2], false)
	var fwd := Vector3(track.tx[pj[0]], 0.0, track.tz[pj[0]])
	var pc := track.cut_at(o.x, o.z)
	if not pc.is_empty():
		# on the shortcut
		o.y = track.cut_y(pc[0], pc[2])
		up = track.cut_normal(pc[0])
		fwd = Vector3(float(track.cut.tx[pc[0]]), 0.0, float(track.cut.tz[pc[0]]))
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var node: Node3D = o.node
	node.transform = Transform3D(Basis(up.cross(fwd), up, fwd), Vector3(o.x, float(o.y) + 0.04, o.z))


func _oil_node() -> Node3D:
	var g := Node3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.05)
	dark.metallic = 0.4
	dark.roughness = 0.08
	var sheen := StandardMaterial3D.new()
	sheen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheen.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sheen.albedo_color = Color(0.22, 0.3, 0.45, 0.35)
	# a blobby puddle: a big round patch and a few smaller ones at its edge
	for e in [[Vector2.ZERO, 1.0], [Vector2(1.5, 0.6), 0.55], [Vector2(-1.2, 1.0), 0.5], [Vector2(0.4, -1.6), 0.45]]:
		var c := CylinderMesh.new()
		c.top_radius = OIL_R * float(e[1])
		c.bottom_radius = c.top_radius
		c.height = 0.03
		c.radial_segments = 18
		c.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = dark
		mi.position = Vector3(e[0].x, 0.0, e[0].y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	var s := CylinderMesh.new()
	s.top_radius = OIL_R * 0.28
	s.bottom_radius = s.top_radius
	s.height = 0.01
	s.radial_segments = 14
	s.rings = 1
	var si := MeshInstance3D.new()
	si.mesh = s
	si.material_override = sheen
	si.position = Vector3(-0.7, 0.025, -0.5)
	si.scale = Vector3(1.6, 1.0, 0.5)
	si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(si)
	return g


## Lightning: everyone else shrinks for a while (slower, can be run over).
## The star protects, a shield is used up instead.
func _lightning(k: Kart) -> void:
	for o in karts:
		if o == k or o.finished or o.star > 0.0:
			continue
		if o.shield > 0.0:
			o.shield = 0.0
			continue
		o.shrink = Game.SHRINK_TIME
		o.speed *= 0.6
		o.drift_active = false
		o.drift_level = 0
		o.drift_charge = 0.0


## kind 0: a missile, 1: the blue missile's blast
func _explode(px: float, pz: float, kind := 0) -> void:
	explosion_id += 1
	explosions.append([explosion_id, px, pz, kind])
	if explosions.size() > 3:
		explosions.pop_front()
	_explode_fx(px, pz, kind)


func _explode_fx(px: float, pz: float, kind := 0) -> void:
	var gp := Vector3(px, track.ground(px, pz), pz)
	Effects.explosion(fx, gp)
	if kind == 1:
		Effects.flash(fx, gp + Vector3(0, 2.0, 0), Color(0.45, 0.7, 1.0), 16.0, 0.5)
		Effects.shockwave(fx, gp + Vector3(0, 0.3, 0), Color(0.4, 0.7, 1.0), BLUE_BLAST * 2.2, 0.7)
	for p in panes:
		var c: Camera3D = p.cam
		var d := Vector2(px - c.global_position.x, pz - c.global_position.z).length()
		if d < 40.0:
			p.shake = maxf(float(p.shake), 0.5 * (1.0 - d / 40.0))
	sound_at("explode", px, pz)


func _update_items(dt: float) -> void:
	var tr := track
	for b in boxes:
		if not b.active:
			b.respawn -= dt
			if b.respawn <= 0.0:
				b.active = true
				b.scale = 0.05
			continue
		for k in karts:
			var dx: float = k.x - b.x
			var dz: float = k.z - b.z
			if dx * dx + dz * dz < 2.6 * 2.6 and k.y < float(b.y) + 1.2:
				b.active = false
				b.respawn = 2.5
				if k.item == 0 and k.roulette <= 0.0 and not k.finished:
					k.roulette = 1.3 if k.local_slot >= 0 or k.human else 1.0
				break
	for i in range(bananas.size() - 1, -1, -1):
		var b: Dictionary = bananas[i]
		b.age += dt
		for k in karts:
			if k == b.owner and b.age < 0.7:
				continue
			var dx: float = k.x - b.x
			var dz: float = k.z - b.z
			if dx * dx + dz * dz < 1.9 * 1.9 and k.y - float(b.y) < 1.0:
				k.hit(1.1, false)
				b.node.queue_free()
				bananas.remove_at(i)
				break
	for i in range(missiles.size() - 1, -1, -1):
		var m: Dictionary = missiles[i]
		m.age += dt
		m.life -= dt
		var tx := 0.0
		var tz := 0.0
		var homing := false
		var tg: Kart = m.target
		if tg != null and not tg.finished:
			var ddx := tg.x - float(m.x)
			var ddz := tg.z - float(m.z)
			if ddx * ddx + ddz * ddz < 50.0 * 50.0:
				tx = tg.x
				tz = tg.z
				homing = true
		if not homing:
			var jj := (int(m.idx) + 9) % tr.n
			tx = tr.x[jj]
			tz = tr.z[jj]
		var des := atan2(tx - float(m.x), tz - float(m.z))
		m.h += clampf(Game.wrap_angle(des - float(m.h)), -4.5 * dt, 4.5 * dt)
		m.x += sin(m.h) * m.v * dt
		m.z += cos(m.h) * m.v * dt
		var pj := tr.project(m.x, m.z, m.idx)
		m.idx = pj[0]
		var over_cut := tr.cut_at(m.x, m.z, 1.0)
		m.y = (tr.cut_y(over_cut[0], over_cut[2]) if not over_cut.is_empty() else tr.road_y(pj[0], pj[1], pj[2])) + 0.9   # skims along the road, over hills and the ramp
		var boom: bool = m.life <= 0.0 or (absf(float(pj[1])) > Game.BAR - 0.6 and over_cut.is_empty())
		if not boom:
			for k in karts:
				if k == m.owner and m.age < 0.6:
					continue
				var dx: float = k.x - m.x
				var dz: float = k.z - m.z
				if dx * dx + dz * dz < 4.0 and absf(k.y + 0.6 - float(m.y)) < 1.6:
					k.hit(1.6, true)
					boom = true
					break
		if not boom:
			for jb in range(bananas.size() - 1, -1, -1):
				var b: Dictionary = bananas[jb]
				var dx: float = b.x - m.x
				var dz: float = b.z - m.z
				if dx * dx + dz * dz < 1.6 * 1.6:
					b.node.queue_free()
					bananas.remove_at(jb)
					boom = true
					break
		if boom:
			_explode(m.x, m.z)
			m.node.queue_free()
			missiles.remove_at(i)
	# oil: a long skid for whoever drives in (the owner gets a moment to get away)
	for i in range(oils.size() - 1, -1, -1):
		var o: Dictionary = oils[i]
		o.age += dt
		if o.age >= OIL_TIME:
			o.node.queue_free()
			oils.remove_at(i)
			continue
		for k in karts:
			if k == o.owner and o.age < 1.0:
				continue
			var dx: float = k.x - o.x
			var dz: float = k.z - o.z
			if dx * dx + dz * dz < (OIL_R + 0.4) * (OIL_R + 0.4) and absf(k.y - float(o.y)) < 1.0 and not k.air:
				k.hit(1.9, false)
	for i in range(blues.size() - 1, -1, -1):
		if _update_blue(blues[i], dt):
			blues[i].node.queue_free()
			blues.remove_at(i)


## Moves one blue missile; true when it has blown up.
func _update_blue(b: Dictionary, dt: float) -> bool:
	b.life -= dt
	var tg: Kart = b.target
	if tg == null or tg.finished:
		# the leader crossed the line: on to whoever leads now
		tg = null
		for k in order:
			if not k.finished and k != b.owner:
				tg = k
				break
		b.target = tg
	if tg == null or b.life <= 0.0:
		_explode(b.x, b.z, 1)
		return true
	var gap := tg.progress() - float(b.prog)
	if float(b.dive) <= 0.0 and gap > 10.0:
		b.prog = float(b.prog) + minf(BLUE_SPEED * dt, gap - 9.0)
		_place_blue(b)
		return false
	# right behind the leader: it drops onto them
	b.dive = float(b.dive) + dt
	var to := Vector3(tg.x - float(b.x), tg.y + 0.8 - float(b.y), tg.z - float(b.z))
	var step := BLUE_SPEED * 0.7 * dt
	if to.length() <= step + 1.2 or float(b.dive) > 1.2:
		_blue_blast(tg)
		return true
	var mv := to.normalized() * step
	b.x = float(b.x) + mv.x
	b.y = float(b.y) + mv.y
	b.z = float(b.z) + mv.z
	b.h = atan2(to.x, to.z)
	b.prog = tg.progress() - 1.0
	return false


func _blue_blast(tg: Kart) -> void:
	_explode(tg.x, tg.z, 1)
	for k in karts:
		var d := Vector2(k.x - tg.x, k.z - tg.z).length()
		if k == tg or (d < BLUE_BLAST and absf(k.y - tg.y) < 3.0):
			k.hit(1.8, true)


# ================================================================== network
func _pack() -> PackedFloat32Array:
	var nk := karts.size()
	var head := 14
	var d := PackedFloat32Array()
	d.resize(head + nk * Kart.SNAP_FIELDS + bananas.size() * 2 + missiles.size() * 3 + blues.size() * 4 + oils.size() * 3)
	d[0] = {"countdown": 0, "race": 1}.get(state, 1)
	d[1] = countdown
	d[2] = race_time
	d[3] = nk
	d[4] = bananas.size()
	d[5] = missiles.size()
	var bits := 0
	for i in boxes.size():
		if boxes[i].active:
			bits |= 1 << i
	d[6] = bits
	d[7] = explosions.size()
	d[8] = blues.size()
	d[9] = oils.size()
	# header slots 10-13 are reserved; explosions (id * 4 + kind, x, z) go after the projectiles
	var o := head
	for k in karts:
		k.pack(d, o)
		o += Kart.SNAP_FIELDS
	for b in bananas:
		d[o] = b.x
		d[o + 1] = b.z
		o += 2
	for m in missiles:
		d[o] = m.x
		d[o + 1] = m.z
		d[o + 2] = m.h
		o += 3
	for b in blues:
		d[o] = b.x
		d[o + 1] = b.z
		d[o + 2] = b.y
		d[o + 3] = b.h
		o += 4
	for p in oils:
		d[o] = p.x
		d[o + 1] = p.z
		d[o + 2] = p.age
		o += 3
	var ex := PackedFloat32Array()
	for e in explosions:
		ex.append_array(PackedFloat32Array([int(e[0]) * 4 + int(e[3]), e[1], e[2]]))
	d.append_array(ex)
	return d


func apply_snapshot(d: PackedFloat32Array) -> void:
	if karts.is_empty() or d.size() < 14:
		return
	var nk := int(d[3])
	if nk != karts.size():
		return
	var st := int(d[0])
	state = "countdown" if st == 0 else "race"
	countdown = d[1]
	race_time = d[2]
	var nb := int(d[4])
	var nm := int(d[5])
	var bits := int(d[6])
	for i in boxes.size():
		var act := (bits >> i) & 1 == 1
		if act and not boxes[i].active:
			boxes[i].scale = 0.05
		boxes[i].active = act
	var o := 14
	var me: Kart = locals[0] if not locals.is_empty() else null
	var was := [me.x, me.y, me.z, me.heading] if me != null and me.predicted else []
	for k in karts:
		k.unpack(d, o)
		o += Kart.SNAP_FIELDS
	if not was.is_empty():
		_reconcile(me, was)
	while bananas.size() < nb:
		var node := _banana_node()
		fx.add_child(node)
		bananas.append({"x": 0.0, "y": 0.0, "z": 0.0, "node": node, "owner": null, "age": 0.0, "fresh": true})
	while bananas.size() > nb:
		var b: Dictionary = bananas.pop_back()
		b.node.queue_free()
	for b in bananas:
		if absf(float(b.x) - d[o]) + absf(float(b.z) - d[o + 1]) > 0.01:
			b.y = track.ground(d[o], d[o + 1])
		b.x = d[o]
		b.z = d[o + 1]
		b.node.position = Vector3(b.x, float(b.y) + 0.25, b.z)
		if b.get("fresh", false):
			b.fresh = false
			sound_at("drop", b.x, b.z)
		o += 2
	while missiles.size() < nm:
		var node := _missile_node()
		fx.add_child(node)
		missiles.append({"x": 0.0, "y": 0.0, "z": 0.0, "h": 0.0, "idx": -1, "node": node, "fresh": true})
	while missiles.size() > nm:
		var m: Dictionary = missiles.pop_back()
		m.node.queue_free()
	for m in missiles:
		m.x = d[o]
		m.z = d[o + 1]
		m.h = d[o + 2]
		var mp := track.project(m.x, m.z, int(m.idx) if int(m.idx) >= 0 else track.nearest(m.x, m.z))
		m.idx = mp[0]
		m.y = track.road_y(mp[0], mp[1], mp[2]) + 0.9
		if m.get("fresh", false):
			m.fresh = false
			sound_at("missile", m.x, m.z)
		o += 3
	var nbl := int(d[8])
	if nbl > 0:
		net_seen["modrá raketa"] = true
	if int(d[9]) > 0:
		net_seen["olej"] = true
	for k in karts:
		if k.shield > 0.0:
			net_seen["štít"] = true
		if k.shrink > 0.0:
			net_seen["blesk"] = true
		if k.on_cut:
			net_seen["zkratka"] = true
	while blues.size() < nbl:
		var node := _missile_node(true)
		fx.add_child(node)
		blues.append({"x": 0.0, "y": 0.0, "z": 0.0, "h": 0.0, "node": node, "fresh": true})
	while blues.size() > nbl:
		var b: Dictionary = blues.pop_back()
		b.node.queue_free()
	for b in blues:
		b.x = d[o]
		b.z = d[o + 1]
		b.y = d[o + 2]
		b.h = d[o + 3]
		if b.get("fresh", false):
			b.fresh = false
			sound_at("blue", b.x, b.z)
		o += 4
	var nol := int(d[9])
	while oils.size() < nol:
		var node := _oil_node()
		fx.add_child(node)
		oils.append({"x": INF, "y": 0.0, "z": 0.0, "node": node, "age": 0.0})
	while oils.size() > nol:
		var p: Dictionary = oils.pop_back()
		p.node.queue_free()
	for p in oils:
		if absf(float(p.x) - d[o]) + absf(float(p.z) - d[o + 1]) > 0.01:
			if p.x == INF:
				sound_at("oil", d[o], d[o + 1])
			p.x = d[o]
			p.z = d[o + 1]
			_place_oil(p, track.project(p.x, p.z, track.nearest(p.x, p.z)))
		p.age = d[o + 2]
		o += 3
	var ne := int(d[7])
	for i in ne:
		if o + 2 >= d.size():
			break
		var code := int(d[o])
		var eid := code >> 2
		if eid > seen_explosion:
			seen_explosion = eid
			_explode_fx(d[o + 1], d[o + 2], code & 3)
		o += 3
	_compute_order_client()


func _compute_order_client() -> void:
	var arr := karts.duplicate()
	arr.sort_custom(func(a, b): return a.rank < b.rank)
	order = arr


func _client_tick() -> void:
	if locals.is_empty():
		return
	var me: Kart = locals[0]
	# the tests drive the client's kart with the computer driver, through the network as a player would
	var inp: Dictionary = _ai_input(me, Game.SIM_DT * 2.0) if me.autopilot and not me.finished else Game.read_input(0)
	if inp.item:
		item_seq += 1
	in_frame += 1
	var btn := (1 if inp.gas else 0) | (2 if inp.brake else 0) | (4 if inp.drift else 0)
	Net.send_input(float(inp.steer), btn, item_seq, in_frame)
	var on := state == "race" and not me.finished and me.human
	if on and not me.predicted:
		# from the smoothed picture of the countdown to our own simulation
		me.corr = Vector3(me.vis_x - me.x, me.vis_y - me.y, me.vis_z - me.z)
		me.corr_h = Game.wrap_angle(me.vis_h - me.heading)
		hist.clear()
	elif me.predicted and not on:
		# back to following the host: carry on from what is on the screen
		me.vis_x = me.x + me.corr.x; me.vis_y = me.y + me.corr.y; me.vis_z = me.z + me.corr.z
		me.vis_h = me.heading + me.corr_h
	me.predicted = on
	if not on:
		return
	var c := {"steer": float(inp.steer), "gas": bool(inp.gas), "brake": bool(inp.brake), "drift": bool(inp.drift), "item": false}
	me.begin_tick()
	for i in 2:
		me.update(Game.SIM_DT, c)
	hist[in_frame] = [c, me.x, me.y, me.z]
	hist.erase(in_frame - 300)


## A snapshot replaced the predicted kart's state with the host's, which has
## our controls up to frame `ack`: simulate the newer ones again, then ease
## the picture from where the kart was shown to the new place.
func _reconcile(me: Kart, was: Array) -> void:
	var a := me.ack
	if hist.has(a):
		var h: Array = hist[a]
		pred_err.append(Vector3(me.x - float(h[1]), me.y - float(h[2]), me.z - float(h[3])).length())
	replaying = true
	for f in range(a + 1, in_frame + 1):
		if not hist.has(f):
			continue
		var h: Array = hist[f]
		for i in 2:
			me.update(Game.SIM_DT, h[0])
		h[1] = me.x; h[2] = me.y; h[3] = me.z
	replaying = false
	var dx := me.x - float(was[0])
	var dy := me.y - float(was[1])
	var dz := me.z - float(was[2])
	pred_corr.append(Vector3(dx, dy, dz).length())
	me.correct(dx, dy, dz, Game.wrap_angle(me.heading - float(was[3])))


## Test summary: how far the prediction was from the host (m).
func prediction_report() -> Dictionary:
	var out := {}
	for pair in [["err", pred_err], ["corr", pred_corr]]:
		var arr: PackedFloat32Array = pair[1].duplicate()
		arr.sort()
		var n := arr.size()
		var sum := 0.0
		for v in arr:
			sum += v
		out[pair[0]] = {"n": n, "avg": sum / maxf(n, 1), "p95": arr[int(n * 0.95)] if n > 0 else 0.0,
			"max": arr[n - 1] if n > 0 else 0.0}
	return out


func on_peer_left(peer_id: int) -> void:
	for k in karts:
		if k.peer == peer_id:
			k.human = false
			k.peer = 0
			k.set_name_tag("")


# ================================================================== per frame
func _process(delta: float) -> void:
	if karts.is_empty():
		return
	var dt := 0.0 if paused else delta
	var alpha := Engine.get_physics_interpolation_fraction()
	var smooth := mode == Mode.CLIENT
	for k in karts:
		k.render(dt, alpha, smooth and not k.predicted, time if not smooth else Time.get_ticks_msec() / 1000.0)
	skids.tick(dt)
	_update_box_visuals(dt)
	Atmosphere.animate(atm)
	Trackside.update(ts, self)
	if ghost_node != null or dev_node != null:
		_move_ghost()
	for b in bananas:
		b.node.position.y = float(b.y) + 0.25 + sin(time * 3.0 + float(b.x)) * 0.04
	for m in missiles:
		m.node.position = Vector3(m.x, m.y, m.z)
		m.node.rotation.y = m.h
	for b in blues:
		var bn: Node3D = b.node
		bn.position = bn.position.lerp(Vector3(b.x, b.y, b.z), 1.0 - exp(-20.0 * dt)) if bn.position != Vector3.ZERO \
			else Vector3(b.x, b.y, b.z)
		bn.rotation = Vector3(0.0, float(b.h), time * 9.0)
	for o in oils:
		# the puddle dries up in its last second
		var left := OIL_TIME - float(o.age)
		var sc := clampf(left, 0.05, 1.0)
		(o.node as Node3D).scale = Vector3(sc, 1.0, sc)
	if mode == Mode.CLIENT:
		for o in oils:
			o.age = float(o.age) + dt
	if zap_t > 0.0:
		zap_t = maxf(0.0, zap_t - delta)
		zap_rect.color.a = 0.6 * zap_t / 0.4
		zap_rect.visible = zap_t > 0.0
	if mode == Mode.CLIENT:
		time += dt
	for k in karts:
		_observe(k, dt)
	_count_display()
	# views
	var sc := get_viewport().get_final_transform().get_scale()
	for p in panes:
		var want := Vector2i((p.root.size * sc * render_scale).round())
		want = want.max(Vector2i(16, 16))
		if p.vp.size != want:
			p.vp.size = want
		_update_camera(p, dt)
		if p.lines != null:
			p.lines.update_lines(dt)
		if p.hud != null:
			p.hud.refresh()
	if mode == Mode.DEMO:
		demo_switch += delta
		if demo_switch > 12.0:
			demo_switch = 0.0
			demo_focus = order[0]
	# engine sound
	for i in 2:
		var on: bool = i < locals.size() and not paused and (state == "race" or state == "countdown") and not locals[i].finished
		var ratio := 0.0
		if i < locals.size():
			var lk: Kart = locals[i]
			ratio = absf(lk.speed) / float(Game.BASE.max)
			if state == "countdown":
				ratio = 0.1
		Sfx.engine(i, ratio, on)
	# pause / back
	if Game.take_pause() and mode != Mode.DEMO and not results_shown:
		toggle_pause()
	# results
	if mode != Mode.DEMO and not locals.is_empty():
		var all_done := true
		for k in locals:
			if not k.finished:
				all_done = false
		if all_done:
			if all_done_t < 0.0:
				all_done_t = 0.0
				Sfx.music(false)
			all_done_t += delta
			if all_done_t > 3.0 and not results_shown:
				_show_results()
		if results_shown:
			results_refresh -= delta
			if results_refresh <= 0.0:
				results_refresh = 0.5
				_fill_results()
				_refresh_podium()
	if podium_t >= 0.0:
		podium_t += delta
		confetti_t -= delta
		if confetti_t <= 0.0:
			confetti_t = 1.4
			var c: Vector3 = ts.podium.center
			Effects.confetti_burst(fx, c + Vector3(randf_range(-4.0, 4.0), 1.0, randf_range(-1.5, 1.5)))


func _update_box_visuals(dt: float) -> void:
	for b in boxes:
		var node: Node3D = b.node
		if not b.active:
			if node.visible:
				node.visible = false
				if _ear(node.position.x, node.position.z) > 0.0:
					Effects.box_shards(fx, node.position)
			continue
		if not node.visible:
			node.visible = true
		b.scale = minf(1.0, float(b.scale) + dt * 2.5)
		node.scale = Vector3.ONE * float(b.scale)
		var ph: float = b.phase
		b.mesh.rotation = Vector3(sin(time * 1.1 + ph) * 0.35, time * 1.6 + ph, 0)
		node.position.y = float(b.y) + sin(time * 2.2 + ph) * 0.18


func _reset_obs(k: Kart) -> void:
	k.obs = {"spin": 0.0, "boost": 0.0, "roulette": 0.0, "item": 0, "level": 0, "hop": 0.0, "star": 0.0,
		"lap": maxi(1, k.lap), "finished": false, "tick": 0.0, "trick": 0.0, "air": false, "shield": 0.0, "shrink": 0.0}


## Turns state changes into sounds, messages and effects. Works the same
## whether this device simulates the race or only receives snapshots.
func _observe(k: Kart, dt: float) -> void:
	var o: Dictionary = k.obs
	var loc := k.local_slot >= 0
	var hud: Hud = null
	if loc and k.local_slot < panes.size():
		hud = panes[k.local_slot].hud
	if k.spin > 0.0 and float(o.spin) <= 0.0:
		sound_at("hit", k.x, k.z, loc)
		burst(Vector3(k.x, k.y + 1.6, k.z), Color(1.0, 0.88, 0.4), 14, 5.0)
		if loc:
			shake(k.local_slot, 0.5)
	# jumps: a whoosh for the trick, a thump on landing
	if k.trick > 0.0 and float(o.trick) <= 0.0:
		sound_at("trick", k.x, k.z, loc, 0.8)
		if loc and hud != null:
			hud.show_msg("Trik!", UI.GOLD)
	o.trick = k.trick
	if bool(o.air) and not k.air:
		sound_at("land", k.x, k.z, loc, 0.7)
		if loc:
			shake(k.local_slot, 0.25)
	o.air = k.air
	if k.boost > float(o.boost) + 0.05:
		sound_at("boost", k.x, k.z, loc, 0.9)
		k.on_boost(int(o.level) if not k.drift_active else 0)
		if loc and hud != null and race_time < 0.6 and state == "race" and k.boost > 1.0:
			hud.show_msg("Raketový start!", UI.GO)
	if k.finished and not bool(o.finished) and mode != Mode.DEMO:
		if loc:
			Effects.confetti_shower(k)
		if _ear(k.x, k.z) > 0.0:
			Effects.confetti_burst(fx, k.position)
	if loc:
		if k.roulette > 0.0 and float(o.roulette) <= 0.0:
			Sfx.play("pickup", 0.9)
		if k.roulette > 0.0:
			o.tick -= dt
			if o.tick <= 0.0:
				o.tick = 0.08
				Sfx.play("tick", 0.5)
		if k.roulette <= 0.0 and float(o.roulette) > 0.0 and k.item != 0:
			Sfx.play("got", 0.9)
		if k.drift_level > int(o.level):
			Sfx.play("level%d" % clampi(k.drift_level, 1, 3), 0.8)
		if k.hop > float(o.hop) + 0.05 and k.spin <= 0.0:
			Sfx.play("hop", 0.6)
		if k.star > 0.0 and float(o.star) <= 0.0:
			Sfx.play("star", 0.8)
		if k.lap > int(o.lap) and mode != Mode.DEMO:
			o.lap = k.lap
			if mode == Mode.CLIENT and k.lap >= 2:
				k.lap_times.append(k.last_lap)
			if k.lap >= 2 and k.lap <= Game.LAPS and hud != null:
				var lap_time := "Kolo %d: %s" % [k.lap - 1, Game.fmt_time(k.last_lap)]
				var sub_col := UI.MUTED
				var split := _ghost_split(k, k.lap - 1)
				if split != INF:
					# time trial: ahead of the ghost (green) or behind it (red) after this many laps
					lap_time += " · " + _signed(split)
					sub_col = UI.GO if split < 0.0 else UI.KERB
				if k.lap == Game.LAPS:
					hud.show_banner("POSLEDNÍ KOLO", UI.GOLD, lap_time, sub_col)
					Sfx.play("final_lap")
					Sfx.music(true, true)
				else:
					hud.show_banner("KOLO %d/%d" % [k.lap, Game.LAPS], UI.PAPER, lap_time, sub_col)
					Sfx.play("lap")
		if k.finished and not bool(o.finished):
			var place := _place_of(k)
			if hud != null:
				hud.show_msg("Vítězství!" if place == 1 else "Cíl! %d. místo" % place, UI.GOLD if place == 1 else UI.GO)
			Sfx.play("finish")
			if trial:
				_trial_finish(k)
			else:
				_save_record(k)
	if k.shield > float(o.shield) + 1.0:
		sound_at("shield", k.x, k.z, loc, 0.8)
	elif k.shield <= 0.0 and float(o.shield) > 0.1:
		# the bubble swallowed a hit
		sound_at("pop", k.x, k.z, loc)
		burst(Vector3(k.x, k.y + 1.0, k.z), Color(0.5, 0.9, 1.0), 18, 6.0)
	if k.shrink > float(o.shrink) + 1.0:
		# struck by the lightning: a bolt from the sky and a flash over the screen
		Effects.flash(fx, Vector3(k.x, k.y + 4.0, k.z), Color(1.0, 0.95, 0.6), 7.0, 0.3)
		burst(Vector3(k.x, k.y + 1.2, k.z), Color(1.0, 0.95, 0.5), 10, 7.0)
		if zap_t < 0.3:
			zap_t = 0.4
			Sfx.play("zap", 0.9)
	o.shield = k.shield
	o.shrink = k.shrink
	o.spin = k.spin
	o.boost = k.boost
	o.roulette = k.roulette
	o.item = k.item
	o.level = k.drift_level
	o.hop = k.hop
	o.star = k.star
	o.finished = k.finished


func _count_display() -> void:
	if mode == Mode.DEMO:
		return
	if state == "countdown":
		var n := ceili(countdown)
		if n != shown_count and n >= 1 and n <= 3:
			shown_count = n
			for p in panes:
				if p.hud != null:
					p.hud.show_count(str(n), false)
			Sfx.play("count")
	elif shown_count != 0:
		shown_count = 0
		for p in panes:
			if p.hud != null:
				p.hud.show_count("START!", true)
		Sfx.play("go")


func _update_camera(p: Dictionary, delta: float) -> void:
	if podium_t >= 0.0:
		_podium_camera(p)
		return
	var k: Kart = p.kart if p.kart != null else demo_focus
	if k == null:
		return
	var cam: Camera3D = p.cam
	var kp := k.position
	# height is followed a little softer, so a jump lifts the kart in the picture
	p.cy = kp.y if not p.snapped else lerpf(float(p.cy), kp.y, 1.0 - exp(-6.0 * delta))
	kp.y = p.cy
	var size: Vector2 = p.root.size
	var aspect := size.x / maxf(1.0, size.y)
	var tgt_fov := 72.0
	if aspect > 2.3:
		tgt_fov = 50.0
	elif aspect < 1.0:
		tgt_fov = 88.0
	var kk := 1.0 - exp(-5.0 * delta)
	var desired: Vector3
	var look: Vector3
	var follow := 1.0 - exp(-12.0 * delta)
	if mode == Mode.DEMO:
		var yaw := k.yaw + sin(time * 0.18) * 0.9
		p.yaw += Game.wrap_angle(yaw - float(p.yaw)) * kk * 0.6
		desired = kp + Vector3(-sin(p.yaw) * 12.0, 5.2, -cos(p.yaw) * 12.0)
		look = kp + Vector3(0, 1.4, 0)
		follow = 1.0 - exp(-4.0 * delta)
	elif k.finished:
		p.yaw += delta * 0.35
		desired = kp + Vector3(sin(p.yaw) * 9.0, 3.6, cos(p.yaw) * 9.0)
		look = kp + Vector3(0, 1.2, 0)
		follow = 1.0 - exp(-3.0 * delta)
	else:
		var yaw := k.yaw + k.slip * 0.45
		if not p.snapped:
			p.yaw = yaw
		p.yaw += Game.wrap_angle(yaw - float(p.yaw)) * kk
		var dist := 9.5 if aspect < 1.0 else 7.4
		var h := 4.0 if aspect < 1.0 else 3.1
		desired = kp + Vector3(-sin(p.yaw) * dist, h + k.hop_y() * 0.4, -cos(p.yaw) * dist)
		look = kp + Vector3(sin(p.yaw) * 5.0, 1.3, cos(p.yaw) * 5.0)
		if k.boost > 0.0 or k.star > 0.0:
			tgt_fov += 10.0
	if not p.snapped:
		cam.position = desired
		p.snapped = true
	else:
		cam.position = cam.position.lerp(desired, follow)
	# never inside a hill behind the kart
	var floor_y := track.ground(cam.position.x, cam.position.z, k.idx) + 1.4
	if cam.position.y < floor_y:
		cam.position.y = floor_y
	if p.shake > 0.0:
		cam.position += Vector3(randf() - 0.5, randf() - 0.5, 0.0) * float(p.shake)
		p.shake = maxf(0.0, float(p.shake) - delta * 1.5)
	if cam.position.distance_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	p.fov = lerpf(p.fov, tgt_fov, 1.0 - exp(-4.0 * delta))
	cam.fov = p.fov


# ================================================================== results & pause
func _place_of(k: Kart) -> int:
	var place := 1
	for o in karts:
		if o != k and o.finished and o.finish_time < k.finish_time:
			place += 1
	return place


func _save_record(k: Kart) -> void:
	if mode == Mode.DEMO or k.lap_times.is_empty() and k.finish_time <= 0.0:
		return
	var key := Game.record_key(track_idx, diff_idx)
	var recs: Dictionary = Game.settings.records
	var rec: Dictionary = recs.get(key, {})
	if not rec.has("total") or k.finish_time < float(rec.total):
		rec.total = k.finish_time
		k.set_meta("new_record", true)
	var best := INF
	for t in k.lap_times:
		best = minf(best, t)
	if best < INF and (not rec.has("lap") or best < float(rec.lap)):
		rec.lap = best
	recs[key] = rec
	Game.settings.records = recs
	Game.save_settings()


func standings() -> Array:
	var rows: Array = []
	for k in karts:
		if k.finished:
			rows.append({"k": k, "t": k.finish_time, "est": false})
		else:
			var rem: float = Game.LAPS * track.length - k.progress()
			rows.append({"k": k, "t": race_time + maxf(0.0, rem) / maxf(10.0, k.max_speed() * 0.85), "est": true})
	rows.sort_custom(func(a, b): return a.t < b.t)
	return rows


func display_name(k: Kart) -> String:
	if k.human and k.player_name != "" and k.player_name != String(k.ch.name):
		return "%s (%s)" % [k.player_name, k.ch.name]
	return k.ch.name


## A panel over the race: centred with a dark shade, or at the bottom with
## the view left clear (results under the podium).
func _panel(title_text: String, bottom := false, width := 0.0) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.07, 0.0 if bottom else 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	if bottom:
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_bottom = -10
		shade.add_child(col)
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(gap)
		col.add_child(center)
	else:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.add_child(center)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style(16))
	pc.custom_minimum_size = Vector2(width if width > 0.0 else (560.0 if bottom else 520.0), 0)
	center.add_child(pc)
	var v := UI.vbox(8 if bottom else 14)
	pc.add_child(v)
	v.add_child(UI.kerb_strip(8))
	var inner := UI.vbox(8 if bottom else 14)
	v.add_child(UI.margin(inner, 24, 0 if bottom else 4, 24, 16 if bottom else 22))
	var title := UI.label(title_text, 32 if bottom else 40, UI.PAPER, UI.display_font)
	inner.add_child(title)
	return [shade, inner, title]


func toggle_pause() -> void:
	if pause_panel != null:
		_resume()
		return
	if mode == Mode.OFFLINE:
		paused = true
		Sfx.music(false)
	var parts := _panel("Pauza" if mode == Mode.OFFLINE else "Menu hry")
	pause_panel = parts[0]
	var inner: VBoxContainer = parts[1]
	if mode != Mode.OFFLINE:
		inner.add_child(UI.label("Hra po síti běží dál i během tohoto menu.", 18, UI.MUTED))
	var resume := UI.button("Pokračovat", _resume, true)
	inner.add_child(resume)
	var row := UI.hbox(10)
	inner.add_child(row)
	if mode == Mode.OFFLINE:
		var r := UI.button("Restartovat závod", func(): restart_requested.emit())
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(r)
	var q := UI.button("Odejít do menu", func(): menu_requested.emit())
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(q)
	var row2 := UI.hbox(10)
	inner.add_child(row2)
	var sb := UI.button(Menu._mute_text().replace("\n", ": "), Callable())
	sb.pressed.connect(_pause_mute.bind(sb))
	var gb := UI.button(Menu._gfx_text().replace("\n", ": "), Callable())
	gb.pressed.connect(_pause_quality.bind(gb))
	var fb := UI.button(Menu._fps_text().replace("\n", ": "), Callable())
	fb.pressed.connect(_pause_fps.bind(fb))
	for b in [sb, gb, fb]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		row2.add_child(b)
	var hint := UI.label("Stíny a záře se přepnou hned, hustota stromů, počet částic a sníh až od dalšího závodu.", 15, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(470, 0)
	inner.add_child(hint)
	resume.grab_focus.call_deferred()


func _pause_mute(b: Button) -> void:
	Sfx.toggle_mute()
	b.text = Menu._mute_text().replace("\n", ": ")


func _pause_quality(b: Button) -> void:
	Gfx.cycle()
	apply_quality()
	b.text = Menu._gfx_text().replace("\n", ": ")


func _pause_fps(b: Button) -> void:
	Game.settings.show_fps = not bool(Game.settings.show_fps)
	Game.save_settings()
	b.text = Menu._fps_text().replace("\n", ": ")


func _resume() -> void:
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	if paused:
		paused = false
		var fast_music := false
		for k in locals:
			if k.lap == Game.LAPS:
				fast_music = true
		if state != "demo":
			Sfx.music(true, fast_music)


func pause_from_system() -> void:
	if mode == Mode.OFFLINE and not paused and not results_shown:
		toggle_pause()


func _show_results() -> void:
	results_shown = true
	if Game.cmd_args.has("fake-unlock"):     # screenshots of the announcement
		unlocked_now = Array(String(Game.cmd_args["fake-unlock"]).split(",", false))
	_start_podium()
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	Game.touch.active = false
	if touch_ctl != null:
		touch_ctl.visible = false
	if not cup.is_empty():
		_show_cup_results()
		return
	if trial:
		_show_trial_results()
		return
	var title := "Výsledky"
	var sub := ""
	if locals.size() == 1:
		var k: Kart = locals[0]
		var place := _place_of(k)
		title = "Vítězství!" if place == 1 else "%d. místo" % place
		var best := INF
		for t in k.lap_times:
			best = minf(best, t)
		sub = "%scelkový čas %s · nejlepší kolo %s" % ["1. místo · " if place == 1 else "", Game.fmt_time(k.finish_time), Game.fmt_time(best)]
		if k.get_meta("new_record", false):
			sub += " · nový rekord trati!"
	else:
		var parts: Array = []
		for k in locals:
			parts.append("Hráč %d: %d. místo" % [k.local_slot + 1, _place_of(k)])
		sub = " · ".join(parts)
	var p := _panel(title, not podium.is_empty())
	results_panel = p[0]
	var inner: VBoxContainer = p[1]
	var tl: Label = p[2]
	if locals.size() == 1:
		tl.add_theme_color_override("font_color", UI.place_color(_place_of(locals[0])))
	var sl := UI.label(sub, 18, UI.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(470, 0)
	inner.add_child(sl)
	results_body = UI.vbox(2)
	inner.add_child(results_body)
	_fill_results()
	var row := UI.hbox(10)
	inner.add_child(row)
	var first: Button
	match mode:
		Mode.OFFLINE:
			first = UI.button("Jet znovu", func(): restart_requested.emit(), true)
			row.add_child(first)
			row.add_child(UI.button("Hlavní menu", func(): menu_requested.emit()))
		Mode.HOST:
			first = UI.button("Zpět do lobby", func(): lobby_requested.emit(), true)
			row.add_child(first)
			row.add_child(UI.button("Ukončit hru", func(): menu_requested.emit()))
		_:
			inner.add_child(UI.label("Další závod spouští hostitel.", 18, UI.MUTED))
			first = UI.button("Odejít", func(): menu_requested.emit())
			row.add_child(first)
	for c in row.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first.grab_focus.call_deferred()


## The first three karts stand on the podium beside the start straight,
## drivers cheering, confetti flying; the camera circles them on a single
## full-screen view.
func _start_podium() -> void:
	if ts.get("podium", {}).is_empty() or mode == Mode.DEMO or trial:
		return
	podium_t = 0.0
	confetti_t = 0.3
	_refresh_podium()
	for i in panes.size():
		var p: Dictionary = panes[i]
		if p.hud != null:
			p.hud.visible = false
		if p.get("lines") != null:
			p.lines.visible = false
		var pane: Control = p.root
		if i == 0:
			pane.anchor_top = 0.0
			pane.anchor_bottom = 1.0
			pane.offset_top = 0
			pane.offset_bottom = 0
		else:
			pane.visible = false
	if split_bar != null:
		split_bar.visible = false


func _refresh_podium() -> void:
	if podium_t < 0.0:
		return
	var rows := _podium_order()
	var slots: Array = ts.podium.slots
	for i in mini(3, rows.size()):
		var k: Kart = rows[i]
		if i < podium.size() and (podium[i] as KartShow).driver == k.driver:
			continue
		if i < podium.size():
			(podium[i] as KartShow).queue_free()
		var show := KartShow.new()
		show.setup(k.driver, false, k.paint)
		show.cheering = true
		show.steer_amp = 0.25
		show.transform = slots[i]
		fx.add_child(show)
		if i < podium.size():
			podium[i] = show
		else:
			podium.append(show)


## Who stands on the podium: the race's first three, after the last race
## of a championship its overall first three.
func _podium_order() -> Array:
	var out: Array = []
	if _cup_last():
		for row in _cup_table(_cup_race_points()):
			out.append(row[0])
	else:
		for row in standings():
			out.append(row.k)
	return out


# ---------------------------------------------------------------- time trial
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;
uniform vec3 tint = vec3(0.6, 0.88, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint;
	ALPHA = 0.16 + 0.6 * rim;
}
"""


static var _ghost_shader: Shader


func _start_trial() -> void:
	ghost = Game.load_ghost(track_idx, diff_idx)
	trial_prev = float(ghost.get("t", 0.0))
	rec = PackedFloat32Array()
	rec_next = 0.0
	if not ghost.is_empty():
		# the ghost: the recorded kart, see-through with a glowing edge
		ghost_node = _ghost_kart(ghost, Color(0.6, 0.88, 1.0))
		ghost_i = 0
		ghost_idx = -1
	# the developer's ghost (won in the time trials, --dev-ghost in tests): gold
	if Game.unlocked("dev") or Game.cmd_args.has("dev-ghost"):
		dev = Game.dev_ghost(track_idx, diff_idx)
		if not dev.is_empty():
			dev_node = _ghost_kart(dev, Color(1.0, 0.78, 0.3))
			dev_i = 0
			dev_idx = -1
	if ghost_node != null or dev_node != null:
		_move_ghost()


func _ghost_kart(g: Dictionary, tint: Color) -> Node3D:
	var show := KartShow.new()
	show.setup(clampi(int(g.get("driver", 0)), 0, Game.CHARS.size() - 1), false, int(g.get("paint", 0)))
	show.steer_amp = 0.0
	if _ghost_shader == null:
		_ghost_shader = Shader.new()
		_ghost_shader.code = GHOST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _ghost_shader
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var stack: Array = [show]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).material_override = mat
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stack.append_array(n.get_children())
	fx.add_child(show)
	return show


func _record(k: Kart) -> void:
	rec.append_array(PackedFloat32Array([race_time, k.x, k.y, k.z, k.heading - k.slip, 1.0 if k.air else 0.0]))
	rec_next += GHOST_DT


func _move_ghost() -> void:
	if ghost_node != null:
		var r := _place_ghost(ghost, ghost_node, ghost_i, ghost_idx)
		ghost_i = r[0]
		ghost_idx = r[1]
		if r[2]:
			ghost_shown = true
	if dev_node != null:
		var r := _place_ghost(dev, dev_node, dev_i, dev_idx)
		dev_i = r[0]
		dev_idx = r[1]
		if r[2]:
			dev_shown = true


## A ghost where its drive was at this moment of the race; it waits at the
## start during the countdown and leaves the track after its finish.
## Returns [frame, track sample, out on the track during the race].
func _place_ghost(g: Dictionary, node: Node3D, gi: int, gidx: int) -> Array:
	var d: PackedFloat32Array = g.data
	var n := d.size() / GHOST_F
	if n < 2:
		return [gi, gidx, false]
	var t := race_time if state == "race" else 0.0
	if t > d[(n - 1) * GHOST_F]:
		node.visible = false
		return [gi, gidx, false]
	node.visible = true
	while gi < n - 2 and d[(gi + 1) * GHOST_F] <= t:
		gi += 1
	var a := gi * GHOST_F
	var b := a + GHOST_F
	var u := clampf((t - d[a]) / maxf(1e-4, d[b] - d[a]), 0.0, 1.0)
	var pos := Vector3(lerpf(d[a + 1], d[b + 1], u), lerpf(d[a + 2], d[b + 2], u), lerpf(d[a + 3], d[b + 3], u))
	var yaw := d[a + 4] + Game.wrap_angle(d[b + 4] - d[a + 4]) * u
	var pj := track.project(pos.x, pos.z, gidx)
	var up := Vector3.UP if d[a + 5] > 0.5 else track.normal(pj[0], pj[1], pj[2])
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var zf := (f - up * f.dot(up)).normalized()
	node.transform = Transform3D(Basis(up.cross(zf), up, zf), pos)
	return [gi, int(pj[0]), state == "race"]


## Seconds ahead (−) or behind (+) the ghost after `laps` laps; INF without one.
func _ghost_split(k: Kart, laps: int) -> float:
	if not trial or ghost.is_empty() or laps < 1 or k.lap_times.size() < laps:
		return INF
	var gl: Array = ghost.get("laps", [])
	if gl.size() < laps:
		return INF
	var mine := 0.0
	var theirs := 0.0
	for i in laps:
		mine += float(k.lap_times[i])
		theirs += float(gl[i])
	return mine - theirs


static func _signed(sec: float) -> String:
	return ("−%.2f s" % -sec) if sec < 0.0 else ("+%.2f s" % sec)


func _trial_finish(k: Kart) -> void:
	_record(k)
	if trial_prev <= 0.0 or k.finish_time < trial_prev:
		k.set_meta("new_record", true)
		Game.save_ghost(track_idx, diff_idx, {"t": k.finish_time, "laps": k.lap_times.duplicate(), "driver": k.driver,
			"paint": k.paint, "data": rec})
	unlocked_now = Game.award_trial()


func _show_trial_results() -> void:
	var k: Kart = locals[0]
	var best_new: bool = k.get_meta("new_record", false)
	var title := "Nový rekord!" if best_new and trial_prev > 0.0 else ("Časovka" if not best_new else "První zapsaný čas")
	var sub := "Čas %s" % Game.fmt_time(k.finish_time)
	if trial_prev > 0.0:
		sub += " · rekord byl %s (%s)" % [Game.fmt_time(trial_prev), _signed(k.finish_time - trial_prev)]
	else:
		sub += " · příště pojedeš proti jeho duchovi"
	var p := _panel(title, false)
	results_panel = p[0]
	var inner: VBoxContainer = p[1]
	var tl: Label = p[2]
	tl.add_theme_color_override("font_color", UI.GOLD if best_new else UI.PAPER)
	var sl := UI.label(sub, 18, UI.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(470, 0)
	inner.add_child(sl)
	if not dev.is_empty():
		var dd := k.finish_time - float(dev.t)
		inner.add_child(UI.label("Duch vývojáře %s (%s)" % [Game.fmt_time(float(dev.t)), _signed(dd)], 17,
			UI.GO if dd < 0.0 else UI.GOLD))
	_unlock_box(inner)
	var best := INF
	for t in k.lap_times:
		best = minf(best, float(t))
	var gl: Array = ghost.get("laps", [])
	for i in k.lap_times.size():
		var lt := float(k.lap_times[i])
		var h := UI.hbox(10)
		var nl := UI.label("Kolo %d" % (i + 1), 19, UI.PAPER, UI.bold_font)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		if i < gl.size():
			var dd := lt - float(gl[i])
			h.add_child(UI.label(_signed(dd), 17, UI.GO if dd < 0.0 else UI.KERB))
		h.add_child(UI.label(Game.fmt_time(lt), 19, UI.GOLD if lt == best else UI.PAPER, UI.bold_font if lt == best else null))
		inner.add_child(h)
		var line := ColorRect.new()
		line.color = UI.LINE
		line.custom_minimum_size = Vector2(0, 1)
		inner.add_child(line)
	var row := UI.hbox(10)
	inner.add_child(row)
	var first := UI.button("Jet znovu", func(): restart_requested.emit(), true)
	row.add_child(first)
	row.add_child(UI.button("Hlavní menu", func(): menu_requested.emit()))
	for c in row.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first.grab_focus.call_deferred()


# ---------------------------------------------------------------- championship
func _cup_last() -> bool:
	return not cup.is_empty() and int(cup.round) >= Game.TRACKS.size() - 1


## "Závod 2/6" slides in at the start of every championship race.
func _cup_banner() -> void:
	for p in panes:
		if p.hud != null:
			p.hud.show_banner("ZÁVOD %d/%d" % [int(cup.round) + 1, Game.TRACKS.size()], UI.GOLD,
				"Mistrovství · " + String(track.def.name))


## Points for this race from the current standings (unfinished karts by
## their estimated time).
func _cup_race_points() -> Dictionary:
	if mode == Mode.CLIENT and not net_points.is_empty():
		return net_points
	var pts := {}
	var rows := standings()
	for i in rows.size():
		pts[int(rows[i].k.driver)] = int(Game.CUP_POINTS[i]) if i < Game.CUP_POINTS.size() else 0
	return pts


## [kart, total, gained] sorted by total; a tie goes to the better result
## in this race.
func _cup_table(pts: Dictionary) -> Array:
	var rows := standings()
	var place := {}
	for i in rows.size():
		place[rows[i].k] = i
	var out: Array = []
	for k in karts:
		var g := int(pts.get(k.driver, 0))
		out.append([k, int(cup.points.get(k.driver, 0)) + g, g])
	out.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else place[a[0]] < place[b[0]])
	return out


func _cup_place(k: Kart) -> int:
	var t := _cup_table(_cup_race_points())
	for i in t.size():
		if t[i][0] == k:
			return i + 1
	return t.size()


func _show_cup_results() -> void:
	var last := _cup_last()
	if last and unlocked_now.is_empty():
		unlocked_now = _award_cup()
	var title := ""
	if last:
		if locals.size() == 1:
			var cp := _cup_place(locals[0])
			title = "Vítěz mistrovství!" if cp == 1 else "%d. místo v mistrovství" % cp
		else:
			title = "Konec mistrovství"
	else:
		title = "%d. místo" % _place_of(locals[0]) if locals.size() == 1 else "Výsledky"
	var nxt := "" if last else String(Game.TRACKS[int(cup.round) + 1].name)
	var sub := "Mistrovství · závod %d z %d · %s" % [int(cup.round) + 1, Game.TRACKS.size(), track.def.name]
	if locals.size() == 2:
		var parts: Array = []
		for k in locals:
			parts.append("Hráč %d: %d. místo" % [k.local_slot + 1, _cup_place(k) if last else _place_of(k)])
		sub += " · " + " · ".join(parts)
	var p := _panel(title, not podium.is_empty(), 860.0)
	results_panel = p[0]
	var inner: VBoxContainer = p[1]
	var tl: Label = p[2]
	if locals.size() == 1:
		tl.add_theme_color_override("font_color", UI.place_color(_cup_place(locals[0]) if last else _place_of(locals[0])))
	inner.add_child(UI.label(sub, 18, UI.MUTED))
	_unlock_box(inner)
	var cols := UI.hbox(26)
	inner.add_child(cols)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UI.label("Tento závod", 15, UI.MUTED, UI.bold_font))
	results_body = UI.vbox(2)
	left.add_child(results_body)
	cols.add_child(left)
	var right := UI.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label("Celkové pořadí" if last else "Mistrovství po %d. závodě" % (int(cup.round) + 1), 15,
		UI.GOLD if last else UI.MUTED, UI.bold_font))
	cup_body = UI.vbox(2)
	right.add_child(cup_body)
	cols.add_child(right)
	_fill_results()
	if mode == Mode.CLIENT:
		inner.add_child(UI.label("Hostitel vás vrátí do lobby." if last else "Další závod spouští hostitel.", 18, UI.MUTED))
	var row := UI.hbox(10)
	inner.add_child(row)
	var next := func(): cup_next_requested.emit(_cup_race_points())
	var buttons: Array = []    # [text, action]; the first one is the main button
	match mode:
		Mode.HOST:
			# over Wi-Fi the host leads: next race once every player is in, or back to the lobby
			buttons = [["Zpět do lobby", lobby_requested.emit], ["Ukončit hru", menu_requested.emit]] if last else \
				[["Další závod: " + nxt, next], ["Zpět do lobby", lobby_requested.emit]]
		Mode.CLIENT:
			buttons = [["Odejít", menu_requested.emit]]
		_:
			buttons = [["Nové mistrovství", restart_requested.emit], ["Hlavní menu", menu_requested.emit]] if last else \
				[["Další závod: " + nxt, next], ["Ukončit mistrovství", menu_requested.emit]]
	var first: Button
	for i in buttons.size():
		var b := UI.button(String(buttons[i][0]), buttons[i][1], i == 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		if i == 0:
			first = b
	if mode == Mode.HOST and not last:
		cup_next = first
	_cup_wait_check()
	first.grab_focus.call_deferred()


## Host: "next race" waits until every player over Wi-Fi has finished.
func _cup_wait_check() -> void:
	if cup_next == null or not is_instance_valid(cup_next):
		return
	var waiting := false
	for k in karts:
		if k.human and not k.finished:
			waiting = true
	cup_next.disabled = waiting
	if waiting:
		cup_next.text = "Čekáme na ostatní hráče…"
	else:
		cup_next.text = "Další závod: " + String(Game.TRACKS[int(cup.round) + 1].name)


## End of a championship: each local player wins with their own driver
## and place (cups, paints, mirrored tracks, the secret driver).
func _award_cup() -> Array:
	var out: Array = []
	for k in locals:
		for key in Game.award_cup([k.driver], int(cup.diff), _cup_place(k)):
			if not (key in out):
				out.append(key)
	return out


## "Odemčeno!" with the results: what this race has just won, with a fanfare.
func _unlock_box(inner: VBoxContainer) -> void:
	if unlocked_now.is_empty():
		return
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(Color(UI.GOLD, 0.16), 14, 2, UI.GOLD))
	var v := UI.vbox(3)
	box.add_child(UI.margin(v, 16, 10, 16, 12))
	v.add_child(UI.label("ODEMČENO!", 24, UI.GOLD, UI.display_font))
	for key in unlocked_now:
		v.add_child(UI.label(Game.unlock_name(String(key)), 18, UI.PAPER, UI.bold_font))
	v.add_child(UI.label("Najdeš v menu ve Sbírce.", 14, UI.MUTED))
	inner.add_child(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): Sfx.play("unlock", 0.9))
	if trial and not locals.is_empty():
		Effects.confetti_burst(fx, (locals[0] as Kart).position + Vector3(0, 1.5, 0))


## The best championship place of the local players goes into the records.
func _save_cup() -> void:
	var best := 99
	for k in locals:
		best = mini(best, _cup_place(k))
	if best < 99:
		Game.save_cup(int(cup.diff), best)


func _podium_camera(p: Dictionary) -> void:
	var cam: Camera3D = p.cam
	var c: Vector3 = ts.podium.center
	var front: Vector3 = ts.podium.front
	var a := atan2(front.x, front.z) + sin(podium_t * 0.22) * 0.8
	cam.position = c + Vector3(sin(a), 0.0, cos(a)) * 15.0 + Vector3(0, 4.5, 0)
	cam.look_at(c + Vector3(0, -5.5, 0), Vector3.UP)   # podium in the upper half, results below
	cam.fov = 58.0


func _fill_results() -> void:
	if results_body == null:
		return
	for c in results_body.get_children():
		c.queue_free()
	var rows := standings()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var k: Kart = r.k
		var h := UI.hbox(10)
		var me := k.local_slot >= 0
		var col := UI.GOLD if me else UI.PAPER
		var pl := UI.label("%d." % (i + 1), 19, UI.MUTED if not me else UI.GOLD, UI.bold_font)
		pl.custom_minimum_size = Vector2(34, 0)
		h.add_child(pl)
		var dot := ColorRect.new()
		dot.color = k.ch.color
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var nl := UI.label(display_name(k), 19, col, UI.bold_font if me else null)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		h.add_child(nl)
		h.add_child(UI.label("jede…" if r.est else Game.fmt_time(r.t), 19, UI.MUTED if r.est else col))
		if not cup.is_empty():
			var gain := UI.label("+%d" % (int(Game.CUP_POINTS[i]) if i < Game.CUP_POINTS.size() else 0), 19, UI.GO, UI.bold_font)
			gain.custom_minimum_size = Vector2(40, 0)
			gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(gain)
		results_body.add_child(h)
		var line := ColorRect.new()
		line.color = UI.LINE
		line.custom_minimum_size = Vector2(0, 1)
		results_body.add_child(line)
	if cup_body != null and not cup.is_empty():
		if mode == Mode.HOST:
			Net.send_cup_points(_cup_race_points())
			_cup_wait_check()
		for c in cup_body.get_children():
			c.queue_free()
		var table := _cup_table(_cup_race_points())
		for i in table.size():
			var k: Kart = table[i][0]
			var me := k.local_slot >= 0
			var col := UI.GOLD if me else UI.PAPER
			var h := UI.hbox(10)
			var pl := UI.label("%d." % (i + 1), 19, UI.place_color(i + 1) if i < 3 else UI.MUTED, UI.bold_font)
			pl.custom_minimum_size = Vector2(34, 0)
			h.add_child(pl)
			var dot := ColorRect.new()
			dot.color = k.ch.color
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(dot)
			var nl := UI.label(display_name(k), 19, col, UI.bold_font if me else null)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.clip_text = true
			h.add_child(nl)
			var tot := UI.label("%d b." % int(table[i][1]), 19, col, UI.bold_font)
			tot.custom_minimum_size = Vector2(60, 0)
			tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(tot)
			cup_body.add_child(h)
			var line := ColorRect.new()
			line.color = UI.LINE
			line.custom_minimum_size = Vector2(0, 1)
			cup_body.add_child(line)
