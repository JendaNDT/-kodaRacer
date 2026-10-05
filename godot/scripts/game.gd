extends Node
## Global game data, settings and player input (keyboard, gamepads, touch).

const LAPS := 3
const HW := 11.0          # half road width
const KERB := 1.6         # kerb width
const BAR := 18.0         # barrier distance from the centre line
const KART_R := 1.25      # kart collision radius
const MAX_KARTS := 6
const SIM_DT := 1.0 / 120.0

var BASE := {"max": 40.0, "accel": 24.0, "brake": 45.0, "rev": 12.0, "drag": 9.0, "turn": 2.1}

var CHARS := [
	{"name": "Turbo Tonda", "tag": "Vyvážený", "color": Color("e63946"), "accent": Color("ffd166"), "helmet": Color("ffffff"),
		"speed": 1.00, "accel": 1.00, "handling": 1.00, "weight": 1.00},
	{"name": "Zuzka Zběsilá", "tag": "Hbitá", "color": Color("ff5fa2"), "accent": Color("ffffff"), "helmet": Color("ffd1e8"),
		"speed": 0.96, "accel": 1.12, "handling": 1.08, "weight": 0.90},
	{"name": "Pepa Plyn", "tag": "Rychlík", "color": Color("2f6fed"), "accent": Color("e8f0ff"), "helmet": Color("1b2a49"),
		"speed": 1.05, "accel": 0.90, "handling": 0.94, "weight": 1.12},
	{"name": "Máňa Motor", "tag": "Akcelerace", "color": Color("ffc23d"), "accent": Color("2b2d42"), "helmet": Color("ff7b00"),
		"speed": 0.98, "accel": 1.09, "handling": 1.04, "weight": 0.95},
	{"name": "Karel Kolo", "tag": "Tahoun", "color": Color("2bb673"), "accent": Color("f1faee"), "helmet": Color("0b6e4f"),
		"speed": 1.03, "accel": 0.95, "handling": 0.99, "weight": 1.07},
	{"name": "Bára Brzda", "tag": "Zatáčky", "color": Color("8e5cf6"), "accent": Color("9ef0ff"), "helmet": Color("e0d4ff"),
		"speed": 1.00, "accel": 1.02, "handling": 1.10, "weight": 0.97},
]

var DIFFS := [
	{"name": "Lehká", "cc": "50 ccm", "speed": 0.82, "ai": 0.86},
	{"name": "Střední", "cc": "100 ccm", "speed": 1.00, "ai": 0.93},
	{"name": "Těžká", "cc": "150 ccm", "speed": 1.15, "ai": 0.985},
]

var TRACKS := [
	{
		"id": "udoli", "name": "Zelené údolí", "desc": "Pohodový okruh mezi kopci", "seed": 11,
		"pts": [Vector2(0, 0), Vector2(120, 0), Vector2(220, 10), Vector2(280, -40), Vector2(290, -120), Vector2(240, -180),
			Vector2(160, -170), Vector2(110, -120), Vector2(50, -130), Vector2(0, -200), Vector2(-80, -230), Vector2(-170, -200),
			Vector2(-210, -120), Vector2(-180, -40), Vector2(-100, 0)],
		"boxes": [0.1, 0.36, 0.6, 0.84],
		"theme": {"sky_top": Color("2f7fd6"), "horizon": Color("cde9ff"), "ground": Color("4caa3c"), "ground2": Color("41983a"),
			"ground3": Color("5cb84a"), "road": Color("54565e"), "kerb_a": Color("e8333a"), "kerb_b": Color("f4f4f4"),
			"ambient": Color("eaf6ff"), "dust": Color("8a6a45"), "deco": "trees", "mount": Color("5d8c68"),
			"cap": Color("f4f8ff"), "tree": Color("2f8a3e"), "lake": Color("3d9be0")},
	},
	{
		"id": "kanon", "name": "Pouštní kaňon", "desc": "Dlouhé rovinky a ostré vracečky", "seed": 23,
		"pts": [Vector2(0, 0), Vector2(160, 0), Vector2(260, -30), Vector2(300, -110), Vector2(250, -170), Vector2(150, -160),
			Vector2(90, -200), Vector2(80, -280), Vector2(150, -330), Vector2(160, -400), Vector2(60, -440), Vector2(-80, -420),
			Vector2(-150, -340), Vector2(-130, -240), Vector2(-180, -150), Vector2(-150, -60), Vector2(-90, -10)],
		"boxes": [0.08, 0.3, 0.55, 0.78],
		"theme": {"sky_top": Color("3d8fd9"), "horizon": Color("ffe1b3"), "ground": Color("d9aa62"), "ground2": Color("c99852"),
			"ground3": Color("e6bb7c"), "road": Color("6a5a50"), "kerb_a": Color("d9480f"), "kerb_b": Color("fff1dc"),
			"ambient": Color("fff3e0"), "dust": Color("d8b07a"), "deco": "cactus", "mount": Color("c0622f"),
			"cap": null, "tree": Color("3f8f3a"), "lake": null},
	},
	{
		"id": "laguna", "name": "Ledová laguna", "desc": "Zasněžené serpentiny u zamrzlého jezera", "seed": 37,
		"pts": [Vector2(0, 0), Vector2(140, 0), Vector2(230, -50), Vector2(240, -150), Vector2(170, -210), Vector2(80, -190),
			Vector2(20, -250), Vector2(-60, -300), Vector2(-160, -280), Vector2(-220, -200), Vector2(-200, -100), Vector2(-130, -60),
			Vector2(-90, 10), Vector2(-50, 20)],
		"boxes": [0.12, 0.38, 0.62, 0.86],
		"theme": {"sky_top": Color("5a7fcf"), "horizon": Color("e6f0ff"), "ground": Color("e4ebf4"), "ground2": Color("d5dfec"),
			"ground3": Color("f4f7fb"), "road": Color("5b6678"), "kerb_a": Color("2a7de1"), "kerb_b": Color("f7fbff"),
			"ambient": Color("f0f6ff"), "dust": Color("ffffff"), "deco": "pines", "mount": Color("dbe6f3"),
			"cap": Color("ffffff"), "tree": Color("2e6b55"), "lake": Color("a9d8f5")},
	},
]

## Item types: 0 none, 1 turbo, 2 banana, 3 missile, 4 star
enum Item { NONE, TURBO, BANANA, MISSILE, STAR }
var ITEM_NAMES := ["", "Turbo", "Banán", "Raketa", "Hvězda"]

# ---------------------------------------------------------------- settings
const SETTINGS_PATH := "user://settings.cfg"
var settings := {
	"driver": 0, "driver2": 1, "track": 0, "diff": 1, "muted": false, "name": "", "host_ip": "", "records": {},
}

# ---------------------------------------------------------------- input state
var key_down := {}          # key id -> bool (shift/ctrl keep left/right apart)
var item_queue := [false, false]
var pause_queue := false
var touch := {"active": false, "steer": 0.0, "drift": false, "brake": false, "item": false}
var _trigger_prev := {}

const K_LSHIFT := -1
const K_RSHIFT := -2
const K_LCTRL := -3
const K_RCTRL := -4

# Solo: everything drives player 1. Split: P1 = WASD side, P2 = arrows side.
var KEYS_SOLO := {
	"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "gas": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
	"drift": [KEY_SPACE, K_LSHIFT, K_RSHIFT, KEY_K], "item": [KEY_X, KEY_E, KEY_Q, KEY_L, K_LCTRL, K_RCTRL, KEY_ENTER],
}
var KEYS_P1 := {
	"left": [KEY_A], "right": [KEY_D], "gas": [KEY_W], "brake": [KEY_S],
	"drift": [KEY_SPACE, K_LSHIFT, KEY_C], "item": [KEY_E, KEY_Q, K_LCTRL],
}
var KEYS_P2 := {
	"left": [KEY_LEFT], "right": [KEY_RIGHT], "gas": [KEY_UP], "brake": [KEY_DOWN],
	"drift": [K_RSHIFT, KEY_KP_0, KEY_PERIOD], "item": [KEY_ENTER, KEY_KP_ENTER, K_RCTRL, KEY_COMMA],
}

var cmd_args := {}
var _solo_mode := true
var _local_count := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			cmd_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	load_settings()


func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")


# ---------------------------------------------------------------- helpers
static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)


static func approach(v: float, t: float, d: float) -> float:
	return minf(v + d, t) if v < t else maxf(v - d, t)


static func fmt_time(t: float) -> String:
	if t < 0.0 or is_inf(t) or is_nan(t):
		return "-:--.--"
	var cs := int(round(t * 100.0))
	return "%d:%02d.%02d" % [cs / 6000, (cs / 100) % 60, cs % 100]


func record_key(track: int, diff: int) -> String:
	return "%s_%d" % [TRACKS[track].id, diff]


func player_name() -> String:
	var n := String(settings.name).strip_edges()
	return n if n != "" else CHARS[int(settings.driver)].name


# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("game", k, settings[k])
	settings.driver = clampi(int(settings.driver), 0, CHARS.size() - 1)
	settings.driver2 = clampi(int(settings.driver2), 0, CHARS.size() - 1)
	settings.track = clampi(int(settings.track), 0, TRACKS.size() - 1)
	settings.diff = clampi(int(settings.diff), 0, DIFFS.size() - 1)
	if typeof(settings.records) != TYPE_DICTIONARY:
		settings.records = {}


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("game", k, settings[k])
	cf.save(SETTINGS_PATH)


# ---------------------------------------------------------------- input
func _key_id(e: InputEventKey) -> int:
	var code := int(e.physical_keycode) if e.physical_keycode != 0 else int(e.keycode)
	if code == KEY_SHIFT:
		return K_RSHIFT if e.location == KEY_LOCATION_RIGHT else K_LSHIFT
	if code == KEY_CTRL:
		return K_RCTRL if e.location == KEY_LOCATION_RIGHT else K_LCTRL
	return code


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var id := _key_id(event)
		key_down[id] = event.pressed
		if event.pressed and not event.echo:
			if _solo_mode:
				if id in KEYS_SOLO.item:
					item_queue[0] = true
			else:
				if id in KEYS_P1.item:
					item_queue[0] = true
				if id in KEYS_P2.item:
					item_queue[1] = true
			if id == KEY_ESCAPE or id == KEY_P:
				pause_queue = true
			if id == KEY_F11 and not is_mobile():
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	elif event is InputEventJoypadButton and event.pressed:
		var slot := _pad_slot(event.device)
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X, JOY_BUTTON_Y] and slot >= 0:
			item_queue[slot] = true
		if event.button_index == JOY_BUTTON_START:
			pause_queue = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		key_down.clear()


## Called by the race when it starts so input knows how keys are split.
func set_local_players(count: int) -> void:
	_local_count = count
	_solo_mode = count <= 1
	item_queue = [false, false]
	pause_queue = false


func _pad_slot(device: int) -> int:
	var pads := Input.get_connected_joypads()
	var i := pads.find(device)
	if i < 0:
		return -1
	if _solo_mode:
		return 0
	if pads.size() == 1:
		return 1   # one pad in split-screen: keyboard WASD for P1, pad for P2
	return i if i < 2 else -1


func _pad_for_slot(slot: int) -> int:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	if _solo_mode:
		return pads[0] if slot == 0 else -1
	if pads.size() == 1:
		return pads[0] if slot == 1 else -1
	return pads[slot] if slot < pads.size() else -1


func _any(keys: Array) -> bool:
	for k in keys:
		if key_down.get(k, false):
			return true
	return false


## Returns the controls for local player `slot` (0 or 1).
func read_input(slot: int) -> Dictionary:
	var map: Dictionary = KEYS_SOLO if _solo_mode else (KEYS_P1 if slot == 0 else KEYS_P2)
	var steer := (1.0 if _any(map.right) else 0.0) - (1.0 if _any(map.left) else 0.0)
	var gas := _any(map.gas)
	var brake := _any(map.brake)
	var drift := _any(map.drift)
	var item: bool = item_queue[slot]
	item_queue[slot] = false
	var pad := _pad_for_slot(slot)
	if pad >= 0:
		var ax := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(ax) > 0.18:
			steer = clampf((ax - signf(ax) * 0.18) / 0.7, -1.0, 1.0)
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
			steer = -1.0
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
			steer = 1.0
		gas = gas or Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		brake = brake or Input.is_joy_button_pressed(pad, JOY_BUTTON_B)
		drift = drift or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.4
		var lt := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.4
		if lt and not _trigger_prev.get(pad, false):
			item = true
		_trigger_prev[pad] = lt
	if slot == 0 and touch.active:
		if absf(touch.steer) > 0.0:
			steer = touch.steer
		brake = brake or touch.brake
		gas = gas or not brake
		drift = drift or touch.drift
		if touch.item:
			item = true
			touch.item = false
	return {"steer": steer, "gas": gas, "brake": brake, "drift": drift, "item": item}


func take_pause() -> bool:
	var p := pause_queue
	pause_queue = false
	return p
