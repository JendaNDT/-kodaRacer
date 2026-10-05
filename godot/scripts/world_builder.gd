class_name WorldBuilder
extends RefCounted
## Builds everything you see around a track: ground, road, kerbs, tyre
## barriers, start gantry, item boxes and themed scenery. Sky, sun, fog,
## clouds and weather come from Atmosphere.

const GROUND := 3600.0


static func build(tr: Track) -> Dictionary:
	var th: Dictionary = tr.def.theme
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tr.def.seed)
	var root := Node3D.new()
	root.name = "World"

	# --- sky, sun, fog, clouds and weather
	var atm := Atmosphere.build(root, tr, th)

	# --- ground
	var gimg := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	gimg.fill(th.ground)
	for i in 2600:
		var c: Color = th.ground2 if i % 2 == 1 else th.ground3
		var s := 1 + rng.randi() % 3
		var rect := Rect2i(rng.randi() % 256, rng.randi() % 256, s, s * (1 + rng.randi() % 3))
		gimg.fill_rect(rect, Color(th.ground).lerp(c, 0.35 + rng.randf() * 0.45))
	gimg.generate_mipmaps()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = ImageTexture.create_from_image(gimg)
	gmat.uv1_scale = Vector3(GROUND / 24.0, GROUND / 24.0, 1.0)
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	gmat.roughness = 1.0
	var gplane := PlaneMesh.new()
	gplane.size = Vector2(GROUND, GROUND)
	gplane.material = gmat
	var ground := MeshInstance3D.new()
	ground.mesh = gplane
	ground.position = Vector3(tr.cx, 0.0, tr.cz)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)

	# --- lake in the infield where there is room
	tr.lake = {}
	if th.lake != null:
		var bx := 0.0
		var bz := 0.0
		var bd := 0.0
		var gx := tr.min_x
		while gx <= tr.max_x:
			var gz := tr.min_z
			while gz <= tr.max_z:
				if tr.inside(gx, gz):
					var d := tr.min_dist(gx, gz)
					if d > bd:
						bd = d
						bx = gx
						bz = gz
				gz += 16.0
			gx += 16.0
		var r := minf(70.0, bd - Game.BAR - 8.0)
		if r > 12.0:
			var shore := _disc(r + 3.0, Color(th.ground2), 0.02, false)
			shore.position = Vector3(bx, 0.0, bz)
			root.add_child(shore)
			var lake := _disc(r, th.lake, 0.035, true)
			lake.position = Vector3(bx, 0.0, bz)
			root.add_child(lake)
			tr.lake = {"x": bx, "z": bz, "r": r + 3.0}

	# --- road and kerbs
	var road_col: Color = th.road
	var rimg := Image.create_empty(128, 256, false, Image.FORMAT_RGBA8)
	rimg.fill(road_col)
	for i in 1800:
		var l := 1.0 if rng.randf() < 0.5 else 0.0
		var a := 0.03 + rng.randf() * 0.07
		rimg.fill_rect(Rect2i(rng.randi() % 128, rng.randi() % 256, 1 + rng.randi() % 2, 1 + rng.randi() % 2),
			road_col.lerp(Color(l, l, l), a))
	rimg.fill_rect(Rect2i(31, 0, 13, 256), road_col.darkened(0.1))
	rimg.fill_rect(Rect2i(84, 0, 13, 256), road_col.darkened(0.1))
	rimg.fill_rect(Rect2i(4, 0, 3, 256), Color.WHITE.lerp(road_col, 0.12))
	rimg.fill_rect(Rect2i(121, 0, 3, 256), Color.WHITE.lerp(road_col, 0.12))
	rimg.generate_mipmaps()
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_texture = ImageTexture.create_from_image(rimg)
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_mat.roughness = 0.9
	var road := MeshInstance3D.new()
	road.mesh = ribbon(tr, -Game.HW, Game.HW, 0.04, 14.0)
	road.material_override = road_mat
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(road)

	var kimg := Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	kimg.fill_rect(Rect2i(0, 0, 4, 1), th.kerb_a)
	kimg.fill_rect(Rect2i(0, 1, 4, 1), th.kerb_b)
	var kmat := StandardMaterial3D.new()
	kmat.albedo_texture = ImageTexture.create_from_image(kimg)
	kmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	kmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [1.0, -1.0]:
		var k := MeshInstance3D.new()
		var o0: float = Game.HW if side > 0.0 else -Game.HW - Game.KERB
		var o1: float = Game.HW + Game.KERB if side > 0.0 else -Game.HW
		k.mesh = ribbon(tr, o0, o1, 0.065, 6.0)
		k.material_override = kmat
		k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(k)

	# --- start line and gantry
	root.add_child(_start_gantry(tr))

	# --- tyre barriers, skipping spots that would fold into the road
	var tyre_xf: Array = []
	var tyre_cols: Array = []
	for side in [-1.0, 1.0]:
		var d := 0.0
		while d < tr.length:
			var i := int(d / tr.step) % tr.n
			var off: float = side * (Game.BAR + 0.7)
			var px := tr.x[i] + tr.nx[i] * off
			var pz := tr.z[i] + tr.nz[i] * off
			if not tr.near(px, pz, Game.BAR - 0.2):
				tyre_xf.append(Transform3D(Basis.IDENTITY, Vector3(px, 0.62, pz)))
				tyre_cols.append(th.kerb_a if (tyre_cols.size() / 2) % 2 == 1 else th.kerb_b)
			d += 2.3
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = 0.75
	tyre_mesh.bottom_radius = 0.75
	tyre_mesh.height = 1.25
	tyre_mesh.radial_segments = 10
	tyre_mesh.rings = 1
	root.add_child(_multi(tyre_mesh, _vc_mat(), tyre_xf, tyre_cols))

	# --- item boxes
	var boxes: Array = []
	var bimg := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var rainbow := [Color("ff4d6d"), Color("ffb703"), Color("8ac926"), Color("1982c4"), Color("9b5de5")]
	for yy in 32:
		for xx in 32:
			var t := (xx + yy) / 62.0 * 4.0
			var ci := mini(int(t), 3)
			var c: Color = rainbow[ci].lerp(rainbow[ci + 1], t - ci)
			if xx < 2 or yy < 2 or xx > 29 or yy > 29:
				c = Color.WHITE
			bimg.set_pixel(xx, yy, c)
	bimg.generate_mipmaps()
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_texture = ImageTexture.create_from_image(bimg)
	box_mat.albedo_color = Color(1, 1, 1, 0.82)
	box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_mat.emission_enabled = true
	box_mat.emission = Color(0.18, 0.18, 0.2)
	atm.box_mat = box_mat
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.7, 1.7, 1.7)
	for f in tr.def.boxes:
		var i := int(float(f) * tr.n)
		var k := 0
		for lane in [-0.6, -0.2, 0.2, 0.6]:
			var bx: float = tr.x[i] + tr.nx[i] * lane * Game.HW
			var bz: float = tr.z[i] + tr.nz[i] * lane * Game.HW
			var node := Node3D.new()
			node.position = Vector3(bx, 1.4, bz)
			var mi := MeshInstance3D.new()
			mi.mesh = box_mesh
			mi.material_override = box_mat
			node.add_child(mi)
			var q := Label3D.new()
			q.text = "?"
			q.font = UI.display_font
			q.font_size = 96
			q.pixel_size = 0.011
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.outline_size = 22
			q.outline_modulate = Color(0.08, 0.08, 0.16, 0.9)
			q.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(q)
			root.add_child(node)
			boxes.append({"x": bx, "z": bz, "node": node, "mesh": mi, "active": true, "respawn": 0.0,
				"phase": k * 0.7 + float(f) * 10.0, "scale": 1.0})
			k += 1

	# --- scenery
	_scenery(root, tr, th, rng)
	return {"root": root, "boxes": boxes, "atm": atm}


# ------------------------------------------------------------------ pieces
static func ribbon(tr: Track, o0: float, o1: float, y: float, v_len: float) -> ArrayMesh:
	var cnt := tr.n
	v_len = tr.length / maxf(1.0, round(tr.length / v_len))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize((cnt + 1) * 2)
	uvs.resize((cnt + 1) * 2)
	norms.resize((cnt + 1) * 2)
	for i in cnt + 1:
		var j := i % cnt
		var v := i * tr.step / v_len
		verts[i * 2] = Vector3(tr.x[j] + tr.nx[j] * o0, y, tr.z[j] + tr.nz[j] * o0)
		verts[i * 2 + 1] = Vector3(tr.x[j] + tr.nx[j] * o1, y, tr.z[j] + tr.nz[j] * o1)
		uvs[i * 2] = Vector2(0, v)
		uvs[i * 2 + 1] = Vector2(1, v)
		norms[i * 2] = Vector3.UP
		norms[i * 2 + 1] = Vector3.UP
		if i < cnt:
			# wound so the front face looks up: the sun lights the road and kerbs
			var a := i * 2
			idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Re-creates a mesh with one normal per face for a low-poly look.
static func flat(src: Mesh) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx = arr[Mesh.ARRAY_INDEX]
	var has_idx: bool = idx != null and idx.size() > 0
	var count: int = idx.size() if has_idx else v.size()
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	for i in range(0, count - 2, 3):
		var ia: int = idx[i] if has_idx else i
		var ib: int = idx[i + 1] if has_idx else i + 1
		var ic: int = idx[i + 2] if has_idx else i + 2
		var a := v[ia]
		var b := v[ib]
		var c := v[ic]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() < 1e-12:
			continue
		fn = fn.normalized()
		if fn.dot(nrm[ia] + nrm[ib] + nrm[ic]) < 0.0:
			fn = -fn
		ov.append(a)
		ov.append(b)
		ov.append(c)
		on.append(fn)
		on.append(fn)
		on.append(fn)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = ov
	out[Mesh.ARRAY_NORMAL] = on
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return m


static func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	return m


## MultiMesh helper: one transform per instance, optional per-instance colours.
static func _multi(mesh: Mesh, mat: Material, xfs: Array, cols: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i] if i < cols.size() else Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	return mi


## Far-away scenery (mountains, mesas) would throw huge shadows over the
## track at sunset, so it only receives light.
static func _no_cast(g: GeometryInstance3D) -> GeometryInstance3D:
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


static func _xf(rot_y: float, scale: Vector3, pos: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scale), pos)


static func _disc(r: float, color: Color, y: float, shiny: bool) -> Node3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 40
	m.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if shiny:
		mat.roughness = 0.15
		mat.metallic_specular = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder


static func _start_gantry(tr: Track) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(tr.x[0], 0.0, tr.z[0])
	g.rotation.y = tr.heading(0)
	var cimg := Image.create_empty(16, 2, false, Image.FORMAT_RGBA8)
	for yy in 2:
		for xx in 16:
			cimg.set_pixel(xx, yy, Color(0.07, 0.07, 0.07) if (xx + yy) % 2 == 1 else Color.WHITE)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_texture = ImageTexture.create_from_image(cimg)
	lmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var plane := PlaneMesh.new()
	plane.size = Vector2(Game.HW * 2.0, 2.6)
	var line := MeshInstance3D.new()
	line.mesh = plane
	line.material_override = lmat
	line.position.y = 0.085
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(line)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color("dfe3ea")
	var pole := CylinderMesh.new()
	pole.top_radius = 0.4
	pole.bottom_radius = 0.5
	pole.height = 9.0
	pole.radial_segments = 10
	for s in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		p.mesh = pole
		p.material_override = pole_mat
		p.position = Vector3(s * (Game.HW + 2.6), 4.5, 0)
		g.add_child(p)
	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Game.HW * 2.0 + 6.0, 2.2, 0.5)
	banner.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("11151f")
	banner.material_override = bmat
	banner.position.y = 8.4
	g.add_child(banner)
	var cq := QuadMesh.new()
	cq.size = Vector2(2.6, 2.0)
	var cimg2 := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	for yy in 4:
		for xx in 4:
			cimg2.set_pixel(xx, yy, Color.WHITE if (xx + yy) % 2 == 0 else Color(0.07, 0.07, 0.07))
	var cmat := StandardMaterial3D.new()
	cmat.albedo_texture = ImageTexture.create_from_image(cimg2)
	cmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for face in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "ŠKODA RACER"
		lbl.font = UI.display_font
		lbl.font_size = 120
		lbl.pixel_size = 0.0115
		lbl.modulate = Color.WHITE
		lbl.outline_size = 0
		lbl.position = Vector3(0, 8.4, face * 0.27)
		lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if face < 0.0:
			lbl.rotation.y = PI
		g.add_child(lbl)
		for s in [-1.0, 1.0]:
			var q := MeshInstance3D.new()
			q.mesh = cq
			q.material_override = cmat
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.position = Vector3(s * (Game.HW + 1.3), 8.4, face * 0.27)
			if face < 0.0:
				q.rotation.y = PI
			g.add_child(q)
	return g


static func _scatter(tr: Track, rng: RandomNumberGenerator, count: int, extra: float, min_clear: float) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 25:
		tries += 1
		var px := tr.min_x - extra + rng.randf() * (tr.max_x - tr.min_x + 2.0 * extra)
		var pz := tr.min_z - extra + rng.randf() * (tr.max_z - tr.min_z + 2.0 * extra)
		if tr.near(px, pz, min_clear):
			continue
		if not tr.lake.is_empty() and Vector2(px - float(tr.lake.x), pz - float(tr.lake.z)).length() < float(tr.lake.r) + 3.0:
			continue
		out.append([px, pz, rng.randf(), rng.randf(), rng.randf()])
	return out


static func _scenery(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator) -> void:
	var clear := Game.BAR + 5.0
	var dens := Gfx.foliage()
	var deco: String = th.deco
	var base: Color = th.tree
	if deco == "trees" or deco == "pines":
		var pine := deco == "pines"
		var trees := _scatter(tr, rng, int((240 if pine else 230) * dens), 160.0, clear)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.35
		trunk.bottom_radius = 0.55
		trunk.height = 3.0
		trunk.radial_segments = 6
		trunk.rings = 1
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color("7a5232")
		var fol: Mesh
		if pine:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 2.4
			cone.height = 7.0
			cone.radial_segments = 7
			cone.rings = 1
			fol = flat(cone)
		else:
			var sph := SphereMesh.new()
			sph.radius = 2.9
			sph.height = 5.8
			sph.radial_segments = 7
			sph.rings = 4
			fol = flat(sph)
		var trunk_xf: Array = []
		var fol_xf: Array = []
		var cap_xf: Array = []
		var fcols: Array = []
		for t in trees:
			var s: float = 0.8 + t[2] * 0.8
			var rot: float = t[3] * 6.0
			trunk_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0], 1.5 * s, t[1])))
			fol_xf.append(_xf(rot, Vector3(s, s * (1.0 if pine else 1.15), s), Vector3(t[0], (6.0 if pine else 5.4) * s, t[1])))
			cap_xf.append(_xf(rot, Vector3(s, s, s), Vector3(t[0], 8.4 * s, t[1])))
			var c := base
			c.h = fposmod(c.h + (t[4] - 0.5) * 0.05, 1.0)
			c.v = clampf(c.v + (t[4] - 0.5) * 0.15, 0.0, 1.0)
			fcols.append(c)
		root.add_child(_multi(trunk, trunk_mat, trunk_xf))
		root.add_child(_multi(fol, _vc_mat(), fol_xf, fcols))
		if pine:
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = 1.25
			cap.height = 2.6
			cap.radial_segments = 7
			cap.rings = 1
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color.WHITE
			root.add_child(_multi(flat(cap), cap_mat, cap_xf))
			_snowmen(root, tr, rng)
		else:
			var bushes := _scatter(tr, rng, int(120 * dens), 60.0, Game.BAR + 2.5)
			var bush := SphereMesh.new()
			bush.radius = 1.2
			bush.height = 2.4
			bush.radial_segments = 6
			bush.rings = 3
			var bush_xf: Array = []
			var bcols: Array = []
			for t in bushes:
				var s: float = 0.7 + t[2] * 0.9
				bush_xf.append(_xf(t[3] * 6.0, Vector3(s * 1.3, s, s * 1.3), Vector3(t[0], 0.6 * s, t[1])))
				bcols.append(base.lightened(0.08 + t[4] * 0.1))
			root.add_child(_multi(flat(bush), _vc_mat(), bush_xf, bcols))
	elif deco == "cactus":
		var cact := _scatter(tr, rng, int(110 * dens), 150.0, clear)
		var body := CylinderMesh.new()
		body.top_radius = 0.6
		body.bottom_radius = 0.7
		body.height = 6.0
		body.radial_segments = 8
		body.rings = 1
		var arm := CylinderMesh.new()
		arm.top_radius = 0.42
		arm.bottom_radius = 0.45
		arm.height = 2.6
		arm.radial_segments = 7
		arm.rings = 1
		var body_xf: Array = []
		var ccols: Array = []
		var arm_xf: Array = []
		var acols: Array = []
		for t in cact:
			var s: float = 0.7 + t[2] * 0.7
			body_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0], 3.0 * s, t[1])))
			var c := base
			c.v = clampf(c.v + (t[4] - 0.5) * 0.12, 0.0, 1.0)
			ccols.append(c)
			var a: float = t[3] * TAU
			arm_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0] + cos(a) * 1.2 * s, 4.4 * s, t[1] + sin(a) * 1.2 * s)))
			acols.append(c)
			if t[4] > 0.4:
				arm_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0] - cos(a) * 1.2 * s, 3.4 * s, t[1] - sin(a) * 1.2 * s)))
				acols.append(c)
		root.add_child(_multi(flat(body), _vc_mat(), body_xf, ccols))
		root.add_child(_multi(flat(arm), _vc_mat(), arm_xf, acols))
		var rocks := _scatter(tr, rng, int(80 * dens), 120.0, Game.BAR + 3.0)
		var rock := SphereMesh.new()
		rock.radius = 1.5
		rock.height = 3.0
		rock.radial_segments = 5
		rock.rings = 3
		var rock_xf: Array = []
		var rcols: Array = []
		for t in rocks:
			var s: float = 0.6 + t[2] * 2.2
			var b := Basis.from_euler(Vector3(t[3], t[4] * 6.0, 0)) * Basis.from_scale(Vector3(s, s * 0.7, s))
			rock_xf.append(Transform3D(b, Vector3(t[0], 0.4 * s, t[1])))
			rcols.append(Color(th.mount).lightened(0.05 + t[4] * 0.15))
		root.add_child(_multi(flat(rock), _vc_mat(), rock_xf, rcols))

	# distant mountains or mesas
	var mount: Color = th.mount
	var ring_xf: Array = []
	var cap_ring_xf: Array = []
	var mcols: Array = []
	var mesas := deco == "cactus"
	for i in 30:
		var a := float(i) / 30.0 * TAU + rng.randf() * 0.15
		var rad := tr.radius + 330.0 + rng.randf() * 230.0
		var px := tr.cx + cos(a) * rad
		var pz := tr.cz + sin(a) * rad
		var r1 := rng.randf()
		var r2 := rng.randf()
		var r3 := rng.randf()
		if mesas:
			var r := 45.0 + r1 * 70.0
			var h := 30.0 + r2 * 70.0
			ring_xf.append(_xf(r3 * 6.0, Vector3(r, h, r * (0.7 + r3 * 0.5)), Vector3(px, h * 0.5, pz)))
		else:
			var r := 70.0 + r1 * 80.0
			var h := 90.0 + r2 * 120.0
			var k := 0.3
			ring_xf.append(_xf(r3 * 6.0, Vector3(r, h, r), Vector3(px, h * 0.5, pz)))
			cap_ring_xf.append(_xf(r3 * 6.0, Vector3(r * k * 1.03, h * k, r * k * 1.03), Vector3(px, h - h * k * 0.5 + 0.5, pz)))
		mcols.append(mount.lightened((r3 - 0.5) * 0.24) if r3 > 0.5 else mount.darkened((0.5 - r3) * 0.24))
	if mesas:
		var mesa := CylinderMesh.new()
		mesa.top_radius = 1.0
		mesa.bottom_radius = 1.15
		mesa.height = 1.0
		mesa.radial_segments = 7
		mesa.rings = 1
		root.add_child(_no_cast(_multi(flat(mesa), _vc_mat(), ring_xf, mcols)))
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.0
		cone.height = 1.0
		cone.radial_segments = 6
		cone.rings = 1
		var fcone := flat(cone)
		root.add_child(_no_cast(_multi(fcone, _vc_mat(), ring_xf, mcols)))
		if th.cap != null:
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = th.cap
			root.add_child(_no_cast(_multi(fcone, cap_mat, cap_ring_xf)))


static func _snowmen(root: Node3D, tr: Track, rng: RandomNumberGenerator) -> void:
	var spots := _scatter(tr, rng, 10, 40.0, Game.BAR + 4.0)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color.WHITE
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color("1b1b1b")
	var carrot := StandardMaterial3D.new()
	carrot.albedo_color = Color("ff7b00")
	for p in spots:
		var g := Node3D.new()
		for part in [[1.6, 1.4], [1.15, 3.7], [0.8, 5.4]]:
			var s := SphereMesh.new()
			s.radius = part[0]
			s.height = part[0] * 2.0
			s.radial_segments = 8
			s.rings = 5
			var mi := MeshInstance3D.new()
			mi.mesh = flat(s)
			mi.material_override = snow
			mi.position.y = part[1]
			g.add_child(mi)
		var nose := MeshInstance3D.new()
		var nm := CylinderMesh.new()
		nm.top_radius = 0.0
		nm.bottom_radius = 0.15
		nm.height = 0.8
		nm.radial_segments = 6
		nose.mesh = nm
		nose.material_override = carrot
		nose.rotation.x = PI / 2.0
		nose.position = Vector3(0, 5.4, 0.95)
		g.add_child(nose)
		for ex in [-0.3, 0.3]:
			var eye := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.1
			em.height = 0.2
			em.radial_segments = 6
			em.rings = 3
			eye.mesh = em
			eye.material_override = coal
			eye.position = Vector3(ex, 5.7, 0.7)
			g.add_child(eye)
		var pj := tr.project(p[0], p[1], -1)
		var i: int = pj[0]
		g.position = Vector3(p[0], 0, p[1])
		g.rotation.y = atan2(tr.x[i] - float(p[0]), tr.z[i] - float(p[1]))
		root.add_child(g)
