class_name Race
extends Control
## One race (or the menu's demo race): world, karts, AI, items, cameras,
## split-screen views, HUD, pause and results.
## Offline and host run the simulation; a network client only renders the
## snapshots it receives from the host and sends its controls back.

signal restart_requested
signal menu_requested
signal lobby_requested

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
var holder: Node
var fx: Node3D
var boxes: Array = []
var karts: Array = []
var order: Array = []
var locals: Array = []
var bananas: Array = []
var missiles: Array = []
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
var render_scale := 1.0
var dust_color := Color.WHITE
var demo_focus: Kart
var demo_switch := 0.0
var all_done_t := -1.0
var results_shown := false
var results_refresh := 0.0
var music_fast := false

var view_layer: Control
var overlay: Control
var panes: Array = []
var touch_ctl: Control
var pause_panel: Control
var results_panel: Control
var results_body: VBoxContainer


static func get_track(i: int) -> Track:
	if not _tracks.has(i):
		_tracks[i] = Track.new(Game.TRACKS[i])
	return _tracks[i]


## Worlds are cached per track and quality level (scenery density depends on it).
static func get_world(i: int) -> Dictionary:
	var key := "%d_%d" % [i, Gfx.level()]
	if not _worlds.has(key):
		# drop worlds built for another quality level that are not on screen
		for k in _worlds.keys():
			var root: Node3D = _worlds[k].root
			if not String(k).ends_with("_%d" % Gfx.level()) and root.get_parent() == null:
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
	Atmosphere.apply_quality(atm)
	Kart.apply_quality()
	if world.get_parent() != null:
		world.get_parent().remove_child(world)
	holder.add_child(world)
	for b in boxes:
		b.active = true
		b.respawn = 0.0
		b.scale = 1.0
		b.node.visible = true
		b.node.scale = Vector3.ONE
	fx = Node3D.new()
	holder.add_child(fx)
	dust_color = track.def.theme.dust
	render_scale = Gfx.render_scale()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var k := Kart.new()
		k.setup(self, int(r.driver))
		holder.add_child(k)
		k.human = bool(r.get("human", false))
		k.peer = int(r.get("peer", 0))
		k.player_name = String(r.get("name", ""))
		k.local_slot = int(r.get("local", -1))
		var gp := _grid_pos(i)
		k.reset(gp.x, gp.y, gp.z)
		k.ai = {"lane": (-1.0 if i % 2 == 1 else 1.0) * (0.12 + randf() * 0.33) * Game.HW, "phase": randf() * 10.0,
			"t": 0.0, "rb": 1.0, "stuck": 0.0, "rev": 0.0, "item_t": 1.0, "last_seq": 0, "gas_at": -1.0,
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
	Sfx.music(mode != Mode.DEMO, false)


## Remove the cached world before this race is freed so it can be reused.
func dispose() -> void:
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
			"yaw": 0.0, "fov": 72.0, "shake": 0.0, "hud": null, "snapped": false}
		if mode != Mode.DEMO and p.kart != null:
			var hud := Hud.new()
			pane.add_child(hud)
			hud.setup(self, p.kart, count > 1)
			p.hud = hud
		panes.append(p)
	if count == 2:
		var bar := ColorRect.new()
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
	_update_items(dt)
	_compute_ranks()
	for k in karts:
		if k.human and not k.finished and state == "race":
			var fwd := cos(Game.wrap_angle(k.heading - track.heading(k.idx)))
			if fwd < -0.2 and absf(k.speed) > 3.0:
				k.wrong_t += dt
			else:
				k.wrong_t = 0.0


func _go() -> void:
	state = "race"
	for k in karts:
		k.lap_start = 0.0
		if k.human:
			var ga: float = k.ai.gas_at
			if ga > 0.1 and ga < 1.05:
				k.boost = 1.1
				k.boost_mul = 1.3
		elif randf() < (0.6 if diff_idx == 2 else 0.3):
			k.boost = 0.8
			k.boost_mul = 1.25


func _human_input(k: Kart) -> Dictionary:
	if k.local_slot >= 0:
		return Game.read_input(k.local_slot)
	var ni = Net.inputs.get(k.peer)
	if ni == null:
		return {"steer": 0.0, "gas": false, "brake": false, "drift": false, "item": false}
	var btn: int = ni.buttons
	var item: bool = int(ni.seq) != int(k.ai.last_seq)
	k.ai.last_seq = int(ni.seq)
	return {"steer": float(ni.steer), "gas": btn & 1 != 0, "brake": btn & 2 != 0, "drift": btn & 4 != 0, "item": item}


func on_lap(k: Kart, dir: int) -> void:
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
			if d2 >= mn * mn or d2 < 1e-6:
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
	ai.t += dt
	var out := {"steer": 0.0, "gas": true, "brake": false, "drift": false, "item": false}
	if ai.rev > 0.0:
		ai.rev -= dt
		out.gas = false
		out.brake = true
		var jr := (k.idx + 8) % n
		out.steer = clampf(Game.wrap_angle(atan2(tr.x[jr] - k.x, tr.z[jr] - k.z) - k.heading) * 2.0, -1.0, 1.0)
		return out
	var lane: float = ai.lane + sin(ai.t * 0.35 + ai.phase) * 0.22 * Game.HW
	for b in bananas:
		var bdx: float = b.x - k.x
		var bdz: float = b.z - k.z
		if bdx * bdx + bdz * bdz > 35.0 * 35.0:
			continue
		var pj := tr.project(b.x, b.z, k.idx)
		var ahead: float = ((int(pj[0]) - k.idx + n) % n) * tr.step
		if ahead > 2.0 and ahead < 30.0 and absf(float(pj[1]) - lane) < 3.0:
			lane = float(pj[1]) + (-5.0 if float(pj[1]) > 0.0 else 5.0)
	lane = clampf(lane, -Game.HW * 0.65, Game.HW * 0.65)
	var look := 4 + int(absf(k.speed) * 0.22)
	var j := (k.idx + look) % n
	var tx := tr.x[j] + tr.nx[j] * lane
	var tz := tr.z[j] + tr.nz[j] * lane
	var dif := Game.wrap_angle(atan2(tx - k.x, tz - k.z) - k.heading)
	out.steer = clampf(-dif * 2.4, -1.0, 1.0)
	var max_c := 0.0
	var off := int(absf(k.speed) * 0.2)
	for s in range(4, 34, 3):
		max_c = maxf(max_c, absf(tr.curv[(k.idx + s + off) % n]))
	var cf := clampf(1.0 - (max_c - 0.012) * 8.0, 0.72, 1.0)
	var rb_t := 1.0
	if mode != Mode.DEMO and not k.human:
		var best := -INF
		for h in karts:
			if h.human and not h.finished:
				best = maxf(best, h.progress())
		if best > -INF:
			var d := k.progress() - best
			rb_t = 1.08 if d < -60.0 else (1.03 if d < -20.0 else (0.94 if d > 140.0 else (0.97 if d > 60.0 else 1.0)))
	ai.rb = lerpf(ai.rb, rb_t, clampf(dt * 0.6, 0.0, 1.0))
	var target: float = k.max_speed() * float(ai.skill) * float(ai.rb) * cf
	out.gas = k.speed < target
	out.brake = k.speed > target + 7.0
	if absf(dif) > 1.3:
		out.gas = k.speed < 12.0
	if absf(k.speed) < 2.0 and k.spin <= 0.0 and state != "countdown":
		ai.stuck += dt
	else:
		ai.stuck = 0.0
	if ai.stuck > 1.3:
		ai.stuck = 0.0
		ai.rev = 0.9
	if k.item != 0 and k.roulette <= 0.0:
		ai.item_t -= dt
		if ai.item_t <= 0.0:
			var use := false
			if k.item == Game.Item.TURBO:
				use = cf > 0.9 and absf(dif) < 0.2
			elif k.item == Game.Item.STAR:
				use = true
			elif k.item == Game.Item.MISSILE:
				var ah: Kart = order[k.rank - 2] if k.rank >= 2 else null
				use = ah != null and ah.progress() - k.progress() < 140.0
			elif k.item == Game.Item.BANANA:
				var bh: Kart = order[k.rank] if k.rank < order.size() else null
				use = (bh != null and k.progress() - bh.progress() < 18.0) or randf() < 0.01
			if ai.item_t < -9.0:
				use = true
			if use:
				out.item = true
				ai.item_t = 0.6 + randf() * 1.5
	return out


# ---------------------------------------------------------------- items
func give_item(k: Kart) -> void:
	var p := clampf((k.rank - 1.0) / (karts.size() - 1.0), 0.0, 1.0)
	var w := [
		[Game.Item.BANANA, 1, lerpf(55, 5, p)], [Game.Item.TURBO, 1, lerpf(30, 25, p)], [Game.Item.MISSILE, 1, lerpf(15, 28, p)],
		[Game.Item.TURBO, 3, lerpf(0, 25, p)], [Game.Item.STAR, 1, lerpf(0, 18, p)],
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


func _missile_node() -> Node3D:
	var g := Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e63946")
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
	trail.color = Color(1.0, 0.55, 0.15)
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
	if absf(la) > Game.BAR - 1.5:
		var d := absf(la) - (Game.BAR - 1.5)
		var sg := signf(la)
		px -= track.nx[pj[0]] * sg * d
		pz -= track.nz[pj[0]] * sg * d
	var node := _banana_node()
	node.position = Vector3(px, 0.25, pz)
	node.rotation.y = randf() * TAU
	fx.add_child(node)
	bananas.append({"x": px, "z": pz, "node": node, "owner": k, "age": 0.0})
	if bananas.size() > 24:
		var old: Dictionary = bananas.pop_front()
		old.node.queue_free()
	sound_at("drop", k.x, k.z, k.local_slot >= 0)


func _fire_missile(k: Kart) -> void:
	var target: Kart = order[k.rank - 2] if k.rank >= 2 else null
	var px := k.x + sin(k.heading) * 2.8
	var pz := k.z + cos(k.heading) * 2.8
	var node := _missile_node()
	node.position = Vector3(px, 0.9, pz)
	fx.add_child(node)
	missiles.append({"x": px, "z": pz, "h": k.heading, "v": maxf(k.speed + 26.0, 64.0), "owner": k, "target": target,
		"life": 9.0, "age": 0.0, "idx": k.idx, "node": node})
	sound_at("missile", k.x, k.z, k.local_slot >= 0)


func _explode(px: float, pz: float) -> void:
	explosion_id += 1
	explosions.append([explosion_id, px, pz])
	if explosions.size() > 3:
		explosions.pop_front()
	_explode_fx(px, pz)


func _explode_fx(px: float, pz: float) -> void:
	burst(Vector3(px, 1.0, pz), Color(1.0, 0.6, 0.15), 28, 9.0, true, 1.4, 0.7)
	burst(Vector3(px, 1.0, pz), Color(0.35, 0.35, 0.35, 0.7), 12, 3.0, false, 2.4, 1.0)
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
			if dx * dx + dz * dz < 2.6 * 2.6:
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
			if dx * dx + dz * dz < 1.9 * 1.9:
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
		var boom: bool = m.life <= 0.0 or absf(float(pj[1])) > Game.BAR - 0.6
		if not boom:
			for k in karts:
				if k == m.owner and m.age < 0.6:
					continue
				var dx: float = k.x - m.x
				var dz: float = k.z - m.z
				if dx * dx + dz * dz < 4.0:
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


# ================================================================== network
func _pack() -> PackedFloat32Array:
	var nk := karts.size()
	var head := 14
	var d := PackedFloat32Array()
	d.resize(head + nk * Kart.SNAP_FIELDS + bananas.size() * 2 + missiles.size() * 3)
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
	# header slots 8-13 are reserved; explosions (id, x, z) go after the projectiles
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
	var ex := PackedFloat32Array()
	for e in explosions:
		ex.append_array(PackedFloat32Array([e[0], e[1], e[2]]))
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
	for k in karts:
		k.unpack(d, o)
		o += Kart.SNAP_FIELDS
	while bananas.size() < nb:
		var node := _banana_node()
		fx.add_child(node)
		bananas.append({"x": 0.0, "z": 0.0, "node": node, "owner": null, "age": 0.0, "fresh": true})
	while bananas.size() > nb:
		var b: Dictionary = bananas.pop_back()
		b.node.queue_free()
	for b in bananas:
		b.x = d[o]
		b.z = d[o + 1]
		b.node.position = Vector3(b.x, 0.25, b.z)
		if b.get("fresh", false):
			b.fresh = false
			sound_at("drop", b.x, b.z)
		o += 2
	while missiles.size() < nm:
		var node := _missile_node()
		fx.add_child(node)
		missiles.append({"x": 0.0, "z": 0.0, "h": 0.0, "node": node, "fresh": true})
	while missiles.size() > nm:
		var m: Dictionary = missiles.pop_back()
		m.node.queue_free()
	for m in missiles:
		m.x = d[o]
		m.z = d[o + 1]
		m.h = d[o + 2]
		if m.get("fresh", false):
			m.fresh = false
			sound_at("missile", m.x, m.z)
		o += 3
	var ne := int(d[7])
	for i in ne:
		if o + 2 >= d.size():
			break
		var eid := int(d[o])
		if eid > seen_explosion:
			seen_explosion = eid
			_explode_fx(d[o + 1], d[o + 2])
		o += 3
	_compute_order_client()


func _compute_order_client() -> void:
	var arr := karts.duplicate()
	arr.sort_custom(func(a, b): return a.rank < b.rank)
	order = arr


func _client_tick() -> void:
	if locals.is_empty():
		return
	var inp := Game.read_input(0)
	if inp.item:
		item_seq += 1
	var btn := (1 if inp.gas else 0) | (2 if inp.brake else 0) | (4 if inp.drift else 0)
	Net.send_input(float(inp.steer), btn, item_seq)


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
		k.render(dt, alpha, smooth, time if not smooth else Time.get_ticks_msec() / 1000.0, dust_color)
	_update_box_visuals(dt)
	Atmosphere.animate(atm)
	for b in bananas:
		b.node.position.y = 0.25 + sin(time * 3.0 + float(b.x)) * 0.04
	for m in missiles:
		m.node.position = Vector3(m.x, 0.9, m.z)
		m.node.rotation.y = m.h
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


func _update_box_visuals(dt: float) -> void:
	for b in boxes:
		var node: Node3D = b.node
		if not b.active:
			if node.visible:
				node.visible = false
				burst(node.position, Color(1.0, 0.62, 0.25), 16, 6.0, true, 0.4, 0.5)
			continue
		if not node.visible:
			node.visible = true
		b.scale = minf(1.0, float(b.scale) + dt * 2.5)
		node.scale = Vector3.ONE * float(b.scale)
		var ph: float = b.phase
		b.mesh.rotation = Vector3(sin(time * 1.1 + ph) * 0.35, time * 1.6 + ph, 0)
		node.position.y = 1.4 + sin(time * 2.2 + ph) * 0.18


func _reset_obs(k: Kart) -> void:
	k.obs = {"spin": 0.0, "boost": 0.0, "roulette": 0.0, "item": 0, "level": 0, "hop": 0.0, "star": 0.0,
		"lap": maxi(1, k.lap), "finished": false, "tick": 0.0}


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
		burst(Vector3(k.x, 1.6, k.z), Color(1.0, 0.88, 0.4), 14, 5.0)
		if loc:
			shake(k.local_slot, 0.5)
	if k.boost > float(o.boost) + 0.05:
		sound_at("boost", k.x, k.z, loc, 0.9)
		if loc and hud != null and race_time < 0.6 and state == "race" and k.boost > 1.0:
			hud.show_msg("Raketový start!", UI.GO)
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
			Sfx.play("level1" if k.drift_level == 1 else "level2", 0.8)
		if k.hop > float(o.hop) + 0.05 and k.spin <= 0.0:
			Sfx.play("hop", 0.6)
		if k.star > 0.0 and float(o.star) <= 0.0:
			Sfx.play("star", 0.8)
		if k.lap > int(o.lap) and mode != Mode.DEMO:
			o.lap = k.lap
			if mode == Mode.CLIENT and k.lap >= 2:
				k.lap_times.append(k.last_lap)
			if k.lap >= 2 and k.lap <= Game.LAPS and hud != null:
				if k.lap == Game.LAPS:
					hud.show_msg("Poslední kolo!", UI.GOLD)
					Sfx.play("final_lap")
					Sfx.music(true, true)
				else:
					hud.show_msg("Kolo %d: %s" % [k.lap - 1, Game.fmt_time(k.last_lap)], UI.PAPER)
					Sfx.play("lap")
		if k.finished and not bool(o.finished):
			var place := _place_of(k)
			if hud != null:
				hud.show_msg("Vítězství!" if place == 1 else "Cíl! %d. místo" % place, UI.GOLD if place == 1 else UI.GO)
			Sfx.play("finish")
			_save_record(k)
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
	var k: Kart = p.kart if p.kart != null else demo_focus
	if k == null:
		return
	var cam: Camera3D = p.cam
	var kp := k.position
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
		var yaw := k.rotation.y + sin(time * 0.18) * 0.9
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
		var yaw := k.rotation.y + k.slip * 0.45
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


func _panel(title_text: String) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.07, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel_style(16))
	pc.custom_minimum_size = Vector2(520, 0)
	center.add_child(pc)
	var v := UI.vbox(14)
	pc.add_child(v)
	v.add_child(UI.kerb_strip(8))
	var inner := UI.vbox(14)
	v.add_child(UI.margin(inner, 24, 4, 24, 22))
	var title := UI.label(title_text, 40, UI.PAPER, UI.display_font)
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
	if pause_panel != null:
		pause_panel.queue_free()
		pause_panel = null
	Game.touch.active = false
	if touch_ctl != null:
		touch_ctl.visible = false
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
	var p := _panel(title)
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
		results_body.add_child(h)
		var line := ColorRect.new()
		line.color = UI.LINE
		line.custom_minimum_size = Vector2(0, 1)
		results_body.add_child(line)
