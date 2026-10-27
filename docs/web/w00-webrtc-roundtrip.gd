extends SceneTree

var left: WebRTCPeerConnection
var right: WebRTCPeerConnection
var outgoing := {}
var incoming := {}
var sent := {}
var returned := {}
var started := 0

func _initialize() -> void:
	started = Time.get_ticks_msec()
	left = WebRTCPeerConnection.new()
	right = WebRTCPeerConnection.new()
	var a := left.initialize({"iceServers": []})
	var b := right.initialize({"iceServers": []})
	if a != OK or b != OK:
		print("PROBE FAIL initialize ", a, " ", b)
		quit(1)
		return
	left.session_description_created.connect(func(kind: String, description: String):
		left.set_local_description(kind, description)
		right.set_remote_description(kind, description))
	right.session_description_created.connect(func(kind: String, description: String):
		right.set_local_description(kind, description)
		left.set_remote_description(kind, description))
	left.ice_candidate_created.connect(func(media: String, index: int, candidate: String):
		right.add_ice_candidate(media, index, candidate))
	right.ice_candidate_created.connect(func(media: String, index: int, candidate: String):
		left.add_ice_candidate(media, index, candidate))
	right.data_channel_received.connect(func(channel: WebRTCDataChannel): incoming[channel.get_label()] = channel)
	outgoing["reliable"] = left.create_data_channel("reliable", {"ordered": true})
	outgoing["unreliable"] = left.create_data_channel("unreliable", {"ordered": false, "maxRetransmits": 0})
	var offer := left.create_offer()
	if offer != OK:
		print("PROBE FAIL offer ", offer)
		quit(1)

func _process(_delta: float) -> bool:
	if left == null or right == null:
		return false
	left.poll()
	right.poll()
	for label in outgoing:
		var channel: WebRTCDataChannel = outgoing[label]
		if channel != null and channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			if not sent.has(label):
				channel.put_packet(("W00-" + label).to_utf8_buffer())
				sent[label] = true
			if channel.get_available_packet_count() > 0:
				var message := channel.get_packet().get_string_from_utf8()
				if message != "W00-" + label:
					print("PROBE FAIL payload ", label)
					quit(1)
				returned[label] = true
	for label in incoming:
		var channel: WebRTCDataChannel = incoming[label]
		if channel.get_available_packet_count() > 0:
			channel.put_packet(channel.get_packet())
	if returned.size() == 2:
		print("PROBE PASS Godot=", Engine.get_version_info().string, " reliable+unreliable roundtrip ms=", Time.get_ticks_msec() - started)
		left.close()
		right.close()
		quit(0)
	elif Time.get_ticks_msec() - started > 15000:
		print("PROBE FAIL timeout states=", left.get_connection_state(), " ", right.get_connection_state())
		left.close()
		right.close()
		quit(1)
	return false
