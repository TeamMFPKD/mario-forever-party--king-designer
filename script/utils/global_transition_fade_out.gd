extends Node

class_name GlobalTransitionFader

## 全局场景过渡（autoload：GlobalTransition）。
##
## 统一所有场景切换入口：切换前截取当前画面，切换后让截图通过 shader 淡出，
## 避免场景硬切。本项目不再直接调用 SceneTree.change_scene_to_file /
## reload_current_scene，一律走这里。
##
## 用法：
##   GlobalTransition.change_scene_to_file("uid://xxx")
##   GlobalTransition.reload_current_scene()
## 两者都是协程，需要等待过渡播放完毕时可以 await。
##
## 注意：autoload 必须挂脚本本身（而不是 .tscn 场景），否则本项目的 GDScript
## 静态类型推断会把 GlobalTransition 退化成 Node，调用处会编译失败。

const TRANSITION_SHADER: Shader = preload("res://object/utils/global_transition_fade_out.gdshader")

## 淡出时长（秒）
@export var duration: float = 0.25

var rect_texture: TextureRect
var texture_material: ShaderMaterial

var _canvas: CanvasLayer
var _transition_texture: ImageTexture
var _animating: bool = false
var _time: float = 0.0
var _busy: bool = false


func _ready() -> void:
	# 场景切换常发生在暂停状态下（死亡、超时），过渡必须继续播放
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


## 带过渡地切换到指定场景（支持 res:// 与 uid://）
func change_scene_to_file(path: String) -> void:
	if _busy:
		Log.w("GlobalTransition", "transition in progress, ignore change_scene_to_file: %s" % path)
		return
	var capture: Image = await _capture_screen()
	var shown: bool = _show_capture(capture)
	_busy = true
	var err: int = get_tree().change_scene_to_file(path)
	await _play_fade_out(err, shown)


## 带过渡地切换到已加载的场景资源
func change_scene_to_packed(packed: PackedScene) -> void:
	if _busy:
		Log.w("GlobalTransition", "transition in progress, ignore change_scene_to_packed")
		return
	var capture: Image = await _capture_screen()
	var shown: bool = _show_capture(capture)
	_busy = true
	var err: int = get_tree().change_scene_to_packed(packed)
	await _play_fade_out(err, shown)


## 带过渡地重新加载当前场景
func reload_current_scene() -> void:
	if _busy:
		Log.w("GlobalTransition", "transition in progress, ignore reload_current_scene")
		return
	var capture: Image = await _capture_screen()
	var shown: bool = _show_capture(capture)
	_busy = true
	var err: int = get_tree().reload_current_scene()
	await _play_fade_out(err, shown)


## 用代码搭建覆盖层，避免把 autoload 指向场景资源
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "Canvas"
	_canvas.layer = 10
	add_child(_canvas)

	var screen: Control = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(screen)

	texture_material = ShaderMaterial.new()
	texture_material.shader = TRANSITION_SHADER
	texture_material.set_shader_parameter("i_time", 0.0)
	texture_material.set_shader_parameter("i_time_total", duration)

	rect_texture = TextureRect.new()
	rect_texture.name = "Capture"
	rect_texture.material = texture_material
	rect_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect_texture.stretch_mode = TextureRect.STRETCH_SCALE
	rect_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect_texture.visible = false
	screen.add_child(rect_texture)


## 截取当前帧画面；headless 等无渲染环境返回 null
func _capture_screen() -> Image:
	if rect_texture == null or texture_material == null:
		return null
	if DisplayServer.get_name() == "headless":
		return null
	# 等本帧绘制结束，保证截到的是切换前的最后一帧
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## 把截图贴满屏幕盖住当前画面（画面不变，但之后切场景不会闪）
func _show_capture(img: Image) -> bool:
	if img == null:
		return false
	var width: int = img.get_width()
	var height: int = img.get_height()
	if _transition_texture == null \
			or _transition_texture.get_width() != width \
			or _transition_texture.get_height() != height \
			or _transition_texture.get_format() != img.get_format():
		_transition_texture = ImageTexture.create_from_image(img)
		rect_texture.texture = _transition_texture
	else:
		_transition_texture.update(img)
	texture_material.set_shader_parameter("i_time", 0.0)
	texture_material.set_shader_parameter("i_time_total", duration)
	rect_texture.visible = true
	return true


## 等新场景就绪后，让截图淡出露出新场景
func _play_fade_out(err: int, shown: bool) -> void:
	if err != OK:
		Log.e("GlobalTransition", "failed to switch scene: %s" % error_string(err))
		rect_texture.visible = false
		_busy = false
		return
	if not shown:
		# 没有截图可淡出（headless / 取图失败），新场景直接显示
		_busy = false
		return
	# 等新场景实例化并完成第一帧绘制，再开始淡出，避免闪出未绘制的画面
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_time = 0.0
	_animating = true
	texture_material.set_shader_parameter("i_time", 0.0)
	while _animating:
		await get_tree().process_frame
	_busy = false


func _process(delta: float) -> void:
	if not _animating:
		return
	_time += delta
	if texture_material:
		texture_material.set_shader_parameter("i_time", _time)
	if _time >= duration:
		_animating = false
		rect_texture.visible = false
