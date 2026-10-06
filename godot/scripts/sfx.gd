extends Node
## Procedural audio: sound effects, a music loop and engine noise, all
## synthesised at start-up so the game ships without audio files.

const RATE := 22050
enum W { SINE, SQUARE, SAW, TRI }

var sounds := {}
var music_player: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var pool_i := 0
var engines: Array = []
var muted := false
var _want_music := false
var _music_fast := false
var _music_task_id := -1
var _built_music: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -9.0
	add_child(music_player)
	_build_sounds()
	# the music loop takes the longest to synthesise, so build it off the main thread
	_music_task_id = WorkerThreadPool.add_task(_music_task)
	for i in 2:
		_make_engine()
	set_muted(bool(Game.settings.muted))


# ---------------------------------------------------------------- public API
func play(name: String, vol := 1.0) -> void:
	if muted or vol <= 0.01 or not sounds.has(name):
		return
	var p := pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = sounds[name]
	p.volume_db = linear_to_db(clampf(vol, 0.0, 1.0))
	p.play()


func music(on: bool, fast := false) -> void:
	_want_music = on
	_music_fast = fast
	music_player.pitch_scale = 1.12 if fast else 1.0
	if music_player.stream == null:
		return
	if on and not music_player.playing:
		music_player.play()
	elif not on and music_player.playing:
		music_player.stop()


func _music_task() -> void:
	_built_music = _build_music()


## Picks up the music once the worker thread is done (read only after completion).
func _collect_music() -> void:
	if _music_task_id < 0 or not WorkerThreadPool.is_task_completed(_music_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_music_task_id)
	_music_task_id = -1
	music_player.stream = _built_music
	if Game.cmd_args.has("timing"):
		print("MUSIC READY after %d ms" % Time.get_ticks_msec())
	music(_want_music, _music_fast)


func _exit_tree() -> void:
	if _music_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task_id)
		_music_task_id = -1


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


func toggle_mute() -> bool:
	set_muted(not muted)
	Game.settings.muted = muted
	Game.save_settings()
	return muted


## ratio: speed / top speed, on: whether the engine is audible
func engine(slot: int, ratio: float, on: bool) -> void:
	if slot < 0 or slot >= engines.size():
		return
	var e: Dictionary = engines[slot]
	e.target_freq = 48.0 + 125.0 * clampf(ratio, 0.0, 1.4)
	e.target_vol = 0.16 if on else 0.0
	e.cut = clampf(0.05 + 0.35 * clampf(ratio, 0.0, 1.4), 0.05, 0.6)


# ---------------------------------------------------------------- engine noise
func _make_engine() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.1
	var p := AudioStreamPlayer.new()
	p.stream = gen
	add_child(p)
	p.play()
	engines.append({"player": p, "playback": p.get_stream_playback(), "ph1": 0.0, "ph2": 0.0, "lp": 0.0,
		"freq": 50.0, "target_freq": 50.0, "vol": 0.0, "target_vol": 0.0, "cut": 0.1})


func _process(_delta: float) -> void:
	_collect_music()
	for e in engines:
		var pb: AudioStreamGeneratorPlayback = e.playback
		if pb == null:
			continue
		var n := pb.get_frames_available()
		if n <= 0:
			continue
		if float(e.vol) < 0.0005 and float(e.target_vol) <= 0.0:
			continue
		var buf := PackedVector2Array()
		buf.resize(n)
		var f: float = e.freq
		var v: float = e.vol
		var ph1: float = e.ph1
		var ph2: float = e.ph2
		var lp: float = e.lp
		var cut: float = e.cut
		var tf: float = e.target_freq
		var tv: float = e.target_vol
		for i in n:
			f += (tf - f) * 0.002
			v += (tv - v) * 0.002
			ph1 = fmod(ph1 + f / RATE, 1.0)
			ph2 = fmod(ph2 + f * 0.5 / RATE, 1.0)
			var s := (2.0 * ph1 - 1.0) + (0.35 if ph2 < 0.5 else -0.35)
			lp += (s - lp) * cut
			var o := lp * v
			buf[i] = Vector2(o, o)
		pb.push_buffer(buf)
		e.freq = f
		e.vol = v
		e.ph1 = ph1
		e.ph2 = ph2
		e.lp = lp


# ---------------------------------------------------------------- synthesis
func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE) + 1)
	return b


func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: int, vol: float) -> void:
	var n0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	var attack := 0.004 * RATE
	for i in n:
		var t := float(i) / n
		var f := f0 if f1 <= 0.0 else f0 * pow(f1 / f0, t)
		ph = fmod(ph + f / RATE, 1.0)
		var s := 0.0
		match wave:
			W.SINE: s = sin(TAU * ph)
			W.SQUARE: s = 1.0 if ph < 0.5 else -1.0
			W.SAW: s = 2.0 * ph - 1.0
			_: s = 4.0 * absf(ph - 0.5) - 1.0
		var env := minf(1.0, i / attack) * exp(-5.0 * t) * (1.0 - t)
		var idx := n0 + i
		if idx < b.size():
			b[idx] += s * vol * env


## kind: 0 lowpass, 1 bandpass, 2 highpass (state-variable filter)
func _noise(b: PackedFloat32Array, start: float, dur: float, kind: int, f0: float, f1: float, vol: float) -> void:
	var n0 := int(start * RATE)
	var n := int(dur * RATE)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / n
		var fc := f0 if f1 <= 0.0 else f0 * pow(f1 / f0, t)
		var k := 2.0 * sin(PI * minf(fc, RATE * 0.24) / RATE)
		var x := randf() * 2.0 - 1.0
		low += k * band
		var high := x - low - 1.0 * band
		band += k * high
		var s: float = low if kind == 0 else (band if kind == 1 else high)
		var env := exp(-4.0 * t) * (1.0 - t)
		var idx := n0 + i
		if idx < b.size():
			b[idx] += s * vol * env


func _to_stream(b: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = b.size() - 1
	return s


static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _build_sounds() -> void:
	var b: PackedFloat32Array
	b = _buf(0.08); _tone(b, 0, 0.07, 880, 0, W.TRI, 0.3); sounds.ui = _to_stream(b)
	b = _buf(0.25); _tone(b, 0, 0.22, 523, 0, W.SQUARE, 0.3); sounds.count = _to_stream(b)
	b = _buf(0.6); _tone(b, 0, 0.55, 1046, 0, W.SQUARE, 0.3); sounds.go = _to_stream(b)
	b = _buf(0.25)
	for i in 3:
		_tone(b, i * 0.05, 0.09, [660, 880, 1320][i], 0, W.TRI, 0.35)
	sounds.pickup = _to_stream(b)
	b = _buf(0.04); _tone(b, 0, 0.035, 1300, 0, W.SQUARE, 0.12); sounds.tick = _to_stream(b)
	b = _buf(0.3); _tone(b, 0, 0.1, 990, 0, W.SQUARE, 0.25); _tone(b, 0.08, 0.16, 1480, 0, W.SQUARE, 0.25); sounds.got = _to_stream(b)
	b = _buf(0.65); _noise(b, 0, 0.6, 1, 400, 2600, 0.9); _tone(b, 0, 0.45, 220, 700, W.SAW, 0.18); sounds.boost = _to_stream(b)
	b = _buf(0.1); _tone(b, 0, 0.09, 880, 0, W.TRI, 0.3); sounds.level1 = _to_stream(b)
	b = _buf(0.1); _tone(b, 0, 0.09, 1320, 0, W.TRI, 0.3); sounds.level2 = _to_stream(b)
	b = _buf(0.18); _tone(b, 0, 0.07, 1760, 0, W.TRI, 0.3); _tone(b, 0.07, 0.1, 2093, 0, W.TRI, 0.3); sounds.level3 = _to_stream(b)
	b = _buf(0.1); _tone(b, 0, 0.08, 320, 520, W.TRI, 0.2); sounds.hop = _to_stream(b)
	b = _buf(0.62); _tone(b, 0, 0.6, 760, 110, W.SQUARE, 0.25); _noise(b, 0, 0.3, 1, 900, 0, 0.5); sounds.hit = _to_stream(b)
	b = _buf(0.18); _noise(b, 0, 0.16, 0, 320, 0, 1.2); _tone(b, 0, 0.12, 90, 0, W.SINE, 0.6); sounds.bump = _to_stream(b)
	b = _buf(0.82); _noise(b, 0, 0.8, 0, 1600, 90, 1.4); sounds.explode = _to_stream(b)
	b = _buf(0.12); _tone(b, 0, 0.1, 520, 300, W.TRI, 0.3); sounds.drop = _to_stream(b)
	b = _buf(0.32); _tone(b, 0, 0.3, 380, 1400, W.TRI, 0.3); _noise(b, 0, 0.28, 1, 1800, 4200, 0.35); sounds.trick = _to_stream(b)
	b = _buf(0.22); _noise(b, 0, 0.2, 0, 240, 0, 1.3); _tone(b, 0, 0.16, 70, 40, W.SINE, 0.8); sounds.land = _to_stream(b)
	b = _buf(0.52); _noise(b, 0, 0.5, 1, 3000, 600, 0.7); sounds.missile = _to_stream(b)
	# new items: a rising whistle (blue missile), a splat (oil), a shimmer (shield),
	# a pop (shield used up) and a crack of thunder (lightning)
	b = _buf(0.7); _tone(b, 0, 0.65, 500, 1600, W.SINE, 0.3); _noise(b, 0, 0.6, 1, 2400, 900, 0.5); sounds.blue = _to_stream(b)
	b = _buf(0.3); _noise(b, 0, 0.25, 0, 700, 120, 1.1); _tone(b, 0, 0.2, 180, 60, W.SINE, 0.5); sounds.oil = _to_stream(b)
	b = _buf(0.5)
	for i in 5:
		_tone(b, i * 0.06, 0.2, mtof(79 + i * 3), 0, W.SINE, 0.22)
	sounds.shield = _to_stream(b)
	b = _buf(0.18); _tone(b, 0, 0.05, 1400, 500, W.SINE, 0.45); _noise(b, 0, 0.12, 1, 3500, 1200, 0.5); sounds.pop = _to_stream(b)
	b = _buf(1.0); _noise(b, 0, 0.08, 1, 6000, 3000, 1.3); _noise(b, 0.05, 0.9, 0, 900, 60, 1.2); _tone(b, 0, 0.5, 1200, 80, W.SAW, 0.2); sounds.zap = _to_stream(b)
	b = _buf(0.5)
	var steps := [0, 4, 7, 12, 16, 19, 24]
	for i in steps.size():
		_tone(b, i * 0.05, 0.09, mtof(76 + steps[i]), 0, W.SQUARE, 0.16)
	sounds.star = _to_stream(b)
	b = _buf(0.4); _tone(b, 0, 0.12, 784, 0, W.SQUARE, 0.28); _tone(b, 0.12, 0.22, 1047, 0, W.SQUARE, 0.28); sounds.lap = _to_stream(b)
	b = _buf(0.7)
	var fl := [67, 72, 76, 79, 84]
	for i in fl.size():
		_tone(b, i * 0.1, 0.14, mtof(fl[i]), 0, W.SQUARE, 0.25)
	sounds.final_lap = _to_stream(b)
	b = _buf(1.3)
	var fin := [72, 76, 79, 84, 79, 84]
	for i in fin.size():
		_tone(b, i * 0.12, 0.6 if i == 5 else 0.14, mtof(fin[i]), 0, W.SQUARE, 0.25)
	sounds.finish = _to_stream(b)


## A cheerful 4-bar loop: F – C – Dm – B♭, two phrases.
func _build_music() -> AudioStreamWAV:
	var e := 0.2
	var steps := 64
	var b := _buf(e * steps)
	var root := [41, 36, 38, 34]
	var ch := [[65, 69, 72], [64, 67, 72], [62, 65, 69], [62, 65, 70]]
	var bp := [0, 12, 0, 12, 0, 12, 7, 12]
	var lp := [[0, 1, 2, 1, 2, -1, 1, 0], [2, -1, 2, 1, 0, 1, 2, -1]]
	for st in steps:
		var bar := int(st / 8) % 4
		var s := st % 8
		var phrase := int(st / 32) % 2
		var t := st * e
		_tone(b, t, e * 0.9, mtof(root[bar] + bp[s]), 0, W.TRI, 0.5)
		var li: int = lp[phrase][s]
		if li >= 0:
			_tone(b, t, e * 0.7, mtof(ch[bar][li] + (12 if phrase == 1 else 0)), 0, W.SQUARE, 0.09)
		if s % 2 == 1:
			_noise(b, t, 0.04, 2, 7000, 0, 0.25)
	return _to_stream(b, true)
