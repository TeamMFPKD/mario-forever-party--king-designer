extends Node

@export var rect_texture: TextureRect

@export var duration: float = 0.18

var texture_material: ShaderMaterial

var _animating: bool = false
var _time: float = 0.0

func _ready() -> void:
	for i in range(3):
		await get_tree().process_frame
	get_tree().scene_changed.connect(_on_scene_changed)
	if not rect_texture:
		push_error("RectTexture node is not assigned!")
		return
	texture_material = rect_texture.material as ShaderMaterial
	texture_material.set_shader_parameter("i_time_total", duration)
	if not texture_material:
		push_error("ShaderMaterial node is not assigned!")
		return
	rect_texture.visible = false

func _process(delta: float) -> void:
	if not _animating:
		return

	_time += delta
	texture_material.set_shader_parameter("i_time", _time)

	if _time >= duration:
		_animating = false
		rect_texture.visible = false
		texture_material.set_shader_parameter("i_time", 0.0)

func _on_scene_changed() -> void:
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	rect_texture.texture = ImageTexture.create_from_image(img)

	_time = 0.0
	_animating = true
	rect_texture.visible = true
	texture_material.set_shader_parameter("i_time", 0.0)