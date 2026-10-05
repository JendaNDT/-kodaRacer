extends Node
## Wi-Fi multiplayer (crossplay Android ↔ Windows): ENet host/client,
## LAN discovery via UDP broadcast, lobby and race messages.
## The host simulates the race; clients send controls and get snapshots.

const PORT := 24680
const DISCOVERY_PORT := 24681
const MAX_PLAYERS := 6
const MAGIC := "SKODARACER1"

signal lobby_changed
signal joined
signal join_failed(reason: String)
signal session_ended(reason: String)
signal hosts_changed
signal race_started(track: int, diff: int, roster: Array)
signal snapshot_received(data: PackedFloat32Array)
signal back_to_lobby
signal peer_left(id: int)

var active := false
var is_host := false
var players := {}      # peer id -> {"name": String, "driver": int}
var track := 0
var diff := 1
var in_race := false
var inputs := {}       # peer id -> {"steer", "buttons", "seq"}
var hosts := {}        # ip -> {"name", "count", "racing", "t"}
var _pending := {}
var _udp: PacketPeerUDP
var _listen: PacketPeerUDP
var _bcast_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


# ---------------------------------------------------------------- session
func host(name: String, driver: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	in_race = false
	players = {1: {"name": name, "driver": driver}}
	track = int(Game.settings.track)
	diff = int(Game.settings.diff)
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_bcast_t = 0.0
	lobby_changed.emit()
	return OK


func join(ip: String, name: String, driver: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	_pending = {"name": name, "driver": driver}
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	in_race = false
	players = {}
	inputs = {}
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


func _process(delta: float) -> void:
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
			if parts.size() >= 4 and parts[0] == MAGIC:
				var known := hosts.has(ip)
				hosts[ip] = {"name": parts[1], "count": int(parts[2]), "racing": parts[3] == "1", "t": Time.get_ticks_msec()}
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
	var msg := "%s|%s|%d|%d" % [MAGIC, host_name.replace("|", " "), players.size(), 1 if in_race else 0]
	var data := msg.to_utf8_buffer()
	var targets := ["255.255.255.255"]
	for ip in local_ips():
		var p := String(ip).split(".")
		targets.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	for t in targets:
		_udp.set_dest_address(t, DISCOVERY_PORT)
		_udp.put_packet(data)


# ---------------------------------------------------------------- peers
func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	players.erase(id)
	inputs.erase(id)
	peer_left.emit(id)
	_sync_lobby()


func _on_connected() -> void:
	_register.rpc_id(1, String(_pending.get("name", "Hráč")), int(_pending.get("driver", 0)))
	joined.emit()


func _on_failed() -> void:
	leave()
	join_failed.emit("Nepodařilo se připojit. Zkontroluj adresu a že jste na stejné Wi-Fi.")


func _on_server_gone() -> void:
	leave()
	session_ended.emit("Hostitel ukončil hru.")


@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, driver: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS or in_race:
		_rejected.rpc_id(id, "Hra je plná nebo už závod běží.")
		return
	players[id] = {"name": pname.substr(0, 16), "driver": _free_driver(driver, id)}
	_sync_lobby()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	leave()
	join_failed.emit(reason)


@rpc("any_peer", "call_remote", "reliable")
func _request_driver(driver: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].driver = _free_driver(driver, id)
		_sync_lobby()


func set_my_driver(d: int) -> void:
	if is_host:
		players[1].driver = _free_driver(d, 1)
		_sync_lobby()
	elif active:
		_request_driver.rpc_id(1, d)


func set_track(t: int, d: int) -> void:
	if not is_host:
		return
	track = t
	diff = d
	_sync_lobby()


func _free_driver(want: int, id: int) -> int:
	var taken := {}
	for pid in players.keys():
		if pid != id:
			taken[int(players[pid].driver)] = true
	if not taken.has(want):
		return want
	for i in Game.CHARS.size():
		if not taken.has(i):
			return i
	return want


func _sync_lobby() -> void:
	lobby_changed.emit()
	if is_host and active:
		_lobby.rpc(players, track, diff)


@rpc("authority", "call_remote", "reliable")
func _lobby(p: Dictionary, t: int, d: int) -> void:
	players = p
	track = t
	diff = d
	lobby_changed.emit()


# ---------------------------------------------------------------- race
func start_race() -> void:
	if not is_host:
		return
	var humans: Array = []
	var used := {}
	for pid in players.keys():
		var pl: Dictionary = players[pid]
		humans.append({"driver": int(pl.driver), "human": true, "peer": int(pid), "name": String(pl.name)})
		used[int(pl.driver)] = true
	humans.shuffle()
	var ai: Array = []
	for i in Game.CHARS.size():
		if not used.has(i):
			ai.append({"driver": i, "human": false, "peer": 0, "name": ""})
	ai.shuffle()
	var roster := ai.slice(0, Game.MAX_KARTS - humans.size()) + humans
	in_race = true
	inputs = {}
	_race_start.rpc(track, diff, roster)
	race_started.emit(track, diff, roster)


@rpc("authority", "call_remote", "reliable")
func _race_start(t: int, d: int, roster: Array) -> void:
	in_race = true
	race_started.emit(t, d, roster)


func return_to_lobby() -> void:
	if not is_host:
		return
	in_race = false
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
	snapshot_received.emit(d)


func send_input(steer: float, buttons: int, seq: int) -> void:
	if active and not is_host:
		_net_input.rpc_id(1, steer, buttons, seq)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(steer: float, buttons: int, seq: int) -> void:
	if not is_host:
		return
	inputs[multiplayer.get_remote_sender_id()] = {"steer": clampf(steer, -1.0, 1.0), "buttons": buttons, "seq": seq}
