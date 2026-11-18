extends Node

## 探针：走真实 Adventure API 的导入失败分支（缺关卡 / 坏码 / 槽位满），
## 确认错误文案拼接与「不写档」的行为。结果写进 tools/adventure_share_fail_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_share_fail_probe_result.txt"
const TMP_INI: String = "user://adventure_share_fail_probe.ini"
const GHOST_LEVEL: String = "__definitely_missing_level__.lvl"

var _lines: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup()
	Adventure.store = AdventureStore.new(TMP_INI)
	Adventure.store.load()
	await _run()
	_write()
	_cleanup()
	get_tree().quit()


func _run() -> void:
	# 造一条引用「本机不存在关卡」的码
	var src: AdventureStore = AdventureStore.new(TMP_INI + ".src")
	src.load()
	src.set_level_meta(GHOST_LEVEL, GHOST_LEVEL, "1111222233334444", 0)
	var ghost_run: Dictionary = {
		"active": true, "id": "ghost", "mode": "finite", "seed": 1, "tier": 1,
		"active_tier": 1, "started_at": 0, "index": 0, "total_levels": 1,
		"lives_total": 2, "lives_left": 2, "lives_cap": 100, "cleared_count": 0,
		"deaths": 0, "skipped_count": 0, "skipped_soft": 0, "skipped_hard": 0,
		"skipped_keys": [], "cycle": 1, "cycle_played": [],
		"level_keys": [GHOST_LEVEL], "level_fingerprints": ["1111222233334444"],
	}
	var ghost_code: String = AdventureShareCode.encode(src, 1, ghost_run)
	_line("ghost_code_len", ghost_code.length() > 0, true)

	var missing: Array[String] = Adventure.share_code_missing_levels(ghost_code)
	_line("missing_count", missing.size(), 1)
	_line("missing_name", missing[0] if missing.size() > 0 else "", GHOST_LEVEL)

	var before: int = Adventure.store.used_run_slots()
	var result: Dictionary = Adventure.import_share_code(ghost_code)
	_line("ghost_ok", bool(result.get("ok", false)), false)
	_line("ghost_error", str(result.get("error", "")), "存档引用了本机没有的关卡：" + GHOST_LEVEL)
	_line("ghost_no_write", Adventure.store.used_run_slots(), before)

	# 坏码走同一出口
	var bad: Dictionary = Adventure.import_share_code("这不是码")
	_line("bad_ok", bool(bad.get("ok", false)), false)
	_line("bad_error", str(bad.get("error", "")), AdventureShareCode.ERR_PREFIX)
	_line("bad_no_write", Adventure.store.used_run_slots(), before)

	# 槽位满：5 个位全占，再导一条合法码
	for slot: int in range(1, AdventureStore.MAX_RUN_SLOTS + 1):
		var filler: Dictionary = _filler_run(slot)
		Adventure.store.set_run(filler, slot)
	_line("full_slots", Adventure.store.used_run_slots(), AdventureStore.MAX_RUN_SLOTS)
	var local_key: String = _make_local_level()
	var good_code: String = Adventure.export_share_code(1)
	_line("good_code_len", good_code.length() > 0, true)
	var full: Dictionary = Adventure.import_share_code(good_code)
	_line("full_ok", bool(full.get("ok", false)), false)
	_line("full_error_has_count", str(full.get("error", "")).contains("5/5"), true)
	_remove_local_level(local_key)


## 造一个占位团（关卡用本机一定存在的文件名即可，这里只要能占住槽位）。
func _filler_run(slot: int) -> Dictionary:
	return {
		"active": true, "id": "filler%d" % slot, "mode": "finite", "seed": slot,
		"tier": 1, "active_tier": 1, "started_at": 0, "index": 0, "total_levels": 1,
		"lives_total": 2, "lives_left": 2, "lives_cap": 100, "cleared_count": 0,
		"deaths": 0, "skipped_count": 0, "skipped_soft": 0, "skipped_hard": 0,
		"skipped_keys": [], "cycle": 1, "cycle_played": [],
		"level_keys": [FILLER_KEY], "level_fingerprints": ["0000000000000000"],
	}


const FILLER_KEY: String = "adventure_share_fail_probe_filler.lvl"


func _make_local_level() -> String:
	# import 路径要求关卡文件存在，否则会被 missing_levels 拦下。
	for path: String in ["user://" + FILLER_KEY, "user://liked courses/" + FILLER_KEY]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string("{}")
			file.close()
			break
	return FILLER_KEY


func _remove_local_level(_key: String) -> void:
	for path: String in ["user://" + FILLER_KEY, "user://liked courses/" + FILLER_KEY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _cleanup() -> void:
	for path: String in [TMP_INI, TMP_INI + ".src"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_remove_local_level(FILLER_KEY)
