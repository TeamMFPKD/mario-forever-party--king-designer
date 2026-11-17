extends Control

class_name UiVirtualPointer

## 虚拟光标（**纯表现组件**）。
##
## 移动端没有系统鼠标指针：`Input.warp_mouse` 在那种环境下无事可做，屏幕上什么都不会出现。
## 手柄玩家用左摇杆推动的就是这个光标——所以必须自己画一个指在那儿。
## 位置、显隐全部由 autoload `UiNavigator` 决定（见 script/utils/ui_navigator.gd）。
##
## 桌面端不显示它：系统指针本身就是"手在哪"，再叠一个反而重影。

## 贴图热点（相对图标左上角）。与 project.godot 的 mouse_cursor/custom_image_hotspot 一致。
@export var hotspot: Vector2 = Vector2(25.0, 25.0)
## 按下确认键时整体缩小一点，给"按下去"一点反馈。
@export var press_scale: float = 0.88
@export var scale_speed: float = 14.0

var _shown: bool = false
var _scale_k: float = 1.0
var _scale_target: float = 1.0

@onready var _icon: TextureRect = $Icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	if _icon != null:
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not _shown:
		return
	_scale_k = move_toward(_scale_k, _scale_target, maxf(scale_speed, 0.01) * delta)
	_apply()


## 把光标摆到视口局部坐标 point 上。
func show_at(point: Vector2) -> void:
	_shown = true
	visible = true
	position = point - hotspot
	_apply()


func hide_pointer() -> void:
	_shown = false
	visible = false


## 按住确认键时置 true，松开置 false。
func set_highlight(on: bool) -> void:
	_scale_target = press_scale if on else 1.0


func _apply() -> void:
	if _icon == null:
		return
	_icon.pivot_offset = hotspot
	_icon.scale = Vector2(_scale_k, _scale_k)
