extends Node

@export var rect_texture: TextureRect

## 动画总时长（秒）：从最左边的星出现到最右边的星出现完毕
@export var duration: float = 1.5

var texture_material: ShaderMaterial

var _animating: bool = false
var _time: float = 0.0

func _ready() -> void:
	for i in range(3):
		await get_tree().process_frame
	get_tree().scene_changed.connect(_on_scene_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	if not rect_texture:
		push_error("RectTexture node is not assigned!")
		return
	texture_material = rect_texture.material as ShaderMaterial
	if not texture_material:
		push_error("ShaderMaterial node is not assigned!")
		return
	rect_texture.visible = false
	texture_material.set_shader_parameter("iTime", 0.0)
	texture_material.set_shader_parameter("iDuration", duration)
	_update_resolution()

func _process(delta: float) -> void:
	if not _animating:
		return

	_time += delta
	texture_material.set_shader_parameter("iTime", _time)

	# scroll 走完整屏后星星自然缩小消失，多留 0.5 秒等最后的星收尾
	if _time >= duration + 0.5:
		_animating = false
		rect_texture.visible = false
		texture_material.set_shader_parameter("iTime", 0.0)

func _on_scene_changed() -> void:
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	rect_texture.texture = ImageTexture.create_from_image(img)
	_update_resolution(vp)

	_time = 0.0
	_animating = true
	rect_texture.visible = true
	texture_material.set_shader_parameter("iTime", 0.0)
	texture_material.set_shader_parameter("iDuration", duration)

func _on_viewport_size_changed() -> void:
	_update_resolution()

func _update_resolution(vp: Viewport = null) -> void:
	if vp == null:
		vp = get_viewport()
	if texture_material:
		texture_material.set_shader_parameter("iResolution", vp.get_visible_rect().size)
