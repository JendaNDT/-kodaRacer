extends Node
## Autoloaded before Game so browser capabilities exist before settings load.

var capabilities: Dictionary = {}
var _refresh_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_refresh_capabilities()


func _refresh_capabilities() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge = Engine.get_singleton("JavaScriptBridge")
	var raw = bridge.eval("window.SkodaRacerWeb ? window.SkodaRacerWeb.capabilitiesJson() : '{}'", true)
	if raw is String:
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			capabilities = parsed


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 2.0
		_refresh_capabilities()


func scene_ready() -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var bridge = Engine.get_singleton("JavaScriptBridge")
	bridge.eval("window.SkodaRacerWeb && window.SkodaRacerWeb.reportReady(%d)" % Engine.get_frames_drawn(), true)
	print("WEB READY: menu and 3D scene, frames=", Engine.get_frames_drawn())
