class_name Kart
extends Node3D
## One kart: low-poly model, effects and the arcade driving model
## (ported 1:1 from the web prototype).

const SNAP_FIELDS := 24
## Drift spark / turbo colours for drift levels 1–3 (blue, orange, purple).
const DRIFT_COLS := [Color(0.35, 0.78, 1.0), Color(1.0, 0.64, 0.18), Color(0.78, 0.36, 1.0)]
const DRIFT_BOOST := [0.0, 0.7, 1.3, 1.75]
const FLAME_COL := Color(1.0, 0.63, 0.19)

var race: Race
var ch: Dictionary
var driver := 0
var human := false
var local_slot := -1        # 0/1 = player on this device, -1 = AI or remote
var peer := 0               # network peer that drives it (0 = AI)
var player_name := ""
var autopilot := false
var ai := {}

# --- simulation state
var x := 0.0
var z := 0.0
var heading := 0.0
var speed := 0.0
var steer := 0.0
var slip := 0.0
var boost := 0.0
var boost_mul := 1.3
var star := 0.0
var spin := 0.0
var spin_total := 1.0
var hop := 0.0
var hop_max := 0.3
var hop_h := 0.45
var invuln := 0.0
var item := 0
var item_n := 0
var roulette := 0.0
var roll_tick := 0.0
var lap := 0
var max_lap := 0
var lap_start := 0.0
var lap_times: Array = []
var last_lap := 0.0
var finished := false
var finish_time := 0.0
var offroad := false
var lat := 0.0
var idx := 0
var s := 0.0
var last_s := 0.0
var rank := 6
var drift_prev := false
var drift_active := false
var drift_dir := 0.0
var drift_charge := 0.0
var drift_level := 0
var braking := false
var bump_cd := 0.0
var wrong_t := 0.0
var obs := {}

# --- visuals
var body: Node3D
var front: Array = []
var spins: Array = []
var flames: Array = []
var glow_mats: Array = []
var cores: Array = []
var flame_mat: StandardMaterial3D
var sparks: Array = []
var wheel_dust: Array = []
var wheel_smoke: Array = []
var flame_fx: CPUParticles3D
var boost_fx: CPUParticles3D
var star_fx: CPUParticles3D
var stars: Node3D
var boost_col := FLAME_COL
var boost_age := 0.0
var skid_last: Array = [null, null]
var name_tag: Label3D
var wheel_rot := 0.0
var star_hue := 0.0
var prev_x := 0.0
var prev_z := 0.0
var prev_h := 0.0
var vis_x := 0.0
var vis_z := 0.0
var vis_h := 0.0

static var _m := {}


func setup(p_race: Race, p_driver: int) -> void:
	race = p_race
	driver = p_driver
	ch = Game.CHARS[p_driver]
	_build_model()


# ================================================================== model
static func _shared() -> Dictionary:
	if not _m.is_empty():
		return _m
	_m.chassis = _box(1.7, 0.34, 2.7)
	_m.nose = _box(1.25, 0.28, 0.8)
	_m.pod = _box(0.34, 0.32, 1.5)
	_m.seat = _box(0.95, 0.75, 0.22)
	_m.engine = _box(0.9, 0.45, 0.55)
	_m.visor = _box(0.58, 0.2, 0.14)
	_m.spoiler = _box(1.8, 0.1, 0.42)
	_m.post = _box(0.1, 0.4, 0.1)
	_m.flag = _box(0.03, 0.34, 0.52)
	_m.torso = _cyl(0.3, 0.38, 0.62, 10)
	_m.wheel = _cyl(0.44, 0.44, 0.4, 14)
	_m.hub = _cyl(0.2, 0.2, 0.42, 8)
	_m.pipe = _cyl(0.1, 0.12, 0.5, 8)
	_m.flame = _cyl(0.0, 0.2, 1.0, 8)
	_m.core = _cyl(0.0, 0.1, 0.7, 8)
	_m.antenna = _cyl(0.03, 0.03, 1.4, 4)
	var head := SphereMesh.new()
	head.radius = 0.42
	head.height = 0.84
	head.radial_segments = 14
	head.rings = 8
	_m.head = head
	var sw := TorusMesh.new()
	sw.inner_radius = 0.17
	sw.outer_radius = 0.27
	sw.rings = 14
	sw.ring_segments = 6
	_m.sw = sw
	_m.dark = _mat(Color("23262e"), 0.8)
	_m.tire = _mat(Color("161616"), 0.95)
	_m.hubm = _mat(Color("d0d5de"), 0.4)
	_m.visorm = _mat(Color("12151c"), 0.1)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.63, 0.19, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_m.flamem = fm
	var cm := fm.duplicate()
	cm.albedo_color = Color(1.0, 0.95, 0.75, 0.9)
	_m.corem = cm
	# soft round blob shadow
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for yy in 64:
		for xx in 64:
			var d := Vector2(xx - 31.5, yy - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(0, 0, 0, 0.5 * a * a * (3.0 - 2.0 * a)))
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = ImageTexture.create_from_image(img)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sq := PlaneMesh.new()
	sq.size = Vector2(2.8, 3.8)
	sq.material = sm
	_m.shadow = sq
	# particle dot
	var dot := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for yy in 32:
		for xx in 32:
			var d := Vector2(xx - 15.5, yy - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			dot.set_pixel(xx, yy, Color(1, 1, 1, a * a))
	_m.dot = ImageTexture.create_from_image(dot)
	return _m


static func _box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return b


static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func particle_mesh(size: float, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _shared().dot
	m.disable_fog = true
	# fade particles that fly right past the camera instead of filling the screen
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 5.0
	q.material = m
	return q


static func fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func _part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else body).add_child(mi)
	return mi


func _build_model() -> void:
	var m := _shared()
	body = Node3D.new()
	add_child(body)
	var main := StandardMaterial3D.new()
	main.albedo_color = ch.color
	main.roughness = 0.35
	main.metallic_specular = 0.7
	var acc := _mat(ch.accent, 0.6)
	var helm := StandardMaterial3D.new()
	helm.albedo_color = ch.helmet
	helm.roughness = 0.25
	glow_mats = [main, acc, helm]
	_part(m.chassis, main, Vector3(0, 0.5, 0))
	_part(m.nose, main, Vector3(0, 0.46, 1.65))
	_part(m.pod, acc, Vector3(0.98, 0.5, 0.1))
	_part(m.pod, acc, Vector3(-0.98, 0.5, 0.1))
	_part(m.seat, m.dark, Vector3(0, 0.98, -0.55))
	_part(m.engine, m.dark, Vector3(0, 0.82, -1.15))
	flame_mat = m.flamem.duplicate()
	for px in [-0.3, 0.3]:
		_part(m.pipe, m.hubm, Vector3(px, 0.78, -1.5)).rotation.x = PI / 2.0
		var f := _part(m.flame, flame_mat, Vector3(px, 0.78, -2.05))
		f.rotation.x = -PI / 2.0
		f.visible = false
		flames.append(f)
		var c := _part(m.core, m.corem, Vector3(px, 0.78, -1.95))
		c.rotation.x = -PI / 2.0
		c.visible = false
		cores.append(c)
	_part(m.torso, acc, Vector3(0, 1.2, -0.25))
	_part(m.head, helm, Vector3(0, 1.78, -0.2))
	_part(m.visor, m.visorm, Vector3(0, 1.8, 0.16))
	_part(m.sw, m.dark, Vector3(0, 1.15, 0.45)).rotation.x = PI / 2.0 - 0.9
	_part(m.spoiler, main, Vector3(0, 1.32, -1.45))
	_part(m.post, m.dark, Vector3(0.6, 1.1, -1.45))
	_part(m.post, m.dark, Vector3(-0.6, 1.1, -1.45))
	_part(m.antenna, m.dark, Vector3(-0.75, 1.7, -1.3))
	_part(m.flag, helm, Vector3(-0.75, 2.25, -1.55))
	var wheels := [[0.98, 0.44, 0.95, 1.0], [-0.98, 0.44, 0.95, 1.0], [1.0, 0.48, -0.95, 1.1], [-1.0, 0.48, -0.95, 1.1]]
	for i in wheels.size():
		var w: Array = wheels[i]
		var pivot := Node3D.new()
		pivot.position = Vector3(w[0], w[1], w[2])
		body.add_child(pivot)
		var sp := Node3D.new()
		sp.scale = Vector3.ONE * float(w[3])
		pivot.add_child(sp)
		_part(m.wheel, m.tire, Vector3.ZERO, sp).rotation.z = PI / 2.0
		_part(m.hub, m.hubm, Vector3.ZERO, sp).rotation.z = PI / 2.0
		if i < 2:
			front.append(pivot)
		spins.append(sp)
	var shadow := MeshInstance3D.new()
	shadow.mesh = m.shadow
	shadow.position.y = 0.1
	add_child(shadow)

	# effects
	for sx in [-1.0, 1.0]:
		var p := _emitter(0.5, true, 28, 0.25)
		p.position = Vector3(sx * 1.0, 0.3, -1.3)
		p.direction = Vector3(sx * 0.3, 1.0, -0.6)
		p.spread = 40.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -14, 0)
		add_child(p)
		sparks.append(p)
	_wheel_fx(race.track.def.theme)
	flame_fx = _emitter(0.7, true, 24, 0.18)
	flame_fx.position = Vector3(0, 0.8, -2.2)
	flame_fx.direction = Vector3(0, 0.2, -1)
	flame_fx.spread = 15.0
	flame_fx.initial_velocity_min = 4.0
	flame_fx.initial_velocity_max = 7.0
	flame_fx.gravity = Vector3.ZERO
	flame_fx.color = Color(1.0, 0.55, 0.15)
	add_child(flame_fx)
	boost_fx = _emitter(0.22, true, 16, 0.3)
	boost_fx.local_coords = true
	boost_fx.position = Vector3(0, 0.78, -1.9)
	boost_fx.direction = Vector3(0, 0.5, -1)
	boost_fx.spread = 35.0
	boost_fx.initial_velocity_min = 4.0
	boost_fx.initial_velocity_max = 8.0
	boost_fx.gravity = Vector3(0, -12, 0)
	add_child(boost_fx)
	star_fx = _emitter(0.5, true, 20, 0.4)
	star_fx.position = Vector3(0, 1.0, 0)
	star_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	star_fx.emission_sphere_radius = 1.6
	star_fx.direction = Vector3.UP
	star_fx.initial_velocity_min = 1.0
	star_fx.initial_velocity_max = 2.0
	star_fx.gravity = Vector3.ZERO
	star_fx.color = Color(1, 0.3, 0.3)
	star_fx.hue_variation_min = -1.0
	star_fx.hue_variation_max = 1.0
	add_child(star_fx)
	stars = Effects.hit_stars()
	stars.position.y = 2.6
	add_child(stars)


## Dust or snow thrown up by the rear wheels off the road (by surface) and
## tyre smoke while drifting or spinning on the road.
func _wheel_fx(th: Dictionary) -> void:
	var surf: String = th.get("surface", "grass")
	var dust_col: Color = th.dust
	for sx in [-1.0, 1.0]:
		var p: CPUParticles3D
		match surf:
			"snow":
				p = _emitter(0.9, false, 22, 0.7)
				p.direction = Vector3(sx * 0.4, 1.0, -0.7)
				p.spread = 25.0
				p.initial_velocity_min = 3.5
				p.initial_velocity_max = 7.0
				p.gravity = Vector3(0, -9, 0)
				p.scale_amount_min = 0.5
				p.scale_amount_max = 1.3
				p.color = Color(1, 1, 1, 0.95)
			"sand":
				p = _emitter(1.6, false, 16, 1.0)
				p.direction = Vector3(sx * 0.3, 0.6, -1.0)
				p.spread = 40.0
				p.initial_velocity_min = 1.0
				p.initial_velocity_max = 3.0
				p.gravity = Vector3(0, 0.4, 0)
				p.scale_amount_curve = Effects._curve(0.6, 1.5)
				p.color = Color(dust_col, 0.8)
			_:
				p = _emitter(0.7, false, 14, 0.55)
				p.direction = Vector3(sx * 0.3, 1.0, -0.6)
				p.spread = 30.0
				p.initial_velocity_min = 2.5
				p.initial_velocity_max = 5.0
				p.gravity = Vector3(0, -14, 0)
				p.scale_amount_min = 0.6
				p.scale_amount_max = 1.2
				var g := Gradient.new()
				g.colors = PackedColorArray([Color(th.ground).darkened(0.25), dust_col])
				p.color_initial_ramp = g
		p.position = Vector3(sx * 1.0, 0.3, -1.2)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		add_child(p)
		wheel_dust.append(p)
		var sm := _emitter(1.4, false, 12, 0.8)
		sm.position = Vector3(sx * 1.0, 0.25, -1.1)
		sm.direction = Vector3(0, 1, -0.3)
		sm.spread = 30.0
		sm.initial_velocity_min = 0.5
		sm.initial_velocity_max = 1.5
		sm.gravity = Vector3(0, 1.0, 0)
		sm.scale_amount_curve = Effects._curve(0.6, 1.8)
		sm.color = Color(1, 1, 1, 0.6) if surf == "snow" else Color(0.9, 0.9, 0.92, 0.38)
		add_child(sm)
		wheel_smoke.append(sm)


func _emitter(size: float, additive: bool, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = particle_mesh(size, additive)
	p.amount = Gfx.amount(amount)
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.color_ramp = fade_ramp()
	return p


func set_name_tag(text: String) -> void:
	if name_tag == null:
		name_tag = Label3D.new()
		name_tag.font = UI.bold_font
		name_tag.font_size = 48
		name_tag.pixel_size = 0.012
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.outline_size = 12
		name_tag.outline_modulate = Color(0, 0, 0, 0.8)
		name_tag.position = Vector3(0, 3.2, 0)
		name_tag.no_depth_test = false
		add_child(name_tag)
	name_tag.text = text
	# local players' own tag lives on its own render layer that their camera skips
	name_tag.layers = 1 << (10 + local_slot) if local_slot >= 0 else 1
	name_tag.modulate = ch.color.lightened(0.35)
	name_tag.visible = text != ""


# ================================================================== state
func reset(px: float, pz: float, h: float) -> void:
	x = px; z = pz; heading = h
	speed = 0.0; steer = 0.0; slip = 0.0; boost = 0.0; boost_mul = 1.3; star = 0.0
	spin = 0.0; spin_total = 1.0; hop = 0.0; hop_max = 0.3; hop_h = 0.45; invuln = 0.0
	item = 0; item_n = 0; roulette = 0.0; roll_tick = 0.0
	lap = 0; max_lap = 0; lap_start = 0.0; lap_times = []; last_lap = 0.0
	finished = false; finish_time = 0.0; offroad = false; lat = 0.0; rank = 6
	drift_prev = false; drift_active = false; drift_dir = 0.0; drift_charge = 0.0; drift_level = 0; braking = false
	bump_cd = 0.0; wrong_t = 0.0; autopilot = false
	var pj := race.track.project(x, z, -1)
	idx = pj[0]
	s = race.track.arc_pos(idx, pj[2])
	last_s = s
	prev_x = x; prev_z = z; prev_h = heading
	vis_x = x; vis_z = z; vis_h = heading
	for f in flames + cores:
		f.visible = false
	skid_last = [null, null]
	boost_col = FLAME_COL
	stars.visible = false
	for mt in glow_mats:
		mt.emission_enabled = false
	body.rotation = Vector3.ZERO
	position = Vector3(x, 0, z)
	rotation = Vector3(0, heading, 0)


func progress() -> float:
	return (lap - 1) * race.track.length + s


func max_speed() -> float:
	return float(Game.BASE.max) * float(race.diff.speed) * float(ch.speed)


func hop_y() -> float:
	return sin(PI * (1.0 - hop / hop_max)) * hop_h if hop > 0.0 and hop_max > 0.0 else 0.0


func hit(dur: float, big: bool) -> bool:
	if star > 0.0 or invuln > 0.0 or finished:
		return false
	spin = dur
	spin_total = dur
	speed *= 0.3
	boost = 0.0
	drift_active = false
	hop = 0.7 if big else 0.35
	hop_max = hop
	hop_h = 2.4 if big else 0.6
	invuln = dur + 0.8
	return true


func end_drift() -> void:
	if drift_level > 0:
		boost = maxf(boost, float(DRIFT_BOOST[mini(drift_level, 3)]))
		boost_mul = 1.25
	drift_active = false
	drift_charge = 0.0
	drift_level = 0


## One fixed simulation step (host / offline only).
func update(dt: float, inp: Dictionary) -> void:
	var base: Dictionary = Game.BASE
	var mx := max_speed()
	var handling: float = ch.handling
	boost = maxf(0.0, boost - dt)
	star = maxf(0.0, star - dt)
	hop = maxf(0.0, hop - dt)
	invuln = maxf(0.0, invuln - dt)
	bump_cd = maxf(0.0, bump_cd - dt)

	braking = false
	if spin > 0.0:
		spin -= dt
		speed = Game.approach(speed, 0.0, 32.0 * dt)
		steer = 0.0
	else:
		steer = Game.approach(steer, float(inp.steer), 7.0 * dt)
		var slow := offroad and boost <= 0.0 and star <= 0.0
		var cap := mx
		if slow:
			cap *= 0.5
		if star > 0.0:
			cap *= 1.18
		if boost > 0.0:
			cap = maxf(cap, mx * boost_mul)
			speed = minf(cap, speed + 70.0 * dt)
		elif inp.gas:
			if speed < cap:
				var a: float = base.accel * float(ch.accel) * float(race.diff.speed) * (2.2 if speed < 0.0 else 1.0) * (1.0 - 0.55 * clampf(speed / cap, 0.0, 1.0))
				speed = minf(cap, speed + a * dt)
		elif inp.brake:
			braking = speed > 8.0
			if speed > 0.5:
				speed -= float(base.brake) * dt
			else:
				speed = maxf(-float(base.rev), speed - 16.0 * dt)
		else:
			speed = Game.approach(speed, 0.0, float(base.drag) * dt)
		if speed > cap:
			speed = Game.approach(speed, cap, (45.0 if slow else 18.0) * dt)

		# drifting
		var a_sp := absf(speed)
		var drift_in: bool = inp.drift
		if drift_in and not drift_prev and hop <= 0.0:
			hop = 0.26
			hop_max = 0.26
			hop_h = 0.45
		if not drift_active and drift_in and absf(float(inp.steer)) > 0.25 and speed > mx * 0.4:
			drift_active = true
			drift_dir = signf(float(inp.steer))
			drift_charge = 0.0
			drift_level = 0
		if drift_active:
			if not drift_in or speed < mx * 0.3:
				end_drift()
			else:
				var tight := clampf((steer * drift_dir + 1.0) * 0.5, 0.0, 1.0)
				heading -= drift_dir * float(base.turn) * handling * (0.5 + 0.62 * tight) * dt
				drift_charge += dt * (0.55 + 0.9 * tight) * (0.4 if offroad else 1.0)
				var lvl := 3 if drift_charge > 3.5 else (2 if drift_charge > 2.2 else (1 if drift_charge > 1.0 else 0))
				if lvl > drift_level:
					drift_level = lvl
		if not drift_active:
			var f := clampf(a_sp / (mx * 0.22), 0.0, 1.0) * (1.0 - 0.28 * clampf(a_sp / mx, 0.0, 1.0))
			heading -= steer * float(base.turn) * handling * f * signf(speed) * dt
		drift_prev = drift_in
		if inp.item and item != 0 and roulette <= 0.0:
			race.use_item(self)
	slip = Game.approach(slip, drift_dir * 0.4 if drift_active else 0.0, 3.0 * dt)

	x += sin(heading) * speed * dt
	z += cos(heading) * speed * dt
	constrain()

	if roulette > 0.0:
		roulette -= dt
		if roulette <= 0.0:
			race.give_item(self)


func constrain() -> void:
	var tr := race.track
	var pj := tr.project(x, z, idx)
	idx = pj[0]
	var la: float = pj[1]
	var lim := Game.BAR - Game.KART_R
	if absf(la) > lim:
		var sg := signf(la)
		var push := absf(la) - lim
		x -= tr.nx[idx] * sg * push
		z -= tr.nz[idx] * sg * push
		var into := (sin(heading) * tr.nx[idx] + cos(heading) * tr.nz[idx]) * sg
		if into * speed > 0.0:
			var tang := tr.heading(idx)
			var facing := tang if cos(Game.wrap_angle(heading - tang)) >= 0.0 else tang + PI
			heading += Game.wrap_angle(facing - heading) * 0.5
			var loss := absf(into)
			speed *= 1.0 - 0.55 * loss
			if bump_cd <= 0.0 and loss > 0.2 and absf(speed) > 4.0:
				bump_cd = 0.4
				race.on_bump(self, loss)
		la = sg * lim
	lat = la
	offroad = absf(la) > Game.HW + Game.KERB * 0.6
	var ns := tr.arc_pos(idx, pj[2])
	var ds := ns - last_s
	if ds < -tr.length * 0.5:
		race.on_lap(self, 1)
	elif ds > tr.length * 0.5:
		race.on_lap(self, -1)
	last_s = ns
	s = ns


# ================================================================== network
func pack(out: PackedFloat32Array, o: int) -> void:
	out[o] = x; out[o + 1] = z; out[o + 2] = heading; out[o + 3] = speed
	out[o + 4] = slip; out[o + 5] = steer; out[o + 6] = spin; out[o + 7] = spin_total
	out[o + 8] = hop; out[o + 9] = hop_max; out[o + 10] = hop_h; out[o + 11] = boost
	out[o + 12] = star
	out[o + 13] = drift_dir * (drift_level + 1) if drift_active else 0.0
	out[o + 14] = lap; out[o + 15] = s; out[o + 16] = rank; out[o + 17] = 1.0 if finished else 0.0
	out[o + 18] = finish_time; out[o + 19] = item * 10 + item_n; out[o + 20] = roulette
	out[o + 21] = last_lap; out[o + 22] = wrong_t; out[o + 23] = (1 if offroad else 0) + (2 if braking else 0)


func unpack(d: PackedFloat32Array, o: int) -> void:
	x = d[o]; z = d[o + 1]; heading = d[o + 2]; speed = d[o + 3]
	slip = d[o + 4]; steer = d[o + 5]; spin = d[o + 6]; spin_total = maxf(0.01, d[o + 7])
	hop = d[o + 8]; hop_max = maxf(0.01, d[o + 9]); hop_h = d[o + 10]; boost = d[o + 11]
	star = d[o + 12]
	var dv := d[o + 13]
	drift_active = dv != 0.0
	drift_dir = signf(dv)
	drift_level = int(absf(dv)) - 1 if drift_active else 0
	lap = int(d[o + 14]); s = d[o + 15]; rank = int(d[o + 16]); finished = d[o + 17] > 0.5
	finish_time = d[o + 18]
	var it := int(round(d[o + 19]))
	item = it / 10
	item_n = it % 10
	roulette = d[o + 20]
	last_lap = d[o + 21]; wrong_t = d[o + 22]; var fl := int(d[o + 23])
	offroad = fl & 1 != 0
	braking = fl & 2 != 0


# ================================================================== visuals
func begin_tick() -> void:
	prev_x = x
	prev_z = z
	prev_h = heading


## alpha: physics interpolation fraction; smooth > 0 eases toward network state instead.
func render(delta: float, alpha: float, smooth: bool, t: float) -> void:
	var px: float
	var pz: float
	var ph: float
	if smooth:
		var k := 1.0 - exp(-14.0 * delta)
		vis_x = lerpf(vis_x, x, k)
		vis_z = lerpf(vis_z, z, k)
		vis_h += Game.wrap_angle(heading - vis_h) * k
		if Vector2(vis_x - x, vis_z - z).length() > 12.0:
			vis_x = x; vis_z = z; vis_h = heading
		px = vis_x; pz = vis_z; ph = vis_h
	else:
		px = lerpf(prev_x, x, alpha)
		pz = lerpf(prev_z, z, alpha)
		ph = prev_h + Game.wrap_angle(heading - prev_h) * alpha
	var mx := maxf(1.0, max_speed())
	var sr := clampf(absf(speed) / mx, 0.0, 1.5)
	position = Vector3(px, 0.0, pz)
	rotation = Vector3(0.0, ph - slip, 0.0)
	body.position.y = hop_y() + sin(t * 38.0 + driver) * 0.02 * sr
	body.rotation.y = (1.0 - spin / spin_total) * PI * 4.0 if spin > 0.0 else 0.0
	body.rotation.z = (-drift_dir * 0.08 if drift_active else -steer * 0.05 * sr)
	body.rotation.x = -0.04 if boost > 0.0 else 0.0
	wheel_rot += speed * delta / 0.44
	for sp in spins:
		sp.rotation.x = wheel_rot
	for f in front:
		f.rotation.y = -steer * 0.45
	_render_flames(delta)
	if star > 0.0:
		for mt in glow_mats:
			mt.emission_enabled = true
			mt.emission = Color.from_hsv(star_hue, 1.0, 0.9)
	elif glow_mats[0].emission_enabled:
		for mt in glow_mats:
			mt.emission_enabled = false
	star_fx.emitting = star > 0.0
	var lvl := clampi(drift_level, 1, 3)
	for p in sparks:
		p.emitting = drift_active and drift_level > 0
		p.color = DRIFT_COLS[lvl - 1]
		p.scale_amount_min = 1.5 if drift_level == 3 else 1.0
		p.scale_amount_max = p.scale_amount_min
	var moving := absf(speed) > 8.0
	var on_road_slide := not offroad and absf(speed) > 6.0 and (drift_active or spin > 0.0)
	for i in 2:
		wheel_dust[i].emitting = offroad and moving and hop_y() < 0.2
		wheel_smoke[i].emitting = on_road_slide
	_render_skids()
	stars.visible = spin > 0.0
	if stars.visible:
		stars.rotation.y = t * 5.0
		stars.position.y = 2.6 + hop_y()


func _render_flames(delta: float) -> void:
	var fl := boost > 0.0 or star > 0.0
	boost_age = boost_age + delta if fl else 0.0
	flame_fx.emitting = fl
	boost_fx.emitting = boost > 0.0
	if not fl:
		if flames[0].visible:
			for f in flames + cores:
				f.visible = false
		return
	var col := boost_col
	if star > 0.0:
		star_hue = fposmod(star_hue + delta * 1.6, 1.0)
		if boost <= 0.0:
			col = Color.from_hsv(star_hue, 0.8, 1.0)
	flame_mat.albedo_color = Color(col, 0.85)
	flame_fx.color = col
	boost_fx.color = col.lightened(0.4)
	# the flame bursts out long right after the turbo kicks in, then flickers
	var pulse := 1.0 + 0.9 * clampf(1.0 - boost_age / 0.35, 0.0, 1.0)
	for i in flames.size():
		var ln := (0.9 + randf() * 0.6) * pulse * 1.2
		var f: MeshInstance3D = flames[i]
		f.visible = true
		f.scale = Vector3(pulse, ln, pulse)
		f.position.z = -1.75 - 0.5 * ln
		var c: MeshInstance3D = cores[i]
		c.visible = true
		c.scale = Vector3(1.0, ln * 0.8, 1.0)
		c.position.z = -1.75 - 0.35 * ln * 0.8


## Tyre marks from both rear wheels while drifting, braking hard or spinning.
func _render_skids() -> void:
	var skid := (drift_active or braking or spin > 0.0) and not offroad and absf(speed) > 6.0 and hop_y() < 0.15
	var strength := 0.75 if braking and not drift_active else 1.0
	for i in 2:
		if not skid:
			skid_last[i] = null
			continue
		var wp := transform * Vector3(-1.0 if i == 0 else 1.0, 0.0, -0.95)
		if skid_last[i] == null:
			skid_last[i] = wp
		elif wp.distance_to(skid_last[i]) >= SkidMarks.STEP:
			race.skids.add(skid_last[i], wp, strength)
			skid_last[i] = wp


## Turbo just started: colour by what gave it (drift level 1–3, 0 = item or start) and a flash.
func on_boost(level: int) -> void:
	boost_col = DRIFT_COLS[level - 1] if level >= 1 and level <= 3 else FLAME_COL
	boost_age = 0.0
	Effects.flash(body, Vector3(0, 0.8, -2.2), boost_col.lightened(0.3), 3.2, 0.3)
