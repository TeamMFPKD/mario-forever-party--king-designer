extends MarginContainer

## 让 Host / Join 面板的尺寸跟随内部控件，而不是让控件拉伸去填满面板。
##
## 背景：面板原本写死 900x1000，内部控件又全部带 size_flags_vertical = 3（EXPAND），
## 一屏高度被几个控件均分，控件于是又大又空。
##
## 现在的规则：
##   - 高度：跟随内容容器的 combined_minimum_size，内容多就高，内容少就矮；
##   - 宽度：不低于 min_width（对齐 2026-09 版本的 680），内容更宽时才继续外扩。
##
## 面板使用居中锚点（anchors_preset = 8），offset 需按尺寸对称重算。

## 面板最小宽度，对齐 2026-09-26 那版的 680。
@export var min_width: float = 680.0

@onready var _content: Control = get_node_or_null("MfpkdPanel/UiMarginContainer")


func _ready() -> void:
	if _content == null:
		push_warning("FitContentPanel: 找不到 MfpkdPanel/UiMarginContainer")
		return
	# 控件增删、换字体、换语言都会改变内容尺寸，统一延后一帧重测。
	_content.minimum_size_changed.connect(_fit)
	_content.child_entered_tree.connect(_on_content_changed)
	_content.child_exiting_tree.connect(_on_content_changed)
	call_deferred("_fit")


func _on_content_changed(_node: Node) -> void:
	call_deferred("_fit")


func _fit() -> void:
	if _content == null:
		return

	var inner: Vector2 = _content.get_combined_minimum_size()
	var target: Vector2 = Vector2(maxf(inner.x, min_width), inner.y)

	custom_minimum_size = target
	offset_left = -target.x * 0.5
	offset_right = target.x * 0.5
	offset_top = -target.y * 0.5
	offset_bottom = target.y * 0.5
