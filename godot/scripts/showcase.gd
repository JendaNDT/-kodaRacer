class_name Showcase
extends RefCounted
## Screenshot helper (--showcase): the six karts parked on the start
## straight with a fixed camera.
##   --view=front|back|side|close   where the camera stands (close: --driver=N)
##   --pose=drive|steer|cheer|dizzy|boost|star|mix   what the drivers do
##   --steer=0.8                     steering for the steer pose


static func hold(race: Race) -> void:
	var a := Game.cmd_args
	var view := String(a.get("view", "front"))
	var pose := String(a.get("pose", "drive"))
	var tr := race.track
	race.state = "countdown"
	race.countdown = 1e6
	var base := (tr.n - int(round(16.0 / tr.step))) % tr.n
	var fwd := Vector3(sin(tr.heading(base)), 0.0, cos(tr.heading(base)))
	var side := Vector3(tr.nx[base], 0.0, tr.nz[base])
	var ctr := Vector3(tr.x[base], 0.0, tr.z[base])
	var karts := race.karts.duplicate()
	karts.sort_custom(func(p: Kart, q: Kart) -> bool: return p.driver < q.driver)
	for i in karts.size():
		var k: Kart = karts[i]
		# first driver on the left as the camera sees it
		var p := ctr + side * (float(i) - 2.5) * (3.7 if view == "back" else -3.7)
		if view == "side":
			p = ctr + fwd * (float(i) - 2.5) * 5.6
		k.x = p.x
		k.z = p.z
		k.heading = tr.heading(base)
		k.prev_x = k.x
		k.prev_z = k.z
		k.prev_h = k.heading
		var kp := pose
		if pose == "mix":
			kp = ["drive", "steer", "cheer", "dizzy", "boost", "star"][i % 6]
		k.speed = 0.0 if kp == "cheer" else 24.0
		k.steer = float(a.get("steer", "0.8")) if kp == "steer" else 0.0
		k.finished = kp == "cheer"
		k.spin = 0.5 if kp == "dizzy" else 0.0
		k.spin_total = 1.0
		k.boost = 1.0 if kp == "boost" else 0.0
		k.star = 5.0 if kp == "star" else 0.0
	var cam: Camera3D = race.panes[0].cam
	var up := Vector3.UP
	var look := ctr + up * 0.9
	cam.fov = 42.0
	match view:
		"back":
			cam.position = ctr - fwd * 15.0 + up * 3.2
			cam.fov = 48.0
		"side":
			cam.position = ctr + side * 17.0 + up * 3.0
		"close":
			var d := clampi(int(a.get("driver", "0")), 0, karts.size() - 1)
			var k: Kart = karts[d]
			var ang := float(a.get("angle", "35")) * PI / 180.0
			var dir := (fwd * cos(ang) + side * sin(ang)).normalized()
			look = k.position + up * 1.0
			cam.position = look + dir * float(a.get("dist", "6.5")) + up * float(a.get("height", "1.6"))
			cam.fov = 40.0
		_:
			cam.position = ctr + fwd * 15.0 + up * 2.7
			cam.fov = 48.0
	cam.look_at(look, up)
