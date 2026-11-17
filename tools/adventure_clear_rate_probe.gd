extends Node

## 探针：验证「随心挑战」左侧面板的个人通过率不再把「正在打的那一次 attempt」算进分母。
##
## 判据（写进 tools/adventure_clear_rate_probe_result.txt）：
##   1. 没进过关卡时 0/0 -> 0.0%
##   2. 刚进关（attempt 已 +1，还没结局）-> 分母排掉它，仍显示 0.0%
##   3. 通过之后 -> 1/1 = 100.0%
##   4. 死过一次再进（attempt=2, pass=1）-> 50.0%
##
## 用自建的 user://adventure_clear_rate_probe.ini，不碰玩家存档，跑完清理。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_clear_rate_probe_result.txt"
const TMP_INI: String = "user://adventure_clear_rate_probe.ini"
const PANEL_SCENE: String = "res://object/ui/adventure_level_info.tscn"

var _lines: Array[String] = []
var _panel: Control


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_ini()
	_store_temp()
	await _run()
	_write()
	_cleanup_ini()
	get_tree().quit()


func _store_temp() -> void:
	Adventure.store = AdventureStore.new(TMP_INI)
	Adventure.store.load()


func _run() -> void:
	GameModeSingleton.game_mode = GameMode.GameModeType.ADVENTURE
	var key_a: String = "adventure_clear_rate_probe_a.lvl"
	var key_b: String = "adventure_clear_rate_probe_b.lvl"
	var keys: Array = [key_a, key_b, key_a, key_b]

	# --- 1. 没进过关卡：0/0 ---
	Adventure.current_run = {
		"active": true, "slot": 1, "mode": "finite", "index": 0,
		"total_levels": 4, "lives_left": 8, "cleared_count": 0,
		"deaths": 0, "skipped_count": 0, "skipped_soft": 0, "skipped_hard": 0,
		"level_keys": keys, "tier": 0, "active_tier": 0,
	}
	Adventure.current_key = key_a
	Adventure._pending_attempt_key = ""
	_make_panel()
	_line("fresh_attempt", 0)
	_line("fresh_settled", 0)
	_line("fresh_rate", _rate(), "0.0%")

	# --- 2. 刚进关：attempt=1，但还没有结局 ---
	Adventure.on_level_loaded("user://" + key_a)
	var st: Dictionary = Adventure.current_level_stats()
	_line("entering_attempt", _num(st, "solo_attempt"), "1")
	_line("entering_settled", _num(st, "solo_attempt_settled"), "0")
	_line("entering_rate", _rate(), "0.0%")

	# --- 3. 通过：这次 attempt 落地 ---
	# on_level_passed() 内部会 advance()（index 0 -> 1），之后 current_level_stats()
	# 读到的已经是下一关，所以这里直接查 key_a 在 ini 里的记录。
	Adventure.on_level_passed()
	_line("passed_pending_empty", Adventure._pending_attempt_key.is_empty(), "true")
	var saved_a: Dictionary = Adventure.store.get_level_data(key_a)
	_line("passed_pass", _num(saved_a, "solo_pass"), "1")
	_line("passed_attempt", _num(saved_a, "solo_attempt"), "1")
	# 回到 key_a 再看面板：分母这时应把那次 attempt 算进去 -> 1/1。
	Adventure.current_run["index"] = 0
	st = Adventure.current_level_stats()
	_line("passed_settled", _num(st, "solo_attempt_settled"), "1")
	_line("passed_rate", _rate(), "100.0%")

	# --- 4. 再进同一关（attempt=2, pass=1），还没结局 -> 仍是 100% ---
	Adventure.current_run["index"] = 0
	Adventure.current_key = key_a
	Adventure.on_level_loaded("user://" + key_a)
	st = Adventure.current_level_stats()
	_line("reenter_attempt", _num(st, "solo_attempt"), "2")
	_line("reenter_settled", _num(st, "solo_attempt_settled"), "1")
	_line("reenter_rate", _rate(), "100.0%")

	# --- 5. 死一次（走 on_player_died 会让命数扣 1 并落盘）---
	Adventure.current_run["lives_left"] = 8
	var lives_before: int = int(Adventure.current_run.get("lives_left", 0))
	Adventure.on_player_died()
	st = Adventure.current_level_stats()
	_line("died_attempt", _num(st, "solo_attempt"), "2")
	_line("died_settled", _num(st, "solo_attempt_settled"), "2")
	_line("died_rate", _rate(), "50.0%")
	# 关键：死亡到底有没有写进 ini（用户反馈「死亡没算上」）
	var saved_a2: Dictionary = Adventure.store.get_level_data(key_a)
	_line("died_solo_death", _num(saved_a2, "solo_death"), "1")
	_line("died_lives_left", int(Adventure.current_run.get("lives_left", -1)), str(lives_before - 1))

	# --- 6. 另一关：从没碰过，进关后仍显示 0.0% ---
	Adventure.current_run["index"] = 1
	Adventure.current_key = key_b
	Adventure.on_level_loaded("user://" + key_b)
	st = Adventure.current_level_stats()
	_line("other_attempt", _num(st, "solo_attempt"), "1")
	_line("other_settled", _num(st, "solo_attempt_settled"), "0")
	_line("other_pass", _num(st, "solo_pass"), "0")
	_line("other_rate", _rate(), "0.0%")

	# --- 7. 中断团：挂起的 attempt 必须被清掉 ---
	Adventure.interrupt_run()
	_line("after_interrupt_pending_empty", Adventure._pending_attempt_key.is_empty(), "true")


## 从字典里取一个计数字段（Dictionary.get 返回 Variant，这里统一收口）。
func _num(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key, 0)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	return 0


func _make_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	var scene: PackedScene = load(PANEL_SCENE) as PackedScene
	if scene == null:
		_line("panel_loaded", false, "true")
		return
	_panel = scene.instantiate() as Control
	add_child(_panel)
	_line("panel_loaded", true, "true")


## 直接问面板要显示的文字（而不是复算一遍），确保测的是真正的显示逻辑。
func _rate() -> String:
	_make_panel()
	if _panel == null or not _panel.has_method("_format_clear_rate"):
		return "NO_PANEL"
	return str(_panel.call("_format_clear_rate", Adventure.current_level_stats()))


func _line(key: String, value: Variant, expect: Variant = null) -> void:
	var text: String = str(value)
	if expect != null:
		var ok: bool = text == str(expect)
		_lines.append("%s=%s expect=%s %s" % [key, text, str(expect), "ok" if ok else "MISMATCH"])
	else:
		_lines.append("%s=%s" % [key, text])


func _write() -> void:
	var mismatches: int = 0
	for line: String in _lines:
		if line.contains("MISMATCH") or line.contains("NO_PANEL"):
			mismatches += 1
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	for line: String in _lines:
		f.store_line(line)
	f.store_line("mismatches=%d" % mismatches)
	f.store_line("result=%s" % ("ok" if mismatches == 0 else "fail"))
	f.close()


func _cleanup_ini() -> void:
	if FileAccess.file_exists(TMP_INI):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_INI))
