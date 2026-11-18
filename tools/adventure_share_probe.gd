extends Node

## 探针：验证百人团「快速导出 / 快速导入」的文本码。
##
## 判据（写进 tools/adventure_share_probe_result.txt）：
##   1. 导出码前缀 / 版本正确，looks_like_code 认它
##   2. 整条码被聊天软件折行后仍能解
##   3. 从「QQ 聊天记录」里粘（前后夹着昵称、时间、别的话）也能挑出码
##   4. 团的全部字段与关卡统计逐项还原
##   5. 坏码的几种失败各有明确提示
##   6. 大团（500 关）一条码装得下、解得开
##   7. 空库接收后能从存档位读回同一个团，且第二次导入不覆盖第一次
##
## 用两个自建的 user:// 临时 ini，不碰玩家真实存档，跑完清理。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUT_PATH: String = "res://tools/adventure_share_probe_result.txt"
const TMP_SRC: String = "user://adventure_share_probe_src.ini"
const TMP_DST: String = "user://adventure_share_probe_dst.ini"
const LEVEL_A: String = "adventure_share_probe_a.lvl"
const LEVEL_B: String = "adventure_share_probe_b.lvl"
const LEVEL_C: String = "adventure_share_probe_c.lvl"

## 打了很多关的团：码要装得下，不能靠分段。
const BIG_LEVELS: int = 500

var _lines: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup()
	_run()
	_write()
	_cleanup()
	get_tree().quit()


func _run() -> void:
	var src: AdventureStore = AdventureStore.new(TMP_SRC)
	src.load()

	# --- 小团 ---
	src.set_level_meta(LEVEL_A, LEVEL_A, "aaaa1111bbbb2222", 0)
	src.set_level_meta(LEVEL_B, LEVEL_B, "cccc3333dddd4444", 2)
	src.set_level_meta(LEVEL_C, LEVEL_C, "eeee5555ffff6666", 0)
	src.record_attempt(LEVEL_A)
	src.record_pass(LEVEL_A)
	src.record_death(LEVEL_C)
	src.set_excluded(LEVEL_B, true, "unsolvable")
	src.save()
	var run: Dictionary = _make_run([LEVEL_A, LEVEL_B, LEVEL_C])
	src.set_run(run, 2)

	var code: String = AdventureShareCode.encode(src, 2, run)
	_line("code_prefix", code.begins_with("MFMP-RAID-2:"), true)
	_line("no_newline", code.contains("\n"), false)
	_line("looks_like_code", AdventureShareCode.looks_like_code(code), true)
	_line("looks_like_garbage", AdventureShareCode.looks_like_code("hello world"), false)
	_line("looks_like_prefix_only", AdventureShareCode.looks_like_code("MFMP-RAID-2:"), false)

	var decoded: Dictionary = AdventureShareCode.decode(code)
	_line("decode_ok", bool(decoded.get("ok", false)), true)
	_line("decode_error", str(decoded.get("error", "")), "")
	_check_fields(decoded, run)

	# --- 折行 ---
	var wrapped: String = ""
	var offset: int = 0
	while offset < code.length():
		wrapped += code.substr(offset, 76) + "\r\n"
		offset += 76
	_line("wrapped_ok", bool(AdventureShareCode.decode(wrapped).get("ok", false)), true)

	# --- 大团：一条码装下 ---
	var big_keys: Array[String] = []
	for index: int in range(BIG_LEVELS):
		big_keys.append("mfmp_2026-04-26_23-01-25_测试关卡%03d_e5d7f.lvl" % index)
	var big_run: Dictionary = _make_run(big_keys)
	big_run["mode"] = "endless"
	big_run["index"] = BIG_LEVELS - 1
	big_run["total_levels"] = -1
	for key: String in big_keys:
		src.set_level_meta(key, key, "0123456789abcdef", 0)
	var big_code: String = AdventureShareCode.encode(src, 1, big_run)
	_line("big_single_code", big_code.contains("\n"), false)
	_line("big_code_chars", big_code.length() > 0, true)
	var big_decoded: Dictionary = AdventureShareCode.decode(big_code)
	_line("big_ok", bool(big_decoded.get("ok", false)), true)
	var big_back: Dictionary = big_decoded.get("run", {})
	_line("big_keys_match", str(big_back.get("level_keys", [])) == str(big_keys), true)
	_line("big_levels_count", (big_decoded.get("levels", {}) as Dictionary).size(), BIG_LEVELS)

	# --- 从 QQ 聊天记录里挑码 ---
	var chat: String = "[09:12] 绿糖 2026-11-18 09:12:30\n" + big_code + "\n\n这是我打完的存档，你试试\n"
	var from_chat: Dictionary = AdventureShareCode.decode(chat)
	_line("chat_ok", bool(from_chat.get("ok", false)), true)
	var chat_run: Dictionary = from_chat.get("run", {})
	_line("chat_keys_match", str(chat_run.get("level_keys", [])) == str(big_keys), true)

	# --- 小团字段 ---
	var levels: Dictionary = decoded.get("levels", {})
	_line("levels_count", levels.size(), 3)
	var level_b: Dictionary = levels.get(LEVEL_B, {})
	_line("level_b_excluded", bool(level_b.get("excluded", false)), true)
	_line("level_b_reason", str(level_b.get("exclude_reason", "")), "unsolvable")
	var level_a: Dictionary = levels.get(LEVEL_A, {})
	_line("level_a_pass", int(level_a.get("solo_pass", 0)), 1)
	_line("level_a_attempt", int(level_a.get("solo_attempt", 0)), 1)

	# --- 坏码 ---
	_line("bad_empty", str(AdventureShareCode.decode("").get("error", "")), AdventureShareCode.ERR_EMPTY)
	_line("bad_prefix", str(AdventureShareCode.decode("helloworld").get("error", "")), AdventureShareCode.ERR_PREFIX)
	var bad_body: Dictionary = AdventureShareCode.decode("MFMP-RAID-2:!!!!!!!!")
	_line("bad_body_ok", bool(bad_body.get("ok", false)), false)

	# --- 导入端 ---
	var dst: AdventureStore = AdventureStore.new(TMP_DST)
	dst.load()
	var imported: Dictionary = _import(dst, decoded)
	_line("import_ok", bool(imported.get("ok", false)), true)
	_line("import_slot", int(imported.get("slot", 0)), 1)
	var got: Dictionary = dst.get_run(1)
	_line("roundtrip_active", bool(got.get("active", false)), true)
	_line("roundtrip_index", int(got.get("index", 0)), 1)
	_line("roundtrip_lives", int(got.get("lives_left", 0)), 4)
	_line("roundtrip_keys", str(got.get("level_keys", [])) == str(run.get("level_keys", [])), true)
	var got_b: Dictionary = dst.get_level_data(LEVEL_B)
	_line("roundtrip_excluded", bool(got_b.get("excluded", false)), true)
	var second: Dictionary = _import(dst, decoded)
	_line("second_slot", int(second.get("slot", 0)), 2)
	_line("first_slot_intact", int(dst.get_run(1).get("index", -1)), 1)


func _check_fields(decoded: Dictionary, run: Dictionary) -> void:
	var back: Dictionary = decoded.get("run", {})
	_line("run_slot", int(decoded.get("slot", 0)), 2)
	for field: String in ["mode", "index", "lives_left", "cleared_count", "deaths", "tier", "seed", "total_levels", "cycle"]:
		_line("run_" + field, back.get(field), run.get(field))
	_line("level_keys_match", str(back.get("level_keys", [])) == str(run.get("level_keys", [])), true)


func _import(store: AdventureStore, decoded: Dictionary) -> Dictionary:
	var run: Dictionary = decoded.get("run", {})
	var levels: Dictionary = decoded.get("levels", {})
	for key: String in levels.keys():
		var data: Dictionary = levels[key]
		var section: String = store.level_section(key)
		if store.config.has_section(section) and store.config.get_section_keys(section).size() > 0:
			continue
		for field: String in data.keys():
			store.config.set_value(section, field, data[field])
	var slot: int = store.first_free_slot()
	if slot <= 0:
		return {"ok": false, "slot": 0}
	run["slot"] = slot
	run["active"] = true
	store.set_run(run, slot)
	return {"ok": true, "slot": slot}


func _make_run(keys: Array[String]) -> Dictionary:
	return {
		"active": true,
		"id": "2026-11-18_08-00-00",
		"mode": "finite",
		"seed": 123456789,
		"tier": 2,
		"active_tier": 2,
		"started_at": 1794500000,
		"index": 1,
		"total_levels": 3,
		"lives_total": 6,
		"lives_left": 4,
		"lives_cap": 100,
		"cleared_count": 1,
		"deaths": 1,
		"skipped_count": 0,
		"skipped_soft": 0,
		"skipped_hard": 0,
		"skipped_keys": [],
		"cycle": 1,
		"cycle_played": [keys[0]],
		"level_keys": keys,
	}


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
	for path: String in [TMP_SRC, TMP_DST]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
