class_name Tilt
extends RefCounted
## Steering by tilting the phone like a wheel held in both hands (Etapa G).
##
## Godot hands over gravity in the screen's frame: x to the right, y up,
## z out of the screen, pointing at the ground (Android's reading negated,
## see GodotLib.gravity in Godot 4.7.1). It also turns the axes with the
## display, but only when Android reports a configuration change, and
## turning the phone straight over to the other landscape side is not one
## (GodotInputHandler.onSensorChanged keeps its cached rotation). The game is
## always drawn with its bottom towards the ground, so in the true frame
## gravity points down the screen (y < 0). When it clearly points up, the
## axes are half a turn behind and the reading is turned back here.

const FULL := [35.0, 25.0, 18.0]   # degrees of tilt for full lock: Jemná, Střední, Ostrá
const NAMES := ["Jemná", "Střední", "Ostrá"]
const DEAD := 3.0                  # degrees around straight that do nothing
const SMOOTH := 0.07               # s: hand tremor is smoothed away
const LEVEL_TIME := 0.5            # s: how long "Vyrovnat" averages the hold
const FLIP_AT := 3.0               # m/s²: how clearly gravity must point up (or down again) to turn the frame
const FLAT_Z := 0.5                # weight of the out-of-screen part (phone held nearly flat)

var angle := 0.0        # smoothed wheel angle, degrees, + = to the right
var zero := 0.0         # the angle taken as straight
var flipped := false    # the axes are half a turn behind the display
var have := false       # the sensor has given a reading
var _level_left := -1.0 # levelling: seconds left (-1 = not levelling)
var _level_sum := 0.0
var _level_n := 0


## The wheel angle of one reading in degrees. Upright, it is exactly the
## turn around the screen's axis; held flat (no part of gravity along the
## screen) it falls back on how far the right edge dips.
static func wheel(g: Vector3, flip: bool) -> float:
	var gx := -g.x if flip else g.x
	return rad_to_deg(atan2(gx, sqrt(g.y * g.y + FLAT_Z * FLAT_Z * g.z * g.z)))


## One sensor reading, `dt` seconds after the previous one.
func feed(g: Vector3, dt: float) -> void:
	if g.length_squared() < 1.0:
		return
	var gy := -g.y if flipped else g.y
	if gy > FLIP_AT:
		flipped = not flipped
	var a := wheel(g, flipped)
	if not have:
		have = true
		angle = a
		zero = 0.0
	else:
		angle += (a - angle) * (1.0 - exp(-dt / SMOOTH))
	if _level_left >= 0.0:
		_level_sum += angle
		_level_n += 1
		_level_left -= dt
		if _level_left < 0.0:
			zero = clampf(_level_sum / maxi(_level_n, 1), -45.0, 45.0)


## Takes the way the phone is held over the next `secs` seconds as straight
## (start of a race, the Vyrovnat button).
func level(secs := LEVEL_TIME) -> void:
	_level_left = secs
	_level_sum = 0.0
	_level_n = 0


func levelling() -> bool:
	return _level_left >= 0.0


## Steering from -1 (full left) to 1 (full right) for sensitivity `sens`.
func steer(sens: int) -> float:
	if not have:
		return 0.0
	var d := angle - zero
	var full: float = FULL[clampi(sens, 0, FULL.size() - 1)]
	return signf(d) * clampf((absf(d) - DEAD) / (full - DEAD), 0.0, 1.0)
