extends Node
## Vibrations (Etapa G): every buzz goes through here. A phone vibrates
## itself; on a computer the player's gamepad rumbles (in split screen only
## the pad of the player it concerns, slot 0 or 1). A player gets at most one
## buzz every GAP seconds, so that they never run into one long hum: a
## stronger one that comes too soon waits for its turn, a weaker one is
## dropped.

const GAP := 0.1
const WAIT_MAX := 0.3        # s: a buzz that had to wait longer than this is stale
const SECOND := 0.17         # s: the second short buzz at the finish
# kind: [ms at strength 0, ms at strength 1, amplitude at 0, amplitude at 1]
const KINDS := {
	"bump": [20.0, 60.0, 0.35, 0.85],     # into a barrier or another kart, by how hard
	"hit": [120.0, 160.0, 0.7, 0.9],      # missile, banana, oil, lightning, a star's push
	"land": [30.0, 110.0, 0.3, 0.9],      # down from a jump, by how far it fell
	"boost": [35.0, 50.0, 0.3, 0.45],     # any turbo (drift, item, rocket start, trick)
	"drift": [15.0, 30.0, 0.25, 0.55],    # the drift sparks change colour
	"finish": [70.0, 70.0, 0.7, 0.7],     # twice
}

var log_on := false          # tests: buzzes are written into `buzzes` instead of the phone or pad
var buzzes: Array = []       # [time, slot, kind, ms, amplitude]
var asked := {}              # kind -> how many times an event asked for a buzz (tests)
var speed := 1.0             # the race's --fast: the game runs that many times faster than the clock
var _clock := 0.0
var _last := [-10.0, -10.0]
var _wait: Array = [{}, {}]  # per slot: {kind, ms, amp, at} waiting for its turn
var _later: Array = []       # [at, slot, kind, strength]: second buzzes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func enabled() -> bool:
	return bool(Game.settings.vibrate)


## Local player `slot` (0 or 1) feels event `kind` at `strength` 0..1.
func buzz(slot: int, kind: String, strength := 1.0) -> void:
	if slot < 0 or slot > 1 or not KINDS.has(kind):
		return
	asked[kind] = int(asked.get(kind, 0)) + 1
	if not enabled():
		return
	if kind == "finish":
		_later.append([_clock + SECOND, slot, kind, strength])
	_try(slot, kind, strength)


func _try(slot: int, kind: String, strength: float) -> void:
	var k: Array = KINDS[kind]
	var s := clampf(strength, 0.0, 1.0)
	var ms := lerpf(k[0], k[1], s)
	var amp := lerpf(k[2], k[3], s)
	if _clock - float(_last[slot]) >= GAP:
		_out(slot, kind, ms, amp)
		return
	var w: Dictionary = _wait[slot]
	if w.is_empty() or amp > float(w.amp):
		_wait[slot] = {"kind": kind, "ms": ms, "amp": amp, "at": _clock}


func _process(delta: float) -> void:
	_clock += delta * speed
	for slot in 2:
		var w: Dictionary = _wait[slot]
		if w.is_empty() or _clock - float(_last[slot]) < GAP:
			continue
		_wait[slot] = {}
		if _clock - float(w.at) <= WAIT_MAX and enabled():
			_out(slot, String(w.kind), float(w.ms), float(w.amp))
	var i := 0
	while i < _later.size():
		var l: Array = _later[i]
		if _clock >= float(l[0]):
			_later.remove_at(i)
			if enabled():
				_try(int(l[1]), String(l[2]), float(l[3]))
		else:
			i += 1


func _out(slot: int, kind: String, ms: float, amp: float) -> void:
	_last[slot] = _clock
	if log_on:
		buzzes.append([_clock, slot, kind, ms, amp])
		return
	var pad := Game._pad_for_slot(slot)
	if pad >= 0:
		# rumble motors need a moment to spin up; the strong one only for real knocks
		Input.start_joy_vibration(pad, amp, clampf((amp - 0.45) * 1.8, 0.0, 1.0), maxf(ms * 1.5, 60.0) / 1000.0)
	elif slot == 0 and Game.is_mobile():
		Input.vibrate_handheld(int(ms), amp)


## Tests: forget everything buzzed so far.
func reset_log() -> void:
	buzzes.clear()
	asked.clear()
	_wait = [{}, {}]
	_later.clear()
	_last = [-10.0, -10.0]
