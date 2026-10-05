class_name Gfx
extends RefCounted
## Graphics quality: Nízká / Střední / Vysoká. This table is the one place
## that decides what each level turns on.

enum { LOW, MEDIUM, HIGH }

const NAMES := ["Nízká", "Střední", "Vysoká"]

const LEVELS := [
	{	# Nízká – slower phones
		"msaa": Viewport.MSAA_DISABLED, "scale_pc": 0.7, "scale_mobile": 0.55,
		"particles": 0.4, "foliage": 0.45, "skids": 160,
		"shadows": false, "glow": false, "ssao": false, "weather": 0.0,
	},
	{	# Střední – default on phones
		"msaa": Viewport.MSAA_2X, "scale_pc": 1.0, "scale_mobile": 0.75,
		"particles": 0.75, "foliage": 0.75, "skids": 360,
		"shadows": true, "glow": true, "ssao": false, "weather": 0.6,
	},
	{	# Vysoká – default on computers
		"msaa": Viewport.MSAA_4X, "scale_pc": 1.0, "scale_mobile": 0.9,
		"particles": 1.0, "foliage": 1.0, "skids": 700,
		"shadows": true, "glow": true, "ssao": true, "weather": 1.0,
	},
]


static func default_level() -> int:
	return MEDIUM if Game.is_mobile() else HIGH


static func level() -> int:
	return clampi(int(Game.settings.quality), LOW, HIGH)


static func level_name() -> String:
	return NAMES[level()]


static func _val(key: String) -> Variant:
	return LEVELS[level()][key]


## Cycles Nízká → Střední → Vysoká → Nízká and saves the choice.
static func cycle() -> int:
	Game.settings.quality = (level() + 1) % NAMES.size()
	Game.save_settings()
	return level()


static func msaa() -> Viewport.MSAA:
	var m: Viewport.MSAA = _val("msaa")
	# 4× MSAA is too heavy for phones even on the top level
	if Game.is_mobile() and m == Viewport.MSAA_4X:
		return Viewport.MSAA_2X
	return m


## Fraction of the screen resolution the 3D view is rendered at.
static func render_scale() -> float:
	return float(_val("scale_mobile" if Game.is_mobile() else "scale_pc"))


## Scales a particle count for the current level (never below 2).
static func amount(n: int) -> int:
	return maxi(2, int(round(n * float(_val("particles")))))


## Multiplier for trees, bushes, cacti, rocks and clouds.
static func foliage() -> float:
	return float(_val("foliage"))


## How many tyre-mark strips stay on the road at once.
static func skid_marks() -> int:
	return int(_val("skids"))


## Phase 1 (light and atmosphere) reads these.
static func shadows() -> bool:
	return bool(_val("shadows"))


static func glow() -> bool:
	return bool(_val("glow"))


static func ssao() -> bool:
	return bool(_val("ssao"))


static func weather() -> float:
	return float(_val("weather"))
