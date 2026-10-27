class_name PlatformCaps
extends RefCounted
## Platform differences live here; native behaviour stays unchanged.

static func is_web() -> bool:
	return OS.has_feature("web")


static func has_touch() -> bool:
	if is_web():
		return bool(WebBridge.capabilities.get("touch", false))
	return DisplayServer.is_touchscreen_available()


static func uses_mobile_layout() -> bool:
	if is_web():
		return bool(WebBridge.capabilities.get("mobileLayout", false))
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")


static func has_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func has_persistent_storage() -> bool:
	if is_web():
		return bool(WebBridge.capabilities.get("storageAvailable", false)) and OS.is_userfs_persistent()
	return true


static func has_fullscreen() -> bool:
	if is_web():
		return bool(WebBridge.capabilities.get("fullscreen", false))
	return DisplayServer.get_name() != "headless"


static func audio_ready() -> bool:
	# W03 replaces procedural audio before enabling it in the web build.
	return not is_web()


static func network_ready() -> bool:
	# ENet and UDP remain native-only; web rooms arrive in W10–W12.
	return not is_web()


static func haptics_ready() -> bool:
	return not is_web()   # Browser haptics and sensor permissions are part of W04.


static func preview_ai_line() -> bool:
	# W01 uses the existing centre-line fallback. W02 replaces it with baked data.
	return is_web()
