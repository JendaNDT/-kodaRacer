class_name Kart
extends Node3D
## One kart: its model (KartModel + DriverRig), effects, suspension and
## the arcade driving model (ported from the web prototype), plus height:
## it follows hills and banked corners, flies off the ramp (never off a
## crest) and can do a trick in the air for a turbo on landing.

const SNAP_FIELDS := 36
const CORR_RATE := 9.0       # how fast a predicted kart eases into the host's position (1/s)
const CORR_SNAP := 4.0       # a bigger difference (m) is not eased, the kart moves there at once
const TRICK_TIME := 0.42    # one barrel roll
const SLOPE_PULL := 16.0    # how much hills slow you down (or help) per unit of slope
const STICK := 2.0          # how fast the kart drops off a step, in units of gravity
const STEP_DROP := 0.25     # a drop in one tick this big is a step to fly off (m)
## Drift spark / turbo colours for drift levels 1–3 (blue, orange, purple).
const DRIFT_COLS := [Color(0.35, 0.78, 1.0), Color(1.0, 0.64, 0.18), Color(0.78, 0.36, 1.0)]
const DRIFT_BOOST := [0.0, 0.7, 1.3, 1.75]
## Drift charge for the blue, orange and purple sparks (turbo levels 1–3). Since
## 1.14.0 at 60 % of the old 1.0 / 2.2 / 3.5, so a long bend is enough for a turbo.
const DRIFT_LEVELS := [0.6, 1.3, 2.1]
const FLAME_COL := Color(1.0, 0.63, 0.19)

var race: Race
var ch: Dictionary
var driver := 0
var human := false
var local_slot := -1        # 0/1 = player on this device, -1 = AI or remote
var peer := 0               # network peer that drives it (0 = AI)
var player_name := ""
var autopilot := false
var drift_boosts := 0       # turbos from drifts in this race (tests)
var ack := 0                # host: number of the last control message of its player used
var predicted := false      # Wi-Fi client: this kart is simulated here from its own controls
var corr := Vector3.ZERO    # predicted kart: what is left to ease away after a correction
var corr_h := 0.0
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
var vis_scale := 1.0
var bubble: MeshInstance3D   # the shield, made the first time it is needed
var shield := 0.0            # > 0: a bubble that swallows one hit
var shrink := 0.0            # > 0: made small by the lightning (slower, can be run over)
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
var on_cut := false         # on the track's shortcut (lat/along then belong to the path, idx to the lap)
var cut_i := 0              # nearest sample of the shortcut
var cut_along := 0.0
var cut_uses := 0           # times it took the shortcut this race (tests)
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
var y := 0.0
var vy := 0.0
var air := false            # flying (off a crest or the ramp)
var air_t := 0.0
var trick := 0.0            # > 0 while the trick roll plays
var tricked := false        # a trick was done on this flight
var along := 0.0            # metres ahead of sample idx

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
var blob: MeshInstance3D
var star_hue := 0.0
var susp_y := 0.0
var susp_v := 0.0
var pitch := 0.0
var pitch_v := 0.0
var accel_f := 0.0
var prev_speed := 0.0
var sus_py := 0.0           # height on screen last frame, for the swing over crests
var sus_vy := 0.0
var prev_hop := 0.0
var rumble_t := 0.0
var prev_x := 0.0
var prev_z := 0.0
var prev_h := 0.0
var prev_y := 0.0
var vis_x := 0.0
var vis_z := 0.0
var vis_h := 0.0
var vis_y := 0.0
var vis_up := Vector3.UP
var yaw := 0.0              # where the kart points on screen (for the camera)
var was_air := false
var land_v := 0.0

static var _m := {}
## --jumptest: every take-off is written down here ([track id, arc metres, speed]).
static var takeoffs: Array = []
static var log_takeoffs := false


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
	_m.core = _cyl(0.0, 0.1, 0.7, 8)
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
		# fade particles that fly right past the camera instead of filling the screen
		pm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		pm.distance_fade_min_distance = 1.5
		pm.distance_fade_max_distance = 5.0
		_m["pmat_add" if additive else "pmat_mix"] = pm
	# the shield: a glassy bubble, clear in the middle and bright at the rim
	var sph := SphereMesh.new()
	sph.radius = 1.85
	sph.height = 3.1
	sph.radial_segments = 24
	sph.rings = 12
	_m.bubble = sph
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform vec4 tint : source_color = vec4(0.35, 0.85, 1.0, 1.0);
void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float shine = smoothstep(0.82, 0.98, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.7, 0.6))));
	ALBEDO = tint.rgb * (0.12 + 0.9 * rim * rim * rim) + vec3(shine * 0.6);
}
"""
	var bm := ShaderMaterial.new()
	bm.shader = sh
	_m.bubblem = bm
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
	m.corem.albedo_color = Color(1.0 * b, 0.95 * b, 0.75 * b, 0.9)
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


## Detailed mesh up close, the simpler one beyond `dist` metres. The sun's
## shadow always comes from the simpler one (a shadow-only copy up close):
## nobody sees the difference in a shadow, but it is drawn once per cascade.
static func _lod_pair(parent: Node3D, near: Mesh, far: Mesh, dist: float) -> Array:
	var a := MeshInstance3D.new()
	a.mesh = near
	a.visibility_range_end = dist
	a.visibility_range_end_margin = 2.0
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = far
	b.visibility_range_begin = dist
	b.visibility_range_begin_margin = 2.0
	parent.add_child(b)
	var c := MeshInstance3D.new()
	c.mesh = far
	c.visibility_range_end = dist
	c.visibility_range_end_margin = 2.0
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(c)
	return [a, b, c]


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
	flame_mat = m.flamem.duplicate()
	for sx in [-1.0, 1.0]:
		var f := _part(m.flame, flame_mat, Vector3(ex.x * sx, ex.y, ex.z - 0.3))
		f.rotation.x = -PI / 2.0
		f.visible = false
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(f)
		var c := _part(m.core, m.corem, Vector3(ex.x * sx, ex.y, ex.z - 0.2))
		c.rotation.x = -PI / 2.0
		c.visible = false
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cores.append(c)
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
	_wheel_fx(race.track.def.theme)
	flame_fx = _emitter(0.7, true, 24, 0.18)
	flame_fx.position = Vector3(0, ex.y + 0.02, ex.z - 0.45)
	flame_fx.direction = Vector3(0, 0.2, -1)
	flame_fx.spread = 15.0
	flame_fx.initial_velocity_min = 4.0
	flame_fx.initial_velocity_max = 7.0
	flame_fx.gravity = Vector3.ZERO
	flame_fx.color = Color(1.0, 0.55, 0.15)
	add_child(flame_fx)
	boost_fx = _emitter(0.22, true, 16, 0.3)
	boost_fx.local_coords = true
	boost_fx.position = Vector3(0, ex.y, ex.z - 0.15)
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
	var rw: Dictionary = model.rear
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
		p.position = Vector3(sx * float(rw.x), 0.3, float(rw.z) - 0.25)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		add_child(p)
		wheel_dust.append(p)
		var sm := _emitter(1.4, false, 12, 0.8)
		sm.position = Vector3(sx * float(rw.x), 0.25, float(rw.z) - 0.15)
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
	speed = 0.0; steer = 0.0; slip = 0.0; boost = 0.0; boost_mul = 1.3; star = 0.0; shield = 0.0; shrink = 0.0
	spin = 0.0; spin_total = 1.0; hop = 0.0; hop_max = 0.3; hop_h = 0.45; invuln = 0.0
	item = 0; item_n = 0; roulette = 0.0; roll_tick = 0.0
	lap = 0; max_lap = 0; lap_start = 0.0; lap_times = []; last_lap = 0.0
	finished = false; finish_time = 0.0; offroad = false; lat = 0.0; rank = 6; on_cut = false; cut_i = 0
	drift_prev = false; drift_active = false; drift_dir = 0.0; drift_charge = 0.0; drift_level = 0; braking = false
	bump_cd = 0.0; wrong_t = 0.0; autopilot = false
	var pj := race.track.project(x, z, -1)
	idx = pj[0]
	lat = pj[1]
	along = pj[2]
	s = race.track.arc_pos(idx, pj[2])
	last_s = s
	y = race.track.road_y(idx, lat, along)
	vy = 0.0; air = false; air_t = 0.0; trick = 0.0; tricked = false; was_air = false; land_v = 0.0
	prev_x = x; prev_z = z; prev_h = heading; prev_y = y
	vis_x = x; vis_z = z; vis_h = heading; vis_y = y
	vis_up = race.track.normal(idx, lat, along)
	yaw = heading
	for f in flames + cores:
		f.visible = false
	skid_last = [null, null]
	boost_col = FLAME_COL
	stars.visible = false
	for mt in glow_mats:
		mt.emission_enabled = false
	body.rotation = Vector3.ZERO
	chassis.transform = Transform3D.IDENTITY
	susp_y = 0.0; susp_v = 0.0; pitch = 0.0; pitch_v = 0.0; accel_f = 0.0
	prev_speed = 0.0; prev_hop = 0.0; rumble_t = 0.0; sus_vy = 0.0; sus_py = y
	rig.reset()
	position = Vector3(x, y, z)
	rotation = Vector3(0, heading, 0)


func progress() -> float:
	return (lap - 1) * race.track.length + s


func max_speed() -> float:
	return float(Game.BASE.max) * float(race.diff.speed) * float(ch.speed) * (Game.SHRINK_SPEED if shrink > 0.0 else 1.0)


func hop_y() -> float:
	return sin(PI * (1.0 - hop / hop_max)) * hop_h if hop > 0.0 and hop_max > 0.0 else 0.0


func hit(dur: float, big: bool) -> bool:
	if star > 0.0 or invuln > 0.0 or finished:
		return false
	if shield > 0.0:
		shield = 0.0            # the bubble pops instead
		invuln = 0.5
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
		drift_boosts += 1
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
	if on_cut:
		handling *= float(race.track.cut.grip)   # ice and sand: the kart slides
	boost = maxf(0.0, boost - dt)
	star = maxf(0.0, star - dt)
	shield = maxf(0.0, shield - dt)
	shrink = maxf(0.0, shrink - dt)
	hop = maxf(0.0, hop - dt)
	trick = maxf(0.0, trick - dt)
	invuln = maxf(0.0, invuln - dt)
	bump_cd = maxf(0.0, bump_cd - dt)

	braking = false
	if spin > 0.0:
		spin -= dt
		speed = Game.approach(speed, 0.0, 32.0 * dt)
		steer = 0.0
	else:
		steer = Game.approach(steer, float(inp.steer), 7.0 * dt)
		var slow := (offroad or on_cut) and boost <= 0.0 and star <= 0.0 and not air
		var cap := mx
		if slow:
			cap *= 0.5 if offroad else float(race.track.cut.slow[race.diff_idx])   # grass, or the shortcut's dirt / sand / ice
		if star > 0.0:
			cap *= 1.18
		if air:
			speed = Game.approach(speed, 0.0, 1.5 * dt)   # no grip in the air
		elif boost > 0.0:
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
		if speed > cap and not air:
			speed = Game.approach(speed, cap, (45.0 if slow else 18.0) * dt)

		# drifting
		var a_sp := absf(speed)
		var drift_in: bool = inp.drift
		if air:
			# the drift button in the air is a trick: a roll, turbo on landing
			if drift_in and not drift_prev and not tricked and air_t > 0.06:
				tricked = true
				trick = TRICK_TIME
		elif drift_in and not drift_prev and hop <= 0.0:
			hop = 0.26
			hop_max = 0.26
			hop_h = 0.45
		if not drift_active and not air and drift_in and absf(float(inp.steer)) > 0.25 and speed > mx * 0.4:
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
				var lvl := 3 if drift_charge > DRIFT_LEVELS[2] else (2 if drift_charge > DRIFT_LEVELS[1] else (1 if drift_charge > DRIFT_LEVELS[0] else 0))
				if lvl > drift_level:
					drift_level = lvl
		if not drift_active:
			var f := clampf(a_sp / (mx * 0.22), 0.0, 1.0) * (1.0 - 0.28 * clampf(a_sp / mx, 0.0, 1.0))
			if air:
				f *= 0.35
			heading -= steer * float(base.turn) * handling * f * signf(speed) * dt
		drift_prev = drift_in
		if inp.item and item != 0 and roulette <= 0.0:
			race.use_item(self)
	slip = Game.approach(slip, drift_dir * 0.4 if drift_active else 0.0, 3.0 * dt)

	if not air and not on_cut:
		# uphill slows you down, downhill helps (only up to the usual top speed)
		var tr := race.track
		var fx := sin(heading)
		var fz := cos(heading)
		var dh := tr.slope[idx] * (fx * tr.tx[idx] + fz * tr.tz[idx]) + tr.bank[idx] * (fx * tr.nx[idx] + fz * tr.nz[idx])
		speed -= SLOPE_PULL * dh * signf(speed) * dt
	x += sin(heading) * speed * dt
	z += cos(heading) * speed * dt
	constrain()
	_vertical(dt)

	if roulette > 0.0 and race.mode != Race.Mode.CLIENT:   # the host draws the items
		roulette -= dt
		if roulette <= 0.0:
			race.give_item(self)


## Height: stick to the road while it does not drop away faster than
## gravity would pull the kart down, otherwise fly until it lands again.
func _vertical(dt: float) -> void:
	var gy := ground_y()
	if air:
		air_t += dt
		vy -= Game.GRAVITY * dt
		y += vy * dt
		if y <= gy:
			land_v = maxf(0.0, -vy)
			y = gy
			vy = 0.0
			air = false
			trick = 0.0
			if tricked:
				tricked = false
				boost = maxf(boost, 0.9)
				boost_mul = 1.25
		return
	# tyres grip: only a real step in the road (the ramp's lip or its sides,
	# STEP_DROP or more at once) lets the kart take off; over a crest, however
	# fast, it stays down and only swings on its springs
	var free_y := y + vy * dt - STICK * Game.GRAVITY * dt * dt
	if gy < free_y - STEP_DROP and absf(speed) > 3.0:
		air = true
		air_t = 0.0
		if log_takeoffs:
			takeoffs.append([race.track.def.id, s, speed])
		tricked = false
		vy -= Game.GRAVITY * dt
		y = free_y
		return
	vy = clampf((gy - y) / dt, -30.0, 30.0)
	y = gy


func constrain() -> void:
	var tr := race.track
	if not tr.cut.is_empty() and _constrain_cut(tr):
		return
	var pj := tr.project(x, z, idx)
	idx = pj[0]
	along = pj[2]
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
	_count_lap(tr, tr.arc_pos(idx, pj[2]))


## Laps: the place on the lap wrapping past the line counts one (or back one).
func _count_lap(tr: Track, ns: float) -> void:
	var ds := ns - last_s
	if ds < -tr.length * 0.5:
		race.on_lap(self, 1)
	elif ds > tr.length * 0.5:
		race.on_lap(self, -1)
	last_s = ns
	s = ns


## On the shortcut (or getting onto it): stays between its edges, leaves it
## onto the road at either end. False when the kart is on the road.
func _constrain_cut(tr: Track) -> bool:
	var m: int = tr.cut.m
	if not on_cut:
		# the path can only be entered where it leaves or joins the road
		if tr._arc(idx, int(tr.cut.a)) > 70.0 and tr._arc(idx, int(tr.cut.b)) > 70.0:
			return false
		var pc0 := tr.cut_at(x, z)
		if pc0.is_empty():
			return false
		var pj0 := tr.project(x, z, idx)
		if absf(float(pj0[1])) <= Game.HW + Game.KERB:
			return false                 # still on the road
		on_cut = true
		cut_i = pc0[0]
		cut_uses += 1
	var pc := tr.cut_project(x, z, cut_i)
	cut_i = pc[0]
	cut_along = pc[2]
	var la: float = pc[1]
	var near_end := cut_i < 30 or cut_i > m - 31
	if near_end:
		var pj := tr.project(x, z, int(tr.cut.a) + 12 if cut_i < m / 2 else int(tr.cut.b) - 12)
		var past := (cut_i == 0 and cut_along < 0.0) or (cut_i == m - 1 and cut_along > 0.0)
		if absf(float(pj[1])) < Game.HW or past:
			on_cut = false               # back on the road
			idx = pj[0]
			return false
	var lim := Track.CUT_W - Game.KART_R
	if absf(la) > lim:
		var sg := signf(la)
		var push := absf(la) - lim
		var cnx: float = -float(tr.cut.tz[cut_i])
		var cnz: float = float(tr.cut.tx[cut_i])
		x -= cnx * sg * push
		z -= cnz * sg * push
		var into := (sin(heading) * cnx + cos(heading) * cnz) * sg
		if into * speed > 0.0:
			var tang := tr.cut_heading(cut_i)
			var facing := tang if cos(Game.wrap_angle(heading - tang)) >= 0.0 else tang + PI
			heading += Game.wrap_angle(facing - heading) * 0.5
			var loss := absf(into)
			speed *= 1.0 - 0.55 * loss
			if bump_cd <= 0.0 and loss > 0.2 and absf(speed) > 4.0:
				bump_cd = 0.4
				race.on_bump(self, loss)
		la = sg * lim
	lat = la
	offroad = false
	var arc := tr.cut_arc(cut_i, cut_along)
	idx = int(arc / tr.step) % tr.n
	along = arc - idx * tr.step
	_count_lap(tr, arc)
	return true


## Heading of the way the kart is on (the road or the shortcut).
func way_heading() -> float:
	return race.track.cut_heading(cut_i) if on_cut else race.track.heading(idx)


## Height of the ground under the kart (road or shortcut).
func ground_y() -> float:
	return race.track.cut_ground(x, z, cut_i, cut_along) if on_cut else race.track.road_y(idx, lat, along)


# ================================================================== network
func pack(out: PackedFloat32Array, o: int) -> void:
	out[o] = x; out[o + 1] = z; out[o + 2] = heading; out[o + 3] = speed
	out[o + 4] = slip; out[o + 5] = steer; out[o + 6] = spin; out[o + 7] = spin_total
	out[o + 8] = hop; out[o + 9] = hop_max; out[o + 10] = hop_h; out[o + 11] = boost
	out[o + 12] = star
	out[o + 13] = drift_dir * (drift_level + 1) if drift_active else 0.0
	out[o + 14] = lap; out[o + 15] = s; out[o + 16] = rank; out[o + 17] = 1.0 if finished else 0.0
	out[o + 18] = finish_time; out[o + 19] = item * 10 + item_n; out[o + 20] = roulette
	out[o + 21] = last_lap; out[o + 22] = wrong_t
	out[o + 23] = (1 if offroad else 0) + (2 if braking else 0) + (4 if air else 0) + (8 if on_cut else 0)
	out[o + 24] = y; out[o + 25] = trick
	# the rest lets a Wi-Fi client carry on simulating its own kart from here
	out[o + 26] = vy; out[o + 27] = drift_charge; out[o + 28] = boost_mul; out[o + 29] = air_t
	out[o + 30] = invuln; out[o + 31] = bump_cd
	out[o + 32] = (1 if drift_prev else 0) + (2 if tricked else 0)
	out[o + 33] = ack
	out[o + 34] = shield; out[o + 35] = shrink


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
	air = fl & 4 != 0
	var was_cut := on_cut
	on_cut = fl & 8 != 0
	y = d[o + 24]; trick = d[o + 25]
	vy = d[o + 26]; drift_charge = d[o + 27]; boost_mul = d[o + 28]; air_t = d[o + 29]
	invuln = d[o + 30]; bump_cd = d[o + 31]
	var f2 := int(d[o + 32])
	drift_prev = f2 & 1 != 0
	tricked = f2 & 2 != 0
	ack = int(d[o + 33])
	shield = d[o + 34]; shrink = d[o + 35]
	last_s = s
	var tr := race.track
	if on_cut and not tr.cut.is_empty():
		var pc := tr.cut_project(x, z, cut_i if was_cut else -1)
		cut_i = pc[0]
		lat = pc[1]
		cut_along = pc[2]
		var arc := tr.cut_arc(cut_i, cut_along)
		idx = int(arc / tr.step) % tr.n
		along = arc - idx * tr.step
		return
	on_cut = false
	var pj := tr.project(x, z, idx)
	idx = pj[0]
	lat = pj[1]
	along = pj[2]


# ================================================================== visuals
func begin_tick() -> void:
	prev_x = x
	prev_z = z
	prev_h = heading
	prev_y = y


## Predicted kart: the host's state replaced ours. Shown where it was a
## moment ago, the difference eased away (or jumped at once when big).
func correct(dx: float, dy: float, dz: float, dh: float) -> void:
	prev_x += dx; prev_y += dy; prev_z += dz; prev_h += dh
	corr -= Vector3(dx, dy, dz)
	corr_h -= dh
	if corr.length() > CORR_SNAP:
		corr = Vector3.ZERO
		corr_h = 0.0


## alpha: physics interpolation fraction; smooth > 0 eases toward network state instead.
func render(delta: float, alpha: float, smooth: bool, t: float) -> void:
	var px: float
	var pz: float
	var ph: float
	var py: float
	if smooth:
		var k := 1.0 - exp(-14.0 * delta)
		vis_x = lerpf(vis_x, x, k)
		vis_z = lerpf(vis_z, z, k)
		vis_y = lerpf(vis_y, y, k)
		vis_h += Game.wrap_angle(heading - vis_h) * k
		if Vector2(vis_x - x, vis_z - z).length() > 12.0:
			vis_x = x; vis_z = z; vis_h = heading; vis_y = y
		px = vis_x; pz = vis_z; ph = vis_h; py = vis_y
	else:
		px = lerpf(prev_x, x, alpha)
		pz = lerpf(prev_z, z, alpha)
		py = lerpf(prev_y, y, alpha)
		ph = prev_h + Game.wrap_angle(heading - prev_h) * alpha
		if predicted:
			# a correction from the host is eased in over a fraction of a second
			var k := exp(-CORR_RATE * delta)
			corr *= k
			corr_h *= k
			px += corr.x; py += corr.y; pz += corr.z; ph += corr_h
	var mx := maxf(1.0, max_speed())
	var sr := clampf(absf(speed) / mx, 0.0, 1.5)
	yaw = ph - slip
	_orient(Vector3(px, py, pz), delta)
	body.position.y = hop_y()
	body.rotation.y = (1.0 - spin / spin_total) * PI * 4.0 if spin > 0.0 else 0.0
	# the trick: a full roll, quick at first and settling at the end
	var tu := 1.0 - trick / TRICK_TIME if trick > 0.0 else 0.0
	body.rotation.z = -TAU * (1.0 - pow(1.0 - tu, 2.0)) if trick > 0.0 else 0.0
	_suspension(delta, sr, py)
	chassis.position.y = susp_y + sin(t * 38.0 + driver) * 0.015 * sr
	chassis.rotation.x = pitch - (0.03 if boost > 0.0 else 0.0)
	chassis.rotation.z = (-drift_dir * 0.08 if drift_active else -steer * 0.05 * sr)
	for i in spins.size():
		spin_a[i] = fposmod(spin_a[i] + speed * delta / float(spin_r[i]), TAU)
		(spins[i] as Node3D).rotation.x = spin_a[i]
	for f in front:
		f.rotation.y = -steer * 0.45
	rig.update(self, delta, t)
	_render_flames(delta)
	if star > 0.0:
		for mt in glow_mats:
			mt.emission_enabled = true
			mt.emission = Color.from_hsv(star_hue, 1.0, 0.9)
			mt.emission_energy_multiplier = Gfx.boost()
	elif glow_mats[0].emission_enabled:
		for mt in glow_mats:
			mt.emission_enabled = false
	star_fx.emitting = star > 0.0
	if shield > 0.0 and bubble == null:
		bubble = MeshInstance3D.new()
		bubble.mesh = _shared().bubble
		bubble.material_override = _shared().bubblem
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.position = Vector3(0, 0.85, 0)
		add_child(bubble)
	if bubble != null:
		# blinks in its last two seconds
		bubble.visible = shield > 0.0 and (shield > 2.0 or fmod(t * 8.0, 1.0) < 0.6)
		if bubble.visible:
			bubble.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 5.0))
	var lvl := clampi(drift_level, 1, 3)
	for p in sparks:
		p.emitting = drift_active and drift_level > 0
		p.color = DRIFT_COLS[lvl - 1]
		p.scale_amount_min = 1.5 if drift_level == 3 else 1.0
		p.scale_amount_max = p.scale_amount_min
	var moving := absf(speed) > 8.0
	var on_road_slide := not offroad and not air and absf(speed) > 6.0 and (drift_active or spin > 0.0)
	for i in 2:
		wheel_dust[i].emitting = (offroad or on_cut) and moving and hop_y() < 0.2 and not air
		wheel_smoke[i].emitting = on_road_slide
	_render_skids()
	stars.visible = spin > 0.0
	if stars.visible:
		stars.rotation.y = t * 5.0
		stars.position.y = float(model.top) + 0.45 + hop_y()


## Stands the kart on the road surface (slope and bank); in the air the
## nose follows the flight, down as it falls.
func _orient(pos: Vector3, delta: float) -> void:
	var tr := race.track
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var want: Vector3
	if air:
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var fwd := Vector3(f.x, clampf(vy / maxf(absf(speed), 12.0), -0.6, 0.6) * 0.7, f.z).normalized()
		want = fwd.cross(right).normalized()
	else:
		want = tr.cut_normal(cut_i) if on_cut else tr.normal(idx, lat, along)
	vis_up = vis_up.lerp(want, 1.0 - exp(-(5.0 if air else 14.0) * delta)).normalized()
	var zf := (f - vis_up * f.dot(vis_up)).normalized()
	var b := Basis(vis_up.cross(zf), vis_up, zf)
	# the lightning shrinks the whole kart (driver, wheels, effects)
	vis_scale = Game.approach(vis_scale, Game.SHRINK_SCALE if shrink > 0.0 else 1.0, 2.5 * delta)
	transform = Transform3D(b.scaled_local(Vector3.ONE * vis_scale), pos)
	# the soft shadow spot stays on the ground while flying
	blob.position.y = 0.1 - (maxf(0.0, pos.y - ground_y()) if air else 0.0)


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
	var b := Gfx.boost()
	flame_mat.albedo_color = Color(col.r * b, col.g * b, col.b * b, 0.85)
	flame_fx.color = col
	boost_fx.color = col.lightened(0.4)
	# the flame bursts out long right after the turbo kicks in, then flickers
	var pulse := 1.0 + 0.9 * clampf(1.0 - boost_age / 0.35, 0.0, 1.0)
	var ex: Vector3 = model.exhaust
	for i in flames.size():
		var ln := (0.9 + randf() * 0.6) * pulse * 1.2
		var f: MeshInstance3D = flames[i]
		f.visible = true
		f.scale = Vector3(pulse, ln, pulse)
		f.position.z = ex.z - 0.5 * ln
		var c: MeshInstance3D = cores[i]
		c.visible = true
		c.scale = Vector3(1.0, ln * 0.8, 1.0)
		c.position.z = ex.z - 0.28 * ln


## Tyre marks from both rear wheels while drifting, braking hard or spinning.
func _render_skids() -> void:
	var skid := (drift_active or braking or spin > 0.0) and not offroad and not on_cut and not air and absf(speed) > 6.0 and hop_y() < 0.15
	var strength := 0.75 if braking and not drift_active else 1.0
	var rw: Dictionary = model.rear
	for i in 2:
		if not skid:
			skid_last[i] = null
			continue
		var wp := transform * Vector3(float(rw.x) * (-1.0 if i == 0 else 1.0), 0.0, float(rw.z))
		if skid_last[i] == null:
			skid_last[i] = wp
		elif wp.distance_to(skid_last[i]) >= SkidMarks.STEP:
			race.skids.add(skid_last[i], wp, strength, vis_up)
			skid_last[i] = wp


## Turbo just started: colour by what gave it (drift level 1–3, 0 = item or start) and a flash.
func on_boost(level: int) -> void:
	boost_col = DRIFT_COLS[level - 1] if level >= 1 and level <= 3 else FLAME_COL
	boost_age = 0.0
	var ex: Vector3 = model.exhaust
	Effects.flash(body, Vector3(0, ex.y, ex.z - 0.45), boost_col.lightened(0.3), 3.2, 0.3)


## Springy chassis: dips on landing, nods when speeding up or braking and
## rattles over grass, sand and snow, floats up a little over a crest and
## squats in a dip. Visual only, so it also works from network snapshots.
func _suspension(delta: float, sr: float, py: float) -> void:
	if delta <= 0.0:
		return
	var vy_now := (py - sus_py) / delta
	if not air and not was_air and absf(vy_now) < 40.0:
		susp_v -= clampf(vy_now - sus_vy, -3.0, 3.0) * 0.35
	sus_py = py
	sus_vy = vy_now
	if prev_hop > 0.0 and hop <= 0.0:   # just landed
		susp_v -= 0.9 + 1.1 * clampf(hop_h, 0.0, 2.5)
	prev_hop = hop
	if was_air and not air:              # down from a jump
		susp_v -= 1.2 + clampf(land_v, 0.0, 14.0) * 0.16
	was_air = air
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
