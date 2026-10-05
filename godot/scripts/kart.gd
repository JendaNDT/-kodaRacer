class_name Kart
extends Node3D
## One kart: its model (KartModel + DriverRig), effects, suspension and
## the arcade driving model (ported 1:1 from the web prototype).

const SNAP_FIELDS := 24

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
var bump_cd := 0.0
var wrong_t := 0.0
var obs := {}

# --- visuals
var body: Node3D            # hops and spins with the kart (wheels included)
var chassis: Node3D         # sits on the suspension: everything but the wheels
var rig: DriverRig
var model: Dictionary
var front: Array = []
var spins: Array = []
var spin_r: Array = []
var spin_a := PackedFloat32Array()
var flames: Array = []
var glow_mats: Array = []
var sparks: Array = []
var dust: CPUParticles3D
var flame_fx: CPUParticles3D
var star_fx: CPUParticles3D
var name_tag: Label3D
var blob: MeshInstance3D
var star_hue := 0.0
var susp_y := 0.0
var susp_v := 0.0
var pitch := 0.0
var pitch_v := 0.0
var accel_f := 0.0
var prev_speed := 0.0
var prev_hop := 0.0
var rumble_t := 0.0
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
	_m.flame = _cyl(0.0, 0.2, 1.0, 8)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.63, 0.19, 0.85)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_m.flamem = fm
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
	# particle materials, shared so apply_quality() can brighten them at once
	for additive in [true, false]:
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.vertex_color_use_as_albedo = true
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		pm.albedo_texture = _m.dot
		pm.disable_fog = true
		_m["pmat_add" if additive else "pmat_mix"] = pm
	return _m


static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func particle_mesh(size: float, additive: bool) -> QuadMesh:
	var m := _shared()
	var key := "quad_%s_%s" % [size, additive]
	if not m.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = m.pmat_add if additive else m.pmat_mix
		m[key] = q
	return m[key]


## Glowing things (flames, sparks, star) get brighter than white when the
## level has glow, so they bloom. Shared materials, so it applies at once.
static func apply_quality() -> void:
	var m := _shared()
	var b := Gfx.boost()
	m.flamem.albedo_color = Color(1.0 * b, 0.63 * b, 0.19 * b, 0.85)
	m.pmat_add.albedo_color = Color(b, b, b, 1.0)


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
	(parent if parent != null else chassis).add_child(mi)
	return mi


## Detailed mesh up close, the simpler one beyond `dist` metres.
static func _lod_pair(parent: Node3D, near: Mesh, far: Mesh, dist: float) -> Array:
	var a := MeshInstance3D.new()
	a.mesh = near
	a.visibility_range_end = dist
	a.visibility_range_end_margin = 2.0
	parent.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = far
	b.visibility_range_begin = dist
	b.visibility_range_begin_margin = 2.0
	parent.add_child(b)
	return [a, b]


func _build_model() -> void:
	var m := _shared()
	model = KartModel.get_model(driver)
	body = Node3D.new()
	add_child(body)
	chassis = Node3D.new()
	body.add_child(chassis)
	# one material per kart so the star can make just this kart glow
	var paint := MeshKit.body_material()
	glow_mats = [paint]
	var lod := Gfx.kart_lod()
	for mesh in _lod_pair(chassis, model.body, model.body_low, lod):
		mesh.set_surface_override_material(0, paint)
	var ex: Vector3 = model.exhaust
	for sx in [-1.0, 1.0]:
		var f := _part(m.flame, m.flamem, Vector3(ex.x * sx, ex.y, ex.z - 0.3))
		f.rotation.x = -PI / 2.0
		f.visible = false
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(f)
	# front wheels steer on their own pivots, the rear pair spins on one axle
	var fw: Dictionary = model.front
	var rw: Dictionary = model.rear
	for sx in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(float(fw.x) * sx, float(fw.r), float(fw.z))
		body.add_child(pivot)
		var sp := Node3D.new()
		pivot.add_child(sp)
		for wm in _lod_pair(sp, model.front_mesh, model.front_low, lod):
			wm.scale = Vector3(sx, 1.0, 1.0)
		front.append(pivot)
		spins.append(sp)
		spin_r.append(float(fw.r))
		spin_a.append(0.0)
	var axle := Node3D.new()
	axle.position = Vector3(0.0, float(rw.r), float(rw.z))
	body.add_child(axle)
	_lod_pair(axle, model.rear_mesh, model.rear_low, lod)
	spins.append(axle)
	spin_r.append(float(rw.r))
	spin_a.append(0.0)
	rig = DriverRig.new()
	chassis.add_child(rig)
	var seat: Vector3 = model.seat
	var wheel: Vector3 = model.wheel
	rig.position = seat
	rig.setup(driver, wheel - seat, float(model.tilt), paint, lod * 1.3)
	# soft dark spot under the kart, used where the sun casts no real shadows
	var size: Vector2 = model.size
	blob = MeshInstance3D.new()
	blob.mesh = m.shadow
	blob.position.y = 0.1
	blob.scale = Vector3(size.x / 2.8, 1.0, size.y / 3.8)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.visible = not Gfx.shadows()
	add_child(blob)

	# effects
	for sx in [-1.0, 1.0]:
		var p := _emitter(0.5, true, 28, 0.25)
		p.position = Vector3(sx * float(rw.x), 0.3, float(rw.z) - 0.35)
		p.direction = Vector3(sx * 0.3, 1.0, -0.6)
		p.spread = 40.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -14, 0)
		add_child(p)
		sparks.append(p)
	dust = _emitter(1.2, false, 24, 0.6)
	dust.position = Vector3(0, 0.3, float(rw.z) - 0.45)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.0
	dust.direction = Vector3(0, 1, -0.3)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.5
	dust.gravity = Vector3(0, 0.5, 0)
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.6
	add_child(dust)
	flame_fx = _emitter(0.7, true, 24, 0.18)
	flame_fx.position = Vector3(0, ex.y + 0.02, ex.z - 0.45)
	flame_fx.direction = Vector3(0, 0.2, -1)
	flame_fx.spread = 15.0
	flame_fx.initial_velocity_min = 4.0
	flame_fx.initial_velocity_max = 7.0
	flame_fx.gravity = Vector3.ZERO
	flame_fx.color = Color(1.0, 0.55, 0.15)
	add_child(flame_fx)
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


func _emitter(size: float, additive: bool, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = particle_mesh(size, additive)
	p.amount = Gfx.amount(amount)
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.color_ramp = fade_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		name_tag.position = Vector3(0, float(model.top) + 1.0, 0)
		name_tag.no_depth_test = false
		name_tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	drift_prev = false; drift_active = false; drift_dir = 0.0; drift_charge = 0.0; drift_level = 0
	bump_cd = 0.0; wrong_t = 0.0; autopilot = false
	var pj := race.track.project(x, z, -1)
	idx = pj[0]
	s = race.track.arc_pos(idx, pj[2])
	last_s = s
	prev_x = x; prev_z = z; prev_h = heading
	vis_x = x; vis_z = z; vis_h = heading
	for f in flames:
		f.visible = false
	for mt in glow_mats:
		mt.emission_enabled = false
	body.rotation = Vector3.ZERO
	chassis.transform = Transform3D.IDENTITY
	susp_y = 0.0; susp_v = 0.0; pitch = 0.0; pitch_v = 0.0; accel_f = 0.0
	prev_speed = 0.0; prev_hop = 0.0; rumble_t = 0.0
	rig.reset()
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
		boost = maxf(boost, 0.7 if drift_level == 1 else 1.3)
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
				var lvl := 2 if drift_charge > 2.2 else (1 if drift_charge > 1.0 else 0)
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
	out[o + 21] = last_lap; out[o + 22] = wrong_t; out[o + 23] = 1.0 if offroad else 0.0


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
	last_lap = d[o + 21]; wrong_t = d[o + 22]; offroad = d[o + 23] > 0.5


# ================================================================== visuals
func begin_tick() -> void:
	prev_x = x
	prev_z = z
	prev_h = heading


## alpha: physics interpolation fraction; smooth > 0 eases toward network state instead.
func render(delta: float, alpha: float, smooth: bool, t: float, dust_color: Color) -> void:
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
	body.position.y = hop_y()
	body.rotation.y = (1.0 - spin / spin_total) * PI * 4.0 if spin > 0.0 else 0.0
	_suspension(delta, sr)
	chassis.position.y = susp_y + sin(t * 38.0 + driver) * 0.015 * sr
	chassis.rotation.x = pitch - (0.03 if boost > 0.0 else 0.0)
	chassis.rotation.z = (-drift_dir * 0.08 if drift_active else -steer * 0.05 * sr)
	for i in spins.size():
		spin_a[i] = fposmod(spin_a[i] + speed * delta / float(spin_r[i]), TAU)
		(spins[i] as Node3D).rotation.x = spin_a[i]
	for f in front:
		f.rotation.y = -steer * 0.45
	rig.update(self, delta, t)
	var fl := boost > 0.0 or star > 0.0
	for f in flames:
		f.visible = fl
		if fl:
			f.scale = Vector3(1.0, 0.8 + randf() * 0.6, 1.0)
	flame_fx.emitting = fl
	if star > 0.0:
		star_hue = fposmod(star_hue + delta * 1.6, 1.0)
		var c := Color.from_hsv(star_hue, 1.0, 0.9)
		for mt in glow_mats:
			mt.emission_enabled = true
			mt.emission = c
			mt.emission_energy_multiplier = Gfx.boost()
	elif glow_mats[0].emission_enabled:
		for mt in glow_mats:
			mt.emission_enabled = false
	star_fx.emitting = star > 0.0
	var spark_col := Color(1.0, 0.64, 0.18) if drift_level == 2 else Color(0.35, 0.78, 1.0)
	for p in sparks:
		p.emitting = drift_active and drift_level > 0
		p.color = spark_col
	dust.emitting = offroad and absf(speed) > 8.0
	dust.color = dust_color


## Springy chassis: dips on landing, nods when speeding up or braking and
## rattles over grass, sand and snow. Visual only, so it also works from
## network snapshots.
func _suspension(delta: float, sr: float) -> void:
	if delta <= 0.0:
		return
	if prev_hop > 0.0 and hop <= 0.0:   # just landed
		susp_v -= 0.9 + 1.1 * clampf(hop_h, 0.0, 2.5)
	prev_hop = hop
	if offroad and absf(speed) > 6.0:
		rumble_t -= delta
		if rumble_t <= 0.0:
			rumble_t = randf_range(0.05, 0.13)
			susp_v += randf_range(-0.7, 0.7) * sr
	accel_f = lerpf(accel_f, (speed - prev_speed) / delta, 1.0 - exp(-8.0 * delta))
	prev_speed = speed
	var want_pitch := clampf(-accel_f * 0.0028, -0.07, 0.08) if spin <= 0.0 else 0.0
	var steps := ceili(delta / (1.0 / 90.0))
	var h := delta / steps
	for i in steps:
		susp_v += (-susp_y * 240.0 - susp_v * 12.0) * h
		susp_y += susp_v * h
		pitch_v += ((want_pitch - pitch) * 150.0 - pitch_v * 13.0) * h
		pitch += pitch_v * h
	susp_y = clampf(susp_y, -0.16, 0.12)
