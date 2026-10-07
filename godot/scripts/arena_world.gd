class_name ArenaWorld
extends RefCounted
## Builds what you see in a battle arena (Etapa H): sky and weather
## (Atmosphere), the land around, the paved or snowy floor, the wall around
## it, the fountain and planters or the ice and snow banks, the ramps, the
## item boxes, the houses or stands with fans around, and the podium just
## outside the wall for the winners.

const FACADES := ["e9c46a", "f4a261", "e76f51", "a8dadc", "f1faee", "dda15e", "b5838d", "cdb4db", "90be6d"]
const ROOF := Color("8e3b2a")
const STONE := Color("cfc6b8")


static func build(ar: Arena) -> Dictionary:
	var th: Dictionary = ar.def.theme
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ar.def.seed)
	var root := Node3D.new()
	root.name = "Arena"
	var atm := Atmosphere.build(root, ar, th)
	root.add_child(_land(th, rng))
	root.add_child(_floor(ar, th, rng))
	if not ar.ice.is_empty():
		_ice(root, ar, th)
	var kit := MeshKit.new()
	_edge_wall(kit, ar, th)
	for c in ar.circles:
		if float(c.r) >= 5.0:
			_fountain(root, kit, c, th)
		else:
			_planter(kit, c)
	for c in ar.caps:
		if c.has("ramp"):
			continue                             # a ramp's side: the ramp itself shows it
		if ar.round_shape:
			_snow_bank(kit, c)
		else:
			_low_wall(kit, c, th)
	var ts := {"lights": null, "spin": [], "spots": {}, "podium": {}}
	var cloth := Trackside.Cloth.new()
	var crowd: Array = []
	if ar.round_shape:
		_stands(root, ar, th, rng, crowd, cloth)
		_floodlights(kit, ar)
	else:
		_houses(kit, ar, rng)
		_fans(ar, rng, crowd)
	var props := MeshInstance3D.new()
	props.mesh = kit.commit()
	root.add_child(props)
	for r in ar.ramps:
		root.add_child(_ramp(r))
	# the podium just outside the wall, facing in (south side)
	var n := Vector3(0, 0, -1)
	var f := Transform3D(Basis(n, Vector3.UP, n.cross(Vector3.UP)), Vector3(0, 0, -(ar.half + 3.0)))
	Trackside._build_podium(root, f, ts, cloth)
	# item boxes
	var boxes: Array = []
	var box_mat := WorldBuilder.box_material()
	atm.box_mat = box_mat
	for i in ar.boxes.size():
		var p: Vector2 = ar.boxes[i]
		boxes.append(WorldBuilder.item_box(root, Vector3(p.x, 1.4, p.y), box_mat, i * 0.7))
	for group in crowd:
		if not (group as Array).is_empty():
			root.add_child(Trackside._crowd(group))
	if not cloth.v.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = cloth.commit()
		mi.material_override = Trackside._material("cloth", Trackside.CLOTH_SHADER)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return {"root": root, "boxes": boxes, "atm": atm, "trackside": ts}


# ------------------------------------------------------------------ ground
static func _speckle(base: Color, a: Color, b: Color, rng: RandomNumberGenerator, size := 256, count := 2600) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for i in count:
		var c: Color = a if i % 2 == 1 else b
		var s := 1 + rng.randi() % 3
		img.fill_rect(Rect2i(rng.randi() % size, rng.randi() % size, s, s * (1 + rng.randi() % 3)),
			base.lerp(c, 0.35 + rng.randf() * 0.45))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _land(th: Dictionary, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _speckle(th.ground, th.ground2, th.ground3, rng)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_scale = Vector3(WorldBuilder.GROUND / 40.0, WorldBuilder.GROUND / 40.0, 1.0)
	mat.roughness = 1.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(WorldBuilder.GROUND, WorldBuilder.GROUND)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = -0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Paving stones in staggered rows (square) or packed snow (stadium), one
## texture repeat every 4 m.
static func _floor_texture(ar: Arena, th: Dictionary, rng: RandomNumberGenerator) -> ImageTexture:
	var a: Color = th.floor
	var b: Color = th.floor2
	if ar.round_shape:
		return _speckle(a, b, a.lightened(0.3), rng, 128, 700)
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(b.darkened(0.25))
	var rows := 8
	var cols := 6
	for r in rows:
		var off := (r % 2) * 64 / cols
		for c in cols + 1:
			var x0 := c * 128 / cols - off
			var col := a.lerp(b, rng.randf()).lerp(Color.WHITE, rng.randf() * 0.08)
			img.fill_rect(Rect2i(maxi(0, x0 + 1), r * 16 + 1, mini(128 / cols - 2, 128 - maxi(0, x0 + 1)), 14), col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _floor(ar: Arena, th: Dictionary, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _floor_texture(ar, th, rng)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := ar.outline(3.0)
	var c := Vector3(ar.cx, 0.01, ar.cz)
	for i in pts.size() - 1:
		var p0 := Vector3(pts[i].x, 0.01, pts[i].y)
		var p1 := Vector3(pts[i + 1].x, 0.01, pts[i + 1].y)
		# wound to face up whichever way the outline runs
		var tri := [c, p0, p1] if (p0 - c).cross(p1 - c).y < 0.0 else [c, p1, p0]
		for v in tri:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) / 4.0)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The ice in the middle of the stadium: the frozen-lake look, a blue rim
## and a red centre circle like a hockey rink.
static func _ice(root: Node3D, ar: Arena, th: Dictionary) -> void:
	var r := float(ar.ice.r)
	var rim := WorldBuilder._disc(r + 0.7, Color("2a7de1"), 0.02, false)
	rim.position = Vector3(float(ar.ice.x), 0.0, float(ar.ice.z))
	root.add_child(rim)
	var ice := WorldBuilder._disc(r, Color("cfeaf7"), 0.035, true)
	ice.position = rim.position
	(ice.get_child(0) as MeshInstance3D).material_override = Trackside.lake_material(Color("bfe3f5"), th.mood.horizon, true)
	root.add_child(ice)
	for spot in [[6.0, 5.4, Color("e63946")], [1.2, 0.0, Color("e63946")]]:
		var ring := WorldBuilder._disc(float(spot[0]), spot[2], 0.05, false)
		ring.position = rim.position
		root.add_child(ring)
		if float(spot[1]) > 0.0:
			var hole := WorldBuilder._disc(float(spot[1]), Color("cfeaf7"), 0.055, true)
			hole.position = rim.position
			(hole.get_child(0) as MeshInstance3D).material_override = (ice.get_child(0) as MeshInstance3D).material_override
			root.add_child(hole)


# ------------------------------------------------------------------ solid parts
## A wall along the whole edge: stone with a darker cap on the square,
## white boards with a blue band in the stadium.
static func _edge_wall(kit: MeshKit, ar: Arena, th: Dictionary) -> void:
	var pts := ar.outline(4.0)
	var h := 1.2 if ar.round_shape else 1.4
	var thick := 1.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var ln := d.length()
		if ln < 0.01:
			continue
		var n := Vector2(d.y, -d.x) / ln
		var mid := (a + b) * 0.5
		if n.dot(mid - Vector2(ar.cx, ar.cz)) < 0.0:
			n = -n
		var yaw := atan2(-d.y, d.x)
		var o := mid + n * thick * 0.5
		if ar.round_shape:
			kit.rbox(MeshKit.at(Vector3(o.x, h * 0.5, o.y), Vector3(0, yaw, 0)), Vector3(ln + 0.06, h, thick), 0.0,
				th.wall, MeshKit.SATIN, 0)
			kit.rbox(MeshKit.at(Vector3(o.x, h * 0.75, o.y), Vector3(0, yaw, 0)), Vector3(ln + 0.07, 0.3, thick + 0.04), 0.0,
				th.trim, MeshKit.GLOSS, 0)
			kit.rbox(MeshKit.at(Vector3(o.x, 0.08, o.y), Vector3(0, yaw, 0)), Vector3(ln + 0.07, 0.16, thick + 0.04), 0.0,
				Color("f4c430"), MeshKit.GLOSS, 0)
		else:
			kit.rbox(MeshKit.at(Vector3(o.x, h * 0.5, o.y), Vector3(0, yaw, 0)), Vector3(ln + 0.06, h, thick), 0.0,
				th.wall, MeshKit.MATTE, 0)
			kit.rbox(MeshKit.at(Vector3(o.x, h + 0.08, o.y), Vector3(0, yaw, 0)), Vector3(ln + 0.1, 0.16, thick + 0.3), 0.0,
				th.trim, MeshKit.SATIN, 0)


## The fountain in the middle of the square: a round basin full of water,
## a pillar with a bowl and water spraying from the top.
static func _fountain(root: Node3D, kit: MeshKit, c: Dictionary, th: Dictionary) -> void:
	var p := Vector3(float(c.x), 0.0, float(c.z))
	var r := float(c.r)
	var id := MeshKit.at(Vector3.ZERO)
	kit.tube(id, p, p + Vector3(0, 0.7, 0), r, STONE, MeshKit.MATTE, 32)
	var seg := 28
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		kit.tube(id, p + Vector3(sin(a0) * r, 0.85, cos(a0) * r), p + Vector3(sin(a1) * r, 0.85, cos(a1) * r), 0.3,
			STONE.lightened(0.15), MeshKit.SATIN, 6)
	kit.tube(id, p + Vector3(0, 0.7, 0), p + Vector3(0, 2.4, 0), 1.0, STONE, MeshKit.SATIN, 16, 0.7)
	kit.tube(id, p + Vector3(0, 2.4, 0), p + Vector3(0, 2.8, 0), 0.8, STONE.lightened(0.1), MeshKit.SATIN, 18, 2.6)
	kit.tube(id, p + Vector3(0, 2.8, 0), p + Vector3(0, 4.0, 0), 0.35, STONE, MeshKit.SATIN, 12)
	kit.sphere(MeshKit.at(p + Vector3(0, 4.2, 0)), Vector3(0.45, 0.45, 0.45), Color("d4a017"), MeshKit.CHROME, 12, 6)
	var water := WorldBuilder._disc(r - 0.3, Color("4aa3df"), 0.0, true)
	water.position = p + Vector3(0, 0.74, 0)
	(water.get_child(0) as MeshInstance3D).material_override = Trackside.lake_material(Color("3d9be0"), th.mood.horizon, false)
	root.add_child(water)
	var spray := CPUParticles3D.new()
	spray.mesh = Kart.particle_mesh(0.35, false)
	spray.amount = Gfx.amount(60)
	spray.lifetime = 1.3
	spray.position = p + Vector3(0, 4.3, 0)
	spray.direction = Vector3.UP
	spray.spread = 28.0
	spray.initial_velocity_min = 4.0
	spray.initial_velocity_max = 5.5
	spray.gravity = Vector3(0, -9.0, 0)
	spray.color = Color(0.85, 0.94, 1.0, 0.7)
	spray.color_ramp = Kart.fade_ramp()
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(spray)


## A round stone planter with a small tree.
static func _planter(kit: MeshKit, c: Dictionary) -> void:
	var p := Vector3(float(c.x), 0.0, float(c.z))
	var r := float(c.r)
	var id := MeshKit.at(Vector3.ZERO)
	kit.tube(id, p, p + Vector3(0, 0.9, 0), r, STONE, MeshKit.MATTE, 18)
	kit.tube(id, p + Vector3(0, 0.9, 0), p + Vector3(0, 0.95, 0), r - 0.25, Color("5b3f2a"), MeshKit.MATTE, 18)
	kit.tube(id, p + Vector3(0, 0.9, 0), p + Vector3(0, 3.2, 0), 0.22, Color("6b4a33"), MeshKit.MATTE, 8)
	kit.sphere(MeshKit.at(p + Vector3(0, 4.0, 0)), Vector3(2.0, 1.7, 2.0), Color("3f8f3a"), MeshKit.MATTE, 10, 6)


## A low wall in the square: a rounded stone block with a darker cap.
static func _low_wall(kit: MeshKit, c: Dictionary, th: Dictionary) -> void:
	var a := Vector3(float(c.x0), 0.0, float(c.z0))
	var b := Vector3(float(c.x1), 0.0, float(c.z1))
	var d := b - a
	var r := float(c.r)
	var yaw := atan2(-d.z, d.x)
	var mid := (a + b) * 0.5
	kit.rbox(MeshKit.at(mid + Vector3(0, 0.45, 0), Vector3(0, yaw, 0)), Vector3(d.length() + r * 2.0, 0.9, r * 2.0), 0.25,
		th.wall, MeshKit.MATTE, 2)
	kit.rbox(MeshKit.at(mid + Vector3(0, 0.95, 0), Vector3(0, yaw, 0)), Vector3(d.length() + r * 2.0 + 0.1, 0.14, r * 2.0 + 0.2),
		0.05, th.trim, MeshKit.SATIN, 1)


## A snow bank in the stadium: a long white mound and a few lumps.
static func _snow_bank(kit: MeshKit, c: Dictionary) -> void:
	var a := Vector3(float(c.x0), 0.0, float(c.z0))
	var b := Vector3(float(c.x1), 0.0, float(c.z1))
	var d := b - a
	var r := float(c.r)
	var yaw := atan2(-d.z, d.x)
	var mid := (a + b) * 0.5
	var snow := Color("f7fbff")
	kit.sphere(MeshKit.at(mid, Vector3(0, yaw, 0)), Vector3(d.length() * 0.5 + r, 2.0, r), snow, MeshKit.MATTE, 18, 8)
	for e in [-0.35, 0.3]:
		kit.sphere(MeshKit.at(mid + d * float(e) + Vector3(0, 1.3, 0), Vector3(0, yaw, 0)), Vector3(r * 0.9, 1.1, r * 0.7),
			snow.darkened(0.03), MeshKit.MATTE, 12, 6)


## A ramp: a wedge in yellow and black stripes, the lip at the far end.
static func _ramp(r: Dictionary) -> MeshInstance3D:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for yy in 32:
		for xx in 32:
			img.set_pixel(xx, yy, Color("ffc21a") if (xx + yy) % 32 < 16 else Color("1d1f26"))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ln := float(r.len)
	var hw := float(r.w) * 0.5
	var top := float(r.top)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# local: x across, z along (0 at the low end), y up
	var p := func(x: float, a: float, y: float) -> Vector3:
		return Vector3(x, y, a - ln * 0.5)
	var quad := func(qa: Vector3, qb: Vector3, qc: Vector3, qd: Vector3, uv: Array) -> void:
		var nrm := (qd - qa).cross(qb - qa).normalized()
		var vs := [qa, qb, qc, qa, qc, qd]
		var us := [uv[0], uv[1], uv[2], uv[0], uv[2], uv[3]]
		for i in 6:
			st.set_normal(nrm)
			st.set_uv(us[i])
			st.add_vertex(vs[i])
	var w3 := hw * 2.0 / 3.0
	quad.call(p.call(hw, 0.0, 0.04), p.call(hw, ln, top), p.call(-hw, ln, top), p.call(-hw, 0.0, 0.04),
		[Vector2(w3, 0), Vector2(w3, ln / 3.0), Vector2(0, ln / 3.0), Vector2(0, 0)])
	# the lip
	quad.call(p.call(hw, ln, 0.0), p.call(-hw, ln, 0.0), p.call(-hw, ln, top), p.call(hw, ln, top),
		[Vector2(w3, 0), Vector2(0, 0), Vector2(0, 0.45), Vector2(w3, 0.45)])
	# the sides (triangles)
	for sx in [-hw, hw]:
		var a: Vector3 = p.call(sx, 0.0, 0.0)
		var b: Vector3 = p.call(sx, ln, 0.0)
		var c: Vector3 = p.call(sx, ln, top)
		var tri := [a, b, c] if sx > 0.0 else [a, c, b]
		var nrm := Vector3(signf(sx), 0, 0)
		for v in tri:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.z / 3.0, v.y / 3.0))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = Vector3(float(r.x), 0.0, float(r.z))
	mi.rotation.y = float(r.h)
	return mi


# ------------------------------------------------------------------ around
## Houses all around the square, pastel fronts with rows of windows, a town
## hall with a clock tower on the north side; the south side stays open
## for the podium.
static func _houses(kit: MeshKit, ar: Arena, rng: RandomNumberGenerator) -> void:
	var back := ar.half + 14.0
	var hall := false
	for side in 4:
		var a := side * PI * 0.5
		var n := Vector3(sin(a), 0, cos(a))      # outwards
		var t := Vector3(n.z, 0, -n.x)          # along the row
		var yaw := atan2(-t.z, t.x)
		var x := -ar.half - 4.0
		while x < ar.half + 4.0:
			var w := rng.randf_range(9.0, 13.0)
			var mid := x + w * 0.5
			x += w + 0.3
			if side == 2 and absf(mid) < 16.0:
				continue                         # the podium's place (south)
			var h := rng.randf_range(10.0, 15.0)
			var depth := 10.0
			var o := n * (back + depth * 0.5) + t * mid
			var col := Color(FACADES[rng.randi() % FACADES.size()])
			if side == 0 and absf(mid) - w * 0.5 < 8.5:
				if not hall:
					hall = true
					_town_hall(kit, n * (back + depth * 0.5), yaw, n)
				continue
			kit.rbox(MeshKit.at(o + Vector3(0, h * 0.5, 0), Vector3(0, yaw, 0)), Vector3(w, h, depth), 0.0, col, MeshKit.MATTE, 0)
			kit.rbox(MeshKit.at(o + Vector3(0, h + 0.15, 0), Vector3(0, yaw, 0)), Vector3(w + 0.4, 0.3, depth + 0.4), 0.0,
				col.darkened(0.25), MeshKit.SATIN, 0)
			# a gable roof: two slabs leaning together
			for s: float in [-1.0, 1.0]:
				var rp := o + Vector3(0, h + 1.6, 0) + n * s * depth * 0.25
				kit.rbox(MeshKit.at(rp, Vector3(0, yaw, 0)) * MeshKit.at(Vector3.ZERO, Vector3(s * 0.55, 0, 0)),
					Vector3(w + 0.2, 0.25, depth * 0.62), 0.0, ROOF, MeshKit.SATIN, 0)
			# windows on the side facing the square, a door on the ground floor
			var face := o - n * (depth * 0.5 + 0.02)
			var cols := maxi(2, int(w / 3.2))
			var floors := int((h - 3.5) / 3.0) + 1
			for fl in floors:
				for c in cols:
					var u := (c + 0.5) / cols - 0.5
					var wp := face + t * u * (w - 2.0) + Vector3(0, 4.2 + fl * 3.0, 0)
					kit.rbox(MeshKit.at(wp, Vector3(0, yaw, 0)), Vector3(1.1, 1.5, 0.12), 0.0, Color("2b3a55"), MeshKit.GLOSS, 0)
			kit.rbox(MeshKit.at(face + Vector3(0, 1.3, 0), Vector3(0, yaw, 0)), Vector3(1.6, 2.6, 0.14), 0.0,
				Color("5b3a29"), MeshKit.SATIN, 0)


static func _town_hall(kit: MeshKit, o: Vector3, yaw: float, n: Vector3) -> void:
	var stone := Color("e8dcc4")
	kit.rbox(MeshKit.at(o + Vector3(0, 8, 0), Vector3(0, yaw, 0)), Vector3(16, 16, 12), 0.0, stone, MeshKit.MATTE, 0)
	kit.rbox(MeshKit.at(o + Vector3(0, 21, 0), Vector3(0, yaw, 0)), Vector3(6, 26, 6), 0.0, stone.darkened(0.05), MeshKit.MATTE, 0)
	kit.rbox(MeshKit.at(o + Vector3(0, 35.5, 0), Vector3(0, yaw, 0)), Vector3(4.4, 3.0, 4.4), 0.0, Color("3f6e4a"), MeshKit.SATIN, 0)
	kit.tube(MeshKit.at(Vector3.ZERO), o + Vector3(0, 37, 0), o + Vector3(0, 41.5, 0), 2.4, Color("3f6e4a"), MeshKit.SATIN, 8, 0.05)
	var clock := o - n * 3.05 + Vector3(0, 28, 0)
	var face := Transform3D(Basis.looking_at(-n, Vector3.UP, true), clock)
	kit.disc(face, 1.7, Color.WHITE, MeshKit.GLOSS, 24)
	kit.rbox(face * MeshKit.at(Vector3(0, 0.55, 0.05)), Vector3(0.16, 1.2, 0.05), 0.0, Color("1d1f26"), MeshKit.GLOSS, 0)
	kit.rbox(face * MeshKit.at(Vector3(0.4, 0, 0.06), Vector3(0, 0, 1.2)), Vector3(0.14, 0.9, 0.05), 0.0, Color("1d1f26"),
		MeshKit.GLOSS, 0)


## People standing along the outside of the wall, cheering.
static func _fans(ar: Arena, rng: RandomNumberGenerator, crowd: Array) -> void:
	var people: Array = []
	crowd.append(people)
	var pts := ar.outline(1.1)
	var dens := Gfx.crowd() * 0.8
	for i in pts.size() - 1:
		if rng.randf() > dens:
			continue
		var p := pts[i]
		var out := (p - Vector2(ar.cx, ar.cz)).normalized()
		if p.y < -ar.half + 1.0 and absf(p.x) < 16.0:
			continue                             # in front of the podium
		for row in 2:
			var q := p + out * (2.0 + row * 1.2 + rng.randf() * 0.4)
			var face := Vector3(-out.x, 0, -out.y)
			var c := Color(Trackside.SHIRTS[rng.randi() % Trackside.SHIRTS.size()])
			people.append([Transform3D(Basis.looking_at(face, Vector3.UP, true), Vector3(q.x, 0.0, q.y)),
				Color(c.r, c.g, c.b, rng.randf())])


## Stands with fans all around the rink (leaving the podium's place free).
static func _stands(root: Node3D, ar: Arena, th: Dictionary, rng: RandomNumberGenerator, crowd: Array,
		cloth: Trackside.Cloth) -> void:
	var count := 7
	for k in count:
		var a := PI + (k + 1) * TAU / (count + 1)
		var away := Vector3(sin(a), 0, cos(a))
		var f := Transform3D(Basis(away, Vector3.UP, away.cross(Vector3.UP)), away * (ar.half + 1.5))
		var kit := MeshKit.new()
		var fans: Array = []
		crowd.append(fans)
		Trackside._stand(kit, f, 30.0, th, rng, fans, cloth)
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		root.add_child(mi)


## Four floodlight masts around the stadium.
static func _floodlights(kit: MeshKit, ar: Arena) -> void:
	for k in 4:
		var a := (k + 0.5) * TAU / 4.0
		var p := Vector3(sin(a), 0, cos(a)) * (ar.half + 16.0)
		kit.tube(MeshKit.at(Vector3.ZERO), p, p + Vector3(0, 26, 0), 0.45, Color("9aa3b0"), MeshKit.SATIN, 8, 0.3)
		var face := Transform3D(Basis.looking_at(-p.normalized(), Vector3.UP, true), p + Vector3(0, 27, 0))
		kit.rbox(face, Vector3(5.0, 3.0, 0.6), 0.1, Color("6c7480"), MeshKit.SATIN, 1)
		for i in 3:
			for j in 2:
				kit.rbox(face * MeshKit.at(Vector3(-1.6 + i * 1.6, -0.7 + j * 1.4, 0.32)), Vector3(1.2, 1.0, 0.1), 0.0,
					Color("fffbe8"), MeshKit.LIGHT, 0)
