class_name SkidMarks
extends MultiMeshInstance3D
## Tyre marks on the road: thin dark strips left by the rear wheels while
## drifting, braking hard or spinning. A fixed ring of strips (its size comes
## from the graphics quality); the oldest strip is reused for the next one and
## the fading happens on the GPU, so nothing is updated per frame.

const LIFE := 7.0
const WIDTH := 0.36
const STEP := 0.75    # metres between strip joints
const Y := 0.08       # just above the road (0.04) and the kerbs (0.065)

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float now;
uniform float life = 7.0;
uniform vec4 tint : source_color = vec4(0.04, 0.04, 0.05, 0.7);
varying float fade;
void vertex() {
	float age = now - INSTANCE_CUSTOM.r;
	fade = clamp(1.0 - age / life, 0.0, 1.0) * INSTANCE_CUSTOM.g;
}
void fragment() {
	float edge = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = tint.rgb;
	ALPHA = tint.a * fade * smoothstep(0.0, 0.45, edge);
}
"""

static var _shader: Shader

var _next := 0
var _clock := 0.0
var _mat: ShaderMaterial


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("life", LIFE)
	var strip := PlaneMesh.new()
	strip.size = Vector2(WIDTH, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = strip
	mm.instance_count = Gfx.skid_marks()
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-4000, -1, -4000), Vector3(8000, 2, 8000))


## Advances the fade clock (0 while the race is paused).
func tick(dt: float) -> void:
	_clock += dt
	_mat.set_shader_parameter("now", _clock)


## One strip from a to b; strength 0..1 is how dark it starts.
func add(a: Vector3, b: Vector3, strength: float) -> void:
	var d := b - a
	d.y = 0.0
	var l := d.length()
	if l < 0.05 or l > 12.0:   # 12 m = a teleport (respawn, network catch-up)
		return
	var mm := multimesh
	var i := _next % mm.instance_count
	var basis := Basis.from_euler(Vector3(0.0, atan2(d.x, d.z), 0.0)) * Basis.from_scale(Vector3(1.0, 1.0, l + 0.06))
	var mid := (a + b) * 0.5
	mid.y = Y
	mm.set_instance_transform(i, Transform3D(basis, mid))
	mm.set_instance_custom_data(i, Color(_clock, clampf(strength, 0.0, 1.0), 0.0, 0.0))
	_next += 1
	mm.visible_instance_count = mini(_next, mm.instance_count)
