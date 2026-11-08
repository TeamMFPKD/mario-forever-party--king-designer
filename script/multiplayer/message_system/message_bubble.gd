extends Control

class_name MessageBubble

## 左下角单条消息气泡。
## 快捷消息：头像 + 玩家名 + 消息文本；
## 系统消息（玩家离开 / 与主机断开）：沿用旧的纯文字外观，只保留消息文本。
## 两种气泡共用同一套动画：从下方滑入，停留后向左滑出并淡出，由 MessageOverlay 统一堆叠。

signal finished(bubble: MessageBubble)

const SHOW_TIME: float = 2.0
const FADE_IN_TIME: float = 0.18
const FADE_OUT_TIME: float = 0.3
const SLIDE_IN_OFFSET: float = 48.0
const SLIDE_OUT_OFFSET: float = 48.0
const SYSTEM_FONT_SIZE: int = 25
const SYSTEM_HEIGHT: float = 40.0

@export var avatar_texture: TextureRect
@export var avatar_initial: Label
@export var avatar_root: Control
@export var name_label: Label
@export var message_label: Label
@export var bubble_panel: PanelContainer

var _tween: Tween
var _finished: bool = false


func setup(player_name: String, message: String, avatar_id: String = "") -> void:
	name_label.text = player_name
	message_label.text = message
	# 内置头像按 id 取（见 AvatarLibrary）；取不到时回退到名字首字
	var texture: Texture2D = Avatars.get_texture_by_id(avatar_id)
	avatar_texture.texture = texture
	var has_texture: bool = texture != null
	avatar_texture.visible = has_texture
	avatar_initial.visible = not has_texture
	if has_texture:
		avatar_initial.text = ""
	elif player_name.length() > 0:
		avatar_initial.text = player_name.substr(0, 1)
	else:
		avatar_initial.text = "?"


## 系统消息：无头像、无名称、无白色底板，仅保留原来的白字黑描边外观。
func setup_system(message: String) -> void:
	avatar_root.visible = false
	name_label.visible = false
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", SYSTEM_FONT_SIZE)
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	message_label.add_theme_constant_override("outline_size", 7)
	bubble_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	size = Vector2(size.x, SYSTEM_HEIGHT)


func play_intro(target_x: float) -> void:
	var target_y: float = position.y
	# 从下方滑入
	position = Vector2(target_x, target_y + SLIDE_IN_OFFSET)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "position:y", target_y, FADE_IN_TIME)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(SHOW_TIME)
	# 向左滑出并淡出
	_tween.tween_property(self, "position:x", target_x - SLIDE_OUT_OFFSET, FADE_OUT_TIME)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_on_lifetime_finished)


func dismiss() -> void:
	if _finished:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	var target_x: float = position.x - SLIDE_OUT_OFFSET
	_tween = create_tween()
	_tween.tween_property(self, "position:x", target_x, FADE_OUT_TIME)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_on_lifetime_finished)


func _on_lifetime_finished() -> void:
	if _finished:
		return
	_finished = true
	finished.emit(self)
