extends Node

## 探针：用玩家真实的 adventure.ini 量「快速导出」实际会生成多长的码。
## 只读，不写任何东西到玩家存档。结果写进 tools/adventure_share_size_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_share_size_probe_result.txt"

var _lines: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for slot: int in range(1, AdventureStore.MAX_RUN_SLOTS + 1):
		_report(slot)
	_write()
	get_tree().quit()


func _report(slot: int) -> void:
	var run: Dictionary = Adventure.store.get_run(slot)
	if run.is_empty():
		_line("slot%d_empty" % slot, true, true)
		return
	var code: String = Adventure.export_share_code(slot)
	var level_count: int = int(run.get("level_count", 0))
	if level_count <= 0:
		var keys: Array = run.get("level_keys", [])
		level_count = keys.size()
	_line("slot%d_mode" % slot, str(run.get("mode", "finite")))
	_line("slot%d_levels" % slot, level_count)
	_line("slot%d_index" % slot, int(run.get("index", 0)))
	_line("slot%d_code_chars" % slot, code.length())
	_line("slot%d_code_kb" % slot, snappedf(float(code.length()) / 1024.0, 0.1))
	# 一条码里不该有换行（导出是整条交给剪贴板的）。
	_line("slot%d_is_single_line" % slot, not code.contains("\n"), true)
	var decoded: Dictionary = AdventureShareCode.decode(code)
	_line("slot%d_decode_ok" % slot, bool(decoded.get("ok", false)), true)
	var back: Dictionary = decoded.get("run", {})
	_line("slot%d_keys_roundtrip" % slot,
		str(back.get("level_keys", [])) == str(run.get("level_keys", [])), true)


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
