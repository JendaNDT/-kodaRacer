class_name UI
extends RefCounted
## Shared look: palette, fonts, theme and small builders for menu widgets.

const INK := Color("0d111b")
const INK2 := Color("172034")
const INK3 := Color("1f2a44")
const PANEL := Color(0.051, 0.067, 0.106, 0.92)
const LINE := Color(0.925, 0.945, 0.98, 0.16)
const PAPER := Color("ecf1fa")
const MUTED := Color("9aa6bd")
const KERB := Color("ef3340")
const KERB_DARK := Color("9d1d27")
const GOLD := Color("ffc43d")
const SILVER := Color("d5dbe6")
const BRONZE := Color("e08a4f")
const GO := Color("36d47c")

static var display_font: FontFile
static var body_font: FontFile
static var bold_font: FontFile
static var theme: Theme
static var _checker: ImageTexture
static var _kerb: ImageTexture


static func _font(base: String, weight: int) -> FontFile:
	var f: FontFile = load("res://fonts/%s-latin-%d-normal.woff2" % [base, weight])
	var ext: FontFile = load("res://fonts/%s-latin-ext-%d-normal.woff2" % [base, weight])
	f.fallbacks = [ext]
	return f


static func init() -> void:
	if theme != null:
		return
	display_font = _font("bungee", 400)
	body_font = _font("barlow-semi-condensed", 600)
	bold_font = _font("barlow-semi-condensed", 800)
	theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", PAPER)

	# selected (a pressed toggle) = gold fill with dark text; the keyboard /
	# gamepad cursor is drawn apart by FocusRing, so the theme has no focus look
	var normal := box(INK2, 10, 2, Color(0, 0, 0, 0))
	var hover := box(INK3, 10, 2, LINE)
	var pressed := box(GOLD, 10, 2, GOLD)
	var hover_pressed := box(GOLD.lightened(0.12), 10, 2, GOLD.lightened(0.12))
	var disabled := box(Color(INK2, 0.5), 10, 2, Color(0, 0, 0, 0))
	for s in [normal, hover, pressed, hover_pressed, disabled]:
		s.content_margin_left = 14; s.content_margin_right = 14
		s.content_margin_top = 8; s.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", hover_pressed)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", PAPER)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_hover_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_font("font", "Button", bold_font)

	var le := box(INK2, 10, 2, LINE)
	le.content_margin_left = 12; le.content_margin_right = 12
	le.content_margin_top = 8; le.content_margin_bottom = 8
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), 10, 2, GOLD))
	theme.set_color("font_color", "LineEdit", PAPER)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", GOLD)

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, 0, 0, Color(0, 0, 0, 0)))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.25)
	sb.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", sb)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb)
	var sc := StyleBoxEmpty.new()
	sc.content_margin_left = 6
	theme.set_stylebox("scroll", "VScrollBar", sc)


static func box(bg: Color, radius: int, border: int, border_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.anti_aliasing = true
	return s


static func label(text: String, size := 20, color := PAPER, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func caps(text: String) -> Label:
	var l := label(text.to_upper(), 15, MUTED, bold_font)
	return l


static func button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		var n := box(KERB, 12, 0, Color(0, 0, 0, 0))
		n.shadow_color = KERB_DARK
		n.shadow_size = 0
		n.expand_margin_bottom = 0
		n.content_margin_top = 12; n.content_margin_bottom = 12
		n.content_margin_left = 18; n.content_margin_right = 18
		var h: StyleBoxFlat = n.duplicate()
		h.bg_color = KERB.lightened(0.08)
		var p: StyleBoxFlat = n.duplicate()
		p.bg_color = KERB.darkened(0.15)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_stylebox_override("hover_pressed", p)
		b.add_theme_font_override("font", display_font)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
	else:
		b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func(): Sfx.play("ui", 0.6))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Text colour on a choice tile: dark on the gold fill of the selected one.
static func on_tile(selected: bool, color: Color) -> Color:
	if not selected:
		return color
	return INK if color == PAPER else Color(INK, 0.72)


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func grid(cols: int, sep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func checker(height := 12) -> TextureRect:
	var q := maxi(2, height / 2)
	if _checker == null or _checker.get_width() != q * 2:
		var img := Image.create_empty(q * 2, q * 2, false, Image.FORMAT_RGBA8)
		for yy in q * 2:
			for xx in q * 2:
				img.set_pixel(xx, yy, PAPER if ((xx / q) + (yy / q)) % 2 == 0 else INK)
		_checker = ImageTexture.create_from_image(img)
	var t := TextureRect.new()
	t.texture = _checker
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(0, q * 2)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func kerb_strip(height := 8) -> TextureRect:
	if _kerb == null:
		var img := Image.create(36, 8, false, Image.FORMAT_RGBA8)
		for yy in 8:
			for xx in 36:
				img.set_pixel(xx, yy, KERB if xx < 18 else PAPER)
		_kerb = ImageTexture.create_from_image(img)
	var t := TextureRect.new()
	t.texture = _kerb
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(0, height)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func panel_style(radius := 16) -> StyleBoxFlat:
	var s := box(PANEL, radius, 1, LINE)
	return s


static func place_color(rank: int) -> Color:
	match rank:
		1: return GOLD
		2: return SILVER
		3: return BRONZE
	return PAPER
