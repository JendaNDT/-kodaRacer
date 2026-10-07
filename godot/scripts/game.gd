extends Node
## Global game data, settings and player input (keyboard, gamepads, touch).

signal tilt_found           # the tilt sensor gave its first reading: the menu offers tilting

const LAPS := 3
const HW := 11.0          # half road width
const KERB := 1.6         # kerb width
const BAR := 18.0         # barrier distance from the centre line
const KART_R := 1.25      # kart collision radius
const MAX_KARTS := 6
const SIM_DT := 1.0 / 120.0
const GRAVITY := 30.0     # arcade gravity for jumps (m/s²)

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
	# the secret one (Etapa F): only after a gold cup on Hard
	{"name": "Profesor Píst", "tag": "Tajný", "color": Color("c3cad6"), "accent": Color("d62839"), "helmet": Color("1d3557"),
		"speed": 1.03, "accel": 1.03, "handling": 1.03, "weight": 1.02, "secret": true},
]

## The second paint of each driver (body, accent, helmet), won with any cup;
## the gold one is the same for everybody and needs a gold cup on Hard.
var PAINT2 := [
	[Color("1f2329"), Color("e63946"), Color("e63946")],
	[Color("2ec4a6"), Color("ffffff"), Color("c6fff1")],
	[Color("ff7a1a"), Color("1b2a49"), Color("ffffff")],
	[Color("1a9fb5"), Color("ffd166"), Color("0b3c49")],
	[Color("c62828"), Color("f1faee"), Color("ffd166")],
	[Color("f4f4f8"), Color("8e5cf6"), Color("2b2d42")],
	[Color("16181d"), Color("ffd166"), Color("c3cad6")],
]
const GOLD_PAINT := [Color("e2b13c"), Color("3a2a10"), Color("fff1c1")]
## The battle paint (Etapa H): a win in the balloon battle on Hard with that driver.
const BATTLE_PAINT := [Color("20232d"), Color("3dffa8"), Color("ff4fa3")]
const PAINT_NAMES := ["Původní lak", "Druhý lak", "Zlatý lak", "Bitevní lak"]
const SECRET := 6

## How each driver races when the computer drives (fits the tag in the menu):
## corner: speed through bends (late braking > 1), straight: top speed on
## straights, drift: how often and how well they drift, aggr: barges into
## rivals beside them, start: extra chance of a rocket start, patience: how
## long items are kept for the right moment (0 = at once), wander: how far
## they stray from the racing line. In the balloon battle (Etapa H): hunt,
## how keen they are to go after someone (more = closer, braver), aim, how
## well they line up a shot.
var PERSONA := [
	{"corner": 1.00, "straight": 1.00, "drift": 1.00, "aggr": 0.0, "start": 0.0, "patience": 1.0, "wander": 0.10, "hunt": 1.0, "aim": 1.0},   # Turbo Tonda: balanced
	{"corner": 1.00, "straight": 1.00, "drift": 0.95, "aggr": 0.9, "start": 0.05, "patience": 0.0, "wander": 0.16, "hunt": 1.5, "aim": 0.9},   # Zuzka Zběsilá: wild
	{"corner": 1.05, "straight": 1.025, "drift": 0.85, "aggr": 0.2, "start": 0.0, "patience": 1.0, "wander": 0.10, "hunt": 1.1, "aim": 1.0},   # Pepa Plyn: brakes late
	{"corner": 1.00, "straight": 1.00, "drift": 1.00, "aggr": 0.1, "start": 0.4, "patience": 1.0, "wander": 0.10, "hunt": 1.0, "aim": 1.0},    # Máňa Motor: great starts
	{"corner": 0.97, "straight": 1.00, "drift": 0.85, "aggr": 0.0, "start": 0.0, "patience": 2.0, "wander": 0.03, "hunt": 0.6, "aim": 1.0},    # Karel Kolo: careful
	{"corner": 1.03, "straight": 1.00, "drift": 1.3, "aggr": 0.1, "start": 0.0, "patience": 1.0, "wander": 0.08, "hunt": 1.0, "aim": 1.0},     # Bára Brzda: queen of corners
	{"corner": 1.04, "straight": 1.01, "drift": 1.15, "aggr": 0.3, "start": 0.2, "patience": 1.5, "wander": 0.04, "hunt": 1.1, "aim": 1.4},   # Profesor Píst: knows every line
]

var DIFFS := [
	# ai: how close to full speed the computer drives, drift: how often it drifts
	# through a long bend, band: how strongly it catches up / waits (rubber band),
	# start: chance of a rocket start
	{"name": "Lehká", "cc": "50 ccm", "speed": 0.82, "ai": 0.835, "drift": 0.12, "band": 1.0, "start": 0.2},
	{"name": "Střední", "cc": "100 ccm", "speed": 1.00, "ai": 0.915, "drift": 0.55, "band": 0.55, "start": 0.35},
	{"name": "Těžká", "cc": "150 ccm", "speed": 1.15, "ai": 0.99, "drift": 0.92, "band": 0.15, "start": 0.6},
]

var TRACKS := [
	{
		"id": "udoli", "name": "Zelené údolí", "desc": "Pohodový okruh mezi kopci", "seed": 11,
		"pts": [Vector2(0, 0), Vector2(120, 0), Vector2(220, 10), Vector2(280, -40), Vector2(290, -120), Vector2(240, -180),
			Vector2(160, -170), Vector2(110, -120), Vector2(50, -130), Vector2(0, -200), Vector2(-80, -230), Vector2(-170, -200),
			Vector2(-210, -120), Vector2(-180, -40), Vector2(-100, 0)],
		"boxes": [0.1, 0.36, 0.6, 0.84],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 105, "b": 299, "sa": -1, "sb": -1, "bow": 0, "hand": 0.38, "slow": [0.37, 0.45, 0.48]},
		# amp: height of the rolling hills, jump_hill: the hill before the ramp, land: rolls of the land around
		"hills": {"amp": 9.0, "jump_hill": 3.0, "land": 3.5},
		"theme": {"ground": Color("4caa3c"), "ground2": Color("41983a"),
			"ground3": Color("5cb84a"), "road": Color("44464d"), "kerb_a": Color("e8333a"), "kerb_b": Color("f4f4f4"),
			"dust": Color("8a6a45"), "surface": "grass", "deco": "trees", "mount": Color("5d8c68"),
			"cap": Color("f4f8ff"), "tree": Color("2f8a3e"), "lake": Color("3d9be0"),
			# sunny afternoon: high sun, deep blue sky, crisp shadows
			"mood": {"sky_top": Color("1f6fd6"), "horizon": Color("cfe7ff"), "sun_elev": 50.0, "sun_azim": -55.0,
				"sun_color": Color("fff3df"), "sun_energy": 1.3, "disk_energy": 6.0, "sun_halo": 16.0,
				"ambient": Color("d7e8ff"), "ambient_energy": 0.6, "exposure": 1.15,
				"fog": Color("cfe7ff"), "fog_begin": 150.0, "fog_end": 950.0,
				"cloud": Color("ffffff"), "cloud_y": 110.0, "clouds": 16}},
	},
	{
		"id": "kanon", "name": "Pouštní kaňon", "desc": "Dlouhé rovinky a ostré vracečky", "seed": 23,
		"pts": [Vector2(0, 0), Vector2(160, 0), Vector2(260, -30), Vector2(300, -110), Vector2(250, -170), Vector2(150, -160),
			Vector2(90, -200), Vector2(80, -280), Vector2(150, -330), Vector2(160, -400), Vector2(60, -440), Vector2(-80, -420),
			Vector2(-150, -340), Vector2(-130, -240), Vector2(-180, -150), Vector2(-150, -60), Vector2(-90, -10)],
		"boxes": [0.08, 0.3, 0.55, 0.78],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 357, "b": 642, "sa": -1, "sb": -1, "bow": -25, "hand": 0.38, "slow": [0.43, 0.48, 0.53]},
		"hills": {"amp": 11.0, "jump_hill": 3.5, "land": 3.0},
		"theme": {"ground": Color("d9aa62"), "ground2": Color("c99852"),
			"ground3": Color("e6bb7c"), "road": Color("594b43"), "kerb_a": Color("d9480f"), "kerb_b": Color("fff1dc"),
			"dust": Color("d8b07a"), "surface": "sand", "deco": "cactus", "mount": Color("c0622f"),
			"cap": null, "tree": Color("3f8f3a"), "lake": null,
			# sunset: low orange sun, long shadows, warm haze
			"mood": {"sky_top": Color("3b4f9e"), "horizon": Color("ffab6b"), "sun_elev": 9.0, "sun_azim": 125.0,
				"sun_color": Color("ff9a52"), "sun_energy": 1.9, "disk_energy": 5.0, "sun_halo": 30.0,
				"ambient": Color("ffc9a8"), "ambient_energy": 0.55, "exposure": 1.15,
				"fog": Color("f4a874"), "fog_begin": 90.0, "fog_end": 800.0, "sky_curve": 0.18,
				"cloud": Color("ffc4a2"), "cloud_y": 120.0, "clouds": 14}},
	},
	{
		"id": "laguna", "name": "Ledová laguna", "desc": "Zasněžené serpentiny u zamrzlého jezera", "seed": 37,
		"pts": [Vector2(0, 0), Vector2(140, 0), Vector2(230, -50), Vector2(240, -150), Vector2(170, -210), Vector2(80, -190),
			Vector2(20, -250), Vector2(-60, -300), Vector2(-160, -280), Vector2(-220, -200), Vector2(-200, -100), Vector2(-130, -60),
			Vector2(-90, 10), Vector2(-50, 20)],
		"boxes": [0.12, 0.38, 0.62, 0.86],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 276, "b": 518, "sa": -1, "sb": -1, "bow": 0, "hand": 0.25, "slow": [0.50, 0.59, 0.69]},
		"hills": {"amp": 5.5, "jump_hill": 3.0, "land": 2.5},
		"theme": {"ground": Color("e4ebf4"), "ground2": Color("d5dfec"),
			"ground3": Color("f4f7fb"), "road": Color("4b5564"), "kerb_a": Color("2a7de1"), "kerb_b": Color("f7fbff"),
			"dust": Color("ffffff"), "surface": "snow", "deco": "pines", "mount": Color("dbe6f3"),
			"cap": Color("ffffff"), "tree": Color("2e6b55"), "lake": Color("a9d8f5"),
			# cold and grey: weak bluish sun, low clouds, falling snow
			"mood": {"sky_top": Color("7389b3"), "horizon": Color("dfe7f2"), "sun_elev": 24.0, "sun_azim": -150.0,
				"sun_color": Color("d8e5ff"), "sun_energy": 1.0, "disk_energy": 2.0, "sun_halo": 26.0,
				"ambient": Color("c9d8ef"), "ambient_energy": 0.7, "exposure": 1.1, "shadow_opacity": 0.85,
				"fog": Color("d9e2ee"), "fog_begin": 70.0, "fog_end": 620.0,
				"cloud": Color("e3e9f2"), "cloud_y": 62.0, "clouds": 26, "weather": "snow"}},
	},
	{
		"id": "les", "name": "Podzimní les", "desc": "Klikatá lesní silnice a rozhledna", "seed": 41,
		"pts": [Vector2(0, 0), Vector2(150, 0), Vector2(240, -30), Vector2(270, -110), Vector2(220, -180), Vector2(130, -190),
			Vector2(70, -240), Vector2(90, -320), Vector2(180, -350), Vector2(230, -420), Vector2(170, -480), Vector2(60, -470),
			Vector2(-30, -420), Vector2(-90, -330), Vector2(-170, -260), Vector2(-200, -160), Vector2(-170, -70), Vector2(-90, 0)],
		"boxes": [0.1, 0.34, 0.58, 0.82],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 213, "b": 398, "sa": 1, "sb": 1, "bow": 0, "hand": 0.38, "slow": [0.36, 0.43, 0.48]},
		"hills": {"amp": 7.0, "jump_hill": 3.0, "land": 4.0},
		"theme": {"ground": Color("8f9b3e"), "ground2": Color("7f8a35"),
			"ground3": Color("b0a64c"), "road": Color("4a4a52"), "kerb_a": Color("d9480f"), "kerb_b": Color("f7f3e8"),
			"dust": Color("8a6a45"), "surface": "grass", "deco": "autumn", "mount": Color("6f8466"),
			"cap": Color("eef2f6"), "tree": Color("e8862a"), "lake": Color("4d8fb0"),
			# golden autumn morning: low warm sun, light haze, leaves in the wind
			"mood": {"sky_top": Color("4a82c8"), "horizon": Color("f4dcb2"), "sun_elev": 26.0, "sun_azim": 40.0,
				"sun_color": Color("ffd59c"), "sun_energy": 1.35, "disk_energy": 5.0, "sun_halo": 24.0,
				"ambient": Color("eadcc4"), "ambient_energy": 0.6, "exposure": 1.12,
				"fog": Color("f0dcbc"), "fog_begin": 110.0, "fog_end": 820.0,
				"cloud": Color("fff3e3"), "cloud_y": 100.0, "clouds": 18, "weather": "leaves"}},
	},
	{
		"id": "mesto", "name": "Noční město", "desc": "Ulice mezi domy pod lampami", "seed": 53,
		"pts": [Vector2(0, 0), Vector2(160, 0), Vector2(240, -30), Vector2(260, -110), Vector2(250, -200), Vector2(190, -250),
			Vector2(110, -240), Vector2(50, -280), Vector2(30, -360), Vector2(-40, -410), Vector2(-140, -400), Vector2(-200, -330),
			Vector2(-200, -230), Vector2(-150, -160), Vector2(-170, -80), Vector2(-120, -10)],
		"boxes": [0.12, 0.36, 0.6, 0.84],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 309, "b": 612, "sa": -1, "sb": -1, "bow": 0, "hand": 0.38, "slow": [0.33, 0.37, 0.40]},
		"hills": {"amp": 6.0, "jump_hill": 3.0, "land": 1.5},
		"theme": {"ground": Color("4b515d"), "ground2": Color("434955"), "ground3": Color("59606c"),
			"road": Color("2d3037"), "kerb_a": Color("e63946"), "kerb_b": Color("eef0f4"),
			"dust": Color("9aa0aa"), "surface": "concrete", "deco": "city", "mount": Color("252b40"),
			"cap": null, "tree": Color("2f6b45"), "lake": null,
			# night: moonlight, dark blue sky with stars, lamps and lit windows
			"mood": {"sky_top": Color("070d26"), "horizon": Color("26355f"), "sun_elev": 38.0, "sun_azim": -120.0,
				"sun_color": Color("b3c3ff"), "sun_energy": 0.55, "disk_energy": 1.6, "disk_size": 1.4, "sun_halo": 5.0,
				"ambient": Color("6070a8"), "ambient_energy": 0.6, "exposure": 1.25,
				"fog": Color("1c2646"), "fog_begin": 100.0, "fog_end": 720.0, "stars": true,
				"cloud": Color("39446c"), "cloud_y": 130.0, "clouds": 8}},
	},
	{
		"id": "ostrov", "name": "Sopečný ostrov", "desc": "Palmy, moře a láva pod sopkou", "seed": 67,
		"pts": [Vector2(0, 0), Vector2(150, 0), Vector2(260, -40), Vector2(320, -130), Vector2(310, -240), Vector2(240, -320),
			Vector2(130, -350), Vector2(40, -310), Vector2(-40, -330), Vector2(-150, -300), Vector2(-230, -220), Vector2(-250, -120),
			Vector2(-200, -40), Vector2(-100, 0)],
		"boxes": [0.1, 0.35, 0.6, 0.85],
		# the shortcut, found by --trackinfo --findcuts: road samples a → b, sides, bow, curve handles;
		# slow: top speed on it (× normal) measured by --cutcal so it loses ~6 % without a turbo
		"cut": {"a": 414, "b": 677, "sa": -1, "sb": -1, "bow": 50, "hand": 0.30, "slow": [0.53, 0.62, 0.71]},
		"hills": {"amp": 7.0, "jump_hill": 3.0, "land": 3.0, "island": true},
		"theme": {"ground": Color("62b14a"), "ground2": Color("55a142"), "ground3": Color("7cc25c"),
			"road": Color("3c3838"), "kerb_a": Color("ff7b00"), "kerb_b": Color("fff3e0"),
			"dust": Color("d9c38f"), "surface": "sand", "deco": "palms", "mount": Color("4a3b38"),
			"cap": null, "tree": Color("3f9a3a"), "lake": Color("ff5a1f"), "lava": true, "sea": Color("1f8fc2"),
			# tropical noon: high sun, turquoise sea all around
			"mood": {"sky_top": Color("2a8bd8"), "horizon": Color("c4ebf3"), "sun_elev": 56.0, "sun_azim": 160.0,
				"sun_color": Color("fff1d6"), "sun_energy": 1.35, "disk_energy": 6.0, "sun_halo": 14.0,
				"ambient": Color("d6ecff"), "ambient_energy": 0.62, "exposure": 1.12,
				"fog": Color("c8e8f0"), "fog_begin": 140.0, "fog_end": 900.0,
				"cloud": Color("ffffff"), "cloud_y": 115.0, "clouds": 14}},
	},
]

## Championship: every track once, in this order of points for places 1–6.
const CUP_POINTS := [10, 8, 6, 4, 2, 1]

# ---------------------------------------------------------------- balloon battle (Etapa H)
const BALLOONS := 3            # each kart starts with this many
const BATTLE_TIME := 180.0     # seconds, then the most balloons win
const BATTLE_GUARD := 2.0      # seconds a kart cannot lose another balloon after losing one

## Arenas: built by code like the tracks (Arena: the floor and the solid
## parts, ArenaWorld: how it looks), played only in the battle.
var ARENAS := [
	{
		"id": "namesti", "name": "Náměstí", "desc": "Kašna, zídky a rampy u okrajů", "seed": 53,
		"theme": {"ground": Color("8a9a5b"), "ground2": Color("7c8c50"), "ground3": Color("98a867"),
			"floor": Color("b8ab95"), "floor2": Color("a3967f"), "road": Color("b8ab95"), "wall": Color("d9cbb2"), "trim": Color("8d4a36"),
			"kerb_a": Color("e63946"), "kerb_b": Color("f4f4f4"), "dust": Color("b8ab95"), "surface": "paving",
			"mood": {"sky_top": Color("2a74d4"), "horizon": Color("d6e9ff"), "sun_elev": 46.0, "sun_azim": -40.0,
				"sun_color": Color("fff1da"), "sun_energy": 1.3, "disk_energy": 6.0, "sun_halo": 16.0,
				"ambient": Color("dde9ff"), "ambient_energy": 0.62, "exposure": 1.15,
				"fog": Color("d6e9ff"), "fog_begin": 160.0, "fog_end": 900.0,
				"cloud": Color("ffffff"), "cloud_y": 110.0, "clouds": 14}},
	},
	{
		"id": "stadion", "name": "Ledový stadion", "desc": "Kluzký led uprostřed a sněhové valy", "seed": 67,
		"theme": {"ground": Color("e4ebf4"), "ground2": Color("d5dfec"), "ground3": Color("f4f7fb"),
			"floor": Color("eef3f9"), "floor2": Color("dde6f1"), "road": Color("eef3f9"), "wall": Color("f7fbff"), "trim": Color("2a7de1"),
			"kerb_a": Color("2a7de1"), "kerb_b": Color("f7fbff"), "dust": Color("ffffff"), "surface": "snow",
			"mood": {"sky_top": Color("6f86b4"), "horizon": Color("e1e8f3"), "sun_elev": 22.0, "sun_azim": -150.0,
				"sun_color": Color("dbe7ff"), "sun_energy": 1.05, "disk_energy": 2.0, "sun_halo": 26.0,
				"ambient": Color("ccdaf0"), "ambient_energy": 0.7, "exposure": 1.1, "shadow_opacity": 0.85,
				"fog": Color("dbe4ef"), "fog_begin": 90.0, "fog_end": 650.0,
				"cloud": Color("e3e9f2"), "cloud_y": 70.0, "clouds": 22, "weather": "snow"}},
	},
]


## Best place reached in a championship on this difficulty (0 = none yet).
func cup_best(diff: int) -> int:
	return int(settings.cups.get(str(diff), 0))


func save_cup(diff: int, place: int) -> void:
	var best := cup_best(diff)
	if best == 0 or place < best:
		settings.cups[str(diff)] = place
		save_settings()


## Time trial: best time per track and difficulty (0 = none), its ghost
## (the recorded drive) is in its own file.
func trial_best(track: int, diff: int) -> float:
	return float(settings.trials.get(record_key(track, diff), 0.0))


func ghost_path(track: int, diff: int) -> String:
	return "user://ghost_%s.dat" % record_key(track, diff)


func load_ghost(track: int, diff: int) -> Dictionary:
	var f := FileAccess.open(ghost_path(track, diff), FileAccess.READ)
	if f == null:
		return {}
	var g = f.get_var()
	return g if typeof(g) == TYPE_DICTIONARY and g.has("data") else {}


func save_ghost(track: int, diff: int, ghost: Dictionary) -> void:
	var f := FileAccess.open(ghost_path(track, diff), FileAccess.WRITE)
	if f != null:
		f.store_var(ghost)
	settings.trials[record_key(track, diff)] = float(ghost.t)
	save_settings()


## Item types: 0 none, 1 turbo, 2 banana, 3 missile, 4 star, 5 blue missile
## (flies to the leader), 6 oil puddle, 7 lightning (shrinks the others), 8 shield
enum Item { NONE, TURBO, BANANA, MISSILE, STAR, BLUE, OIL, LIGHTNING, SHIELD }
var ITEM_NAMES := ["", "Turbo", "Banán", "Raketa", "Hvězda", "Modrá raketa", "Olej", "Blesk", "Štít"]
const ITEM_COUNT := 8
const SHIELD_TIME := 10.0
const SHRINK_TIME := 6.0
const SHRINK_SCALE := 0.55       # how small the lightning makes the others
const SHRINK_SPEED := 0.78       # and how fast they can go

# ---------------------------------------------------------------- settings
const SETTINGS_PATH := "user://settings.cfg"
var settings := {
	"driver": 0, "driver2": 1, "track": 0, "diff": 1, "muted": false, "name": "", "host_ip": "", "records": {}, "cups": {}, "trials": {},
	"quality": -1, "show_fps": false,
	# Etapa F: what has been won ({key: true}), the paint chosen per driver, mirrored tracks on/off
	"unlocks": {}, "paints": {}, "mirror": false,
	# Etapa G: steering on the phone (0 = the wheel on the screen, 1 = tilting), its sensitivity, vibrations
	"steer": 0, "tilt_sens": 1, "vibrate": true,
	# Etapa H: the arena chosen for the balloon battle, battles won per difficulty
	"arena": 0, "battles": {},
}

# ---------------------------------------------------------------- input state
var key_down := {}          # key id -> bool (shift/ctrl keep left/right apart)
var item_queue := [false, false]
var pause_queue := false
var touch := {"active": false, "steer": 0.0, "drift": false, "brake": false, "item": false}
var _trigger_prev := {}
var tilt := Tilt.new()      # the phone's tilt (Etapa G), read every frame
var fake_gravity := Vector3.ZERO   # tests and screenshots: a made-up sensor

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
	if cmd_args.has("fake-gravity"):     # --fake-gravity=x,y,z: a computer pretends to be a tilted phone
		var v := String(cmd_args["fake-gravity"]).split_floats(",")
		if v.size() == 3:
			fake_gravity = Vector3(v[0], v[1], v[2])


func _process(delta: float) -> void:
	var had := tilt.have
	tilt.feed(gravity(), delta)
	if tilt.have and not had:
		tilt_found.emit()


## The gravity sensor (the accelerometer where a phone has none), in the
## screen's frame; zero on computers.
func gravity() -> Vector3:
	if fake_gravity != Vector3.ZERO:
		return fake_gravity
	var g := Input.get_gravity()
	if g.length_squared() < 1.0:
		g = Input.get_accelerometer()
	return g


## The phone is steered by tilting: chosen, and the phone has the sensor.
func tilting() -> bool:
	return int(settings.steer) == 1 and tilt.have


func is_mobile() -> bool:
	# --mobile: a computer behaves as a phone (tests of the phone's graphics settings)
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile") or cmd_args.has("mobile")


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
	return "%s%s_%d" % [TRACKS[base_track(track)].id, "_z" if is_mirror(track) else "", diff]


# ---------------------------------------------------------------- tracks
## Track numbers: 0..5 the tracks, 6..11 the same ones mirrored (Etapa F).
## Everything that names a track (races, records, ghosts, Wi-Fi) uses them.
func track_count() -> int:
	return TRACKS.size() * 2


func base_track(t: int) -> int:
	return t % TRACKS.size()


func is_mirror(t: int) -> bool:
	return t >= TRACKS.size()


## The track to race: the setting's track, mirrored when that is switched on.
func race_track(base: int, mirror: bool) -> int:
	return base + (TRACKS.size() if mirror else 0)


## The definition a Track is built from; a mirrored one has every point and
## the shortcut's sides flipped left to right (the rest follows by itself).
func track_def(t: int) -> Dictionary:
	var d: Dictionary = TRACKS[base_track(t)]
	if not is_mirror(t):
		return d
	var m := d.duplicate(true)
	var pts: Array = []
	for p in d.pts:
		pts.append(Vector2(-p.x, p.y))
	m.pts = pts
	if m.has("cut"):
		for k in ["sa", "sb", "bow"]:
			m.cut[k] = -float(m.cut[k])
	m.name = String(d.name) + " · zrcadlově"
	m.mirror = true
	return m


# ---------------------------------------------------------------- unlocks (Etapa F)
func unlocked(key: String) -> bool:
	return bool(settings.unlocks.get(key, false))


## The secret driver can be picked only once won (others still see him).
func driver_open(d: int) -> bool:
	return d >= 0 and d < CHARS.size() and (not CHARS[d].get("secret", false) or unlocked("secret"))


## The first driver that can be picked and is not in `taken`.
func free_driver(taken: Array) -> int:
	for i in CHARS.size():
		if driver_open(i) and not (i in taken):
			return i
	return 0


## Drivers the computer may race with: everybody won so far.
func open_drivers() -> Array:
	var out: Array = []
	for i in CHARS.size():
		if driver_open(i):
			out.append(i)
	return out


func paint_open(d: int, p: int) -> bool:
	return p == 0 or unlocked("paint%d_%d" % [p, d])


## The paint this player has chosen for driver d (back to the first if not won).
func paint_of(d: int) -> int:
	var p := int(settings.paints.get(str(d), 0))
	return p if p >= 0 and p < PAINT_NAMES.size() and paint_open(d, p) else 0


func set_paint(d: int, p: int) -> void:
	settings.paints[str(d)] = p
	save_settings()


## A driver's colours in a paint: the driver itself with body, accent and
## helmet swapped (gold also shines like metal: "shiny").
func look(d: int, p: int) -> Dictionary:
	var ch: Dictionary = CHARS[d]
	if p <= 0:
		return ch
	var c: Array = PAINT2[d] if p == 1 else (GOLD_PAINT if p == 2 else BATTLE_PAINT)
	var out := ch.duplicate()
	out.color = c[0]
	out.accent = c[1]
	out.helmet = c[2]
	out.shiny = p == 2
	return out


## What each reward is called (the Collection and "Odemčeno: …").
func unlock_name(key: String) -> String:
	if key.begins_with("paint"):
		var p := int(key.substr(5, 1))
		var d := int(key.substr(7))
		return "%s – %s" % [CHARS[d].name, ["", "druhý lak", "zlatý lak", "bitevní lak"][clampi(p, 0, 3)]]
	match key:
		"mirror": return "Zrcadlové tratě"
		"secret": return "Tajný jezdec %s" % CHARS[SECRET].name
		"dev": return "Duch vývojáře v časovce"
	return key


func _unlock(key: String, out: Array) -> void:
	if not unlocked(key):
		settings.unlocks[key] = true
		out.append(key)


## A finished championship: `drivers` are the local players' drivers, place
## the best of them. Returns what was won just now (saved at once).
## Any cup: second paint. Gold on Normal or Hard: mirrored tracks. Gold on
## Hard: the gold paint and the secret driver.
func award_cup(drivers: Array, diff: int, place: int) -> Array:
	var out: Array = []
	save_cup(diff, place)
	if place <= 3:
		for d in drivers:
			_unlock("paint1_%d" % int(d), out)
	if place == 1 and diff >= 1:
		_unlock("mirror", out)
	if place == 1 and diff >= 2:
		for d in drivers:
			_unlock("paint2_%d" % int(d), out)
		_unlock("secret", out)
	if not out.is_empty():
		save_settings()
	return out


## The developer's ghost: a fast drive on each track and difficulty, kept
## with the game (made by --devghosts). On a mirrored track it is mirrored.
func dev_ghost(t: int, diff: int) -> Dictionary:
	var path := "res://ghosts/dev_%s_%d.dat" % [TRACKS[base_track(t)].id, diff]
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var g = f.get_var()
	if typeof(g) != TYPE_DICTIONARY or not g.has("data"):
		return {}
	if is_mirror(t):
		var d: PackedFloat32Array = (g.data as PackedFloat32Array).duplicate()
		for i in range(0, d.size(), 6):
			d[i + 1] = -d[i + 1]          # x
			d[i + 4] = -d[i + 4]          # heading
		g.data = d
	return g


## The time trial limit for the developer's ghost: 10 % slower than him
## (rounded up to half a second); 0 = no ghost for this track.
func dev_limit(t: int, diff: int) -> float:
	var g := dev_ghost(base_track(t), diff)
	return ceilf(float(g.t) * 1.1 * 2.0) / 2.0 if not g.is_empty() else 0.0


## Tracks where a time trial (any difficulty) beat the limit.
func dev_done(t: int) -> bool:
	for d in DIFFS.size():
		var lim := dev_limit(t, d)
		var best := trial_best(t, d)
		if lim > 0.0 and best > 0.0 and best <= lim:
			return true
	return false


## After a balloon battle: a win on Hard gives each winning local player's
## driver the battle paint. `drivers`: the local players' drivers who won.
func award_battle(drivers: Array, diff: int) -> Array:
	var out: Array = []
	settings.battles[str(diff)] = int(settings.battles.get(str(diff), 0)) + drivers.size()
	if diff >= 2:
		for d in drivers:
			_unlock("paint3_%d" % int(d), out)
	save_settings()
	return out


## After a time trial: all tracks under the limit wins the developer's ghost.
func award_trial() -> Array:
	var out: Array = []
	for t in TRACKS.size():
		if not dev_done(t):
			return out
	_unlock("dev", out)
	if not out.is_empty():
		save_settings()
	return out


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
	# -1 = not chosen yet: phones start on Střední, computers on Vysoká
	if int(settings.quality) < 0:
		settings.quality = 1 if is_mobile() else 2
	if int(settings.quality) > 2:
		settings.quality = 1             # a test level of 1.16.0's trial build: back to Střední
	settings.quality = clampi(int(settings.quality), 0, 2)
	settings.show_fps = bool(settings.show_fps)
	settings.steer = clampi(int(settings.steer), 0, 1)
	settings.tilt_sens = clampi(int(settings.tilt_sens), 0, Tilt.NAMES.size() - 1)
	settings.vibrate = bool(settings.vibrate)
	if typeof(settings.records) != TYPE_DICTIONARY:
		settings.records = {}
	if typeof(settings.cups) != TYPE_DICTIONARY:
		settings.cups = {}
	if typeof(settings.trials) != TYPE_DICTIONARY:
		settings.trials = {}
	settings.arena = clampi(int(settings.arena), 0, ARENAS.size() - 1)
	for k in ["unlocks", "paints", "battles"]:
		if typeof(settings[k]) != TYPE_DICTIONARY:
			settings[k] = {}
	settings.mirror = bool(settings.mirror) and unlocked("mirror")
	if not driver_open(int(settings.driver)):
		settings.driver = 0
	if not driver_open(int(settings.driver2)) or int(settings.driver2) == int(settings.driver):
		settings.driver2 = free_driver([int(settings.driver)])


var save_off := false      # tests that make up results do not write them down


func save_settings() -> void:
	if save_off:
		return
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
		if tilting():
			var ts := tilt.steer(int(settings.tilt_sens))
			if absf(ts) > 0.0:
				steer = ts
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
