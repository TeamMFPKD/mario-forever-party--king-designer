extends Node

## 按父节点（Panel / PanelContainer）的尺寸自动切换面板样式：
## - 接近一屏的大面板：原版灰色底板（无边框），适合大面积铺屏；
## - 普通卡片：纸片制造样式（近白卡片 + 细线），边框表现更明显。
##
## 用法：把本节点作为 Panel / PanelContainer 的子节点即可，样式资源默认已挂好。
## 判定阈值可在检查器里调整，默认面积占视口 25% 以上算大面板；
## 另外「最长边达到视口 90%」的条状面板（如全屏工具栏）也按大面板处理。

const LARGE_STYLE: StyleBox = preload("res://ui/theme/panel_large.tres")
const SMALL_STYLE: StyleBox = preload("res://ui/theme/panel_small.tres")

@export var large_style: StyleBox = LARGE_STYLE
@export var small_style: StyleBox = SMALL_STYLE
@export_range(0.05, 0.95, 0.01) var large_area_ratio: float = 0.25
@export_range(0.30, 1.0, 0.01) var large_edge_ratio: float = 0.9

var _target: Control
var _is_large: bool = false
var _has_applied: bool = false


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_warning("PanelStyleAuto 的父节点必须是 Panel 或 PanelContainer")
		return

	_target.resized.connect(_refresh)
	get_viewport().size_changed.connect(_refresh)
	call_deferred("_refresh")


func _refresh() -> void:
	if _target == null:
		return

	var viewport_size: Vector2 = _target.get_viewport_rect().size
	var target_size: Vector2 = _target.size
	var viewport_area: float = maxf(viewport_size.x * viewport_size.y, 1.0)
	var area_ratio: float = target_size.x * target_size.y / viewport_area
	var max_edge_ratio: float = maxf(
		target_size.x / maxf(viewport_size.x, 1.0),
		target_size.y / maxf(viewport_size.y, 1.0)
	)
	var is_large: bool = area_ratio >= large_area_ratio or max_edge_ratio >= large_edge_ratio

	if _has_applied and is_large == _is_large:
		return

	_is_large = is_large
	_has_applied = true
	var style: StyleBox = large_style if is_large else small_style
	if style != null:
		_target.add_theme_stylebox_override("panel", style)
