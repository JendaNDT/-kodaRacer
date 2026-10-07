class_name Atmosphere
extends RefCounted
## Light and mood of a track: sky with a sun disk (or the moon and stars at
## night), the sun (real shadows on Střední and Vysoká), fog, film colours,
## glow, SSAO, drifting clouds and falling snow or leaves. Colours and light
## look the same on every quality level; shadows, glow, SSAO and the
## weather follow Gfx.

const SNOW_FLAKES := 2600

static var _snow_shader: Shader


## Adds the environment, sun, clouds and snow to `root`. The race calls
## apply_quality() before showing it.
static func build(root: Node3D, tr, th: Dictionary) -> Dictionary:   # tr: a Track or an Arena
	var mood: Dictionary = th.mood
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tr.def.seed) * 7 + 3

	# --- sky, fog, colours
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = mood.sky_top
	sky_mat.sky_horizon_color = mood.horizon
	sky_mat.ground_horizon_color = mood.horizon
	sky_mat.ground_bottom_color = Color(mood.horizon).darkened(0.15)
	sky_mat.sky_curve = mood.get("sky_curve", 0.12)
	sky_mat.sun_angle_max = mood.sun_halo
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = mood.ambient
	env.ambient_light_energy = mood.ambient_energy
	# film colours: AgX keeps bright light soft, the saturation brings the
	# toy colours back (this runs on every level, Nízká included)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = mood.exposure
	env.tonemap_agx_contrast = mood.get("contrast", 1.45)
	env.adjustment_enabled = true
	env.adjustment_saturation = mood.get("saturation", 1.3)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = mood.fog
	env.fog_density = 1.0
	env.fog_depth_begin = mood.fog_begin
	env.fog_depth_end = mood.fog_end
	env.fog_sky_affect = 0.0
	# glow: only emissive things (flames, sparks, the sun) are bright enough
	env.glow_intensity = 0.75
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 2.0
	# SSAO in the Compatibility renderer darkens the finished image
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# --- the sun: one light draws the disk in the sky, the other lights the scene
	var el := deg_to_rad(float(mood.sun_elev))
	var az := deg_to_rad(float(mood.sun_azim))
	var to_sun := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	var xf := Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	var disk := DirectionalLight3D.new()
	disk.name = "SunDisk"
	disk.transform = xf
	disk.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	disk.light_color = mood.sun_color
	disk.light_energy = mood.disk_energy
	disk.light_angular_distance = mood.get("disk_size", 2.2)
	root.add_child(disk)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = xf
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun.shadow_opacity = mood.get("shadow_opacity", 1.0)
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_fade_start = 0.75
	root.add_child(sun)

	var atm := {"env": env, "sun": sun, "mood": mood, "clouds": null, "snow": null, "box_mat": null,
		"plain": Color(mood.sun_color), "plain_energy": float(mood.sun_energy)}
	_shadowed_sun(atm, th)
	_clouds(root, tr, mood, rng, atm)
	var weather: String = mood.get("weather", "")
	if weather == "snow" and Gfx.weather() > 0.0:
		atm.snow = _snow(int(SNOW_FLAKES * Gfx.weather()), Color(1, 1, 1, 0.95), 0.06, 2.6)
		root.add_child(atm.snow)
	elif weather == "leaves" and Gfx.weather() > 0.0:
		# autumn leaves: two colours tumbling down slower and bigger than snow
		atm.snow = Node3D.new()
		for col in [Color(0.93, 0.5, 0.14, 0.95), Color(0.75, 0.22, 0.12, 0.95)]:
			atm.snow.add_child(_snow(int(320 * Gfx.weather()), col, 0.13, 1.3))
		root.add_child(atm.snow)
	if mood.get("stars", false):
		root.add_child(_stars(tr, rng))
	return atm


## Stars on a big dome over the track (nights only).
static func _stars(tr, rng: RandomNumberGenerator) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rad := 1500.0
	for i in 420:
		var a := rng.randf() * TAU
		var el := asin(lerpf(0.06, 1.0, pow(rng.randf(), 0.7)))
		var dir := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		var c := Vector3(tr.cx, 0.0, tr.cz) + dir * rad
		var sz := rng.randf_range(1.6, 4.2)
		var right := dir.cross(Vector3.UP).normalized()
		var up := right.cross(dir).normalized()
		var b := verts.size()
		for q in [Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, -1)]:
			verts.append(c + (right * q.x + up * q.y) * sz)
			var w := rng.randf_range(0.65, 1.0)
			cols.append(Color(w, w, lerpf(w, 1.0, 0.5)))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Stars"
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The Compatibility renderer draws a sun that casts shadows in a second pass
## and adds it in sRGB space, which makes everything far too bright. This
## works out the sun colour that gives sunlit ground and road the same
## brightness as the plain one-pass sun on Nízká, so all levels look alike.
static func _shadowed_sun(atm: Dictionary, th: Dictionary) -> void:
	var mood: Dictionary = atm.mood
	var amb: Color = Color(mood.ambient).srgb_to_linear() * float(mood.ambient_energy)
	var sun: Color = Color(mood.sun_color).srgb_to_linear() * float(mood.sun_energy)
	# match a neutral surface as bright as the ground and road on average,
	# so the sun keeps its colour
	var alb := (Color(th.ground).srgb_to_linear().get_luminance() + Color(th.road).srgb_to_linear().get_luminance()) * 0.5
	var n := maxf(0.15, sin(deg_to_rad(float(mood.sun_elev))))
	var out := Color(0, 0, 0)
	for c in 3:
		var base: float = alb * amb[c]
		var full: float = alb * (amb[c] + sun[c] * n)
		var add: float = _to_lin(_to_srgb(full) - _to_srgb(base))
		out[c] = add / (alb * n)
	var e := maxf(out.r, maxf(out.g, out.b))
	atm.shadow_energy = e
	atm.shadow_color = Color(out.r / e, out.g / e, out.b / e).linear_to_srgb()


static func _to_srgb(v: float) -> float:
	return 12.92 * v if v < 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func _to_lin(v: float) -> float:
	return v / 12.92 if v < 0.04045 else pow((v + 0.055) / 1.055, 2.4)


## Turns shadows, glow, SSAO and snow on or off for the current quality level.
static func apply_quality(atm: Dictionary) -> void:
	var env: Environment = atm.env
	var sun: DirectionalLight3D = atm.sun
	env.glow_enabled = Gfx.glow()
	env.ssao_enabled = Gfx.ssao()
	var shadows := Gfx.shadows()
	sun.shadow_enabled = shadows
	if shadows:
		sun.light_color = atm.shadow_color
		sun.light_energy = atm.shadow_energy
		var modes := {1: DirectionalLight3D.SHADOW_ORTHOGONAL, 2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}
		sun.directional_shadow_mode = modes[Gfx.shadow_splits()]
		sun.directional_shadow_max_distance = Gfx.shadow_distance()
		sun.directional_shadow_blend_splits = Gfx.shadow_splits() == 4
		RenderingServer.directional_shadow_atlas_set_size(Gfx.shadow_size(), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(Gfx.shadow_filter())
	else:
		sun.light_color = atm.plain
		sun.light_energy = atm.plain_energy
	if atm.snow != null:
		atm.snow.visible = Gfx.weather() > 0.0
	if atm.box_mat != null:
		# the rainbow box shines on levels with glow
		(atm.box_mat as ShaderMaterial).set_shader_parameter("glow", 1.0 if Gfx.glow() else 0.0)


## Slow drift of the clouds around the track.
static func animate(atm: Dictionary) -> void:
	if atm.clouds != null:
		atm.clouds.rotation.y = fmod(Time.get_ticks_msec() * 0.001 * float(atm.mood.get("wind", 0.006)), TAU)


static func _clouds(root: Node3D, tr, mood: Dictionary, rng: RandomNumberGenerator, atm: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Clouds"
	holder.position = Vector3(tr.cx, 0.0, tr.cz)
	root.add_child(holder)
	atm.clouds = holder
	var puff_xf: Array = []
	var y0: float = mood.get("cloud_y", 110.0)
	for c in int(float(mood.get("clouds", 16)) * Gfx.foliage()):
		var a := rng.randf() * TAU
		var rad := 150.0 + rng.randf() * 600.0
		var y := y0 + rng.randf() * 70.0
		var px := cos(a) * rad
		var pz := sin(a) * rad
		for p in 4:
			var sz := 8.0 + rng.randf() * 8.0
			puff_xf.append(WorldBuilder._xf(0.0, Vector3(sz * 1.4, sz * 0.8, sz),
				Vector3(px + (p - 1.5) * 13.0 + rng.randf() * 6.0, y + rng.randf() * 5.0, pz + rng.randf() * 10.0)))
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 6
	puff.rings = 3
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = mood.get("cloud", Color.WHITE)
	cloud_mat.disable_fog = true
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(mood.get("cloud", Color.WHITE)) * 0.35
	var mm := WorldBuilder._multi(WorldBuilder.flat(puff), cloud_mat, puff_xf)
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mm)


## Falling snow (or leaves): one mesh of flakes that a shader wraps into a
## box around whichever camera draws it, so split-screen gets it for both.
static func _snow(count: int, tint: Color, size: float, fall: float) -> MeshInstance3D:
	if _snow_shader == null:
		_snow_shader = Shader.new()
		_snow_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform vec3 box = vec3(64.0, 34.0, 64.0);
uniform float fall = 2.6;
uniform vec3 wind = vec3(1.3, 0.0, 0.6);
uniform float size = 0.06;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.95);

varying vec2 corner;
varying float fade;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 seed = VERTEX;
	float speed = fall * (0.7 + 0.6 * fract(seed.x * 7.13 + seed.z * 3.71));
	vec3 p = seed + vec3(wind.x * TIME + sin(TIME * 0.9 + seed.y) * 0.6, -speed * TIME,
		wind.z * TIME + cos(TIME * 0.7 + seed.x) * 0.6);
	p = mod(p - cam + box * 0.5, box) + cam - box * 0.5;
	vec3 d = abs(p - cam) / (box * 0.5);
	fade = 1.0 - smoothstep(0.65, 1.0, max(d.x, max(d.y, d.z)));
	fade *= smoothstep(1.5, 4.0, length(p - cam));
	vec3 vp = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	corner = UV * 2.0 - 1.0;
	vp.xy += corner * size * (1.0 + 0.6 * fract(seed.y * 5.3));
	VERTEX = vp;
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a * clamp(1.0 - dot(corner, corner), 0.0, 1.0) * fade;
}
"""
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(count * 4)
	uvs.resize(count * 4)
	idx.resize(count * 6)
	var box := Vector3(64.0, 34.0, 64.0)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in count:
		var p := Vector3(rng.randf() * box.x, rng.randf() * box.y, rng.randf() * box.z)
		for k in 4:
			verts[i * 4 + k] = p
			uvs[i * 4 + k] = corners[k]
		var b := i * 4
		var o := i * 6
		idx[o] = b; idx[o + 1] = b + 1; idx[o + 2] = b + 2
		idx[o + 3] = b; idx[o + 4] = b + 2; idx[o + 5] = b + 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = _snow_shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("fall", fall)
	var mi := MeshInstance3D.new()
	mi.name = "Snow"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the flakes are moved by the shader, so never cull them
	mi.custom_aabb = AABB(Vector3(-100000, -1000, -100000), Vector3(200000, 2000, 200000))
	return mi
