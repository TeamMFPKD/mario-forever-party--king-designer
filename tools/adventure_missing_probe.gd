extends Node

## 探针：缺关卡（本机没有 .lvl）时的完整链路。
##
## 判据（写进 tools/adventure_missing_probe_result.txt）：
##   1. 导入含缺关的码不再整体拒绝，而是成功落盘并回报缺关列表
##   2. 缺关被标记 missing=true，且与 excluded 分开（不进「排除的关卡」页）
##   3. 缺关不进关卡池（pool 里没有它），所以不会被重新抽到
##   4. 进关前 current_level_exists() 为 false → skip_missing_level() 换一关
##   5. 跳过缺关不涨 skipped_count / solo_skip（不是玩家的锅）
##   6. 固定团跳过缺关后，那一格换成替补关、index 不前进（要真的打完）
##   7. 重复扫描幂等：已标记的关不会被重复计数
##
## 全程用临时 ini + 临时 .lvl，不碰玩家存档。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_missing_probe_result.txt"
const TMP_INI: String = "user://adventure_missing_probe.ini"
const GHOST: String = "__adventure_missing_probe_ghost__.lvl"
const REAL_A: String = "__adventure_missing_probe_a.lvl"
const REAL_B: String = "__adventure_missing_probe_b.lvl"

var _lines: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup()
	_run()
	_write()
	_cleanup()
	get_tree().quit()


func _run() -> void:
	_write_level(REAL_A)
	_write_level(REAL_B)

	# --- 造一条「引用了缺关」的码 ---
	var src: AdventureStore = AdventureStore.new(TMP_INI + ".src")
	src.load()
	var keys: Array[String] = [GHOST, REAL_A]
	src.set_level_meta(GHOST, GHOST, "1111222233334444", 0)
	src.set_level_meta(REAL_A, REAL_A, "5555666677778888", 0)
	var run: Dictionary = {
		"active": true, "id": "2026-11-19_08-00-00", "mode": "finite", "seed": 7,
		"tier": 0, "active_tier": 0, "started_at": 0, "index": 0, "total_levels": 2,
		"lives_total": 4, "lives_left": 4, "lives_cap": 100, "cleared_count": 0,
		"deaths": 0, "skipped_count": 0, "skipped_soft": 0, "skipped_hard": 0,
		"skipped_keys": [], "cycle": 1, "cycle_played": [], "level_keys": keys,
	}
	src.set_run(run, 1)
	var code: String = AdventureShareCode.encode(src, 1, run)
	_line("code_len", code.length() > 0, true)

	# --- 1. 导入：不再整体拒绝 ---
	var dst: AdventureStore = AdventureStore.new(TMP_INI)
	dst.load()
	Adventure.store = dst
	var res: Dictionary = Adventure.import_share_code(code)
	_line("import_ok", bool(res.get("ok", false)), true)
	_line("import_slot", int(res.get("slot", 0)), 1)
	var missing: Array = res.get("missing", [])
	_line("import_missing_count", missing.size(), 1)
	_line("import_missing_name", str(missing[0]) if missing.size() > 0 else "", GHOST)

	var got: Dictionary = dst.get_run(1)
	_line("run_landed", not got.is_empty(), true)
	_line("run_keys_kept", str(got.get("level_keys", [])) == str(keys), true)

	# --- 2. missing 与 excluded 分开 ---
	_line("ghost_marked_missing", dst.is_missing(GHOST), true)
	_line("ghost_not_excluded", dst.is_excluded(GHOST), false)
	_line("real_not_missing", dst.is_missing(REAL_A), false)
	var excluded_list: Array[Dictionary] = dst.get_excluded_levels()
	_line("excluded_list_empty", excluded_list.size(), 0)

	# --- 3. 缺关不进关卡池 ---
	Adventure.pool = AdventurePoolBuilder.build(dst, "all")
	var in_pool: bool = false
	for stat: AdventureLevelStat in Adventure.pool:
		if stat.key == GHOST:
			in_pool = true
	_line("ghost_not_in_pool", in_pool, false)

	# --- 4/5/6. 进关前拦截 ---
	Adventure.current_run = got.duplicate(true)
	Adventure.current_key = GHOST
	_line("current_exists", Adventure.current_level_exists(), false)
	var skip_before: int = int(Adventure.current_run.get("skipped_count", 0))
	var soft_before: int = int(Adventure.current_run.get("skipped_soft", 0))
	var did_skip: bool = Adventure.skip_missing_level()
	_line("skip_missing_ran", did_skip, true)
	_line("skipped_count_unchanged",
		int(Adventure.current_run.get("skipped_count", 0)), skip_before)
	_line("skipped_soft_unchanged",
		int(Adventure.current_run.get("skipped_soft", 0)), soft_before)
	var after_keys: Array = Adventure.current_run.get("level_keys", [])
	_line("slot_replaced", str(after_keys[0]) != GHOST, true)
	_line("index_not_advanced", int(Adventure.current_run.get("index", 0)), 0)
	_line("replacement_exists", Adventure.current_level_exists(), true)
	var after_stat: Dictionary = dst.get_level_data(GHOST)
	_line("ghost_solo_skip_not_counted", int(after_stat.get("solo_skip", 0)), 0)

	# --- 7. 幂等：同一关再扫一次不会重复计数 ---
	var marked_first: int = Adventure.refresh_missing_levels()
	var marked_again: int = Adventure.refresh_missing_levels()
	_line("rescan_idempotent_first", marked_first, 0)
	_line("rescan_idempotent_again", marked_again, 0)


func _write_level(key: String) -> void:
	var file: FileAccess = FileAccess.open("user://" + key, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("{}")
	file.close()


func _line(name: String, actual: Variant, expected: Variant = null) -> void:
	var text: String = "%s=%s" % [name, str(actual)]
	if expected != null:
		text += "  (expect %s)  %s" % [str(expected), "OK" if _same(actual, expected) else "FAIL"]
	_lines.append(text)


func _same(actual: Variant, expected: Variant) -> bool:
	if actual is bool or expected is bool:
		return bool(actual) == bool(expected)
	if actual is int or expected is int:
		return int(actual) == int(expected)
	return str(actual) == str(expected)


func _write() -> void:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines) + "\n")
	file.close()


func _cleanup() -> void:
	for path: String in [TMP_INI, TMP_INI + ".src", "user://" + GHOST, "user://" + REAL_A, "user://" + REAL_B]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
