class_name Trackside
extends RefCounted
## Life around the track: start lights that follow the countdown,
## grandstands with waving fans, bunting and flags in the wind, boards of
## made-up sponsors, cones and hay bales, a rippling or frozen lake, and a
## landmark for every track (windmill and wooden footbridge in the valley,
## rock arch in the canyon, igloos and ice crystals at the lagoon).
## Shaders animate the fans, cloth, trees and water; update() turns the
## windmill sails and drives the start lights.

## Text, board colour and letter colour. Invented names only.
const SPONSORS := [
	["TURBO ŠNEK", "ffd23f", "1d3557"], ["KNEDLÍK EXPRES", "e63946", "ffffff"],
	["PNEU HOP", "1d3557", "ffd23f"], ["RYCHLOKAFE", "6a4c93", "ffffff"],
	["ŠROUBEK & SYN", "2a9d8f", "ffffff"], ["TRYSKÁČ", "f77f00", "1b1b1b"],
	["OLEJ OK", "111111", "ffd23f"], ["BENZÍN BOB", "3a86ff", "ffffff"],
]
const WIND := Vector3(0.85, 0.0, 0.53)
const SHIRTS := ["e63946", "ffd23f", "3a86ff", "2a9d8f", "ffffff", "f77f00", "8e5cf6", "ff5fa2", "1d3557", "8ac926"]

## Trees, bushes and cacti lean with the wind; the higher, the more.
const WIND_SHADER := """
shader_type spatial;
uniform float amp = 0.05;      // sideways metres per metre above floor_y
uniform float floor_y = 2.0;
void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = base.x * 0.071 + base.z * 0.053;
	float s = sin(TIME * 1.6 + ph) * 0.75 + sin(TIME * 3.1 + ph * 2.3) * 0.25;
	vec3 off = vec3(0.85, 0.0, 0.53) * (s * amp * max(0.0, wp.y - floor_y));
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

## Fans: shirt colour and timing per instance (INSTANCE_CUSTOM), about half
## of them wave both arms, the rest bounce with the arms down.
const CROWD_SHADER := """
shader_type spatial;
varying vec3 tint;
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float ph = c.a * 6.2831;
	float waver = step(0.45, fract(c.a * 7.31));
	if (abs(VERTEX.x) > 0.245 && VERTEX.y > 0.75) {
		float side = sign(VERTEX.x);
		float out_a = mix(2.75, 0.35 + 0.4 * sin(TIME * 8.0 + ph), waver);
		float a = -side * out_a;
		vec2 pv = vec2(0.3 * side, 0.8);
		vec2 d = VERTEX.xy - pv;
		VERTEX.xy = pv + vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
	}
	VERTEX.y += abs(sin(TIME * 4.5 + ph)) * 0.12 * (1.0 - waver);
	bool head = VERTEX.y > 0.86 && abs(VERTEX.x) < 0.2;
	vec3 skin = mix(vec3(0.95, 0.76, 0.62), vec3(0.42, 0.27, 0.18), fract(c.a * 13.7));
	tint = head ? to_linear(skin) : to_linear(c.rgb);
}
void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
"""

## Bunting and flags: UV.x = 0 where the cloth hangs, 1 at the free end.
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying float fold;
vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = UV.x * 5.5 - TIME * 6.5 + wp.x * 0.23 + wp.z * 0.19;
	VERTEX += NORMAL * sin(ph) * 0.22 * UV.x;
	fold = cos(ph) * UV.x;
}
void fragment() {
	ALBEDO = to_linear(COLOR.rgb) * (0.86 + 0.14 * fold);
	ROUGHNESS = 0.85;
}
"""

## Five start lamps, UV.x tells which one: red one by one, then all green.
const LIGHTS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int lit = 0;
uniform bool go = false;
uniform float boost = 1.0;
void fragment() {
	float i = floor(UV.x * 5.0);
	vec3 off = vec3(0.09, 0.03, 0.03);
	vec3 col = go ? vec3(0.2, 1.0, 0.35) * boost : (i < float(lit) ? vec3(1.0, 0.12, 0.08) * boost : off);
	ALBEDO = col;
}
"""

## Lake: ripples catch the sun and sparkle; frozen: ice with cracks that
## mirrors the sky at a glancing angle.
const LAKE_SHADER := """
shader_type spatial;
uniform vec3 water : source_color;
uniform vec3 sky : source_color;
uniform float frozen = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}
void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (frozen > 0.5) {
		float big = smoothstep(0.0, 0.05, cracks(p * 0.09));
		float small = smoothstep(0.0, 0.035, cracks(p * 0.33 + 5.0));
		float line = 1.0 - big * mix(1.0, small, 0.6);
		vec3 ice = water * vec3(0.62, 0.8, 0.95);
		ALBEDO = mix(mix(ice, vec3(0.97, 0.99, 1.0), line * 0.85), sky, fres * 0.55);
		ROUGHNESS = 0.06;
		SPECULAR = 0.9;
	} else {
		float t = TIME;
		float k = (p.x + p.y) * 0.8 + t * 2.1;
		vec2 g = vec2(cos(p.x * 0.45 + t * 1.4) * 0.45 + cos(k) * 0.24, cos(p.y * 0.38 - t * 1.2) * 0.38 + cos(k) * 0.24);
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-g.x * 0.18, 1.0, -g.y * 0.18)), 0.0)).xyz);
		ALBEDO = mix(water, sky, fres * 0.6);
		ROUGHNESS = 0.1;
		SPECULAR = 0.8;
		vec2 cell = floor(p * 1.3);
		vec2 fc = fract(p * 1.3) - 0.5;
		float sp = step(0.988, hash(cell + floor(t * 2.5))) * smoothstep(0.22, 0.0, length(fc));
		EMISSION = vec3(sp * 1.6);
	}
}
"""

static var _shaders := {}
static var _person: ArrayMesh


static func _material(key: String, code: String) -> ShaderMaterial:
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[key]
	return m


## Material for swaying foliage (MultiMesh with per-instance colours).
static func wind_material(amp: float, floor_y: float) -> ShaderMaterial:
	var m := _material("wind", WIND_SHADER)
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("floor_y", floor_y)
	return m


static func lake_material(water: Color, sky: Color, frozen: bool) -> ShaderMaterial:
	var m := _material("lake", LAKE_SHADER)
	m.set_shader_parameter("water", water)
	m.set_shader_parameter("sky", sky)
	m.set_shader_parameter("frozen", 1.0 if frozen else 0.0)
	return m


# ================================================================== build
static func build(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ts := {"lights": null, "spin": [], "spots": {}, "podium": {}}
	var crowd: Array = []          # groups of fans: Array of [Transform3D, Color]
	var cloth := Cloth.new()
	var used: Array = []           # track indices taken by stands and landmarks
	_start_lights(root, tr, ts)
	_grandstands(root, tr, th, rng, crowd, cloth, used, ts.spots)
	match String(tr.def.id):
		"udoli":
			_windmill(root, tr, ts, used)
			_footbridge(root, tr, crowd, used, ts.spots)
		"kanon":
			_rock_arch(root, tr, th, rng, used, ts.spots)
		"laguna":
			_igloos(root, tr, rng, used, ts.spots)
	_podium(root, tr, used, ts, cloth)
	_boards(root, tr, used, ts.spots)
	ts.spots.lights = [Vector3(tr.x[0], 6.5, tr.z[0]), -Vector3(tr.tx[0], 0.0, tr.tz[0])]
	if not tr.lake.is_empty():
		ts.spots.lake = [Vector3(float(tr.lake.x), 0.0, float(tr.lake.z)), Vector3(1, 0, 0)]
	_corner_props(root, tr, rng, ts.spots)
	for group in crowd:
		if not (group as Array).is_empty():
			root.add_child(_crowd(group))
	if not cloth.v.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = cloth.commit()
		mi.material_override = _material("cloth", CLOTH_SHADER)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return ts


## Spins the windmill sails and sets the start lights from the race state.
static func update(ts: Dictionary, race: Race) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for s in ts.spin:
		(s[0] as Node3D).rotation.z = fmod(t * float(s[1]), TAU)
	var lm: ShaderMaterial = ts.lights
	if lm == null:
		return
	var lit := 0
	var go := false
	if race.mode != Race.Mode.DEMO:
		if race.state == "countdown":
			lit = clampi(int((3.6 - race.countdown) / 0.6), 0, 5)
		else:
			go = true
	lm.set_shader_parameter("lit", lit)
	lm.set_shader_parameter("go", go)
	lm.set_shader_parameter("boost", Gfx.boost())


# ================================================================== helpers
static func _t(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return MeshKit.at(pos, rot, scale)


## Frame beside the track at sample i: +X points away from the road on
## `side` (+1 / -1 along the track normal), Z runs along the track (+Z
## against the driving direction when side is +1), origin `off` metres
## from the centre line.
static func _frame(tr: Track, i: int, side: float, off: float) -> Transform3D:
	var away := Vector3(tr.nx[i], 0.0, tr.nz[i]) * side
	return Transform3D(Basis(away, Vector3.UP, away.cross(Vector3.UP)), Vector3(tr.x[i], 0.0, tr.z[i]) + away * off)


## True when the points (local to f) keep `gap` metres from every bit of
## track and stay out of the lake.
static func _clear(tr: Track, f: Transform3D, pts: Array, gap: float) -> bool:
	for p in pts:
		var w: Vector3 = f * (p as Vector3)
		if tr.near(w.x, w.z, gap):
			return false
		if not tr.lake.is_empty() and Vector2(w.x - float(tr.lake.x), w.z - float(tr.lake.z)).length() < float(tr.lake.r) + 2.0:
			return false
	return true


static func _taken(tr: Track, i: int, used: Array, metres: float) -> bool:
	for u in used:
		var d := absi(i - int(u))
		d = mini(d, tr.n - d)
		if d * tr.step < metres:
			return true
	return false


## The straightest sample between fractions a and b of the lap.
static func _straightest(tr: Track, a: float, b: float, span: int, used: Array) -> int:
	var best := -1
	var bv := INF
	for i in range(int(a * tr.n), int(b * tr.n)):
		if _taken(tr, i, used, 60.0):
			continue
		var v := 0.0
		for k in range(-span, span + 1):
			v = maxf(v, absf(tr.curv[(i + k + tr.n) % tr.n]))
		if v < bv:
			bv = v
			best = i
	return best


static func _color(hex: String) -> Color:
	return Color(hex)


# ================================================================== start lights
static func _start_lights(root: Node3D, tr: Track, ts: Dictionary) -> void:
	var g := Node3D.new()
	g.position = Vector3(tr.x[0], 0.0, tr.z[0])
	g.rotation.y = tr.heading(0)
	root.add_child(g)
	var kit := MeshKit.new()
	var y := 6.55
	kit.rbox(_t(Vector3(0, y, -0.32)), Vector3(5.3, 1.15, 0.42), 0.12, KartModel.INK, MeshKit.GLOSS, 1)
	for i in 5:
		var x := (i - 2) * 0.98
		kit.rbox(_t(Vector3(x, y + 0.46, -0.66), Vector3(0.35, 0, 0)), Vector3(0.82, 0.05, 0.34), 0.02, KartModel.DARK,
			MeshKit.MATTE, 0)
		kit.disc(MeshKit.decal(Vector3(x, y, -0.535), Vector3(0, 0, -1)), 0.4, KartModel.DARK, MeshKit.MATTE, 16)
	for sx in [-1.0, 1.0]:
		kit.tube(MeshKit.at(Vector3.ZERO), Vector3(sx * 1.9, y + 0.5, -0.32), Vector3(sx * 1.9, 7.4, -0.32), 0.05,
			KartModel.DARK, MeshKit.MATTE, 6)
	var housing := MeshInstance3D.new()
	housing.mesh = kit.commit()
	g.add_child(housing)
	# lamps: one disc per light, UV.x picks the lamp in the shader
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	for i in 5:
		var c := Vector3((i - 2) * 0.98, y, -0.545)
		var u := Vector2((i + 0.5) / 5.0, 0.5)
		for k in 16:
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 1) / 16.0
			for p in [c, c + Vector3(cos(a0), sin(a0), 0) * 0.32, c + Vector3(cos(a1), sin(a1), 0) * 0.32]:
				v.append(p)
				uv.append(u)
				nrm.append(Vector3(0, 0, -1))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	var lm := ArrayMesh.new()
	lm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var lamps := MeshInstance3D.new()
	lamps.mesh = lm
	lamps.material_override = _material("lights", LIGHTS_SHADER)
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(lamps)
	ts.lights = lamps.material_override


# ================================================================== grandstands
## Up to two stands beside the start straight, where there is room.
static func _grandstands(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator, crowd: Array,
		cloth: Cloth, used: Array, spots: Dictionary) -> void:
	var length := 30.0
	var depth := 10.0
	var placed := 0
	for along in [-26.0, 30.0, -62.0, 64.0]:
		if placed >= 2:
			break
		var i := (int(round(along / tr.step)) + tr.n) % tr.n
		for side in [1.0, -1.0]:
			var f := _frame(tr, i, side, Game.BAR + 3.5)
			var pts := [Vector3(0, 0, -length * 0.5), Vector3(0, 0, length * 0.5), Vector3(depth, 0, -length * 0.5),
				Vector3(depth, 0, length * 0.5), Vector3(depth * 0.5, 0, 0)]
			if not _clear(tr, f, pts, Game.BAR + 2.0):
				continue
			var mi := MeshInstance3D.new()
			var kit := MeshKit.new()
			var fans: Array = []
			crowd.append(fans)
			_stand(kit, f, length, th, rng, fans, cloth)
			mi.mesh = kit.commit()
			root.add_child(mi)
			used.append(i)
			placed += 1
			spots["stand%d" % placed] = [f * Vector3(5.0, 3.0, 0.0), -f.basis.x]
			break


static func _stand(kit: MeshKit, f: Transform3D, length: float, th: Dictionary, rng: RandomNumberGenerator,
		crowd: Array, cloth: Cloth) -> void:
	var concrete := Color("c9ccd3")
	var seats: Array = [Color(th.kerb_a), Color(th.kerb_b), Color("ffd23f")]
	var tiers := 5
	var face := -f.basis.x       # fans look at the road
	var dens := Gfx.crowd()
	for k in tiers:
		var x0 := 1.2 + k * 1.5
		var top := 0.6 + k * 0.62
		kit.rbox(f * _t(Vector3(x0 + 0.75, top * 0.5, 0)), Vector3(1.5, top, length), 0.03, concrete, MeshKit.MATTE, 0)
		# seats in blocks of colour
		var blocks := 5
		var bl := length / blocks
		for b in blocks:
			var z := -length * 0.5 + (b + 0.5) * bl
			kit.rbox(f * _t(Vector3(x0 + 0.45, top + 0.1, z)), Vector3(0.55, 0.2, bl - 0.25), 0.04,
				seats[(b + k) % seats.size()], MeshKit.GLOSS, 0)
		# fans, a few seats left empty
		var z := -length * 0.5 + 0.6
		while z < length * 0.5 - 0.5:
			if rng.randf() < dens:
				var p: Vector3 = f * Vector3(x0 + 0.7, top + 0.02, z + rng.randf_range(-0.12, 0.12))
				var c := _color(SHIRTS[rng.randi() % SHIRTS.size()])
				crowd.append([Transform3D(Basis.looking_at(face, Vector3.UP, true), p), Color(c.r, c.g, c.b, rng.randf())])
			z += 0.9
	var back := 1.2 + tiers * 1.5
	var roof_y := 0.6 + tiers * 0.62 + 3.0
	kit.rbox(f * _t(Vector3(back + 0.15, roof_y * 0.5, 0)), Vector3(0.3, roof_y, length + 0.6), 0.05, concrete, MeshKit.MATTE, 0)
	for sz in [-1.0, 1.0]:
		kit.rbox(f * _t(Vector3((1.2 + back) * 0.5, roof_y * 0.5, sz * (length * 0.5 + 0.15))),
			Vector3(back - 1.2, roof_y, 0.3), 0.05, concrete, MeshKit.MATTE, 0)
	kit.rbox(f * _t(Vector3(back * 0.5 + 0.2, roof_y, 0), Vector3(0, 0, 0.06)), Vector3(back + 0.8, 0.3, length + 1.0), 0.08,
		Color(th.kerb_a), MeshKit.GLOSS, 1)
	kit.rbox(f * _t(Vector3(0.0, roof_y - 0.25, 0)), Vector3(0.25, 0.55, length + 1.0), 0.06, Color(th.kerb_b), MeshKit.GLOSS, 1)
	for zp in [-0.5, -0.17, 0.17, 0.5]:
		kit.tube(f, Vector3(0.35, 0, zp * (length - 1.0)), Vector3(0.35, roof_y, zp * (length - 1.0)), 0.13, concrete,
			MeshKit.MATTE, 8)
	kit.rbox(f * _t(Vector3(0.75, 0.5, 0)), Vector3(0.2, 1.0, length), 0.04, Color.WHITE, MeshKit.MATTE, 0)
	# bunting along the roof edge, flags on top
	cloth.bunting(f * Vector3(0.0, roof_y - 0.55, -length * 0.5), f * Vector3(0.0, roof_y - 0.55, length * 0.5), 0.7)
	for zp in [-0.42, 0.0, 0.42]:
		var base: Vector3 = f * Vector3(back - 0.3, roof_y + 0.15, zp * length)
		kit.tube(MeshKit.at(Vector3.ZERO), base, base + Vector3(0, 4.0, 0), 0.06, Color("e3e8ef"), MeshKit.CHROME, 6)
		cloth.flag(base + Vector3(0, 3.95, 0), [seats[0], Color.WHITE, seats[1]] if zp != 0.0 else
			[Color("1d3557"), Color("ffd23f"), Color("1d3557")])


static func _person_mesh() -> ArrayMesh:
	if _person != null:
		return _person
	var k := MeshKit.new()
	k.rbox(_t(Vector3(0, 0.55, 0)), Vector3(0.46, 0.6, 0.3), 0.0, Color.WHITE, MeshKit.MATTE, 0)
	k.sphere(_t(Vector3(0, 1.04, 0)), Vector3(0.17, 0.18, 0.17), Color.WHITE, MeshKit.MATTE, 6, 3)
	for sx in [-1.0, 1.0]:
		k.rbox(_t(Vector3(sx * 0.3, 1.05, 0)), Vector3(0.11, 0.48, 0.11), 0.0, Color.WHITE, MeshKit.MATTE, 0)
	_person = k.commit()
	return _person


static func _crowd(people: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _person_mesh()
	mm.instance_count = people.size()
	for i in people.size():
		mm.set_instance_transform(i, people[i][0])
		mm.set_instance_custom_data(i, people[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _material("crowd", CROWD_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 150.0
	return mi


# ================================================================== podium
## Winners' podium beside the start straight. ts.podium holds where the
## three karts stand (1st, 2nd, 3rd) for the race to fill after the finish.
static func _podium(root: Node3D, tr: Track, used: Array, ts: Dictionary, cloth: Cloth) -> void:
	for along in [12.0, 44.0, -40.0, 76.0, -72.0]:
		var i := (int(round(along / tr.step)) + tr.n) % tr.n
		if _taken(tr, i, used, 22.0):
			continue
		for side in [-1.0, 1.0]:
			var f := _frame(tr, i, side, Game.BAR + 6.0)
			var pts := [Vector3(-1, 0, -8), Vector3(-1, 0, 8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(4, 0, 0)]
			if not _clear(tr, f, pts, Game.BAR + 2.0):
				continue
			used.append(i)
			_build_podium(root, f, ts, cloth)
			return


static func _build_podium(root: Node3D, f: Transform3D, ts: Dictionary, cloth: Cloth) -> void:
	var kit := MeshKit.new()
	var front := -f.basis.x          # the podium faces the road
	var c := f * Vector3(3.5, 0, 0)
	var pf := Transform3D(Basis.looking_at(front, Vector3.UP, true), c)   # +Z towards the road
	kit.rbox(pf * _t(Vector3(0, 0.1, 0)), Vector3(15.5, 0.2, 7.5), 0.05, Color("b3202c"), MeshKit.MATTE, 1)
	var slots: Array = []
	var trims := [UI.GOLD, UI.SILVER, UI.BRONZE]
	var steps := [[0.0, 1.7], [-4.6, 1.15], [4.6, 0.7]]
	for k in 3:
		var x: float = steps[k][0]
		var h: float = steps[k][1]
		kit.rbox(pf * _t(Vector3(x, 0.2 + h * 0.5, 0)), Vector3(4.4, h, 5.4), 0.1, Color("f4f6fa"), MeshKit.GLOSS, 1)
		kit.rbox(pf * _t(Vector3(x, 0.2 + h - 0.05, 0)), Vector3(4.5, 0.12, 5.5), 0.05, trims[k], MeshKit.GLOSS, 1)
		var face := pf * _t(Vector3(x, 0.2 + h * 0.5, 2.712))
		kit.disc(face, minf(0.62, h * 0.4), trims[k], MeshKit.GLOSS, 20)
		kit.number(face * _t(Vector3(0, 0, 0.01)), k + 1, minf(0.72, h * 0.45), KartModel.INK)
		slots.append(Transform3D(pf.basis, pf * Vector3(x, 0.2 + h, 0.2)))
	# poles with bunting behind and beside the podium (the front stays open
	# so nothing hangs in front of the winners)
	var corners := [Vector3(-7.4, 0, 3.4), Vector3(-7.4, 0, -3.4), Vector3(7.4, 0, -3.4), Vector3(7.4, 0, 3.4)]
	for k in 4:
		var p: Vector3 = pf * (corners[k] as Vector3)
		var top := 5.0 if k == 1 or k == 2 else 3.6
		kit.tube(MeshKit.at(Vector3.ZERO), p, p + Vector3(0, top + 0.2, 0), 0.08, Color("e3e8ef"), MeshKit.CHROME, 6)
		if k < 3:
			var q: Vector3 = pf * (corners[k + 1] as Vector3)
			var qt := 5.0 if k + 1 == 1 or k + 1 == 2 else 3.6
			cloth.bunting(p + Vector3(0, top, 0), q + Vector3(0, qt, 0), 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)
	ts.podium = {"slots": slots, "center": pf * Vector3(0, 1.6, 0), "front": front}
	ts.spots.podium = [pf * Vector3(0, 2.0, 0), front]


# ================================================================== boards, cones, hay
## Sponsor boards behind the barriers, spread around the lap.
static func _boards(root: Node3D, tr: Track, used: Array, spots: Dictionary) -> void:
	var kit := MeshKit.new()
	var count := 10
	var made := 0
	for k in count:
		var i := int((k + 0.5) / count * tr.n)
		if i * tr.step < 45.0 or (tr.n - i) * tr.step < 30.0 or _taken(tr, i, used, 25.0):
			continue
		var side := 1.0 if absf(tr.curv[i]) < 0.004 and k % 2 == 0 else (signf(tr.curv[i]) if tr.curv[i] != 0.0 else 1.0)
		var f := _frame(tr, i, side, Game.BAR + 3.2)
		if not _clear(tr, f, [Vector3(0, 0, -4.5), Vector3(0, 0, 4.5)], Game.BAR + 1.5):
			f = _frame(tr, i, -side, Game.BAR + 3.2)
			if not _clear(tr, f, [Vector3(0, 0, -4.5), Vector3(0, 0, 4.5)], Game.BAR + 1.5):
				continue
		var sp: Array = SPONSORS[made % SPONSORS.size()]
		made += 1
		spots["board%d" % made] = [f * Vector3(0, 2.3, 0), -f.basis.x]
		kit.rbox(f * _t(Vector3(0.15, 2.3, 0)), Vector3(0.22, 2.0, 9.0), 0.06, Color(sp[1]), MeshKit.GLOSS, 1)
		kit.rbox(f * _t(Vector3(0.15, 3.36, 0)), Vector3(0.24, 0.12, 9.1), 0.04, Color.WHITE, MeshKit.GLOSS, 0)
		for z in [-3.6, 3.6]:
			kit.tube(f, Vector3(0.3, 0, z), Vector3(0.3, 1.4, z), 0.09, KartModel.DARK, MeshKit.MATTE, 6)
		var lbl := Label3D.new()
		lbl.text = String(sp[0])
		lbl.font = UI.display_font
		lbl.font_size = 72
		lbl.pixel_size = clampf(8.0 / (String(sp[0]).length() * 0.78 * 72.0), 0.005, 0.0125)
		lbl.modulate = Color(sp[2])
		lbl.outline_size = 0
		lbl.double_sided = false
		lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lbl.visibility_range_end = 160.0
		lbl.transform = Transform3D(Basis.looking_at(-f.basis.x, Vector3.UP, true), f * Vector3(0.02, 2.3, 0))
		root.add_child(lbl)
	if made > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		root.add_child(mi)


## Hay bale walls on the outside of the sharpest corners, cones beside them.
static func _corner_props(root: Node3D, tr: Track, rng: RandomNumberGenerator, spots: Dictionary) -> void:
	var picks: Array = []
	var order := range(tr.n)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(tr.curv[a]) > absf(tr.curv[b]))
	for i in order:
		if picks.size() >= 7 or absf(tr.curv[i]) < 0.012:
			break
		var ok := true
		for p in picks:
			var d := absi(i - int(p))
			if mini(d, tr.n - d) * tr.step < 40.0:
				ok = false
		if ok:
			picks.append(i)
	var hay_xf: Array = []
	var cone_xf: Array = []
	for i in picks:
		var side := signf(tr.curv[i])
		var f := _frame(tr, i, side, Game.BAR + 2.6)
		if not _clear(tr, f, [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(1.5, 0, 0)], Game.BAR + 1.2):
			continue
		spots["corner%d" % (hay_xf.size() / 7 + 1)] = [f * Vector3(0, 1.0, 0), -f.basis.x]
		for row in 2:
			for b in 4 - row:
				var z := (b - (3 - row) * 0.5) * 1.3
				var p: Vector3 = f * Vector3(0.2 + rng.randf() * 0.1, 0.42 + row * 0.82, z)
				hay_xf.append(Transform3D(f.basis * Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), p))
		for c in 4:
			var p: Vector3 = f * Vector3(-0.4, 0.0, 4.2 + c * 1.6)
			if not tr.near(p.x, p.z, Game.BAR + 0.8):
				cone_xf.append(Transform3D(Basis.IDENTITY, p))
	if not hay_xf.is_empty():
		var k := MeshKit.new()
		var straw := Color("e2c25a")
		var band := func(p: Vector3, _n: Vector3, _x: Variant) -> Color:
			return straw.darkened(0.25) if absf(absf(p.x) - 0.32) < 0.06 else straw
		k.rbox(_t(Vector3.ZERO), Vector3(1.25, 0.82, 0.82), 0.12, band, MeshKit.MATTE, 1)
		root.add_child(WorldBuilder._no_cast(WorldBuilder._multi(k.commit(), null, hay_xf)))
	if not cone_xf.is_empty():
		var k := MeshKit.new()
		var orange := Color("ff6a13")
		var stripes := func(i: int, _j: int, c: Vector3) -> Color:
			return Color.WHITE if c.x > 0.3 and c.x < 0.48 else orange
		k.lathe(_t(Vector3.ZERO, Vector3(0, 0, PI / 2.0)), PackedVector2Array([Vector2(0.04, 0.24), Vector2(0.72, 0.035),
			Vector2(0.74, 0.0)]), stripes, MeshKit.GLOSS, 10)
		k.rbox(_t(Vector3(0, 0.025, 0)), Vector3(0.5, 0.05, 0.5), 0.02, orange.darkened(0.3), MeshKit.MATTE, 0)
		root.add_child(WorldBuilder._no_cast(WorldBuilder._multi(k.commit(), null, cone_xf)))


# ================================================================== landmarks
## Valley: a windmill near the lake, sails turning, facing the track.
static func _windmill(root: Node3D, tr: Track, ts: Dictionary, used: Array) -> void:
	var spot := Vector3.ZERO
	var found := false
	var cands: Array = []
	if not tr.lake.is_empty():
		for a in 16:
			var ang := TAU * a / 16.0
			var r := float(tr.lake.r) + 9.0
			cands.append(Vector3(float(tr.lake.x) + cos(ang) * r, 0.0, float(tr.lake.z) + sin(ang) * r))
	for k in 24:
		var i := int(k / 24.0 * tr.n)
		for side in [1.0, -1.0]:
			cands.append(_frame(tr, i, side, Game.BAR + 30.0).origin)
	var best := INF
	for c in cands:
		var p: Vector3 = c
		if tr.near(p.x, p.z, Game.BAR + 14.0):
			continue
		# close to the start straight so everyone sees it on the first lap
		var d := Vector2(p.x - tr.x[int(tr.n * 0.12)], p.z - tr.z[int(tr.n * 0.12)]).length() + tr.min_dist(p.x, p.z) * 1.5
		if d < best:
			best = d
			spot = p
			found = true
	if not found:
		return
	var pj := tr.project(spot.x, spot.z, -1)
	var ti: int = pj[0]
	var face := Vector3(tr.x[ti] - spot.x, 0.0, tr.z[ti] - spot.z).normalized()
	var g := Node3D.new()
	g.transform = Transform3D(Basis.looking_at(face, Vector3.UP, true), spot)
	root.add_child(g)
	var kit := MeshKit.new()
	# loft along +Y, turned so a flat side of the octagon faces the track (+Z)
	var up := _t(Vector3.ZERO, Vector3(-PI / 2.0, PI / 8.0, 0))
	var walls := func(_a: float, z: float, _p: Vector3) -> Color:
		return Color("8d8f96") if z < 1.6 else Color("f3ead8")
	kit.loft(up, [[0.0, 0.0, 3.3, 3.3, 3.3], [1.6, 0.0, 3.2, 3.2, 3.2], [10.5, 0.0, 2.3, 2.3, 2.3], [11.2, 0.0, 2.25, 2.25, 2.25]],
		walls, MeshKit.MATTE, 2.0, 8, false, true)
	kit.loft(up, [[11.0, 0.0, 2.6, 2.6, 2.6], [11.6, 0.0, 2.55, 2.55, 2.55], [13.6, 0.0, 1.3, 1.3, 1.3], [14.4, 0.0, 0.15, 0.15, 0.15]],
		Color("5b3a24"), MeshKit.MATTE, 2.0, 8, false, false)
	kit.rbox(_t(Vector3(0, 1.2, 3.05)), Vector3(1.3, 2.4, 0.2), 0.08, Color("5b3a24"), MeshKit.MATTE, 1)
	for wy in [4.5, 7.6]:
		var rad := lerpf(3.2, 2.3, (wy - 1.6) / 8.9)
		kit.rbox(_t(Vector3(0, wy, rad * 0.924 + 0.06)), Vector3(0.8, 1.0, 0.18), 0.05, Color("2b2e36"), MeshKit.MATTE, 0)
	kit.arch(_t(Vector3(0, 5.2, 0), Vector3(0, 0, PI / 2.0)), 3.0, 3.25, 0.18, 0.0, TAU, Color("6b4a30"), MeshKit.MATTE, 16)
	var tower := MeshInstance3D.new()
	tower.mesh = kit.commit()
	g.add_child(tower)
	var hub := Node3D.new()
	hub.position = Vector3(0, 11.9, 2.75)
	g.add_child(hub)
	var sk := MeshKit.new()
	sk.tube(MeshKit.at(Vector3.ZERO), Vector3(0, 0, -0.6), Vector3(0, 0, 0.4), 0.32, Color("5b3a24"), MeshKit.MATTE, 10)
	for b in 4:
		var bt := _t(Vector3.ZERO, Vector3(0, 0, b * PI / 2.0))
		sk.rbox(bt * _t(Vector3(0, 4.6, 0.3)), Vector3(0.28, 9.2, 0.22), 0.05, Color("6b4a30"), MeshKit.MATTE, 1)
		sk.rbox(bt * _t(Vector3(0.95, 5.4, 0.3)), Vector3(1.6, 6.8, 0.08), 0.03, Color("f7f1e3"), MeshKit.MATTE, 0)
		for s in 5:
			sk.rbox(bt * _t(Vector3(0.95, 2.4 + s * 1.5, 0.36)), Vector3(1.7, 0.07, 0.06), 0.0, Color("6b4a30"), MeshKit.MATTE, 0)
	var sails := MeshInstance3D.new()
	sails.mesh = sk.commit()
	hub.add_child(sails)
	ts.spin.append([hub, 0.55])
	ts.spots.windmill = [spot + Vector3(0, 8.0, 0), face]


## Valley: an arched wooden footbridge over a straight, a few fans on it.
static func _footbridge(root: Node3D, tr: Track, crowd: Array, used: Array, spots: Dictionary) -> void:
	var i := _straightest(tr, 0.3, 0.75, 9, used)
	if i < 0:
		return
	var span := Game.BAR + 4.5
	var f := _frame(tr, i, 1.0, 0.0)
	var ends := [Vector3(span + 13.0, 0, -2), Vector3(span + 13.0, 0, 2), Vector3(-span - 13.0, 0, -2), Vector3(-span - 13.0, 0, 2)]
	if not _clear(tr, f, ends, Game.BAR + 1.0):
		return
	for side in [1.0, -1.0]:
		var bf := _frame(tr, i, side, span)
		if not _clear(tr, bf, [Vector3(0, 0, 0), Vector3(2, 0, 0)], Game.BAR + 1.0):
			return
	used.append(i)
	spots.bridge = [f * Vector3(0, 6.0, 0), f.basis.z]
	var kit := MeshKit.new()
	var wood := Color("b07b48")
	var dark := Color("6f4a2a")
	var deck_y := 7.0
	kit.rbox(f * _t(Vector3(0, deck_y, 0)), Vector3(span * 2.0 + 1.0, 0.45, 3.4), 0.08, wood, MeshKit.MATTE, 1)
	for sz in [-1.0, 1.0]:
		kit.rbox(f * _t(Vector3(0, deck_y + 1.0, sz * 1.6)), Vector3(span * 2.0 + 1.0, 0.12, 0.12), 0.03, dark, MeshKit.MATTE, 0)
		# arch over the deck with hangers
		var prev := Vector3(-span, deck_y + 0.2, sz * 1.6)
		for k in range(1, 15):
			var u := float(k) / 14.0
			var x := lerpf(-span, span, u)
			var p := Vector3(x, deck_y + 0.2 + 4.2 * sin(PI * u), sz * 1.6)
			kit.tube(f, prev, p, 0.2, dark, MeshKit.MATTE, 6)
			if k < 14 and k % 2 == 0:
				kit.tube(f, p, Vector3(x, deck_y + 0.2, sz * 1.6), 0.06, dark, MeshKit.MATTE, 5)
			prev = p
		for k in 16:
			var x := lerpf(-span, span, (k + 0.5) / 16.0)
			kit.tube(f, Vector3(x, deck_y + 0.2, sz * 1.6), Vector3(x, deck_y + 1.0, sz * 1.6), 0.05, wood, MeshKit.MATTE, 4)
	for sx in [-1.0, 1.0]:
		kit.rbox(f * _t(Vector3(sx * (span - 0.8), deck_y * 0.5, 0)), Vector3(2.2, deck_y, 3.8), 0.15, Color("8f8a82"),
			MeshKit.MATTE, 1)
		# ramp down to the ground
		var a := Vector3(sx * span, deck_y, 0)
		var b := Vector3(sx * (span + 12.5), 0.2, 0)
		var mid := (a + b) * 0.5
		var ang := atan2(deck_y, 12.5) * float(sx)
		kit.rbox(f * _t(mid, Vector3(0, 0, ang)), Vector3(a.distance_to(b), 0.4, 3.0), 0.06, wood, MeshKit.MATTE, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)
	var look_dir := f.basis.z       # towards the karts coming up the straight
	var fans: Array = []
	crowd.append(fans)
	for k in 7:
		var x := lerpf(-span + 3.0, span - 3.0, k / 6.0)
		var p: Vector3 = f * Vector3(x, deck_y + 0.22, -1.15)
		var c := _color(SHIRTS[(k * 3) % SHIRTS.size()])
		fans.append([Transform3D(Basis.looking_at(look_dir, Vector3.UP, true), p), Color(c.r, c.g, c.b, fposmod(k * 0.37, 1.0))])


## Canyon: a natural sandstone arch spanning a straight.
static func _rock_arch(root: Node3D, tr: Track, th: Dictionary, rng: RandomNumberGenerator, used: Array,
		spots: Dictionary) -> void:
	var i := _straightest(tr, 0.25, 0.7, 8, used)
	if i < 0:
		return
	var half := Game.BAR + 6.5
	var f := _frame(tr, i, 1.0, 0.0)
	if not _clear(tr, f, [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(half + 3, 0, 0), Vector3(-half - 3, 0, 0)],
			Game.BAR + 1.5):
		return
	used.append(i)
	spots.arch = [f * Vector3(0, 8.0, 0), f.basis.z]
	var kit := MeshKit.new()
	var rock: Color = th.mount
	var steps := 18
	var sides := 7
	var rings: Array = []
	var ctrs: Array = []
	for k in steps + 1:
		var u := float(k) / steps
		var th_a := lerpf(-0.12, PI + 0.12, u)
		var cs := cos(th_a)
		var x := half * signf(cs) * pow(absf(cs), 0.7)
		var y := 17.0 * maxf(sin(th_a), -0.2)
		var c := Vector3(x, y, 0.0)
		var r := lerpf(4.6, 2.4, clampf(sin(th_a), 0.0, 1.0))
		# cross-section perpendicular to the path
		var tdir := Vector3(-half * sin(th_a) * 0.7, 17.0 * cos(th_a), 0.0).normalized()
		var nside := Vector3(tdir.y, -tdir.x, 0.0)
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var rr := r * rng.randf_range(0.8, 1.2)
			ring.append(c + nside * cos(a) * rr + Vector3(0, 0, 1) * sin(a) * rr * 1.25)
		rings.append(ring)
		ctrs.append(c)
	for k in steps:
		for s in sides:
			var s1 := (s + 1) % sides
			var q := PackedVector3Array([rings[k][s], rings[k][s1], rings[k + 1][s1], rings[k + 1][s]])
			var mid := (q[0] + q[2]) * 0.5
			var layer := int(floor(mid.y / 1.7)) % 3
			var col := rock.lightened(0.12) if layer == 0 else (rock.darkened(0.08) if layer == 1 else rock.lightened(0.03))
			kit.face(f, q, ((ctrs[k] as Vector3) + (ctrs[k + 1] as Vector3)) * 0.5, col, MeshKit.MATTE)
	# boulders at the feet
	for sx in [-1.0, 1.0]:
		for b in 3:
			var p := Vector3(sx * (half + rng.randf_range(-2.0, 4.0)), 0.6, rng.randf_range(-6.0, 6.0))
			kit.sphere(f * _t(p), Vector3(1.6, 1.0, 1.4) * rng.randf_range(0.7, 1.3), rock.darkened(0.05), MeshKit.MATTE, 6, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)


## Lagoon: igloos by the lake and the road, clusters of glowing ice crystals.
static func _igloos(root: Node3D, tr: Track, rng: RandomNumberGenerator, used: Array, spots: Dictionary) -> void:
	var kit := MeshKit.new()
	var places: Array = []
	if not tr.lake.is_empty():
		for a in [0.3, 2.4, 4.4]:
			var r := float(tr.lake.r) + 7.0
			places.append(Vector3(float(tr.lake.x) + cos(a) * r, 0.0, float(tr.lake.z) + sin(a) * r))
	for k in 3:
		var i := int((k * 0.31 + 0.18) * tr.n)
		places.append(_frame(tr, i, 1.0 if k % 2 == 0 else -1.0, Game.BAR + 9.0).origin)
	var made := 0
	for sp in places:
		var p: Vector3 = sp
		if tr.near(p.x, p.z, Game.BAR + 5.0):
			continue
		var pj := tr.project(p.x, p.z, -1)
		var ti: int = pj[0]
		var face := Vector3(tr.x[ti] - p.x, 0.0, tr.z[ti] - p.z).normalized()
		_igloo(kit, Transform3D(Basis.looking_at(face, Vector3.UP, true), p), rng)
		made += 1
		spots["igloo%d" % made] = [p + Vector3(0, 2.0, 0), face]
	if made > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		root.add_child(mi)
	# ice crystals behind the barriers, a big cluster by the lake
	var ck := MeshKit.new()
	for k in 9:
		var i := int((k + 0.3) / 9.0 * tr.n)
		var f := _frame(tr, i, 1.0 if k % 2 == 1 else -1.0, Game.BAR + 4.0)
		if _clear(tr, f, [Vector3.ZERO], Game.BAR + 2.0):
			_crystals(ck, f.origin, rng, 5, 1.0)
	if not tr.lake.is_empty():
		var big := Vector3(float(tr.lake.x), 0.0, float(tr.lake.z)) + Vector3(float(tr.lake.r) * 0.35, 0, 0)
		_crystals(ck, big, rng, 9, 2.2)
		spots.crystals = [big + Vector3(0, 3.0, 0), Vector3(1, 0, 0)]
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.35, 0.8, 1.0, 0.8)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.roughness = 0.05
	cm.metallic_specular = 1.0
	cm.emission_enabled = true
	cm.emission = Color("38d6ff")
	cm.emission_energy_multiplier = 0.9
	cm.rim_enabled = true
	cm.rim = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = ck.commit()
	mi.material_override = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _igloo(kit: MeshKit, f: Transform3D, rng: RandomNumberGenerator) -> void:
	var r := 3.6
	var lats := PackedFloat32Array()
	var a := 0.0
	while a < PI / 2.0 - 0.2:
		lats.append(a)
		lats.append(a + 0.035)
		a += 0.3
	lats.append(PI / 2.0)
	var blocks := func(_d: Vector3, row: int, col: int) -> Color:
		if row % 2 == 0:
			return Color("b9cbe0")
		var h: float = fposmod(sin(float(row * 31 + col * 7)) * 43758.5, 1.0)
		return Color("f4f8fd").darkened(h * 0.06)
	kit.sphere(f, Vector3(r, r * 0.92, r), blocks, MeshKit.SATIN, 16, 0, 0.0, 0.0, lats)
	var tunnel := f * _t(Vector3(0, 0, r - 0.2), Vector3(0, PI / 2.0, 0))
	kit.arch(tunnel, 1.05, 1.45, 2.2, 0.0, PI, Color("eef4fb"), MeshKit.SATIN, 10)
	var door := PackedVector2Array()
	for k in 9:
		var ang: float = PI * k / 8.0
		door.append(Vector2(cos(ang) * 1.05, sin(ang) * 1.05))
	kit.polygon(f * _t(Vector3(0, 0.01, r + 0.9)), door, Color("1d2a3a"), MeshKit.MATTE)


static func _crystals(kit: MeshKit, at: Vector3, rng: RandomNumberGenerator, count: int, size: float) -> void:
	for c in count:
		var len := rng.randf_range(1.2, 3.2) * size
		var r := rng.randf_range(0.18, 0.38) * size
		var tilt := Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		var t := _t(at + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * size, tilt) * \
			_t(Vector3.ZERO, Vector3(0, 0, PI / 2.0))
		kit.lathe(t, PackedVector2Array([Vector2(-0.3, 0.0), Vector2(-0.3, r), Vector2(len, r), Vector2(len + r * 2.2, 0.0)]),
			Color.WHITE, MeshKit.GLOSS, 6)


# ================================================================== cloth
## Bunting and flags collected into one mesh for the cloth shader.
class Cloth:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	const COLS := ["e63946", "ffd23f", "3a86ff", "2a9d8f", "ffffff", "f77f00"]

	func _add(p: Vector3, nrm: Vector3, col: Color, u: float) -> void:
		v.append(p)
		n.append(nrm)
		c.append(col)
		uv.append(Vector2(u, 0.0))

	## Triangular pennants on a sagging line from a to b.
	func bunting(a: Vector3, b: Vector3, sag: float) -> void:
		var d := b - a
		var count := maxi(2, int(d.length() / 0.85))
		var nrm := d.cross(Vector3.UP).normalized()
		for k in count:
			var t0 := (k + 0.12) / count
			var t1 := (k + 0.88) / count
			var tm := (t0 + t1) * 0.5
			var p0 := a + d * t0 - Vector3.UP * sag * 4.0 * t0 * (1.0 - t0)
			var p1 := a + d * t1 - Vector3.UP * sag * 4.0 * t1 * (1.0 - t1)
			var tip := a + d * tm - Vector3.UP * (sag * 4.0 * tm * (1.0 - tm) + 0.62)
			var col := Color(COLS[k % COLS.size()])
			_add(p0, nrm, col, 0.0)
			_add(p1, nrm, col, 0.0)
			_add(tip, nrm, col, 1.0)

	## Flag flying downwind from the top of a pole, in vertical stripes.
	func flag(top: Vector3, cols: Array) -> void:
		var dir := Trackside.WIND.normalized()
		var nrm := dir.cross(Vector3.UP).normalized()
		var w := 2.1
		var h := 1.35
		var cw := 8
		for i in cw:
			var u0 := float(i) / cw
			var u1 := float(i + 1) / cw
			var col: Color = cols[mini(int(u0 * cols.size() + 0.001), cols.size() - 1)]
			for j in 2:
				var y0 := -h * j / 2.0
				var y1 := -h * (j + 1) / 2.0
				var a := top + dir * w * u0 + Vector3.UP * y0
				var b := top + dir * w * u1 + Vector3.UP * y0
				var cc := top + dir * w * u1 + Vector3.UP * y1
				var d := top + dir * w * u0 + Vector3.UP * y1
				for q in [[a, u0], [b, u1], [cc, u1], [a, u0], [cc, u1], [d, u0]]:
					_add(q[0], nrm, col, q[1])

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m
