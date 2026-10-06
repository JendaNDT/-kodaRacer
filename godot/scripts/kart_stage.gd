class_name KartStage
extends SubViewportContainer
## The chosen kart turning slowly on a pedestal (driver choice in the menu
## and the lobby). thumb() renders the small still pictures on the driver
## buttons once and keeps them.

var vp: SubViewport
var turn: Node3D
var show: KartShow
var driver := -1

static var _thumb_root: Node
static var _thumbs := {}


func _init(p_driver: int, height := 190.0) -> void:
	stretch = true
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = _viewport(Vector2i(480, int(height)), Gfx.msaa())
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_aim(cam, Vector3(0, 2.4, 7.6), Vector3(0, 0.9, 0))
	vp.add_child(cam)
	turn = Node3D.new()
	turn.rotation.y = 0.6
	vp.add_child(turn)
	turn.add_child(_pedestal())
	set_driver(p_driver)


func set_driver(d: int) -> void:
	if d == driver:
		return
	driver = d
	if show != null:
		show.queue_free()
	show = KartShow.new()
	show.setup(d)
	show.position.y = 0.32
	turn.add_child(show)
	show.wave(1.3)


func _process(delta: float) -> void:
	turn.rotation.y = fmod(turn.rotation.y + delta * 0.65, TAU)


static func _aim(cam: Camera3D, pos: Vector3, at: Vector3) -> void:
	cam.transform = Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)


## Own little world: clear background, a key and a fill light, the same
## film colours as the tracks.
static func _viewport(size: Vector2i, msaa: Viewport.MSAA) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = msaa
	vp.audio_listener_enable_3d = false
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e6ff")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.transform = Transform3D(Basis.looking_at(Vector3(0.55, -0.8, -0.6), Vector3.UP), Vector3.ZERO)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.light_color = Color("ffe2c4")
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.7, -0.3, 0.4), Vector3.UP), Vector3.ZERO)
	vp.add_child(fill)
	return vp


## Round pedestal: kerb-striped side, chequered rim on top.
static func _pedestal() -> MeshInstance3D:
	var k := MeshKit.new()
	var cols := func(i: int, j: int, _c: Vector3) -> Color:
		if i == 1:
			return UI.KERB if j % 2 == 0 else Color.WHITE
		if i == 2:
			return Color("1b2030") if j % 2 == 0 else Color("2a3046")
		return Color("10131c")
	k.lathe(MeshKit.at(Vector3.ZERO, Vector3(0, 0, PI / 2.0)), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 2.75),
		Vector2(0.32, 2.75), Vector2(0.32, 0.0)]), cols, MeshKit.GLOSS, 24)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	return mi


## Hosts the thumbnail viewports (the menu passes itself once).
static func host_thumbs(root: Node) -> void:
	_thumb_root = root


## A still picture of a driver's kart, rendered once.
static func thumb(d: int) -> Texture2D:
	if _thumbs.has(d):
		return _thumbs[d]
	if _thumb_root == null or not is_instance_valid(_thumb_root):
		return null
	var vp := _viewport(Vector2i(220, 140), Viewport.MSAA_4X)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.fov = 34.0
	_aim(cam, Vector3(3.5, 2.3, 4.9), Vector3(0, 0.85, 0.15))
	vp.add_child(cam)
	var s := KartShow.new()
	s.setup(d, false)
	s.steer_amp = 0.0
	s.process_mode = Node.PROCESS_MODE_DISABLED
	vp.add_child(s)
	_thumb_root.add_child(vp)
	_thumbs[d] = vp.get_texture()
	return _thumbs[d]
