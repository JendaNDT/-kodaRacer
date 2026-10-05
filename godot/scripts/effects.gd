class_name Effects
extends RefCounted
## One-off visual effects built from code: rocket explosions, item box shards,
## finish confetti and the stars circling a driver after a hit. Particle counts
## follow the graphics quality (Gfx.amount).

const RAINBOW := [Color("ff4d6d"), Color("ffb703"), Color("8ac926"), Color("1982c4"), Color("9b5de5"), Color("ffffff")]

static var _c := {}


static func _shared() -> Dictionary:
	if not _c.is_empty():
		return _c
	# soft ring for shock waves
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for yy in 64:
		for xx in 64:
			var d := Vector2(xx - 31.5, yy - 31.5).length() / 32.0
			var a := clampf(1.0 - absf(d - 0.8) / 0.2, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(1, 1, 1, a * a))
	_c.ring = ImageTexture.create_from_image(img)
	_c.star = _star_mesh(0.27, 0.11)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("ffd43b")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_c.star_mat = sm
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.3, 0.2, 0.36)
	chunk.material = _vc_mat(false)
	_c.chunk = chunk
	var shard := PrismMesh.new()
	shard.size = Vector3(0.55, 0.55, 0.08)
	shard.material = _vc_mat(true)
	_c.shard = shard
	var bit := QuadMesh.new()
	bit.size = Vector2(0.2, 0.3)
	bit.material = _vc_mat(true)
	_c.bit = bit
	_c.rainbow = _palette(RAINBOW)                 # confetti (with white)
	_c.box_cols = _palette(RAINBOW.slice(0, 5))    # item box glass
	var late := Gradient.new()
	late.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	late.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_c.late_fade = late
	return _c


## Vertex-coloured material for particle meshes (colour and fade come from the emitter).
static func _vc_mat(unshaded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	m.disable_fog = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 1.0
	m.distance_fade_max_distance = 3.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Gradient that hands every particle one of the colours (no blending).
static func _palette(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / cols.size())
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	return g


static func _star_mesh(outer: float, inner: float) -> ArrayMesh:
	var pts: Array = []
	for i in 10:
		var a := PI / 2.0 + i * TAU / 10.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	var verts := PackedVector3Array()
	for i in 10:
		verts.append_array(PackedVector3Array([Vector3.ZERO, pts[(i + 1) % 10], pts[i]]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(1.0, maxf(a, b))
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


## A one-shot particle burst; _launch() adds it once it is fully set up.
static func _emitter(pos: Vector3, mesh: Mesh, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = Gfx.amount(amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.color_ramp = Kart.fade_ramp()
	return p


## Adds a burst to the scene, fires it and frees it when it is done.
static func _launch(parent: Node3D, p: CPUParticles3D) -> void:
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


## Billboard light that pops up and fades (turbo start, explosion core).
static func flash(parent: Node3D, pos: Vector3, color: Color, size: float, dur: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Kart._shared().dot
	m.albedo_color = color
	m.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * size * 0.3
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Flat ring that races outwards along the ground.
static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius: float, dur: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _shared().ring
	m.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * 0.4
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Rocket hit: flash, shock wave, fire, rising smoke and flying debris.
static func explosion(parent: Node3D, pos: Vector3) -> void:
	flash(parent, pos + Vector3(0, 1.2, 0), Color(1.0, 0.78, 0.4), 9.0, 0.35)
	shockwave(parent, Vector3(pos.x, 0.3, pos.z), Color(1.0, 0.72, 0.4), 12.0, 0.6)
	var fire := _emitter(pos + Vector3(0, 1.0, 0), Kart.particle_mesh(1.5, true), 30, 0.6)
	fire.spread = 180.0
	fire.initial_velocity_min = 5.0
	fire.initial_velocity_max = 11.0
	fire.damping_min = 6.0
	fire.damping_max = 10.0
	fire.gravity = Vector3(0, 2, 0)
	var fr := Gradient.new()
	fr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	fr.colors = PackedColorArray([Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.12), Color(0.6, 0.12, 0.05, 0.0)])
	fire.color_ramp = fr
	_launch(parent, fire)
	var smoke := _emitter(pos + Vector3(0, 1.2, 0), Kart.particle_mesh(2.6, false), 14, 1.8)
	smoke.emission_sphere_radius = 1.2
	smoke.spread = 60.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 1.6, 0)
	smoke.color = Color(0.32, 0.32, 0.34, 0.75)
	smoke.scale_amount_curve = _curve(0.5, 1.8)
	_launch(parent, smoke)
	var debris := _emitter(pos + Vector3(0, 0.8, 0), _shared().chunk, 14, 1.1)
	debris.spread = 70.0
	debris.initial_velocity_min = 7.0
	debris.initial_velocity_max = 13.0
	debris.gravity = Vector3(0, -24, 0)
	debris.angular_velocity_min = -720.0
	debris.angular_velocity_max = 720.0
	debris.angle_max = 360.0
	debris.particle_flag_rotate_y = true
	debris.scale_amount_min = 0.6
	debris.scale_amount_max = 1.4
	debris.color = Color(0.2, 0.2, 0.22)
	debris.color_ramp = _shared().late_fade
	_launch(parent, debris)


## Item box picked up: it bursts into rainbow shards.
static func box_shards(parent: Node3D, pos: Vector3) -> void:
	flash(parent, pos, Color(1.0, 0.9, 0.7), 4.0, 0.25)
	var p := _emitter(pos, _shared().shard, 18, 0.9)
	p.emission_sphere_radius = 0.7
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -18, 0)
	p.angular_velocity_min = -900.0
	p.angular_velocity_max = 900.0
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color_initial_ramp = _shared().box_cols
	p.color_ramp = _shared().late_fade
	_launch(parent, p)


## Finish: a puff of paper confetti shot into the air.
static func confetti_burst(parent: Node3D, pos: Vector3) -> void:
	var p := _emitter(pos + Vector3(0, 1.5, 0), _shared().bit, 70, 3.0)
	p.spread = 35.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 13.0
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	p.color_initial_ramp = _shared().rainbow
	p.color_ramp = _shared().late_fade
	_launch(parent, p)


## Confetti raining around a kart for a few seconds. It moves with the kart,
## which keeps driving at full speed after the finish line.
static func confetti_shower(kart: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _shared().bit
	p.amount = Gfx.amount(80)
	p.lifetime = 2.6
	p.local_coords = true
	p.position = Vector3(0, 6.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.0, 0.5, 5.0)
	p.direction = Vector3.DOWN
	p.spread = 30.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -3.5, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	p.color_initial_ramp = _shared().rainbow
	p.color_ramp = _shared().late_fade
	kart.add_child(p)
	p.emitting = true
	var tree := kart.get_tree()
	tree.create_timer(4.5).timeout.connect(func(): p.emitting = false)
	tree.create_timer(9.0).timeout.connect(p.queue_free)


## Little stars that circle above a driver's head after a hit.
static func hit_stars() -> Node3D:
	var g := Node3D.new()
	for i in 5:
		var a := i * TAU / 5.0
		var mi := MeshInstance3D.new()
		mi.mesh = _shared().star
		mi.material_override = _shared().star_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * 0.8, 0.0, sin(a) * 0.8)
		g.add_child(mi)
	g.visible = false
	return g
