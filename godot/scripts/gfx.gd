class_name Gfx
extends RefCounted
## Graphics quality: Nízká / Střední / Vysoká. This table is the one place
## that decides what each level turns on.
## Keep glow on wherever shadows are on: tonemapping then happens once after
## the shadowed sun pass instead of per pass (see Atmosphere._shadowed_sun).

enum { LOW, MEDIUM, HIGH }

const NAMES := ["Nízká", "Střední", "Vysoká"]

const LEVELS := [
	{	# Nízká – slower phones
		"msaa": Viewport.MSAA_DISABLED, "scale_pc": 0.7, "scale_mobile": 0.55,
		"particles": 0.4, "foliage": 0.45, "skids": 160, "kart_lod": 10.0, "crowd": 0.35,
		"shadows": false, "glow": false, "ssao": false, "weather": 0.0,
		"shadow_dist": 0.0, "shadow_splits": 2, "shadow_size": 2048, "shadow_filter": 0, "boost": 1.0,
	},
	{	# Střední – default on phones
		"msaa": Viewport.MSAA_2X, "scale_pc": 1.0, "scale_mobile": 0.75,
		"particles": 0.75, "foliage": 0.75, "skids": 360, "kart_lod": 16.0, "crowd": 0.65,
		"shadows": true, "glow": true, "ssao": false, "weather": 0.6,
		"shadow_dist": 55.0, "shadow_splits": 2, "shadow_size": 2048, "shadow_filter": 0, "boost": 1.8,
	},
	{	# Vysoká – default on computers
		"msaa": Viewport.MSAA_4X, "scale_pc": 1.0, "scale_mobile": 0.9,
		"particles": 1.0, "foliage": 1.0, "skids": 700, "kart_lod": 32.0, "crowd": 1.0,
		"shadows": true, "glow": true, "ssao": true, "weather": 1.0,
		"shadow_dist": 85.0, "shadow_splits": 4, "shadow_size": 4096, "shadow_filter": 4, "boost": 1.8,
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


## Share of grandstand seats with a fan in them.
static func crowd() -> float:
	return float(_val("crowd"))


## Karts farther from the camera than this (metres) switch to their
## simpler model, and their drivers drop the arms and steering wheel.
static func kart_lod() -> float:
	return float(_val("kart_lod"))


## Light and atmosphere (Atmosphere, Kart, Race) read these.
static func shadows() -> bool:
	return bool(_val("shadows"))


## How far from the camera the sun still casts shadows (metres).
static func shadow_distance() -> float:
	return float(_val("shadow_dist"))


## Shadow map cascades: 1, 2 or 4 (phones at most 2).
static func shadow_splits() -> int:
	var n := int(_val("shadow_splits"))
	return mini(n, 2) if Game.is_mobile() else n


static func shadow_size() -> int:
	return mini(2048, int(_val("shadow_size"))) if Game.is_mobile() else int(_val("shadow_size"))


## Soft shadow edges: 0 hard, 2 = 5 samples, 4 = 13 samples.
static func shadow_filter() -> RenderingServer.ShadowQuality:
	var q := int(_val("shadow_filter"))
	if Game.is_mobile():
		q = mini(q, 2)
	return q as RenderingServer.ShadowQuality


static func glow() -> bool:
	return bool(_val("glow"))


## Brightness multiplier for flames, sparks and other glowing things: above
## 1 they bloom with glow on, 1 keeps them as they always were.
static func boost() -> float:
	return float(_val("boost"))


static func ssao() -> bool:
	return bool(_val("ssao"))


static func weather() -> float:
	return float(_val("weather"))
