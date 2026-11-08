extends TextureButton

## 标题画面右下角的社区 Ad：鼠标悬停时沿图片轮廓向外扩散一圈羽化的白色描边光晕。

const HOVER_GLOW_SHADER: Shader = preload("res://shader/ad_hover_glow.gdshader")

@export var forum_international_texture: Texture2D
@export var forum_cn_texture: Texture2D

@export_group("Hover Glow")
## 贴边描边颜色
@export var glow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 外围羽化颜色
@export var glow_outer_color: Color = Color(0.9, 0.95, 1.0, 1.0)
## 光晕最大外扩距离（像素）
@export_range(0.0, 96.0, 1.0) var glow_radius: float = 36.0
## 贴边实心描边宽度（像素）
@export_range(0.0, 12.0, 0.5) var glow_edge_width: float = 3.0
## 光晕亮度
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 1.0
## 呼吸脉动幅度（0 = 关闭）
@export_range(0.0, 0.5, 0.01) var glow_pulse_strength: float = 0.15
## 呼吸脉动速度
@export_range(0.0, 10.0, 0.1) var glow_pulse_speed: float = 2.6
## 白光外侧的淡冷暗晕颜色
@export var glow_shadow_color: Color = Color(0.24, 0.34, 0.5, 1.0)
## 暗晕强度（0 = 关闭；亮背景上加大更醒目）
@export_range(0.0, 0.6, 0.01) var glow_shadow_strength: float = 0.22
## 悬停渐入时长（秒）
@export_range(0.0, 1.0, 0.01) var glow_fade_in_time: float = 0.18
## 移出渐出时长（秒）
@export_range(0.0, 1.0, 0.01) var glow_fade_out_time: float = 0.3

var language: String

var _glow: Sprite2D
var _glow_material: ShaderMaterial
var _glow_tween: Tween
var _glow_amount: float = 0.0
var _last_texture: Texture2D
var _last_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_glow()
	_refresh_glow()


func _process(_delta: float) -> void:
	language = TranslationServer.get_locale()
	if language == "zh_CN":
		texture_normal = forum_cn_texture
	else:
		texture_normal = forum_international_texture

	# 切换语言会同时改变贴图和按钮尺寸，只有变化时才重算光晕
	if texture_normal != _last_texture or size != _last_size:
		_refresh_glow()


func _on_button_pressed() -> void:
	match language:
		"en":
			# Mario Forever Space
			OS.shell_open("https://marioforever.space/")
		"zh_CN":
			# Mario Forever 社区
			OS.shell_open("https://www.marioforever.net/")


## 光晕层比按钮四周各多 glow_radius 像素，绘制在按钮贴图之下
func _build_glow() -> void:
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = HOVER_GLOW_SHADER
	_glow_material.set_shader_parameter("glow_color", glow_color)
	_glow_material.set_shader_parameter("glow_color_outer", glow_outer_color)
	_glow_material.set_shader_parameter("intensity", glow_intensity)
	_glow_material.set_shader_parameter("max_radius", glow_radius)
	_glow_material.set_shader_parameter("edge_width", glow_edge_width)
	_glow_material.set_shader_parameter("pulse_strength", glow_pulse_strength)
	_glow_material.set_shader_parameter("pulse_speed", glow_pulse_speed)
	_glow_material.set_shader_parameter("shadow_color", glow_shadow_color)
	_glow_material.set_shader_parameter("shadow_strength", glow_shadow_strength)
	_glow_material.set_shader_parameter("amount", 0.0)

	_glow = Sprite2D.new()
	_glow.name = "HoverGlow"
	_glow.show_behind_parent = true
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.material = _glow_material
	add_child(_glow, false, Node.INTERNAL_MODE_FRONT)


## 按当前贴图与按钮尺寸同步光晕层的大小、位置与 shader 参数
func _refresh_glow() -> void:
	if _glow == null or _glow_material == null:
		return

	var texture: Texture2D = texture_normal
	var button_size: Vector2 = size
	if texture == null or button_size.x <= 0.0 or button_size.y <= 0.0:
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_last_texture = texture
	_last_size = button_size

	var margin: float = glow_radius
	# TextureButton 默认按原尺寸绘制贴图（STRETCH_KEEP），此时图片只占按钮左上角
	var image_size: Vector2 = button_size
	var image_origin: Vector2 = Vector2.ZERO
	match stretch_mode:
		TextureButton.STRETCH_KEEP:
			image_size = texture_size
		TextureButton.STRETCH_KEEP_CENTERED:
			image_size = texture_size
			image_origin = (button_size - texture_size) * 0.5

	var glow_size: Vector2 = image_size + Vector2(margin, margin) * 2.0
	_glow.texture = texture
	_glow.position = image_origin + image_size * 0.5
	_glow.scale = Vector2(glow_size.x / texture_size.x, glow_size.y / texture_size.y)
	_glow_material.set_shader_parameter("source_texture", texture)
	_glow_material.set_shader_parameter("node_size_px", glow_size)
	_glow_material.set_shader_parameter("image_size_px", image_size)


func _on_mouse_entered() -> void:
	_play_glow_tween(1.0, glow_fade_in_time)


func _on_mouse_exited() -> void:
	_play_glow_tween(0.0, glow_fade_out_time)


func _play_glow_tween(target: float, duration: float) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	if duration <= 0.0:
		_set_glow_amount(target)
		return

	_glow_tween = create_tween()
	_glow_tween.set_trans(Tween.TRANS_QUAD)
	_glow_tween.set_ease(Tween.EASE_OUT)
	_glow_tween.tween_method(_set_glow_amount, _glow_amount, target, duration)


func _set_glow_amount(value: float) -> void:
	_glow_amount = value
	if _glow_material != null:
		_glow_material.set_shader_parameter("amount", value)
