extends Node
## Wi-Fi multiplayer (crossplay Android ↔ Windows): ENet host/client,
## LAN discovery via UDP broadcast, lobby and race messages.
## The host simulates the race; clients send controls and get snapshots.

const PORT := 24680
const DISCOVERY_PORT := 24681
const MAX_PLAYERS := 6
const MAGIC := "SKODARACER2"
const OLD_MAGIC := "SKODARACER1"   # version 1.0.0 broadcasts, shown as "jiná verze"

signal lobby_changed
signal joined
signal join_failed(reason: String)
signal session_ended(reason: String)
signal hosts_changed
signal race_started(track: int, diff: int, roster: Array, cup: Dictionary, battle: bool)
signal cup_points(points: Dictionary)
signal snapshot_received(data: PackedFloat32Array)
signal back_to_lobby
signal peer_left(id: int)

## Players can only race together on the same game version.
var version := String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
var active := false
var is_host := false
var players := {}      # peer id -> {"name": String, "driver": int, "paint": int}
var track := 0         # 0..5; with `mirror` the race runs on its mirrored version
var mirror := false
var diff := 1
var cup_mode := false  # the lobby is set to a championship over all tracks
var battle_mode := false  # the lobby is set to a balloon battle (Etapa I)
var arena := 0         # the battle's arena, the host's choice
var cup := {}          # host: the championship being driven {round, points, roster, diff}
var in_race := false
var inputs := {}       # peer id -> {"steer", "buttons", "seq" (item presses), "frame" (number of the message)}
var hosts := {}        # ip -> {"name", "count", "racing", "t"}
var _pending := {}
var _udp: PacketPeerUDP
var _listen: PacketPeerUDP
var _bcast_t := 0.0
# --fake-lag=120 (tests): every race message to and from this player waits
# that many ms (+ up to --fake-jitter ms), as on a slow Wi-Fi
var fake_lag := 0.0
var fake_jitter := 0.0
var _late: Array = []      # [release ms, Callable] in release order


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.cmd_args.has("fake-version"):
		version = String(Game.cmd_args["fake-version"])   # tests only
	fake_lag = float(Game.cmd_args.get("fake-lag", "0"))
	fake_jitter = float(Game.cmd_args.get("fake-jitter", "0"))
	var mp := _mp()
	mp.peer_authenticating.connect(_on_authenticating)
	mp.peer_authentication_failed.connect(_on_auth_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func _mp() -> SceneMultiplayer:
	return multiplayer as SceneMultiplayer


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


# ---------------------------------------------------------------- session
func host(name: String, driver: int, paint := 0) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	_mp().auth_callback = _auth_host
	_mp().auth_timeout = 4.0
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	in_race = false
	players = {1: {"name": name, "driver": driver, "paint": paint}}
	track = int(Game.settings.track)
	diff = int(Game.settings.diff)
	mirror = bool(Game.settings.mirror)
	arena = int(Game.settings.arena)
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_bcast_t = 0.0
	lobby_changed.emit()
	return OK


func join(ip: String, name: String, driver: int, paint := 0) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	_mp().auth_callback = _auth_client
	_mp().auth_timeout = 6.0
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	_pending = {"name": name, "driver": driver, "paint": paint}
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_mp().auth_callback = Callable()
	active = false
	is_host = false
	in_race = false
	cup_mode = false
	battle_mode = false
	cup = {}
	players = {}
	inputs = {}
	_late.clear()
	if _udp != null:
		_udp.close()
		_udp = null


func start_listening() -> void:
	stop_listening()
	hosts = {}
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null


func stop_listening() -> void:
	if _listen != null:
		_listen.close()
		_listen = null


## Private IPv4 addresses of this device (shown to players on the host screen).
func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.contains(":") or s.begins_with("127.") or s.begins_with("169.254."):
			continue
		var p := s.split(".")
		if p.size() != 4:
			continue
		var b := int(p[1])
		if p[0] == "10" or (p[0] == "192" and p[1] == "168") or (p[0] == "172" and b >= 16 and b <= 31):
			out.append(s)
	return out


## Runs cb now, or later with --fake-lag (keeping the order of the messages).
func _delay(cb: Callable) -> void:
	if fake_lag <= 0.0 and fake_jitter <= 0.0:
		cb.call()
		return
	var at := Time.get_ticks_msec() + fake_lag + randf() * fake_jitter
	if not _late.is_empty():
		at = maxf(at, float(_late[_late.size() - 1][0]))
	_late.append([at, cb])


func _process(delta: float) -> void:
	var now_ms := float(Time.get_ticks_msec())
	while not _late.is_empty() and float(_late[0][0]) <= now_ms:
		var cb: Callable = _late.pop_front()[1]
		if active:
			cb.call()
	if is_host and active and _udp != null:
		_bcast_t -= delta
		if _bcast_t <= 0.0:
			_bcast_t = 1.0
			_broadcast()
	if _listen != null:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet()
			var ip := _listen.get_packet_ip()
			var parts := pkt.get_string_from_utf8().split("|")
			if parts.size() >= 4 and (parts[0] == MAGIC or parts[0] == OLD_MAGIC):
				var known := hosts.has(ip)
				var ver := parts[4] if parts[0] == MAGIC and parts.size() >= 5 else "1.0.0"
				hosts[ip] = {"name": parts[1], "count": int(parts[2]), "racing": parts[3] == "1", "version": ver,
					"t": Time.get_ticks_msec()}
				if not known:
					changed = true
		var now := Time.get_ticks_msec()
		for ip in hosts.keys():
			if now - int(hosts[ip].t) > 3500:
				hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


func _broadcast() -> void:
	var host_name := String(players.get(1, {}).get("name", "Hra"))
	var msg := "%s|%s|%d|%d|%s" % [MAGIC, host_name.replace("|", " "), players.size(), 1 if in_race else 0, version]
	var data := msg.to_utf8_buffer()
	var targets := ["255.255.255.255"]
	for ip in local_ips():
		var p := String(ip).split(".")
		targets.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	for t in targets:
		_udp.set_dest_address(t, DISCOVERY_PORT)
		_udp.put_packet(data)


# ---------------------------------------------------------------- version check
# Godot's built-in authentication runs before any RPC is allowed, so the
# check works even against builds whose RPC lists differ.
func _on_authenticating(id: int) -> void:
	if not is_host and id == 1:
		_mp().send_auth(1, ("HELLO|%s" % version).to_utf8_buffer())


func _auth_host(id: int, data: PackedByteArray) -> void:
	var parts := data.get_string_from_utf8().split("|")
	if parts.size() >= 2 and parts[0] == "HELLO" and parts[1] == version:
		_mp().send_auth(id, "OK".to_utf8_buffer())
		_mp().complete_auth(id)
		return
	_mp().send_auth(id, ("BAD|%s" % version).to_utf8_buffer())
	# let the answer reach the player before dropping the connection
	get_tree().create_timer(0.6).timeout.connect(_kick.bind(id))


func _kick(id: int) -> void:
	# the player may already have left after reading the message
	if is_host and multiplayer.multiplayer_peer != null and id in _mp().get_authenticating_peers():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _auth_client(_id: int, data: PackedByteArray) -> void:
	var parts := data.get_string_from_utf8().split("|")
	if parts[0] == "OK":
		_mp().complete_auth(1)
	elif parts[0] == "BAD":
		var theirs := parts[1] if parts.size() > 1 else "?"
		_fail_join.call_deferred("Hostitel má jinou verzi hry (%s), ty máš %s. Stáhněte si oba stejnou verzi." % [theirs, version])


func _on_auth_failed(_id: int) -> void:
	if not is_host:
		_fail_join.call_deferred("Hostitel neodpověděl. Možná má starší verzi hry, stáhněte si oba stejnou verzi.")


func _fail_join(reason: String) -> void:
	if is_host:
		return
	leave()
	join_failed.emit(reason)


# ---------------------------------------------------------------- peers
func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	players.erase(id)
	inputs.erase(id)
	peer_left.emit(id)
	_sync_lobby()


func _on_connected() -> void:
	_register.rpc_id(1, String(_pending.get("name", "Hráč")), int(_pending.get("driver", 0)), int(_pending.get("paint", 0)))
	joined.emit()


func _on_failed() -> void:
	leave()
	join_failed.emit("Nepodařilo se připojit. Zkontroluj adresu a že jste na stejné Wi-Fi.")


func _on_server_gone() -> void:
	leave()
	session_ended.emit("Hostitel ukončil hru.")


@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, driver: int, paint: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS or in_race:
		_rejected.rpc_id(id, "Hra je plná nebo už závod běží.")
		return
	var d := _free_driver(driver, id)
	players[id] = {"name": pname.substr(0, 16), "driver": d, "paint": paint if d == driver else 0}
	_sync_lobby()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	leave()
	join_failed.emit(reason)


@rpc("any_peer", "call_remote", "reliable")
func _request_driver(driver: int, paint: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		_set_driver(id, driver, paint)


func _set_driver(id: int, driver: int, paint: int) -> void:
	var d := _free_driver(driver, id)
	players[id].driver = d
	players[id].paint = paint if d == driver else 0
	_sync_lobby()


## Driver and paint come from the player's own game (what they have won).
func set_my_driver(d: int, paint := 0) -> void:
	if is_host:
		_set_driver(1, d, paint)
	elif active:
		_request_driver.rpc_id(1, d, paint)


func set_track(t: int, d: int, m := mirror) -> void:
	if not is_host:
		return
	track = t
	diff = d
	mirror = m
	_sync_lobby()


func set_cup_mode(on: bool) -> void:
	set_mode(1 if on else 0)


## The host's choice in the lobby: 0 one race, 1 the championship, 2 the
## balloon battle.
func set_mode(m: int) -> void:
	if not is_host:
		return
	cup_mode = m == 1
	battle_mode = m == 2
	_sync_lobby()


func set_arena(a: int) -> void:
	if not is_host:
		return
	arena = clampi(a, 0, Game.ARENAS.size() - 1)
	_sync_lobby()


func _free_driver(want: int, id: int) -> int:
	var taken := {}
	for pid in players.keys():
		if pid != id:
			taken[int(players[pid].driver)] = true
	if not taken.has(want):
		return want
	return Game.free_driver(taken.keys())


func _sync_lobby() -> void:
	lobby_changed.emit()
	if is_host and active:
		_lobby.rpc(players, track, diff, cup_mode, mirror, battle_mode, arena)


@rpc("authority", "call_remote", "reliable")
func _lobby(p: Dictionary, t: int, d: int, cm: bool, m: bool, bm: bool, ar: int) -> void:
	players = p
	track = t
	diff = d
	cup_mode = cm
	mirror = m
	battle_mode = bm
	arena = ar
	lobby_changed.emit()


# ---------------------------------------------------------------- race
func start_race() -> void:
	if not is_host:
		return
	if battle_mode:
		# the balloon battle: the host's arena, free places for the computer
		cup = {}
		_launch(arena, diff, _new_roster(), {}, true)
		return
	if cup_mode and cup.is_empty():
		var first := _new_roster()
		var pts := {}
		for r in first:
			pts[int(r.driver)] = 0
		cup = {"round": clampi(int(Game.cmd_args.get("cup-start", "0")), 0, Game.TRACKS.size() - 1), "points": pts,
			"roster": first, "diff": diff, "mirror": mirror}
	if not cup.is_empty():
		_launch(Game.race_track(int(cup.round), bool(cup.mirror)), int(cup.diff), cup.roster,
			{"round": cup.round, "points": cup.points, "diff": cup.diff, "mirror": cup.mirror})
	else:
		_launch(Game.race_track(track, mirror), diff, _new_roster(), {})


## Host, after a championship race: add the points, then the next track
## with the grid in reverse order of the standings; after the last one
## everybody goes back to the lobby.
func next_cup_round(race_points: Dictionary) -> void:
	if not is_host or cup.is_empty():
		return
	for d in race_points:
		cup.points[d] = int(cup.points.get(d, 0)) + int(race_points[d])
	cup.round = int(cup.round) + 1
	if int(cup.round) >= Game.TRACKS.size():
		return_to_lobby()
		return
	var order: Array = []
	var pos := {}
	for i in cup.roster.size():
		var r: Dictionary = (cup.roster[i] as Dictionary).duplicate()
		if bool(r.human) and not players.has(int(r.peer)):
			r.human = false   # left the game: the computer drives on for them
			r.peer = 0
		order.append(r)
		pos[int(r.driver)] = i
	order.sort_custom(func(a, b):
		var pa := int(cup.points[int(a.driver)])
		var pb := int(cup.points[int(b.driver)])
		return pa < pb if pa != pb else pos[int(a.driver)] < pos[int(b.driver)])
	cup.roster = order
	start_race()


## Host: the points of the race shown on everybody's results.
func send_cup_points(pts: Dictionary) -> void:
	if is_host and active and players.size() > 1:
		_cup_pts.rpc(pts)


@rpc("authority", "call_remote", "reliable")
func _cup_pts(pts: Dictionary) -> void:
	cup_points.emit(pts)


func _launch(t: int, d: int, roster: Array, cupd: Dictionary, battle := false) -> void:
	in_race = true
	inputs = {}
	_race_start.rpc(t, d, roster, cupd, battle)
	race_started.emit(t, d, roster, cupd, battle)


func _new_roster() -> Array:
	var humans: Array = []
	var used := {}
	for pid in players.keys():
		var pl: Dictionary = players[pid]
		humans.append({"driver": int(pl.driver), "paint": int(pl.get("paint", 0)), "human": true, "peer": int(pid),
			"name": String(pl.name)})
		used[int(pl.driver)] = true
	humans.shuffle()
	var ai: Array = []
	for i in Game.open_drivers():     # the computer drivers: what the host has won
		if not used.has(i):
			ai.append({"driver": i, "human": false, "peer": 0, "name": ""})
	ai.shuffle()
	return ai.slice(0, Game.MAX_KARTS - humans.size()) + humans


## t is the track, or the arena when battle is set.
@rpc("authority", "call_remote", "reliable")
func _race_start(t: int, d: int, roster: Array, cupd: Dictionary, battle: bool) -> void:
	in_race = true
	race_started.emit(t, d, roster, cupd, battle)


func return_to_lobby() -> void:
	if not is_host:
		return
	in_race = false
	cup = {}
	inputs = {}
	_to_lobby.rpc()
	back_to_lobby.emit()
	_sync_lobby()


@rpc("authority", "call_remote", "reliable")
func _to_lobby() -> void:
	in_race = false
	back_to_lobby.emit()


func send_snapshot(d: PackedFloat32Array) -> void:
	if is_host and active and players.size() > 1:
		_snap.rpc(d)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snap(d: PackedFloat32Array) -> void:
	_delay(func(): snapshot_received.emit(d))


## Client, every physics frame: its controls, the number of item presses
## (seq) and the number of this message (frame). The host sends back which
## frame it used last, so the client knows what to simulate again.
func send_input(steer: float, buttons: int, seq: int, frame: int) -> void:
	if active and not is_host:
		_delay(func(): _net_input.rpc_id(1, steer, buttons, seq, frame))


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(steer: float, buttons: int, seq: int, frame: int) -> void:
	if not is_host:
		return
	inputs[multiplayer.get_remote_sender_id()] = {"steer": clampf(steer, -1.0, 1.0), "buttons": buttons, "seq": seq,
		"frame": frame}
