class_name WorldBuilder
extends RefCounted
## Builds everything you see around a track: ground, road, kerbs, tyre
## barriers, start gantry, item boxes and themed scenery. Sky, sun, fog,
## clouds and weather come from Atmosphere; stands, boards, start lights
## and landmarks from Trackside.

const GROUND := 3600.0
const AUTUMN := ["e8862a", "d4522a", "e8b830", "c0392b", "f0a030", "9a8a2a", "b5651d"]
const BUILDING := ["5d6475", "6b5f5a", "7a7f8c", "4f5666", "8a8278", "5a6a7a", "6e6a80"]

## Item boxes: rainbow glass with a gleam sweeping across them.
const BOX_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float glow = 0.0;   // 1 on levels with glow: the rainbow box shines
varying float sweep;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	sweep = (VERTEX.x + VERTEX.y * 1.3 + VERTEX.z * 0.7) * 0.22 - TIME * 0.55 + (o.x + o.z) * 0.013;
}
void fragment() {
	float band = abs(fract(sweep) - 0.5);
	float shine = smoothstep(0.07, 0.0, band);
	ALBEDO = texture(tex, UV).rgb;
	vec3 base = mix(vec3(0.18, 0.18, 0.2), (vec3(1.0) + ALBEDO) * 0.4, glow);
	EMISSION = base + vec3(1.0, 0.98, 0.9) * shine * 0.9;
	ALPHA = mix(0.82, 1.0, shine);
	ROUGHNESS = 0.3;
}
"""

## Checkered flag that waves on a pole (UV.x = 0 at the pole).
const FLAG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
varying float fold;
void vertex() {
	float k = UV.x;
	float ph = UV.x * 7.0 - TIME * 7.5 + UV.y * 1.5;
	VERTEX.z += sin(ph) * 0.32 * k;
	VERTEX.y -= k * k * 0.25;
	fold = cos(ph) * k;
}
void fragment() {
	float c = mod(floor(UV.x * 7.0) + floor(UV.y * 5.0), 2.0);
	vec3 col = mix(vec3(0.97), vec3(0.06), c);
	ALBEDO = col * (0.82 + 0.18 * fold);
}
"""


static func build(tr: Track) -> Dictionary:
	var th: Dictionary = tr.def.theme
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tr.def.seed)
	var root := Node3D.new()
	root.name = "World"

	# --- sky, sun, fog, clouds and weather
	var atm := Atmosphere.build(root, tr, th)

	# --- ground
	# an island colours its land per vertex (grass, beach, sea floor), so its
	# texture is a neutral speckle the colours tint
	var tinted := th.has("sea")
	var g0: Color = Color.WHITE if tinted else th.ground
	var gimg := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	gimg.fill(g0)
	for i in 2600:
		var c: Color = th.ground2 if i % 2 == 1 else th.ground3
		if tinted:
			c = Color(0.84, 0.84, 0.84) if i % 2 == 1 else Color(1.0, 1.0, 1.0)
		var s := 1 + rng.randi() % 3
		var rect := Rect2i(rng.randi() % 256, rng.randi() % 256, s, s * (1 + rng.randi() % 3))
		gimg.fill_rect(rect, g0.lerp(c, 0.35 + rng.randf() * 0.45))
	gimg.generate_mipmaps()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = ImageTexture.create_from_image(gimg)
	gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	gmat.roughness = 1.0
	if tinted:
		gmat.vertex_color_use_as_albedo = true
		gmat.vertex_color_is_srgb = true
	root.add_child(_land(tr, gmat, th))
	if tinted:
		# the sea all around, the same water as the lakes
		var sea := PlaneMesh.new()
		sea.size = Vector2(GROUND, GROUND)
		var sea_mi := MeshInstance3D.new()
		sea_mi.mesh = sea
		sea_mi.position = Vector3(tr.cx, Track.SEA_Y, tr.cz)
		sea_mi.material_override = Trackside.lake_material(th.sea, th.mood.horizon, false)
		root.add_child(_no_cast(sea_mi))

	# --- lake in the infield where there is room (Track found the spot)
	if not tr.lake.is_empty():
		var r := float(tr.lake.water)
		var lava: bool = th.get("lava", false)
		var shore := _disc(r + 3.0, Color("3a302e") if lava else Color(th.ground2), 0.02, false)
		shore.position = Vector3(float(tr.lake.x), tr.lake_y, float(tr.lake.z))
		root.add_child(shore)
		var lake := _disc(r, th.lake, 0.035, true)
		lake.position = Vector3(float(tr.lake.x), tr.lake_y, float(tr.lake.z))
		(lake.get_child(0) as MeshInstance3D).material_override = Trackside.lava_material() if lava else \
			Trackside.lake_material(th.lake, th.mood.horizon, th.deco == "pines")
		root.add_child(lake)

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

	# --- start line and gantry, the jump ramp
	root.add_child(_start_gantry(tr))
	if not tr.ramp.is_empty():
		root.add_child(_ramp(tr))

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
				tyre_xf.append(Transform3D(Basis.IDENTITY, Vector3(px, tr.road_y(i, off, 0.0, false) + 0.62, pz)))
				tyre_cols.append(th.kerb_a if (tyre_cols.size() / 2) % 2 == 1 else th.kerb_b)
			d += 2.3
	var tyre_mesh := CylinderMesh.new()
	tyre_mesh.top_radius = 0.75
	tyre_mesh.bottom_radius = 0.75
	tyre_mesh.height = 1.25
	tyre_mesh.radial_segments = 10
	tyre_mesh.rings = 1
	# over a thousand low tyres: their shadow is a thin strip nobody notices,
	# but would be drawn again for every shadow cascade
	root.add_child(_no_cast(_multi(tyre_mesh, _vc_mat(), tyre_xf, tyre_cols)))

	# --- the shortcut through the infield
	_shortcut(root, tr, th, rng)

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
	var box_shader := Shader.new()
	box_shader.code = BOX_SHADER
	var box_mat := ShaderMaterial.new()
	box_mat.shader = box_shader
	box_mat.set_shader_parameter("tex", ImageTexture.create_from_image(bimg))
	atm.box_mat = box_mat
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.7, 1.7, 1.7)
	for f in tr.def.boxes:
		var i := int(float(f) * tr.n)
		var k := 0
		for lane in [-0.6, -0.2, 0.2, 0.6]:
			var bx: float = tr.x[i] + tr.nx[i] * lane * Game.HW
			var bz: float = tr.z[i] + tr.nz[i] * lane * Game.HW
			var by: float = tr.road_y(i, lane * Game.HW, 0.0) + 1.4
			var node := Node3D.new()
			node.position = Vector3(bx, by, bz)
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
			boxes.append({"x": bx, "y": by, "z": bz, "node": node, "mesh": mi, "active": true, "respawn": 0.0,
				"phase": k * 0.7 + float(f) * 10.0, "scale": 1.0})
			k += 1

	# --- scenery, stands, boards, landmarks
	_scenery(root, tr, th, rng)
	var ts := Trackside.build(root, tr, th, rng)
	return {"root": root, "boxes": boxes, "atm": atm, "trackside": ts}


# ------------------------------------------------------------------ pieces
## The shortcut: a dirt (sand, ice, gravel) path with tracks worn into it,
## low posts along its edges away from the road, a sign before it leaves
## the road. The gap in the tyre barrier and the clear ground around it
## come from Track.near counting the path too.
static func _shortcut(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator) -> void:
	if tr.cut.is_empty():
		return
	var c: Dictionary = tr.cut
	var m: int = c.m
	var col: Color = c.color
	# texture: the colour with specks and two worn wheel tracks
	var img := Image.create_empty(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for i in 900:
		var l := 1.0 if rng.randf() < 0.5 else 0.0
		img.fill_rect(Rect2i(rng.randi() % 64, rng.randi() % 128, 1 + rng.randi() % 2, 1 + rng.randi() % 3),
			col.lerp(Color(l, l, l), 0.06 + rng.randf() * 0.1))
	for lane in [17, 43]:
		img.fill_rect(Rect2i(lane, 0, 5, 128), col.darkened(0.14))
	# soft edges blending into the ground
	for xx in 64:
		var e := minf(xx, 63 - xx) / 6.0
		if e < 1.0:
			for yy in 128:
				var p := img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(p.r, p.g, p.b, e))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.roughness = 0.35 if c.kind == "ice" else 1.0
	mat.metallic = 0.15 if c.kind == "ice" else 0.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := Track.CUT_W + 1.0
	for k in m:
		var cx: float = c.x[k]
		var cz: float = c.z[k]
		var nx: float = -float(c.tz[k])
		var nz: float = float(c.tx[k])
		for side in [-1.0, 1.0]:
			var px := cx + nx * w * float(side)
			var pz := cz + nz * w * float(side)
			verts.append(Vector3(px, tr.cut_ground(px, pz, k, 0.0) + 0.03, pz))
			norms.append(tr.cut_normal(k))
			uvs.append(Vector2(0.0 if float(side) < 0.0 else 1.0, float(c.s[k]) / 14.0))
		if k < m - 1:
			var a := k * 2
			idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var path := _mesh_node(verts, norms, uvs, idx, mat)
	root.add_child(path)
	# posts along the edges where the path is away from the road
	var post := BoxMesh.new()
	post.size = Vector3(0.35, 0.9, 0.35)
	var post_col: Color = {"dirt": Color("7a5232"), "sand": Color("b98b52"), "ice": Color("e8f6ff"),
		"gravel": Color("4c4a55")}.get(c.kind, Color("7a5232"))
	var xfs: Array = []
	var cols: Array = []
	var k := 0
	while k < m:
		var nx: float = -float(c.tz[k])
		var nz: float = float(c.tx[k])
		for side in [-1.0, 1.0]:
			var px: float = float(c.x[k]) + nx * (Track.CUT_W + 0.6) * float(side)
			var pz: float = float(c.z[k]) + nz * (Track.CUT_W + 0.6) * float(side)
			var pj := tr.project(px, pz, int(c.a) if k < m / 2 else int(c.b))
			if absf(float(pj[1])) > Game.BAR + 1.5:
				xfs.append(Transform3D(Basis.IDENTITY.rotated(Vector3.UP, rng.randf() * 0.4),
					Vector3(px, tr.cut_ground(px, pz, k, 0.0) + 0.42, pz)))
				cols.append(post_col.lerp(Color.WHITE, 0.3) if (k / 2) % 2 == 0 and c.kind != "ice" else post_col)
		k += 2
	root.add_child(_multi(post, _vc_mat(), xfs, cols))
	# a sign before the path leaves the road: "ZKRATKA" with an arrow to its side
	var a := int(c.a)
	var sa := float(c.sa)
	var si := (a - 18 + tr.n) % tr.n
	var off := sa * (Game.HW + Game.KERB + 2.5)
	var sp := Vector3(tr.x[si] + tr.nx[si] * off, tr.road_y(si, off, 0.0, false), tr.z[si] + tr.nz[si] * off)
	var sign := Node3D.new()
	sign.position = sp
	sign.rotation.y = tr.heading(si) + PI   # its face towards the drivers coming
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.5, 2.1, 0.15)
	board.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("ffc43d")
	board.material_override = bmat
	board.position.y = 3.2
	sign.add_child(board)
	for px in [-2.8, 2.8]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.22, 2.4, 0.22)
		leg.mesh = lm
		leg.position = Vector3(px, 1.2, 0.0)
		sign.add_child(leg)
	var txt := Label3D.new()
	# the board faces back along the road; seen from a kart, +sa (right of the road) is on its left
	txt.text = ("ZKRATKA →" if sa > 0.0 else "← ZKRATKA")
	txt.font = UI.display_font
	txt.font_size = 64
	txt.pixel_size = 0.018
	txt.modulate = Color("1b1b24")
	txt.outline_size = 0
	txt.position = Vector3(0, 3.2, -0.09)
	txt.rotation.y = PI
	sign.add_child(txt)
	root.add_child(sign)



## A strip along the track between offsets o0 and o1, `y` above the road
## surface (it follows the hills and banked corners).
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
		verts[i * 2] = Vector3(tr.x[j] + tr.nx[j] * o0, tr.road_y(j, o0, 0.0, false) + y, tr.z[j] + tr.nz[j] * o0)
		verts[i * 2 + 1] = Vector3(tr.x[j] + tr.nx[j] * o1, tr.road_y(j, o1, 0.0, false) + y, tr.z[j] + tr.nz[j] * o1)
		uvs[i * 2] = Vector2(0, v)
		uvs[i * 2 + 1] = Vector2(1, v)
		var up := tr.normal(j, 0.0, 0.0, false)
		norms[i * 2] = up
		norms[i * 2 + 1] = up
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


## The land: the height grid from Track in 4×4 tiles (so the ones behind
## the camera are skipped), every node on High, every second one below
## (12 m is plenty: next to the road the land is a flat continuation of
## it), and flat ground at 0 around it out to the horizon. Texture
## coordinates in metres so everything joins up.
static func _land(tr: Track, mat: Material, th: Dictionary) -> Node3D:
	tr.land()
	var stp := 1 if Gfx.level() == 2 else 2
	var cols: Array = []
	var ix := 0
	while true:
		cols.append(mini(ix, tr.f_w - 1))
		if ix >= tr.f_w - 1:
			break
		ix += stp
	var rows: Array = []
	var iz := 0
	while true:
		rows.append(mini(iz, tr.f_h - 1))
		if iz >= tr.f_h - 1:
			break
		iz += stp
	var g := Node3D.new()
	var tiles := 4
	for ty in tiles:
		for tx_ in tiles:
			var r0 := (rows.size() - 1) * ty / tiles
			var r1 := (rows.size() - 1) * (ty + 1) / tiles
			var c0 := (cols.size() - 1) * tx_ / tiles
			var c1 := (cols.size() - 1) * (tx_ + 1) / tiles
			g.add_child(_land_tile(tr, mat, rows.slice(r0, r1 + 1), cols.slice(c0, c1 + 1), th))
	# flat ground around the grid: four big strips at height 0
	var c := Track.FCELL
	var x0 := tr.f_x0
	var z0 := tr.f_z0
	var x1 := tr.f_x0 + (tr.f_w - 1) * c
	var z1 := tr.f_z0 + (tr.f_h - 1) * c
	var tinted := th.has("sea")
	var colors := PackedColorArray()
	var ex0 := tr.cx - GROUND * 0.5
	var ez0 := tr.cz - GROUND * 0.5
	var ex1 := tr.cx + GROUND * 0.5
	var ez1 := tr.cz + GROUND * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for rect in [[ex0, ez0, ex1, z0], [ex0, z1, ex1, ez1], [ex0, z0, x0, z1], [x1, z0, ex1, z1]]:
		var b := verts.size()
		for p in [Vector2(rect[0], rect[1]), Vector2(rect[2], rect[1]), Vector2(rect[0], rect[3]), Vector2(rect[2], rect[3])]:
			verts.append(Vector3(p.x, tr.edge_y, p.y))
			norms.append(Vector3.UP)
			uvs.append(p / 24.0)
			if tinted:
				colors.append(_land_color(th, tr.edge_y))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	g.add_child(_mesh_node(verts, norms, uvs, idx, mat, colors))
	return g


## Island colours by height: grass, a sandy beach at the water, sea floor.
static func _land_color(th: Dictionary, h: float) -> Color:
	var sand: Color = th.dust
	var grass: Color = th.ground
	var beach := smoothstep(Track.SEA_Y + 2.4, Track.SEA_Y + 1.0, h)
	var c := grass.lerp(sand, beach)
	return c.lerp(sand.darkened(0.35), smoothstep(Track.SEA_Y, Track.SEA_Y - 4.0, h))


static func _land_tile(tr: Track, mat: Material, rows: Array, cols: Array, th: Dictionary) -> MeshInstance3D:
	var c := Track.FCELL
	var w := cols.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var colors := PackedColorArray()
	var tinted := th.has("sea")
	for r: int in rows:
		for q: int in cols:
			var px := tr.f_x0 + q * c
			var pz := tr.f_z0 + r * c
			verts.append(Vector3(px, tr.node_y(q, r), pz))
			if tinted:
				colors.append(_land_color(th, tr.node_y(q, r)))
			var hl := tr.node_y(maxi(q - 1, 0), r)
			var hr := tr.node_y(mini(q + 1, tr.f_w - 1), r)
			var hd := tr.node_y(q, maxi(r - 1, 0))
			var hu := tr.node_y(q, mini(r + 1, tr.f_h - 1))
			norms.append(Vector3((hl - hr) / (2.0 * c), 1.0, (hd - hu) / (2.0 * c)).normalized())
			uvs.append(Vector2(px, pz) / 24.0)
	for r in rows.size() - 1:
		for q in w - 1:
			var a := r * w + q
			idx.append_array(PackedInt32Array([a, a + 1, a + w, a + 1, a + w + 1, a + w]))
	return _mesh_node(verts, norms, uvs, idx, mat, colors)


static func _mesh_node(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		idx: PackedInt32Array, mat: Material, colors := PackedColorArray()) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	if not colors.is_empty():
		arr[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The jump: a wedge across the road with yellow and black stripes, rising
## to its lip, the drop behind it.
static func _ramp(tr: Track) -> MeshInstance3D:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for yy in 32:
		for xx in 32:
			img.set_pixel(xx, yy, Color("ffc21a") if (xx + yy) % 32 < 16 else Color("1d1f26"))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i0: int = tr.ramp.i
	var segs := int(round(float(tr.ramp.len) / tr.step))
	var hw := Game.HW
	var top: Array = []     # [left, right] per row
	var base: Array = []
	for k in segs + 1:
		var i := (i0 + k) % tr.n
		var lift := float(tr.ramp.h) * minf(1.0, float(k) / segs) + 0.04
		var row: Array = []
		var low: Array = []
		for la in [-hw, hw]:
			var g := Vector3(tr.x[i] + tr.nx[i] * la, tr.road_y(i, la, 0.0, false), tr.z[i] + tr.nz[i] * la)
			row.append(g + Vector3(0, lift, 0))
			low.append(g + Vector3(0, 0.02, 0))
		top.append(row)
		base.append(low)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
		var nrm := (d - a).cross(b - a).normalized()   # the side the winding shows
		for v in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
			st.set_normal(nrm)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	for k in segs:
		var u0 := float(k) * tr.step / 3.0
		var u1 := float(k + 1) * tr.step / 3.0
		# top surface, wound to face up
		quad.call(top[k][0], top[k + 1][0], top[k + 1][1], top[k][1],
			Vector2(0, u0), Vector2(0, u1), Vector2(hw * 2.0 / 3.0, u1), Vector2(hw * 2.0 / 3.0, u0))
		for sd in 2:
			var a: Vector3 = base[k][sd]
			var b: Vector3 = base[k + 1][sd]
			var c: Vector3 = top[k + 1][sd]
			var d: Vector3 = top[k][sd]
			if sd == 0:
				quad.call(a, b, c, d, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0.4), Vector2(u0, 0.4))
			else:
				quad.call(b, a, d, c, Vector2(u1, 0), Vector2(u0, 0), Vector2(u0, 0.4), Vector2(u1, 0.4))
	# the face at the lip
	quad.call(base[segs][0], base[segs][1], top[segs][1], top[segs][0],
		Vector2(0, 0), Vector2(hw * 2.0 / 3.0, 0), Vector2(hw * 2.0 / 3.0, 0.45), Vector2(0, 0.45))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


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
	g.position = Vector3(tr.x[0], tr.y[0], tr.z[0])
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
	# waving checkered flags on top of the gantry
	var flag_shader := Shader.new()
	flag_shader.code = FLAG_SHADER
	var flag_mat := ShaderMaterial.new()
	flag_mat.shader = flag_shader
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = Vector2(3.4, 2.2)
	cloth.center_offset = Vector3(1.7, -1.1, 0.0)
	cloth.subdivide_width = 14
	cloth.subdivide_depth = 4
	var staff := CylinderMesh.new()
	staff.top_radius = 0.09
	staff.bottom_radius = 0.11
	staff.height = 4.6
	staff.radial_segments = 6
	for s in [-1.0, 1.0]:
		var st := MeshInstance3D.new()
		st.mesh = staff
		st.material_override = pole_mat
		st.position = Vector3(s * (Game.HW + 2.6), 9.5 + 2.3, 0)
		g.add_child(st)
		var fl := MeshInstance3D.new()
		fl.mesh = cloth
		fl.material_override = flag_mat
		fl.position = Vector3(s * (Game.HW + 2.6), 13.9, 0)
		# both flags fly towards the middle of the road
		fl.rotation.y = PI if s > 0.0 else 0.0
		g.add_child(fl)
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
	if deco == "trees" or deco == "pines" or deco == "autumn":
		var pine := deco == "pines"
		var autumn := deco == "autumn"
		var trees := _scatter(tr, rng, int((240 if pine else (330 if autumn else 230)) * dens), 110.0 if autumn else 160.0, clear)
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
		var fir_xf: Array = []       # autumn: dark firs between the coloured trees
		var fir_cols: Array = []
		for t in trees:
			var s: float = 0.8 + t[2] * 0.8
			var rot: float = t[3] * 6.0
			var gy := tr.terrain(t[0], t[1]) - 0.2
			trunk_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0], gy + 1.5 * s, t[1])))
			if autumn and t[4] < 0.22:
				fir_xf.append(_xf(rot, Vector3(s, s * 1.15, s), Vector3(t[0], gy + 6.4 * s, t[1])))
				fir_cols.append(Color("2f5e3a").lightened(t[2] * 0.12))
				continue
			fol_xf.append(_xf(rot, Vector3(s, s * (1.0 if pine else 1.15), s), Vector3(t[0], gy + (6.0 if pine else 5.4) * s, t[1])))
			cap_xf.append(_xf(rot, Vector3(s, s, s), Vector3(t[0], gy + 8.4 * s, t[1])))
			var c := base
			if autumn:
				c = Color(AUTUMN[int(t[3] * 997.0) % AUTUMN.size()])
			c.h = fposmod(c.h + (t[4] - 0.5) * 0.05, 1.0)
			c.v = clampf(c.v + (t[4] - 0.5) * 0.15, 0.0, 1.0)
			fcols.append(c)
		root.add_child(_multi(trunk, trunk_mat, trunk_xf))
		root.add_child(_multi(fol, Trackside.wind_material(0.05, 2.0), fol_xf, fcols))
		if not fir_xf.is_empty():
			var fir := CylinderMesh.new()
			fir.top_radius = 0.0
			fir.bottom_radius = 2.3
			fir.height = 7.5
			fir.radial_segments = 7
			fir.rings = 1
			root.add_child(_multi(flat(fir), Trackside.wind_material(0.04, 2.0), fir_xf, fir_cols))
		if pine:
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = 1.25
			cap.height = 2.6
			cap.radial_segments = 7
			cap.rings = 1
			root.add_child(_multi(flat(cap), Trackside.wind_material(0.05, 2.0), cap_xf))
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
				bush_xf.append(_xf(t[3] * 6.0, Vector3(s * 1.3, s, s * 1.3), Vector3(t[0], tr.terrain(t[0], t[1]) + 0.6 * s, t[1])))
				var bc: Color = Color(AUTUMN[int(t[4] * 991.0) % AUTUMN.size()]) if autumn else base
				bcols.append(bc.lightened(0.08 + t[4] * 0.1))
			root.add_child(_multi(flat(bush), Trackside.wind_material(0.06, 0.0), bush_xf, bcols))
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
			var gy := tr.terrain(t[0], t[1]) - 0.2
			body_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0], gy + 3.0 * s, t[1])))
			var c := base
			c.v = clampf(c.v + (t[4] - 0.5) * 0.12, 0.0, 1.0)
			ccols.append(c)
			var a: float = t[3] * TAU
			arm_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0] + cos(a) * 1.2 * s, gy + 4.4 * s, t[1] + sin(a) * 1.2 * s)))
			acols.append(c)
			if t[4] > 0.4:
				arm_xf.append(_xf(0.0, Vector3(s, s, s), Vector3(t[0] - cos(a) * 1.2 * s, gy + 3.4 * s, t[1] - sin(a) * 1.2 * s)))
				acols.append(c)
		root.add_child(_multi(flat(body), Trackside.wind_material(0.012, 0.0), body_xf, ccols))
		root.add_child(_multi(flat(arm), Trackside.wind_material(0.012, 0.0), arm_xf, acols))
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
			rock_xf.append(Transform3D(b, Vector3(t[0], tr.terrain(t[0], t[1]) + 0.4 * s, t[1])))
			rcols.append(Color(th.mount).lightened(0.05 + t[4] * 0.15))
		root.add_child(_multi(flat(rock), _vc_mat(), rock_xf, rcols))

	elif deco == "city":
		_city(root, tr, th, rng)
		return
	elif deco == "palms":
		_palms(root, tr, th, rng)

	# distant mountains or mesas (small islands out at sea)
	var mount: Color = th.mount
	var islands := th.has("sea")
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
		elif islands:
			var r := 60.0 + r1 * 90.0
			var h := 25.0 + r2 * 45.0
			ring_xf.append(_xf(r3 * 6.0, Vector3(r, h, r), Vector3(px, Track.ISLAND_DEEP + h * 0.5, pz)))
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


## Night city: blocks of houses with lit windows lined up along the
## streets, street lamps with pools of light on the road, a skyline
## around the horizon.
static func _city(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator) -> void:
	var wmat := _window_material(rng)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var xfs: Array = []
	var cols: Array = []
	for t in _scatter(tr, rng, int(190 * Gfx.foliage()), 140.0, Game.BAR + 7.0):
		var px: float = t[0]
		var pz: float = t[1]
		var ni := tr.nearest(px, pz)
		var far := clampf((Vector2(px - tr.x[ni], pz - tr.z[ni]).length() - 30.0) / 140.0, 0.0, 1.0)
		var w: float = 10.0 + t[2] * 14.0
		var d: float = 10.0 + t[3] * 12.0
		var h: float = 8.0 + t[4] * t[4] * 34.0 + far * 24.0
		var gy := tr.terrain(px, pz) - 1.0
		xfs.append(Transform3D(Basis(Vector3.UP, tr.heading(ni)) * Basis.from_scale(Vector3(w, h, d)), Vector3(px, gy + h * 0.5, pz)))
		cols.append(Color(BUILDING[int(t[2] * 991.0) % BUILDING.size()]).lightened(t[3] * 0.1))
	root.add_child(_multi(box, wmat, xfs, cols))
	# skyline far away
	var sky_xf: Array = []
	var sky_cols: Array = []
	for i in 46:
		var a := float(i) / 46.0 * TAU + rng.randf() * 0.1
		var rad := tr.radius + 300.0 + rng.randf() * 240.0
		var w := 30.0 + rng.randf() * 34.0
		var h := 40.0 + pow(rng.randf(), 1.5) * 110.0
		sky_xf.append(Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(w, h, w * (0.6 + rng.randf() * 0.6))),
			Vector3(tr.cx + cos(a) * rad, h * 0.5 - 1.0, tr.cz + sin(a) * rad)))
		sky_cols.append(Color(BUILDING[i % BUILDING.size()]).darkened(0.35))
	root.add_child(_no_cast(_multi(box, wmat, sky_xf, sky_cols)))
	_street_lamps(root, tr, th)


## Wall texture with a grid of windows, some of them lit (the lit ones glow
## through an emission texture). World-space triplanar mapping keeps the
## windows the same size on every house.
static func _window_material(rng: RandomNumberGenerator) -> StandardMaterial3D:
	var alb := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var em := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	alb.fill(Color(0.92, 0.92, 0.92))
	em.fill(Color.BLACK)
	for wy in 4:
		for wx in 4:
			var r := Rect2i(wx * 16 + 3, wy * 16 + 4, 10, 9)
			var lit := rng.randf() < 0.5
			var warm := rng.randf() < 0.75
			var glow := Color("ffd27a") if warm else Color("bfe0ff")
			alb.fill_rect(r, glow if lit else Color(0.13, 0.15, 0.2))
			if lit:
				em.fill_rect(r, glow * rng.randf_range(0.7, 1.0))
	alb.generate_mipmaps()
	em.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(alb)
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(em)
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # only the lit windows glow
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 1.3
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 14.0, 1.0 / 12.0, 1.0 / 14.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.8
	return m


## Lamp posts behind the barriers every 32 m, sides taking turns, each
## throwing a warm pool of light on the road (additive, so it costs little).
static func _street_lamps(root: Node3D, tr: Track, th: Dictionary) -> void:
	var post := MeshKit.new()
	var steel := Color("3a3f4a")
	post.tube(MeshKit.at(Vector3.ZERO), Vector3(0, 0, 0), Vector3(0, 7.6, 0), 0.13, steel, MeshKit.SATIN, 6)
	post.tube(MeshKit.at(Vector3.ZERO), Vector3(0, 7.5, 0), Vector3(-2.6, 7.7, 0), 0.09, steel, MeshKit.SATIN, 5)
	post.rbox(MeshKit.at(Vector3(-2.6, 7.55, 0)), Vector3(1.0, 0.22, 0.5), 0.06, steel, MeshKit.SATIN, 0)
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.8, 0.08, 0.36)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(1.0, 0.86, 0.55) * 2.2
	var post_xf: Array = []
	var bulb_xf: Array = []
	var pools := SurfaceTool.new()
	pools.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 10.0
	var side := 1.0
	while d < tr.length - 6.0:
		var i := int(d / tr.step) % tr.n
		var off := side * (Game.BAR + 2.0)
		var px := tr.x[i] + tr.nx[i] * off
		var pz := tr.z[i] + tr.nz[i] * off
		d += 32.0
		side = -side
		if tr.near(px, pz, Game.BAR + 1.0):
			continue
		var away := Vector3(tr.nx[i], 0.0, tr.nz[i]) * signf(off)
		var b := Basis(away, Vector3.UP, away.cross(Vector3.UP))
		var base := Vector3(px, tr.road_y(i, off, 0.0, false) - 0.1, pz)
		post_xf.append(Transform3D(b, base))
		bulb_xf.append(Transform3D(b, base + b * Vector3(-2.6, 7.42, 0)))
		_light_pool(pools, tr, i, signf(off) * 10.5)
	root.add_child(_multi(post.commit(), null, post_xf))
	root.add_child(_no_cast(_multi(bulb, bulb_mat, bulb_xf)))
	var pool_mat := StandardMaterial3D.new()
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pool_mat.vertex_color_use_as_albedo = true
	pool_mat.albedo_texture = _radial()
	var pm := MeshInstance3D.new()
	pm.mesh = pools.commit()
	pm.material_override = pool_mat
	root.add_child(_no_cast(pm))


## A soft round patch of lamp light on the road around lateral offset la.
static func _light_pool(st: SurfaceTool, tr: Track, i: int, la: float) -> void:
	var rows := 5
	var cols := 3
	var grid: Array = []
	for r in rows:
		var j := (i + (r - 2) * 2 + tr.n) % tr.n
		var row: Array = []
		for c in cols:
			var o := la + (c - 1) * 8.0
			row.append([Vector3(tr.x[j] + tr.nx[j] * o, tr.road_y(j, o, 0.0, false) + 0.09, tr.z[j] + tr.nz[j] * o),
				Vector2(float(c) / (cols - 1), float(r) / (rows - 1))])
		grid.append(row)
	var col := Color(1.0, 0.78, 0.45, 0.55)
	for r in rows - 1:
		for c in cols - 1:
			for v in [grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c], grid[r + 1][c + 1], grid[r][c + 1]]:
				st.set_color(col)
				st.set_uv(v[1])
				st.add_vertex(v[0])


static func _radial() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for yy in 64:
		for xx in 64:
			var dd := Vector2(xx - 31.5, yy - 31.5).length() / 32.0
			var a := clampf(1.0 - dd, 0.0, 1.0)
			img.set_pixel(xx, yy, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


## Island: palms swaying in the wind and dark lava rocks.
static func _palms(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator) -> void:
	var dens := Gfx.foliage()
	var palm := _palm_mesh(Color(th.tree))
	var xfs: Array = []
	var cols: Array = []
	for t in _scatter(tr, rng, int(200 * dens), 110.0, Game.BAR + 4.0):
		var gy := tr.terrain(t[0], t[1])
		if gy < Track.SEA_Y + 0.6:
			continue
		var s: float = 0.8 + t[2] * 0.6
		xfs.append(_xf(t[3] * TAU, Vector3(s, s * (0.9 + t[4] * 0.3), s), Vector3(t[0], gy - 0.2, t[1])))
		cols.append(Color.WHITE.darkened(t[4] * 0.2))
	root.add_child(_multi(palm, Trackside.wind_material(0.035, 3.5), xfs, cols))
	var rock := SphereMesh.new()
	rock.radius = 1.5
	rock.height = 3.0
	rock.radial_segments = 5
	rock.rings = 3
	var rock_xf: Array = []
	var rcols: Array = []
	for t in _scatter(tr, rng, int(70 * dens), 110.0, Game.BAR + 3.0):
		var s: float = 0.6 + t[2] * 2.0
		var b := Basis.from_euler(Vector3(t[3], t[4] * 6.0, 0)) * Basis.from_scale(Vector3(s, s * 0.7, s))
		rock_xf.append(Transform3D(b, Vector3(t[0], tr.terrain(t[0], t[1]) + 0.3 * s, t[1])))
		rcols.append(Color(th.mount).lightened(t[4] * 0.12))
	root.add_child(_multi(flat(rock), _vc_mat(), rock_xf, rcols))


## One palm: a curved ringed trunk and drooping fronds (vertex colours, both
## sides of each frond so it shows from below).
static func _palm_mesh(leaf: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		var nrm := (c - a).cross(b - a).normalized()
		for v in [a, b, c]:
			st.set_color(col)
			st.set_normal(nrm)
			st.add_vertex(v)
	var h := 7.5
	var lean := 1.3
	var segs := 7
	var sides := 6
	var rings: Array = []
	for k in segs + 1:
		var u := float(k) / segs
		var c := Vector3(lean * u * u, h * u, 0.0)
		var r := lerpf(0.34, 0.2, u)
		var ring: Array = []
		for sd in sides:
			var a := TAU * sd / sides
			ring.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		rings.append(ring)
	for k in segs:
		var col := Color("8b6a45") if k % 2 == 0 else Color("7a5a3a")
		for sd in sides:
			var s1 := (sd + 1) % sides
			tri.call(rings[k][sd], rings[k + 1][s1], rings[k + 1][sd], col)
			tri.call(rings[k][sd], rings[k][s1], rings[k + 1][s1], col)
	var top := Vector3(lean, h, 0.0)
	for f in 9:
		var a := TAU * f / 9.0 + 0.2
		var dir := Vector3(cos(a), 0.18, sin(a)).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var col := leaf.lightened(0.08) if f % 2 == 0 else leaf.darkened(0.08)
		var prev_l := top
		var prev_r := top
		var steps := 5
		for k in range(1, steps + 1):
			var u := float(k) / steps
			var p := top + dir * (u * 3.6) + Vector3.DOWN * (u * u * 2.0)
			var w := 0.8 * sin(PI * minf(u * 1.15, 1.0)) + 0.05
			var l := p + side * w
			var r := p - side * w
			tri.call(prev_l, l, r, col)
			tri.call(prev_l, r, prev_r, col)
			tri.call(prev_l, r, l, col.darkened(0.15))
			tri.call(prev_l, prev_r, r, col.darkened(0.15))
			prev_l = l
			prev_r = r
	return st.commit()


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
		g.position = Vector3(p[0], tr.terrain(p[0], p[1]) - 0.3, p[1])
		g.rotation.y = atan2(tr.x[i] - float(p[0]), tr.z[i] - float(p[1]))
		root.add_child(g)
