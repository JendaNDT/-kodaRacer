class_name Menu
extends Control
## Main menu docked on the left over the live demo race:
## home, race setup (1 or 2 players), Wi-Fi game and lobby. The chosen
## kart turns on a pedestal, the driver buttons show each kart in 3D.

signal start_offline(players: int)
signal start_cup(players: int)
signal start_trial
signal quit_requested
signal track_changed
signal quality_changed

var panel: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var screen := "home"
var players := 1
var setup_mode := "race"      # setup screen: "race", "cup" (championship) or "trial" (time trial)
var status_text := ""
var _hosts_box: VBoxContainer
var _status_l: Label


class Swatch:
	extends Control
	var body := Color.WHITE
	var helmet := Color.WHITE
	func _init(b: Color, h: Color) -> void:
		body = b
		helmet = h
		custom_minimum_size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, body)
		draw_circle(c - Vector2(0, r * 0.08), r * 0.42, helmet)


class Bar:
	extends Control
	var value := 0.5
	var color := Color.WHITE
	var back := Color(1, 1, 1, 0.1)
	func _init(v: float, c: Color, on_gold := false) -> void:
		value = v
		color = c
		if on_gold:
			back = Color(UI.INK, 0.18)
		custom_minimum_size = Vector2(40, 5)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), color)


## A little trophy: gold, silver or bronze when won, a dim outline when not.
class CupIcon:
	extends Control
	var color := Color.WHITE
	var won := false
	func _init(c: Color, w: bool) -> void:
		color = c
		won = w
		custom_minimum_size = Vector2(34, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := color if won else Color(1, 1, 1, 0.13)
		var w := size.x
		var h := size.y
		var bowl := PackedVector2Array([Vector2(w * 0.18, h * 0.08), Vector2(w * 0.82, h * 0.08), Vector2(w * 0.74, h * 0.4),
			Vector2(w * 0.58, h * 0.55), Vector2(w * 0.42, h * 0.55), Vector2(w * 0.26, h * 0.4)])
		draw_colored_polygon(bowl, c)
		draw_arc(Vector2(w * 0.17, h * 0.24), w * 0.13, PI * 0.5, PI * 1.5, 10, c, 2.5)
		draw_arc(Vector2(w * 0.83, h * 0.24), w * 0.13, -PI * 0.5, PI * 0.5, 10, c, 2.5)
		draw_rect(Rect2(w * 0.45, h * 0.55, w * 0.1, h * 0.22), c)
		draw_rect(Rect2(w * 0.26, h * 0.77, w * 0.48, h * 0.15), c)
		if won:
			draw_line(Vector2(w * 0.32, h * 0.14), Vector2(w * 0.38, h * 0.36), Color(1, 1, 1, 0.55), 2.0)


class TrackThumb:
	extends Control
	var idx := 0
	var active := false
	func _init(i: int, a: bool) -> void:
		idx = i
		active = a
		custom_minimum_size = Vector2(0, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var tr := Race.get_track(idx)
		var th: Dictionary = tr.def.theme
		var bg: Color = th.ground
		bg.a = 0.35
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		var pad := 10.0
		var sc := minf((size.x - 2 * pad) / (tr.max_x - tr.min_x), (size.y - 2 * pad) / (tr.max_z - tr.min_z))
		var pts := PackedVector2Array()
		var i := 0
		while i <= tr.n:
			var j := i % tr.n
			pts.append(size * 0.5 - Vector2((tr.x[j] - tr.cx) * sc, (tr.z[j] - tr.cz) * sc))
			i += 4
		pts.append(pts[0])
		draw_polyline(pts, th.kerb_a, 7.0, true)
		draw_polyline(pts, Color.WHITE if active else Color("c9d1e0"), 3.5, true)
		draw_rect(Rect2(pts[0] - Vector2(4, 4), Vector2(8, 8)), Color("111111"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 0, 0, Color(0, 0, 0, 0)))
	panel.anchor_bottom = 1.0
	panel.offset_right = 520
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # the gamepad cursor never leaves the screen
	panel.add_child(scroll)
	content = UI.vbox(16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := UI.margin(content, 28, 22, 24, 24)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(m)
	KartStage.host_thumbs(self)
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.hosts_changed.connect(_fill_hosts)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(set_status)


func _on_lobby_changed() -> void:
	if screen == "lobby" and visible:
		show_screen("lobby")


func _on_joined() -> void:
	set_status("")
	show_screen("lobby")


func set_status(t: String) -> void:
	status_text = t
	if _status_l != null and is_instance_valid(_status_l):
		_status_l.text = t
		_status_l.visible = t != ""


func show_screen(name: String) -> void:
	if screen == "wifi" and name != "wifi":
		Net.stop_listening()
	# the same screen built again (an option picked, the lobby changed): the
	# cursor and the scroll stay where they were
	var keep := -1
	var keep_scroll := 0
	if name == screen:
		var f := get_viewport().gui_get_focus_owner()
		keep = _buttons(content).find(f)
		keep_scroll = scroll.scroll_vertical
	screen = name
	_hosts_box = null
	_status_l = null
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	match name:
		"home": _home()
		"setup": _setup()
		"wifi": _wifi()
		"lobby": _lobby()
		"collection": _collection()
	scroll.scroll_vertical = keep_scroll
	_place_cursor.call_deferred(keep, keep_scroll)


## The cursor starts on the selected option of the first choice on the
## screen (or the first button); after a rebuild it stays on its place.
func _place_cursor(keep: int, keep_scroll: int) -> void:
	scroll.scroll_vertical = keep_scroll
	var all := _buttons(content)
	var pick: Button = null
	if keep >= 0 and keep < all.size() and not all[keep].disabled:
		pick = all[keep]
	for b in all:
		if pick == null and b.toggle_mode and b.button_pressed and not b.disabled:
			pick = b
	for b in all:
		if pick == null and not b.disabled:
			pick = b
	if pick != null:
		pick.grab_focus()


## Every visible button on the screen, in reading order.
func _buttons(n: Node, out: Array[Button] = []) -> Array[Button]:
	for c in n.get_children():
		if c is Button and c.visible:
			out.append(c)
		_buttons(c, out)
	return out


## Android back button / Escape in the menu.
func back() -> bool:
	match screen:
		"setup", "wifi", "collection":
			show_screen("home")
			return true
		"lobby":
			Net.leave()
			show_screen("wifi")
			return true
	return false


# ---------------------------------------------------------------- pieces
func _brand(small := false) -> void:
	var row := UI.hbox(14)
	row.add_child(UI.label("ŠKODA", 36 if small else 52, UI.PAPER, UI.display_font))
	row.add_child(UI.label("RACER", 36 if small else 52, UI.KERB, UI.display_font))
	content.add_child(row)
	content.add_child(UI.checker(12))


func _text(t: String, size := 18, color := UI.MUTED) -> Label:
	var l := UI.label(t, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	content.add_child(l)
	return l


func _section(title: String) -> VBoxContainer:
	var v := UI.vbox(8)
	v.add_child(UI.caps(title))
	content.add_child(v)
	return v


func _driver_grid(selected: int, taken: Array, on_pick: Callable) -> GridContainer:
	var g := UI.grid(3, 8)
	var group := ButtonGroup.new()
	for i in Game.CHARS.size():
		var ch: Dictionary = Game.CHARS[i]
		var sel := i == selected
		var locked := not Game.driver_open(i)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = sel
		b.disabled = i in taken or locked
		b.custom_minimum_size = Vector2(120, 186)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_top = 9
		v.offset_right = -10
		v.offset_bottom = -9
		b.add_child(v)
		v.add_child(_kart_picture(i, 64.0, Game.paint_of(i)))
		var nl := UI.label(ch.name, 17, UI.on_tile(sel, UI.PAPER), UI.bold_font)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(nl)
		var tl := UI.label("zamčený" if locked else (ch.tag if not (i in taken) else "obsazeno"), 14,
			UI.GOLD if locked else UI.on_tile(sel, UI.MUTED))
		tl.clip_text = true
		v.add_child(tl)
		for st in [["RYCH", ch.speed], ["ZRYCH", ch.accel], ["OVL", ch.handling]]:
			var h := UI.hbox(4)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := UI.label(st[0], 11, UI.on_tile(sel, UI.MUTED), UI.bold_font)
			l.custom_minimum_size = Vector2(40, 0)
			h.add_child(l)
			h.add_child(Bar.new(clampf((float(st[1]) - 0.85) / 0.3, 0.08, 1.0), ch.color, sel))
			v.add_child(h)
		b.pressed.connect(func(): on_pick.call(i))
		b.pressed.connect(func(): Sfx.play("ui", 0.6))
		g.add_child(b)
	return g


## The kart's 3D picture (a colour dot where nothing can be rendered).
func _kart_picture(d: int, height: float, paint := 0) -> Control:
	var tex := KartStage.thumb(d, paint)
	if tex == null:
		var ch: Dictionary = Game.look(d, paint)
		return Swatch.new(ch.color, ch.helmet)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(height * 1.55, height)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _track_grid(selected: int, enabled: bool, on_pick: Callable, trial := false, mirror := false) -> GridContainer:
	var g := UI.grid(3, 8)
	var group := ButtonGroup.new()
	for i in Game.TRACKS.size():
		var td: Dictionary = Game.TRACKS[i]
		var sel := i == selected
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = sel
		b.disabled = not enabled and i != selected
		b.custom_minimum_size = Vector2(120, 176)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 8
		v.offset_top = 8
		v.offset_right = -8
		v.offset_bottom = -8
		b.add_child(v)
		var rt := Game.race_track(i, mirror)
		v.add_child(TrackThumb.new(rt, i == selected))
		var tn := UI.label(td.name, 16, UI.on_tile(sel, UI.PAPER), UI.bold_font)
		tn.clip_text = true
		tn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(tn)
		var rec: Dictionary = Game.settings.records.get(Game.record_key(rt, int(Game.settings.diff)), {})
		var info := UI.label("Rekord " + Game.fmt_time(rec.total) if rec.has("total") else td.desc, 13,
			UI.on_tile(sel, UI.GOLD if rec.has("total") else UI.MUTED))
		if trial:
			var tt := Game.trial_best(rt, int(Game.settings.diff))
			info = UI.label("Časovka " + Game.fmt_time(tt) if tt > 0.0 else "Zatím bez času", 13,
				UI.on_tile(sel, UI.GO if tt > 0.0 else UI.MUTED))
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(60, 0)
		v.add_child(info)
		if enabled:
			b.pressed.connect(func(): on_pick.call(i))
			b.pressed.connect(func(): Sfx.play("ui", 0.6))
		g.add_child(b)
	return g


func _diff_row(selected: int, enabled: bool, on_pick: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	var group := ButtonGroup.new()
	for i in Game.DIFFS.size():
		var d: Dictionary = Game.DIFFS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.disabled = not enabled and i != selected
		b.text = "%s\n%s" % [d.name, d.cc]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		if enabled:
			b.pressed.connect(func(): on_pick.call(i))
			b.pressed.connect(func(): Sfx.play("ui", 0.6))
		h.add_child(b)
	return h


## Paints of one driver: the own colours, the second paint (any cup with
## this driver) and gold (a gold cup on Hard); not yet won ones are locked.
func _paint_row(d: int, selected: int, on_pick: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	var group := ButtonGroup.new()
	for p in Game.PAINT_NAMES.size():
		var open := Game.paint_open(d, p)
		var look := Game.look(d, p)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = p == selected
		b.disabled = not open
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UI.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -8
		b.add_child(row)
		var sw := Swatch.new(look.color, look.accent)
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var l := UI.label(Game.PAINT_NAMES[p] + ("" if open else "\nzamčený"), 14,
			UI.on_tile(p == selected, UI.PAPER if open else UI.MUTED), UI.bold_font)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		if open:
			b.pressed.connect(func(): on_pick.call(p))
			b.pressed.connect(func(): Sfx.play("ui", 0.6))
		h.add_child(b)
	return h


## Normal or mirrored tracks (once won with a gold cup on Normal).
func _mirror_row(on: bool, enabled: bool, on_pick: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	var group := ButtonGroup.new()
	for m in 2:
		var b := Button.new()
		b.text = ["Normální", "Zrcadlové"][m]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = on == (m == 1)
		b.disabled = not enabled and on != (m == 1)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if enabled:
			b.pressed.connect(func(): on_pick.call(m == 1))
			b.pressed.connect(func(): Sfx.play("ui", 0.6))
		h.add_child(b)
	return h


func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(b)
	return b


# ---------------------------------------------------------------- screens
func _home() -> void:
	_brand()
	_text("Tři kola, šest jezdců a otazníky plné překvapení. Driftuj v zatáčkách pro turbo a dojeď první.")
	_wide(UI.button("Závod", _go_setup.bind(1), true))
	_wide(UI.button("Mistrovství (6 tratí)", _go_setup.bind(1, "cup")))
	_wide(UI.button("Časovka proti rekordu", _go_setup.bind(1, "trial")))
	if not Game.is_mobile():
		_wide(UI.button("2 hráči na jednom počítači", _go_setup.bind(2)))
	_wide(UI.button("Hra po Wi-Fi (crossplay)", show_screen.bind("wifi")))
	_wide(UI.button("Sbírka: poháry a odměny", show_screen.bind("collection")))
	var row := UI.hbox(8)
	content.add_child(row)
	var mute := _small_button(_mute_text())
	mute.pressed.connect(_toggle_mute.bind(mute))
	row.add_child(mute)
	var gfx := _small_button(_gfx_text())
	gfx.pressed.connect(_cycle_quality.bind(gfx))
	row.add_child(gfx)
	var fps := _small_button(_fps_text())
	fps.pressed.connect(_toggle_fps.bind(fps))
	row.add_child(fps)
	if not Game.is_mobile():
		_wide(UI.button("Konec", func(): quit_requested.emit()))
	var help := _section("Ovládání")
	var lines := [
		"Klávesnice: šipky nebo WASD, drift mezerník / Shift, předmět X nebo E, pauza Esc, celá obrazovka F11.",
		"Ovladač: A plyn, B brzda, RB/RT drift, LB/LT nebo X předmět, Start pauza.",
		"Drift: drž ho v zatáčce, po modrých a oranžových jiskrách pusť a dostaneš turbo.",
		"Na mobilu plyn běží sám. Vlevo zatáčíš, vpravo je drift, předmět a brzda.",
	]
	for t in lines:
		var l := UI.label(t, 16, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		help.add_child(l)
	_text("Verze %s · Neoficiální fanouškovská hra. Nesouvisí se společností Škoda Auto." % Net.version, 14)


func _setup() -> void:
	_brand(true)
	if players == 2 and setup_mode == "trial":
		setup_mode = "race"
	var heading: String = {"race": "Závod", "cup": "Mistrovství", "trial": "Časovka"}[setup_mode] if players == 1 \
		else "2 hráči na jednom počítači"
	content.add_child(UI.label(heading, 26, UI.PAPER, UI.bold_font))
	# one race, the championship over all tracks or a time trial (alone)
	var modes := UI.hbox(8)
	content.add_child(modes)
	var opts := [["race", "Jeden závod"], ["cup", "Mistrovství"]]
	if players == 1:
		opts.append(["trial", "Časovka"])
	var group := ButtonGroup.new()
	for o in opts:
		var mb := Button.new()
		mb.text = String(o[1])
		mb.toggle_mode = true
		mb.button_group = group
		mb.button_pressed = setup_mode == String(o[0])
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.pressed.connect(func():
			setup_mode = String(o[0])
			Sfx.play("ui", 0.6)
			show_screen("setup"))
		modes.add_child(mb)
	if players == 2 and int(Game.settings.driver2) == int(Game.settings.driver):
		Game.settings.driver2 = Game.free_driver([int(Game.settings.driver)])
	for p in players:
		var key := "driver" if p == 0 else "driver2"
		var other := "driver2" if p == 0 else "driver"
		var sec := _section("Jezdec" if players == 1 else "Hráč %d – jezdec" % (p + 1))
		var taken: Array = [int(Game.settings[other])] if players == 2 else []
		var d := int(Game.settings[key])
		sec.add_child(KartStage.new(d, 170.0 if players == 2 else 200.0, Game.paint_of(d)))
		sec.add_child(_driver_grid(d, taken, _pick_driver.bind(key)))
		sec.add_child(_paint_row(d, Game.paint_of(d), _pick_paint.bind(d)))
	if setup_mode == "cup":
		var cs := _section("Mistrovství: všech %d tratí za sebou" % Game.TRACKS.size())
		cs.add_child(_cup_tracks())
		var pts := Game.CUP_POINTS.map(func(p): return str(p))
		var info := UI.label("Body za 1.–6. místo: %s. Kdo jede nejlíp, startuje příště ze zadu." % ", ".join(pts), 16, UI.MUTED)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(300, 0)
		cs.add_child(info)
	else:
		var ts := _section("Trať")
		ts.add_child(_track_grid(int(Game.settings.track), true, _pick_track, setup_mode == "trial",
			bool(Game.settings.mirror)))
		if setup_mode == "trial":
			var info := UI.label("Jedeš sám, bez soupeřů a otazníků, se třemi turby. Proti tobě jede průhledný duch tvé nejlepší jízdy.",
				16, UI.MUTED)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.custom_minimum_size = Vector2(300, 0)
			ts.add_child(info)
	if Game.unlocked("mirror"):
		var mrs := _section("Tratě")
		mrs.add_child(_mirror_row(bool(Game.settings.mirror), true, _pick_mirror))
	var ds := _section("Obtížnost")
	ds.add_child(_diff_row(int(Game.settings.diff), true, _pick_diff))
	if setup_mode == "cup":
		var best := Game.cup_best(int(Game.settings.diff))
		var cups := ["", "zlatý pohár", "stříbrný pohár", "bronzový pohár"]
		var txt := "Zatím bez poháru na této obtížnosti." if best == 0 else \
			"Nejlepší výsledek: %d. místo%s" % [best, (" – " + cups[best]) if best <= 3 else ""]
		ds.add_child(UI.label(txt, 16, UI.place_color(best) if best > 0 and best <= 3 else UI.MUTED))
	if players == 2:
		_text("Hráč 1 (horní obrazovka): WASD, drift mezerník, předmět E.\nHráč 2 (dolní obrazovka): šipky, drift pravý Shift, předmět Enter.\nPřipojené ovladače: první patří hráči 1, druhý hráči 2.", 16)
	var row := UI.hbox(10)
	content.add_child(row)
	var go_text: String = {"race": "Závodit!", "cup": "Začít mistrovství!", "trial": "Začít časovku!"}[setup_mode]
	var go := UI.button(go_text, _start_setup, true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	row.add_child(UI.button("Zpět", show_screen.bind("home")))


## Sbírka: the cups won on each difficulty and every reward, won or still
## locked with what it takes.
func _collection() -> void:
	_brand(true)
	var head := UI.hbox(10)
	var hl := UI.label("Sbírka", 26, UI.PAPER, UI.bold_font)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(UI.button("Zpět", show_screen.bind("home")))
	content.add_child(head)
	var cs := _section("Poháry v mistrovství")
	var names := ["Zlatý", "Stříbrný", "Bronzový"]
	for d in Game.DIFFS.size():
		var best := Game.cup_best(d)
		var h := UI.hbox(10)
		var dl := UI.label("%s · %s" % [Game.DIFFS[d].name, Game.DIFFS[d].cc], 18, UI.PAPER, UI.bold_font)
		dl.custom_minimum_size = Vector2(170, 0)
		h.add_child(dl)
		for place in [3, 2, 1]:
			h.add_child(CupIcon.new(UI.place_color(place), best > 0 and best <= place))
		var txt := "zatím bez poháru" if best == 0 or best > 3 else "%s pohár" % names[best - 1]
		var tl := UI.label(txt, 16, UI.place_color(best) if best > 0 and best <= 3 else UI.MUTED)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tl)
		cs.add_child(h)
	var rs := _section("Odměny")
	var secret_open := Game.unlocked("secret")
	_reward(rs, Game.unlocked("mirror"), "Zrcadlové tratě", "Zlatý pohár na Střední nebo Těžké.",
		"Všech šest tratí otočených zrcadlově. Zapínají se u výběru trati.")
	_reward(rs, secret_open, Game.unlock_name("secret") if secret_open else "Tajný jezdec", "Zlatý pohár na Těžké.",
		"Sedmý jezdec s vlastní motokárou. Do závodu jich jede šest.", Game.SECRET if secret_open else -1)
	var dev_txt := "Časovka pod limitem na všech tratích (na jakékoli obtížnosti)."
	_reward(rs, Game.unlocked("dev"), Game.unlock_name("dev"), dev_txt,
		"V časovce jede s tebou rychlý duch vývojáře.")
	var lim := UI.grid(2, 4)
	for t in Game.TRACKS.size():
		var ok := Game.dev_done(t)
		var d := int(Game.settings.diff)
		var l := Game.dev_limit(t, d)
		var tl := UI.label("%s · %s %s" % [Game.TRACKS[t].name, "splněno" if ok else "limit",
			"" if ok else (Game.fmt_time(l) if l > 0.0 else "–")], 14, UI.GO if ok else UI.MUTED)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lim.add_child(tl)
	rs.add_child(lim)
	var ps := _section("Laky motokár")
	_text("Druhý lak: jakýkoli pohár s tímto jezdcem. Zlatý lak: zlatý pohár na Těžké s tímto jezdcem.", 15)
	var g := UI.grid(2, 8)
	ps.add_child(g)
	for d in Game.CHARS.size():
		if not Game.driver_open(d):
			continue
		var h := UI.hbox(6)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(_kart_picture(d, 36.0, Game.paint_of(d)))
		var v := UI.vbox(0)
		v.add_child(UI.label(Game.CHARS[d].name, 15, UI.PAPER, UI.bold_font))
		var row := UI.hbox(6)
		for p in [1, 2]:
			var lk := Game.look(d, p)
			var sw := Swatch.new(lk.color, lk.accent) if Game.paint_open(d, p) else Swatch.new(Color(1, 1, 1, 0.12),
				Color(1, 1, 1, 0.08))
			sw.custom_minimum_size = Vector2(20, 20)
			row.add_child(sw)
		v.add_child(row)
		h.add_child(v)
		g.add_child(h)
	_wide(UI.button("Zpět", show_screen.bind("home")))


## One reward row: name and state, what it takes, what it gives.
func _reward(parent: Control, open: bool, title: String, how: String, what: String, kart := -1) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(Color(UI.GOLD, 0.12) if open else Color(1, 1, 1, 0.04), 12, 12,
		Color(UI.GOLD, 0.6) if open else Color(1, 1, 1, 0.08)))
	var h := UI.hbox(10)
	box.add_child(UI.margin(h, 14, 10, 14, 10))
	if kart >= 0:
		h.add_child(_kart_picture(kart, 46.0, Game.paint_of(kart)))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := UI.hbox(8)
	var tl := UI.label(title, 18, UI.PAPER if open else UI.MUTED, UI.bold_font)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	top.add_child(UI.label("ODEMČENO" if open else "ZAMČENO", 13, UI.GOLD if open else UI.MUTED, UI.bold_font))
	v.add_child(top)
	for t in ([what] if open else [how, what]):
		var l := UI.label(t, 14, UI.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		v.add_child(l)
	parent.add_child(box)


func _start_setup() -> void:
	match setup_mode:
		"cup":
			start_cup.emit(players)
		"trial":
			start_trial.emit()
		_:
			start_offline.emit(players)


func _go_setup(n: int, mode := "race") -> void:
	players = n
	setup_mode = mode
	show_screen("setup")


## The tracks of the championship in their order, small maps in a row.
func _cup_tracks() -> GridContainer:
	var g := UI.grid(3, 6)
	for i in Game.TRACKS.size():
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var th := TrackThumb.new(i, false)
		th.custom_minimum_size = Vector2(0, 54)
		v.add_child(th)
		var l := UI.label("%d. %s" % [i + 1, Game.TRACKS[i].name], 14, UI.PAPER)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
		g.add_child(v)
	return g


func _small_button(text: String) -> Button:
	var b := UI.button(text, Callable())
	b.add_theme_font_size_override("font_size", 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func _mute_text() -> String:
	return "Zvuk\n" + ("vypnutý" if Sfx.muted else "zapnutý")


static func _gfx_text() -> String:
	return "Grafika\n" + Gfx.level_name()


static func _fps_text() -> String:
	return "FPS\n" + ("zobrazené" if Game.settings.show_fps else "skryté")


func _toggle_mute(btn: Button) -> void:
	Sfx.toggle_mute()
	btn.text = _mute_text()


func _cycle_quality(btn: Button) -> void:
	Gfx.cycle()
	btn.text = _gfx_text()
	quality_changed.emit()


func _toggle_fps(btn: Button) -> void:
	Game.settings.show_fps = not bool(Game.settings.show_fps)
	Game.save_settings()
	btn.text = _fps_text()


func _pick_driver(i: int, key: String) -> void:
	Game.settings[key] = i
	Game.save_settings()
	show_screen(screen)


func _pick_paint(p: int, d: int) -> void:
	Game.set_paint(d, p)
	if screen == "lobby":
		Net.set_my_driver(d, p)
	show_screen(screen)


func _pick_mirror(on: bool) -> void:
	Game.settings.mirror = on
	Game.save_settings()
	if screen == "lobby":
		Net.set_track(Net.track, Net.diff, on)
	show_screen(screen)


func _pick_track(i: int) -> void:
	Game.settings.track = i
	Game.save_settings()
	track_changed.emit()
	show_screen("setup")


func _pick_diff(i: int) -> void:
	Game.settings.diff = i
	Game.save_settings()
	show_screen("setup")


func _name_changed(t: String) -> void:
	Game.settings.name = t
	Game.save_settings()


func _wifi() -> void:
	_brand(true)
	content.add_child(UI.label("Hra po Wi-Fi", 26, UI.PAPER, UI.bold_font))
	_text("Všichni musí být připojení ke stejné Wi-Fi. Hrát spolu můžou telefony s Androidem i počítače s Windows, až 6 hráčů.")
	var ns := _section("Tvoje jméno")
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = Game.CHARS[int(Game.settings.driver)].name
	name_edit.text = String(Game.settings.name)
	name_edit.max_length = 16
	name_edit.text_changed.connect(_name_changed)
	ns.add_child(name_edit)
	var dsec := _section("Jezdec")
	var d := int(Game.settings.driver)
	dsec.add_child(KartStage.new(d, 180.0, Game.paint_of(d)))
	dsec.add_child(_driver_grid(d, [], _pick_driver.bind("driver")))
	dsec.add_child(_paint_row(d, Game.paint_of(d), _pick_paint.bind(d)))
	_wide(UI.button("Založit hru", _host, true))
	var hs := _section("Hry v síti")
	_hosts_box = UI.vbox(6)
	hs.add_child(_hosts_box)
	var ms := _section("Připojit podle adresy")
	var row := UI.hbox(8)
	ms.add_child(row)
	var ip_edit := LineEdit.new()
	ip_edit.placeholder_text = "např. 192.168.1.23"
	ip_edit.text = String(Game.settings.host_ip)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	row.add_child(ip_edit)
	row.add_child(UI.button("Připojit", func(): _join(ip_edit.text)))
	_status_l = UI.label(status_text, 17, UI.GOLD)
	_status_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_l.custom_minimum_size = Vector2(300, 0)
	_status_l.visible = status_text != ""
	content.add_child(_status_l)
	_wide(UI.button("Zpět", show_screen.bind("home")))
	Net.start_listening()
	_fill_hosts()


func _fill_hosts() -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.hosts.is_empty():
		var l := UI.label("Hledám hry v síti…", 17, UI.MUTED)
		_hosts_box.add_child(l)
		return
	for ip in Net.hosts.keys():
		var h: Dictionary = Net.hosts[ip]
		var same := String(h.get("version", "")) == Net.version
		var t := "%s · %d/6 hráčů%s" % [h.name, h.count, " · závod běží" if h.racing else ""]
		if not same:
			t = "%s · jiná verze hry (%s)" % [h.name, h.get("version", "?")]
		var b := UI.button(t, _join.bind(String(ip)))
		b.disabled = bool(h.racing) or not same
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_hosts_box.add_child(b)


func _host() -> void:
	var d := int(Game.settings.driver)
	var err := Net.host(Game.player_name(), d, Game.paint_of(d))
	if err != OK:
		set_status("Hru se nepodařilo založit (chyba %d). Zavři jinou běžící kopii hry a zkus to znovu." % err)
		return
	set_status("")
	show_screen("lobby")


func _join(ip: String) -> void:
	ip = ip.strip_edges()
	if not ip.is_valid_ip_address():
		set_status("Zadej adresu ve tvaru 192.168.1.23.")
		return
	Game.settings.host_ip = ip
	Game.save_settings()
	set_status("Připojuji se k %s…" % ip)
	var d := int(Game.settings.driver)
	if Net.join(ip, Game.player_name(), d, Game.paint_of(d)) != OK:
		set_status("Připojení se nepodařilo spustit.")


func _lobby() -> void:
	_brand(true)
	content.add_child(UI.label("Lobby", 26, UI.PAPER, UI.bold_font))
	if Net.is_host:
		var ips := Net.local_ips()
		var sec := _section("Tvoje adresa")
		if ips.is_empty():
			sec.add_child(UI.label("Připoj se k Wi-Fi", 26, UI.GOLD, UI.display_font))
		else:
			sec.add_child(UI.label(", ".join(ips), 30, UI.GOLD, UI.display_font))
		var t := UI.label("Ostatní otevřou Hra po Wi-Fi a tvoji hru buď uvidí v seznamu, nebo zadají tuhle adresu.", 16, UI.MUTED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(300, 0)
		sec.add_child(t)
	var ps := _section("Hráči (%d/6)" % Net.players.size())
	var ids := Net.players.keys()
	ids.sort()
	for pid in ids:
		var pl: Dictionary = Net.players[pid]
		var ch: Dictionary = Game.CHARS[int(pl.driver)]
		var h := UI.hbox(10)
		h.add_child(_kart_picture(int(pl.driver), 34.0, int(pl.get("paint", 0))))
		var me := int(pid) == Net.my_id()
		var nl := UI.label("%s%s" % [pl.name, " (hostitel)" if int(pid) == 1 else ""], 19, UI.GOLD if me else UI.PAPER, UI.bold_font)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		h.add_child(UI.label(ch.name, 16, UI.MUTED))
		ps.add_child(h)
	var mine: Dictionary = Net.players.get(Net.my_id(), {})
	var taken: Array = []
	for pid in Net.players.keys():
		if int(pid) != Net.my_id():
			taken.append(int(Net.players[pid].driver))
	var dsec := _section("Tvůj jezdec")
	var md := int(mine.get("driver", Game.settings.driver))
	dsec.add_child(KartStage.new(md, 180.0, int(mine.get("paint", 0))))
	dsec.add_child(_driver_grid(md, taken, _lobby_driver))
	dsec.add_child(_paint_row(md, int(mine.get("paint", 0)), _pick_paint.bind(md)))
	# one race or the championship over all tracks (the host decides)
	var ms := _section("Režim")
	var modes := UI.hbox(8)
	ms.add_child(modes)
	var group := ButtonGroup.new()
	for m in 2:
		var mb := Button.new()
		mb.text = ["Jeden závod", "Mistrovství"][m]
		mb.toggle_mode = true
		mb.button_group = group
		mb.button_pressed = Net.cup_mode == (m == 1)
		mb.disabled = not Net.is_host and Net.cup_mode != (m == 1)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if Net.is_host:
			mb.pressed.connect(func():
				Sfx.play("ui", 0.6)
				Net.set_cup_mode(m == 1))
		modes.add_child(mb)
	if Net.cup_mode:
		var cs := _section("Mistrovství: všech %d tratí za sebou" % Game.TRACKS.size())
		cs.add_child(_cup_tracks())
	else:
		var ts := _section("Trať")
		ts.add_child(_track_grid(Net.track, Net.is_host, _lobby_track, false, Net.mirror))
	# mirrored tracks: the host's choice, if the host has won them
	if Net.mirror or (Net.is_host and Game.unlocked("mirror")):
		var mrs := _section("Tratě")
		mrs.add_child(_mirror_row(Net.mirror, Net.is_host, _pick_mirror))
	var ds := _section("Obtížnost")
	ds.add_child(_diff_row(Net.diff, Net.is_host, _lobby_diff))
	var row := UI.hbox(10)
	content.add_child(row)
	if Net.is_host:
		var go := UI.button("Začít mistrovství" if Net.cup_mode else "Start závodu", Net.start_race, true)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(go)
	else:
		var w := UI.label("Čekáme, až hostitel spustí závod…", 18, UI.MUTED)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(w)
	row.add_child(UI.button("Odejít", _leave_lobby))


func _lobby_driver(i: int) -> void:
	Game.settings.driver = i
	Game.save_settings()
	Net.set_my_driver(i, Game.paint_of(i))


func _lobby_track(i: int) -> void:
	Game.settings.track = i
	Game.save_settings()
	Net.set_track(i, Net.diff)


func _lobby_diff(i: int) -> void:
	Game.settings.diff = i
	Game.save_settings()
	Net.set_track(Net.track, i)


func _leave_lobby() -> void:
	Net.leave()
	show_screen("wifi")
