extends SceneTree

func _initialize() -> void:
	var peer := WebRTCPeerConnection.new()
	var initialized := peer.initialize({"iceServers": []})
	var reliable := peer.create_data_channel("w00-reliable", {"ordered": true})
	var fast := peer.create_data_channel("w00-unreliable", {"ordered": false, "maxRetransmits": 0})
	var ok := initialized == OK and reliable != null and fast != null
	if reliable != null:
		reliable.close()
	if fast != null:
		fast.close()
	peer.close()
	print("API PROBE ", "PASS" if ok else "FAIL", " Godot=", Engine.get_version_info().string,
		" initialize=", initialized, " reliable=", reliable != null, " unreliable=", fast != null)
	quit(0 if ok else 1)
