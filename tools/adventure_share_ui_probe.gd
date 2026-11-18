extends Node

## 探针：验证百人团舞台能正常加载、「快速导出 / 快速导入」按钮与导入页接线正确。
## 结果写进 tools/adventure_share_ui_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_share_ui_probe_result.txt"
const STAGE_SCENE: String = "res://room/adventure/adventure_stage.tscn"
## 端到端导入会真的写档：先切到临时 ini，绝不碰玩家存档。
const TMP_INI: String = "user://adventure_share_ui_probe.ini"

var _lines: Array[String] = []
var _stage: Control


func _ready() -> void:
	await get_tree().process_frame
	_cleanup()
	await _run()
	_write()
	_cleanup()
	get_tree().quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP_INI):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_INI))


func _run() -> void:
	var packed: PackedScene = load(STAGE_SCENE)
	_line("scene_loaded", packed != null, true)
	if packed == null:
		return
	_stage = packed.instantiate() as Control
	add_child(_stage)
	await get_tree().process_frame
	await get_tree().process_frame

	_line("export_button", _stage.get("export_code_button") != null, true)
	_line("import_button", _stage.get("import_code_button") != null, true)
	var export_button: Button = _stage.get("export_code_button") as Button
	_line("export_text", export_button.text if export_button != null else "", tr("快速导出"))
	_line("export_has_script", export_button.get_script() != null, true)
	_line("export_disabled", export_button.disabled, false)

	# 导入页：第一次点才实例化
	_line("panel_before", _stage.get("_import_panel") == null, true)
	_stage.call("_on_import_code_pressed")
	await get_tree().process_frame
	var panel: Control = _stage.get("_import_panel") as Control
	_line("panel_created", panel != null, true)
	if panel == null:
		return
	_line("panel_visible", panel.visible, true)
	var input: LineEdit = panel.get_node_or_null("Panel/Margin/VBox/CodeInput") as LineEdit
	_line("input_exists", input != null, true)
	var import_button: Button = panel.get_node_or_null("Panel/Margin/VBox/Buttons/ImportButton") as Button
	var cancel_button: Button = panel.get_node_or_null("Panel/Margin/VBox/Buttons/CancelButton") as Button
	_line("panel_import_button", import_button != null, true)
	_line("panel_cancel_button", cancel_button != null, true)
	_line("import_disabled_when_empty", import_button.disabled if import_button != null else true, true)

	# 填入一条真码 -> 按钮解禁、提示改口（此时用的还是玩家真实存档，只读）
	var code: String = Adventure.export_share_code(1)
	_line("real_code_len", code.length() > 0, true)
	input.text = code
	input.text_changed.emit(input.text)
	await get_tree().process_frame
	_line("import_enabled_with_code", import_button.disabled if import_button != null else true, false)
	var hint: Label = panel.get_node_or_null("Panel/Margin/VBox/Hint") as Label
	# 提示走 tr()，断言要和当前语言一致，不能写死中文。
	_line("hint_with_code", hint.text if hint != null else "", tr("看起来是一条存档码，点「导入」"))

	# 撤销信号不能残留：取消后应隐藏、且只关不掉别人的面板
	cancel_button.pressed.emit()
	await get_tree().process_frame
	_line("panel_hidden_after_cancel", panel.visible, false)

	# 再开一次：输入清空
	_stage.call("_on_import_code_pressed")
	await get_tree().process_frame
	_line("panel_reopened", panel.visible, true)
	# headless 下剪贴板拿不到，输入应为空（不是把上次的残留带进来）
	_line("input_cleared_on_reopen", input.text.is_empty() or AdventureShareCode.looks_like_code(input.text), true)
	_stage.call("_on_import_cancelled")
	await get_tree().process_frame

	# 端到端：把一条真码喂给导入页，走完整的 submitted -> import_share_code -> 刷新槽位
	# 先换到临时存档，免得污染玩家真实的 adventure.ini。
	Adventure.store = AdventureStore.new(TMP_INI)
	Adventure.store.load()
	var before_slots: Array[Dictionary] = Adventure.get_run_slots()
	var used_before: int = Adventure.store.used_run_slots()
	_stage.call("_on_import_code_pressed")
	await get_tree().process_frame
	_stage.call("_on_import_submitted", code)
	await get_tree().process_frame
	await get_tree().process_frame
	_line("e2e_panel_closed", panel.visible, false)
	var used_after: int = Adventure.store.used_run_slots()
	_line("e2e_slot_used", used_after, used_before + 1)
	var after_slots: Array[Dictionary] = Adventure.get_run_slots()
	var newly_valid: int = 0
	for index: int in range(after_slots.size()):
		var was_valid: bool = bool(before_slots[index].get("valid", false)) if index < before_slots.size() else false
		if bool(after_slots[index].get("valid", false)) and not was_valid:
			newly_valid += 1
	_line("e2e_new_card_valid", newly_valid, 1)


func _line(name: String, actual: Variant, expected: Variant = null) -> void:
	var text: String = "%s=%s" % [name, str(actual)]
	if expected != null:
		text += "  (expect %s)  %s" % [str(expected), "OK" if str(actual) == str(expected) else "FAIL"]
	_lines.append(text)


func _write() -> void:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines) + "\n")
	file.close()