class_name Hud
extends Control
## Race HUD for one local player: position, lap, time, item, speed, minimap,
## countdown and short messages. Smaller when the screen is split.
## Animated: the item is drawn on a slot-machine reel, the position jumps
## and shows +1 / −1 when it changes, each new lap slides in on a banner.

var race: Race
var kart: Kart
var compact := false
var pos_l: Label
var lap_l: Label
var time_l: Label
var speed_l: Label
var msg_l: Label
var count_l: Label
var wrong_l: Label
var item_box: Panel
var item_icon: ItemIcon
var item_n: Label
var minimap: Minimap
var _cache := {}
var _msg_tween: Tween
var _count_tween: Tween
var _k := 1.0
var _last_t := 0.0
var _last_rank := 0
var _settle_t := -1.0
var _settle_from := 0.0
var _settle_to := 0.0
var pop_l: Label
var _pop_val := 0
var _pop_tween: Tween
var _pos_tween: Tween
var banner: PanelContainer
var banner_l: Label
var banner_sub: Label
var _banner_tween: Tween


func setup(p_race: Race, p_kart: Kart, p_compact: bool) -> void:
	race = p_race
	kart = p_kart
	compact = p_compact
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := 0.68 if compact else 1.0
	_k = k

	var tl := UI.vbox(0)
	tl.position = Vector2(18, 10)
	add_child(tl)
	if compact:
		tl.add_child(_shadowed(UI.label("HRÁČ %d" % (kart.local_slot + 1), 15, kart.ch.color.lightened(0.3), UI.bold_font)))
	var pos_row := UI.hbox(2)
	tl.add_child(pos_row)
	pos_l = _shadowed(UI.label("6.", int(70 * k), UI.PAPER, UI.display_font))
	pos_row.add_child(pos_l)
	var suf := _shadowed(UI.label("/%d" % race.karts.size(), int(26 * k), UI.MUTED, UI.display_font))
	suf.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_row.add_child(suf)
	lap_l = _shadowed(UI.label("KOLO 1/3", int(22 * k), UI.PAPER, UI.bold_font))
	tl.add_child(lap_l)
	time_l = _shadowed(UI.label("0:00.00", int(22 * k), UI.PAPER, UI.bold_font))
	tl.add_child(time_l)
	if race.trial:
		# time trial: no places, the record to beat instead
		pos_row.visible = false
		tl.move_child(time_l, 0)
		time_l.add_theme_font_size_override("font_size", int(46 * k))
		time_l.add_theme_font_override("font", UI.display_font)
		var best := Game.trial_best(race.track_idx, race.diff_idx)
		tl.add_child(_shadowed(UI.label("REKORD " + (Game.fmt_time(best) if best > 0.0 else "–"), int(20 * k), UI.GOLD,
			UI.bold_font)))

	var box_size := 78.0 * k
	item_box = Panel.new()
	var sb := UI.box(Color(0.05, 0.07, 0.1, 0.55), 14, 3, Color(0.93, 0.95, 0.98, 0.75))
	item_box.add_theme_stylebox_override("panel", sb)
	item_box.anchor_left = 0.5
	item_box.anchor_right = 0.5
	item_box.offset_left = -box_size * 0.5
	item_box.offset_right = box_size * 0.5
	item_box.offset_top = 10
	item_box.offset_bottom = 10 + box_size
	item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_box.clip_contents = true     # the reel runs behind the window edges
	add_child(item_box)
	item_icon = ItemIcon.new()
	item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_icon.offset_left = 8
	item_icon.offset_top = 8
	item_icon.offset_right = -8
	item_icon.offset_bottom = -8
	item_box.add_child(item_icon)
	item_n = _shadowed(UI.label("", int(18 * k), UI.GOLD, UI.display_font))
	item_n.anchor_left = 1.0
	item_n.anchor_top = 1.0
	item_n.anchor_right = 1.0
	item_n.anchor_bottom = 1.0
	item_n.offset_left = -34
	item_n.offset_top = -26
	item_box.add_child(item_n)
	var touch_ui: bool = Game.is_mobile() or Game.cmd_args.has("touch")
	if not touch_ui and not compact:
		var hint := _shadowed(UI.label("X = předmět", 14, UI.PAPER, UI.bold_font))
		hint.anchor_left = 0.5
		hint.anchor_right = 0.5
		hint.offset_left = -60
		hint.offset_right = 60
		hint.offset_top = 14 + box_size
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.modulate.a = 0.7
		add_child(hint)

	var mm_size := 112.0 if compact else 150.0
	minimap = Minimap.new()
	minimap.race = race
	minimap.me = kart
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -mm_size - 14
	minimap.offset_right = -14
	minimap.offset_top = 10
	minimap.offset_bottom = 10 + mm_size
	add_child(minimap)
	if kart.local_slot == 0 and (Game.is_mobile() or Game.cmd_args.has("touch")):
		minimap.offset_top = 64
		minimap.offset_bottom = 64 + mm_size
		var pb := Button.new()
		pb.text = "II"
		pb.add_theme_font_override("font", UI.display_font)
		pb.add_theme_font_size_override("font_size", 20)
		pb.anchor_left = 1.0
		pb.anchor_right = 1.0
		pb.offset_left = -64
		pb.offset_right = -14
		pb.offset_top = 10
		pb.offset_bottom = 56
		pb.focus_mode = Control.FOCUS_NONE
		pb.pressed.connect(func(): race.toggle_pause())
		add_child(pb)

	speed_l = _shadowed(UI.label("0 km/h", int(30 * k), UI.PAPER, UI.display_font))
	speed_l.anchor_left = 1.0
	speed_l.anchor_top = 1.0
	speed_l.anchor_right = 1.0
	speed_l.anchor_bottom = 1.0
	speed_l.offset_left = -260
	speed_l.offset_right = -18
	speed_l.offset_top = -52 * k
	speed_l.offset_bottom = -10
	speed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if touch_ui and kart.local_slot == 0:
		speed_l.visible = false
	add_child(speed_l)

	pop_l = _shadowed(UI.label("", int(40 * k), UI.GO, UI.display_font))
	pop_l.modulate.a = 0.0
	add_child(pop_l)
	_make_banner()

	count_l = _center_label(int(170 * k), 0.0)
	msg_l = _center_label(int(44 * k), -0.18)
	wrong_l = _center_label(int(34 * k), 0.06)
	wrong_l.text = "Špatný směr!"
	wrong_l.add_theme_color_override("font_color", UI.GOLD)
	wrong_l.visible = false


func _shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


func _center_label(font_size: int, y: float) -> Label:
	var l := _shadowed(UI.label("", font_size, UI.PAPER, UI.display_font))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_top = 0
	l.anchor_top = y
	l.anchor_bottom = 1.0 + y
	l.pivot_offset = Vector2.ZERO
	add_child(l)
	return l


func _set_text(name_key: String, l: Label, text: String) -> void:
	if _cache.get(name_key, "") != text:
		_cache[name_key] = text
		l.text = text


func refresh() -> void:
	var k := kart
	_set_text("pos", pos_l, "%d." % k.rank)
	pos_l.add_theme_color_override("font_color", UI.place_color(k.rank))
	_set_text("lap", lap_l, "KOLO %d/%d" % [clampi(k.lap, 1, Game.LAPS), Game.LAPS])
	_set_text("time", time_l, Game.fmt_time(k.finish_time if k.finished else race.race_time))
	_set_text("speed", speed_l, "%d km/h" % int(round(absf(k.speed) * 3.2)))
	var now := Time.get_ticks_msec() / 1000.0
	var dt := 0.0 if race.paused else clampf(now - _last_t, 0.0, 0.1)   # the reel stops in the pause menu
	_last_t = now
	_reel(k, dt)
	_rank_change(k)
	wrong_l.visible = k.wrong_t > 1.0 and not k.finished and race.state == "race"
	minimap.queue_redraw()


func show_msg(text: String, color: Color) -> void:
	msg_l.text = text
	msg_l.add_theme_color_override("font_color", color)
	msg_l.pivot_offset = msg_l.size * 0.5
	if _msg_tween != null:
		_msg_tween.kill()
	msg_l.modulate.a = 0.0
	msg_l.scale = Vector2(0.6, 0.6)
	_msg_tween = create_tween()
	_msg_tween.tween_property(msg_l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.parallel().tween_property(msg_l, "modulate:a", 1.0, 0.12)
	_msg_tween.tween_interval(1.2)
	_msg_tween.tween_property(msg_l, "modulate:a", 0.0, 0.3)


func show_count(text: String, go: bool) -> void:
	count_l.text = text
	count_l.add_theme_color_override("font_color", UI.GO if go else UI.PAPER)
	count_l.pivot_offset = count_l.size * 0.5
	if _count_tween != null:
		_count_tween.kill()
	count_l.modulate.a = 0.0
	count_l.scale = Vector2(1.6, 1.6)
	_count_tween = create_tween()
	_count_tween.tween_property(count_l, "scale", Vector2.ONE, 0.15)
	_count_tween.parallel().tween_property(count_l, "modulate:a", 1.0, 0.12)
	_count_tween.tween_interval(0.5)
	_count_tween.tween_property(count_l, "modulate:a", 0.0, 0.25)


## Slot machine: the reel runs while the item is being drawn (slowing down
## towards the end), then lands on the won item with a little overshoot.
func _reel(k: Kart, dt: float) -> void:
	var ic := item_icon
	if k.roulette > 0.0:
		if not ic.spinning or _settle_t >= 0.0:
			ic.spinning = true
			ic.win_cell = -999999
			_settle_t = -1.0
		var speed := lerpf(7.0, 24.0, clampf(k.roulette / 1.3, 0.0, 1.0))
		ic.reel += speed * dt
		ic.blur = clampf(speed / 24.0, 0.0, 1.0)
		_set_text("n", item_n, "")
	elif ic.spinning and _settle_t < 0.0:
		_settle_t = 0.0
		_settle_from = ic.reel
		_settle_to = floorf(ic.reel) + 2.0
		ic.win_cell = int(_settle_to)
		ic.win_item = k.item
	if _settle_t >= 0.0:
		_settle_t += dt
		var u := clampf(_settle_t / 0.45, 0.0, 1.0)
		var c1 := 1.9
		var e := 1.0 + (c1 + 1.0) * pow(u - 1.0, 3) + c1 * pow(u - 1.0, 2)    # ease out with overshoot
		ic.reel = lerpf(_settle_from, _settle_to, e)
		ic.blur = (1.0 - u) * 0.6
		if u >= 1.0:
			_settle_t = -1.0
			ic.spinning = false
	if not ic.spinning:
		ic.item = k.item
		_set_text("n", item_n, "×%d" % k.item_n if k.item_n > 1 else "")
	ic.queue_redraw()


## Places gained or lost: the position jumps and +1 / −1 floats up next to it.
func _rank_change(k: Kart) -> void:
	if _last_rank == 0 or race.state != "race" or race.race_time < 1.5 or k.finished:
		_last_rank = k.rank
		return
	if k.rank == _last_rank:
		return
	var gained := _last_rank - k.rank
	_last_rank = k.rank
	_pop_val = gained if (_pop_tween == null or not _pop_tween.is_running() or signi(_pop_val) != signi(gained)) else _pop_val + gained
	pop_l.text = ("+%d" % _pop_val) if _pop_val > 0 else ("−%d" % -_pop_val)
	pop_l.add_theme_color_override("font_color", UI.GO if _pop_val > 0 else UI.KERB)
	var row := (pos_l.get_parent() as Control).get_global_rect()
	pop_l.position = Vector2(row.end.x + 10.0, row.get_center().y - 30.0 * _k) - get_global_rect().position
	pop_l.modulate.a = 1.0
	if _pop_tween != null:
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(pop_l, "position:y", pop_l.position.y - 26.0 * _k, 0.9).set_ease(Tween.EASE_OUT)
	_pop_tween.parallel().tween_property(pop_l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	pos_l.pivot_offset = pos_l.size * 0.5
	if _pos_tween != null:
		_pos_tween.kill()
	pos_l.scale = Vector2.ONE * (1.35 if gained > 0 else 0.8)
	_pos_tween = create_tween()
	_pos_tween.tween_property(pos_l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.1, 0.85), 0, 0, Color(0, 0, 0, 0)))
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	var at := 0.47 if compact else 0.32   # below the lap and time readout
	banner.anchor_top = at
	banner.anchor_bottom = at
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH   # stays centred there
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	add_child(banner)
	var v := UI.vbox(int(6 * _k))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(v)
	v.add_child(UI.kerb_strip(int(6 * _k)))
	banner_l = UI.label("", int(44 * _k), UI.PAPER, UI.display_font)
	banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_l)
	banner_sub = UI.label("", int(22 * _k), UI.MUTED, UI.bold_font)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_sub)
	v.add_child(UI.kerb_strip(int(6 * _k)))


## A band with kerbs slides across the screen: new lap, last lap; `sub` is
## a smaller line under it (the time of the lap just driven).
func show_banner(text: String, color: Color, sub := "", sub_color := UI.MUTED) -> void:
	banner_l.text = text
	banner_l.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_sub.add_theme_color_override("font_color", sub_color)
	banner_sub.visible = sub != ""
	banner.visible = true
	var w := size.x
	if _banner_tween != null:
		_banner_tween.kill()
	banner.position.x = -w
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.5 if sub != "" else 1.1)
	_banner_tween.tween_property(banner, "position:x", w, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(func(): banner.visible = false)
