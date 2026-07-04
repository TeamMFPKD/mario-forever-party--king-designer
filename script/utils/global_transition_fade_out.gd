extends Node

@export var rect_texture: TextureRect

@export var duration: float = 0.18

var texture_material: ShaderMaterial
var _transition_texture: ImageTexture

var _captured_image: Image
var _animating: bool = false
var _time: float = 0.0

func _ready() -> void:
	for i in range(3):
		await get_tree().process_frame
	get_tree().scene_changed.connect(_on_scene_changed)
	_connect_current_scene()
	if not rect_texture:
		push_error("TextureRect node is not assigned!")
		return
	texture_material = rect_texture.material as ShaderMaterial
	if not texture_material:
		push_error("ShaderMaterial node is not assigned!")
		return
	texture_material.set_shader_parameter("i_time_total", duration)
	var placeholder := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color.BLACK)
	_transition_texture = ImageTexture.create_from_image(placeholder)
	rect_texture.texture = _transition_texture
	rect_texture.modulate = Color(1, 1, 1, 0)

func _connect_current_scene() -> void:
	var scene = get_tree().current_scene
	if scene and not scene.tree_exiting.is_connected(_on_scene_exiting):
		scene.tree_exiting.connect(_on_scene_exiting)

func _on_scene_exiting() -> void:
	var vp := get_viewport()
	_captured_image = vp.get_texture().get_image()
	if _captured_image and _transition_texture:
		_transition_texture.update(_captured_image)
		RenderingServer.force_sync()

	_time = 0.0
	_animating = true
	rect_texture.modulate = Color(1, 1, 1, 1)
	texture_material.set_shader_parameter("i_time", 0.0)

func _process(delta: float) -> void:
	if not _animating:
		return

	_time += delta
	texture_material.set_shader_parameter("i_time", _time)

	if _time >= duration:
		_animating = false
		rect_texture.modulate = Color(1, 1, 1, 0)

func _on_scene_changed() -> void:
	_captured_image = null
	_connect_current_scene()