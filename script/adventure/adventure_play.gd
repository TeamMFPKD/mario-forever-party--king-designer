extends Node2D

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

## 百人团游玩场景：清掉编辑/超时/截图等无关节点，挂 HUD。
## 暂停菜单在子节点 AdventurePauseMenu（CanvasLayer，PROCESS_MODE_ALWAYS）。

var _lives_label: Label
var _progress_label: Label
var _tier_label: Label
var _level_label: Label


func _ready() -> void:
	_remove_node("TimeoutManager")
	_remove_node("GameRoomSize/GameTimeHUD")
	_remove_node("GameRoomSize/MarginContainer")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/RandomCapture")
	_remove_node("GameRoomSize/SubViewportContainer/SubViewport/Level/SaveLevel")
	_build_hud()
	Adventure.run_changed.connect(_update_hud)
	_update_hud()


func _remove_node(path: String) -> void:
	var node: Node = get_node_or_null(path)
	if node != null:
		node.queue_free()


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "AdventureHud"
	layer.layer = 20
	add_child(layer)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 28
	margin.offset_top = 24
	margin.offset_right = 760
	margin.offset_bottom = 220
	layer.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_lives_label = _make_label(box, 40)
	_progress_label = _make_label(box, 32)
	_tier_label = _make_label(box, 26)
	_level_label = _make_label(box, 26)


func _make_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	return label


func _update_hud() -> void:
	if not Adventure.is_running():
		return
	var run: Dictionary = Adventure.current_run
	var lives: int = int(run.get("lives_left", 0))
	var cleared: int = int(run.get("cleared_count", 0))
	var mode: String = str(run.get("mode", "finite"))
	var total: int = int(run.get("total_levels", -1))
	var tier: int = int(run.get("active_tier", run.get("tier", 0)))

	_lives_label.text = "♥ %d / 100" % lives
	if mode == "finite":
		_progress_label.text = "已通过 %d / %d" % [cleared, maxi(total, 0)]
	else:
		_progress_label.text = "已通过 %d 关" % cleared
	_tier_label.text = "档位 %d" % tier if tier > 0 else "随机档"

	var index: int = int(run.get("index", 0))
	if mode == "finite":
		_level_label.text = "第 %d / %d 关" % [index + 1, maxi(total, 0)]
	else:
		_level_label.text = "第 %d 关" % (index + 1)
