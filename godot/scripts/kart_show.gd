class_name KartShow
extends Node3D
## A kart with its driver for menus and the podium: the same model as in
## the race, steering idly from side to side, waving while `cheering`.

var driver := 0
var paint := 0
var rig: DriverRig
var front: Array = []
var cheering := false
var steer_amp := 0.45
var _wave_left := 0.0
var _t := 0.0


func setup(p_driver: int, blob := true, p_paint := 0) -> void:
	driver = p_driver
	paint = p_paint
	var m := KartModel.get_model(driver, paint)
	var mat := MeshKit.body_material()
	var chassis := Node3D.new()
	add_child(chassis)
	var shell := MeshInstance3D.new()
	shell.mesh = m.body
	shell.set_surface_override_material(0, mat)
	chassis.add_child(shell)
	var fw: Dictionary = m.front
	var rw: Dictionary = m.rear
	for sx in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(float(fw.x) * sx, float(fw.r), float(fw.z))
		add_child(pivot)
		var wm := MeshInstance3D.new()
		wm.mesh = m.front_mesh
		wm.scale = Vector3(sx, 1.0, 1.0)
		pivot.add_child(wm)
		front.append(pivot)
	var axle := MeshInstance3D.new()
	axle.mesh = m.rear_mesh
	axle.position = Vector3(0.0, float(rw.r), float(rw.z))
	add_child(axle)
	var seat: Vector3 = m.seat
	var wheel: Vector3 = m.wheel
	rig = DriverRig.new()
	rig.position = seat
	chassis.add_child(rig)
	rig.setup(driver, wheel - seat, float(m.tilt), mat, 1000.0, paint)
	if blob:
		var size: Vector2 = m.size
		var b := MeshInstance3D.new()
		b.mesh = Kart._shared().shadow
		b.position.y = 0.02
		b.scale = Vector3(size.x / 2.8, 1.0, size.y / 3.8)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
	_t = randf() * 10.0
	_animate(1.0)


## Waves for a moment (says hello when picked in the menu).
func wave(seconds: float) -> void:
	_wave_left = seconds


func _process(delta: float) -> void:
	_t += delta
	_wave_left = maxf(0.0, _wave_left - delta)
	_animate(delta)


func _animate(delta: float) -> void:
	var steer := sin(_t * 0.9) * steer_amp
	for f in front:
		(f as Node3D).rotation.y = -steer * 0.45
	rig.pose(steer, 0.0, 0.0, false, cheering or _wave_left > 0.0, false, 0.6, delta, _t)
