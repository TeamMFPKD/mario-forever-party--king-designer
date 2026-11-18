extends Node

## 截图脚本（必须窗口化运行）：快速导出的一次性通知 + 导入页。
##   tools/adventure_share_ui.png      舞台右上角两个按钮
##   tools/adventure_share_import.png  导入页（已自动读入剪贴板里的码）

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const STAGE_SCENE: String = "res://room/adventure/adventure_stage.tscn"

var _stage: Control


func _ready() -> void:
	await get_tree().process_frame
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate() as Control
	add_child(_stage)
	await get_tree().create_timer(4.5).timeout
	await _shot("res://tools/adventure_share_ui.png")

	# 选中有团的存档位，点一次导出：看整条码被复制的通知
	_stage.call("_on_selection_changed", 1)
	await get_tree().create_timer(0.4).timeout
	_stage.call("_on_export_code_pressed")
	await get_tree().create_timer(0.6).timeout
	await _shot("res://tools/adventure_share_export.png")
	Notice.hide_notice()
	await get_tree().create_timer(0.7).timeout

	# 导入页：填入导出出来的整条码
	_stage.call("_on_import_code_pressed")
	await get_tree().process_frame
	var panel: Control = _stage.get("_import_panel") as Control
	var input: LineEdit = panel.get_node_or_null("Panel/Margin/VBox/CodeInput") as LineEdit
	if input != null:
		input.text = Adventure.export_share_code(1)
		input.text_changed.emit(input.text)
	await get_tree().create_timer(0.9).timeout
	await _shot("res://tools/adventure_share_import.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
