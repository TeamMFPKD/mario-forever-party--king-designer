class_name AdventureStore
extends RefCounted

## user://adventure.ini 的读写。
##
## 这里只存单人/百人团数据、排除、设置和当前团进度。
## 联机的 pass_count/death_count 存在关卡文件 .lvl 里，不写这里。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const PATH: String = "user://adventure.ini"
const SCHEMA: int = 2
## 同时保留的进行中团上限。一个团占一个槽位，结算 / 放弃后腾出。
const MAX_RUN_SLOTS: int = 5
const LEGACY_RUN_SECTION: String = "run"

var config: ConfigFile
var path: String = PATH


func _init(custom_path: String = "") -> void:
	if not custom_path.is_empty():
		path = custom_path
	config = ConfigFile.new()


func load() -> void:
	var error: int = config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		Log.e("AdventureStore", ["adventure.ini 加载失败：", error_string(error)])
		_backup_broken_file()
		config = ConfigFile.new()
	if not config.has_section("meta"):
		config.set_value("meta", "schema", SCHEMA)
	elif int(config.get_value("meta", "schema", SCHEMA)) != SCHEMA:
		Log.i("AdventureStore", ["adventure.ini schema 升级：", config.get_value("meta", "schema", 0), " -> ", SCHEMA])
	_migrate_legacy_run()


func save() -> bool:
	config.set_value("meta", "schema", SCHEMA)
	config.set_value("meta", "saved_at", Time.get_datetime_string_from_system(false, true))
	var tmp_path: String = path + ".tmp"
	var error: int = config.save(tmp_path)
	if error != OK:
		Log.e("AdventureStore", ["adventure.ini 临时文件写入失败：", error_string(error)])
		return false
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		Log.e("AdventureStore", "无法打开 user://")
		return false
	if FileAccess.file_exists(path):
		var remove_error: int = dir.remove(path)
		if remove_error != OK:
			Log.e("AdventureStore", ["旧 adventure.ini 删除失败：", error_string(remove_error)])
			return false
	var rename_error: int = dir.rename(tmp_path, path)
	if rename_error != OK:
		Log.e("AdventureStore", ["adventure.ini 替换失败：", error_string(rename_error)])
		return false
	return true


func _backup_broken_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var backup: String = "%s.bak.%d" % [path, int(Time.get_unix_time_from_system())]
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.rename(path, backup)
	Log.w("AdventureStore", ["已备份损坏的 adventure.ini：", backup])


# ---------------------------------------------------------------------------
# 关卡统计
# ---------------------------------------------------------------------------

func level_section(key: String) -> String:
	return "level." + key


func get_level_data(key: String) -> Dictionary:
	var section: String = level_section(key)
	return {
		"fingerprint": str(config.get_value(section, "fingerprint", "")),
		"generation": int(config.get_value(section, "generation", 0)),
		"solo_attempt": int(config.get_value(section, "solo_attempt", 0)),
		"solo_pass": int(config.get_value(section, "solo_pass", 0)),
		"solo_death": int(config.get_value(section, "solo_death", 0)),
		"solo_skip": int(config.get_value(section, "solo_skip", 0)),
		"solo_skip_soft": int(config.get_value(section, "solo_skip_soft", 0)),
		"solo_last": int(config.get_value(section, "solo_last", 0)),
		"excluded": bool(config.get_value(section, "excluded", false)),
		"exclude_reason": str(config.get_value(section, "exclude_reason", "")),
		"excluded_at": int(config.get_value(section, "excluded_at", 0)),
	}


func set_level_meta(key: String, file_name: String, fingerprint: String, generation: int) -> void:
	var section: String = level_section(key)
	config.set_value(section, "file", file_name)
	config.set_value(section, "fingerprint", fingerprint)
	config.set_value(section, "generation", generation)


func reset_solo(key: String) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_attempt", 0)
	config.set_value(section, "solo_pass", 0)
	config.set_value(section, "solo_death", 0)
	config.set_value(section, "solo_skip", 0)
	config.set_value(section, "solo_skip_soft", 0)
	config.set_value(section, "solo_last", 0)


func record_attempt(key: String) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_attempt", int(config.get_value(section, "solo_attempt", 0)) + 1)
	config.set_value(section, "solo_last", int(Time.get_unix_time_from_system()))
	save()


func record_pass(key: String) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_pass", int(config.get_value(section, "solo_pass", 0)) + 1)
	config.set_value(section, "solo_last", int(Time.get_unix_time_from_system()))
	save()


func record_death(key: String) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_death", int(config.get_value(section, "solo_death", 0)) + 1)
	config.set_value(section, "solo_last", int(Time.get_unix_time_from_system()))
	save()


## soft = true：「我打不过」跳过；false：「本关不可能通过」永久排除。
## solo_skip 两种都计（用于通过率口径），solo_skip_soft 只计前者（用于关卡信息展示）。
func record_skip(key: String, soft: bool = true) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_skip", int(config.get_value(section, "solo_skip", 0)) + 1)
	if soft:
		config.set_value(section, "solo_skip_soft", int(config.get_value(section, "solo_skip_soft", 0)) + 1)
	config.set_value(section, "solo_last", int(Time.get_unix_time_from_system()))
	save()


func set_excluded(key: String, excluded: bool, reason: String = "") -> void:
	var section: String = level_section(key)
	config.set_value(section, "excluded", excluded)
	config.set_value(section, "exclude_reason", reason if excluded else "")
	config.set_value(section, "excluded_at", int(Time.get_unix_time_from_system()) if excluded else 0)
	save()


func is_excluded(key: String) -> bool:
	return bool(config.get_value(level_section(key), "excluded", false))


## 垃圾桶界面用：所有被永久排除的关卡记录（以 ini 为准，不管文件还在不在）。
## 每条都带上 key 与文件字段，文件是否存在由调用方判断。
func get_excluded_levels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section: String in config.get_sections():
		if not section.begins_with("level."):
			continue
		if not bool(config.get_value(section, "excluded", false)):
			continue
		var key: String = section.trim_prefix("level.")
		if key.is_empty():
			continue
		var data: Dictionary = get_level_data(key)
		data["key"] = key
		data["file"] = str(config.get_value(section, "file", key))
		result.append(data)
	return result


# ---------------------------------------------------------------------------
# 设置 / 当前团 / 累计统计
# ---------------------------------------------------------------------------

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return config.get_value("settings", key, default_value)


func set_setting(key: String, value: Variant) -> void:
	config.set_value("settings", key, value)
	save()


# ---------------------------------------------------------------------------
# 进行中的团（多存档位）
# ---------------------------------------------------------------------------

func run_section(slot: int) -> String:
	return "run.%d" % slot


## slot=0：取第一个有数据的槽位（兼容旧的单存档调用）。
func get_run(slot: int = 0) -> Dictionary:
	if slot <= 0:
		slot = first_saved_slot()
	if slot <= 0:
		return {}
	var section: String = run_section(slot)
	if not config.has_section(section):
		return {}
	var result: Dictionary = {}
	for key: String in config.get_section_keys(section):
		result[key] = config.get_value(section, key)
	result["slot"] = slot
	return result


## slot=0：优先用 run 自带的 slot，其次找空槽位。
func set_run(run: Dictionary, slot: int = 0) -> void:
	if slot <= 0:
		slot = int(run.get("slot", 0))
	if slot <= 0:
		slot = first_free_slot()
	if slot <= 0:
		Log.e("AdventureStore", "保存团进度失败：没有空存档位")
		return
	run["slot"] = slot
	var section: String = run_section(slot)
	# 先清段，避免上一份团的残留键（例如从定量换成无尽后的 total_levels）混进来。
	if config.has_section(section):
		config.erase_section(section)
	for key: String in run.keys():
		config.set_value(section, key, run[key])
	save()


## slot=0：清空全部存档位（迁移 / 重置用）。
func clear_run(slot: int = 0) -> void:
	if slot <= 0:
		for index: int in range(1, MAX_RUN_SLOTS + 1):
			_erase_run_section(index)
	else:
		_erase_run_section(slot)
	save()


func _erase_run_section(slot: int) -> void:
	var section: String = run_section(slot)
	if config.has_section(section):
		config.erase_section(section)


func first_saved_slot() -> int:
	for index: int in range(1, MAX_RUN_SLOTS + 1):
		var section: String = run_section(index)
		if config.has_section(section) and not config.get_section_keys(section).is_empty():
			return index
	return 0


## 槽位是否被一个「还能继续」的团占用（active 且 index 在 level_keys 范围内）。
## active=false、进度字段缺失或 index 越界的坏档都不算占用，可被新团覆盖，避免死锁。
func is_run_occupied(slot: int) -> bool:
	var section: String = run_section(slot)
	if not config.has_section(section):
		return false
	if not bool(config.get_value(section, "active", false)):
		return false
	var keys: Array = config.get_value(section, "level_keys", [])
	var index: int = int(config.get_value(section, "index", 0))
	return not keys.is_empty() and index >= 0 and index < keys.size()


## 第一个可以开新团的槽位；0 = 5 个槽位都被占用。
func first_free_slot() -> int:
	for index: int in range(1, MAX_RUN_SLOTS + 1):
		if not is_run_occupied(index):
			return index
	return 0


## 被进行中的团占用的槽位数。
func used_run_slots() -> int:
	var count: int = 0
	for index: int in range(1, MAX_RUN_SLOTS + 1):
		if is_run_occupied(index):
			count += 1
	return count


## 旧版只有一个 [run] 段：搬到第一个空槽位，然后删掉旧段。
func _migrate_legacy_run() -> void:
	if not config.has_section(LEGACY_RUN_SECTION):
		return
	var legacy: Dictionary = {}
	for key: String in config.get_section_keys(LEGACY_RUN_SECTION):
		legacy[key] = config.get_value(LEGACY_RUN_SECTION, key)
	var had_active: bool = not legacy.is_empty() and bool(legacy.get("active", false))
	config.erase_section(LEGACY_RUN_SECTION)
	if had_active:
		var slot: int = first_free_slot()
		if slot > 0:
			legacy["slot"] = slot
			var section: String = run_section(slot)
			for key: String in legacy.keys():
				config.set_value(section, key, legacy[key])
			Log.i("AdventureStore", ["旧版单团存档迁移到槽位 ", slot])
		else:
			Log.w("AdventureStore", "旧版单团存档迁移失败：没有空槽位")
	save()


func bump_stat(key: String, amount: int = 1) -> void:
	config.set_value("stats", key, int(config.get_value("stats", key, 0)) + amount)


func get_stat(key: String, default_value: int = 0) -> int:
	return int(config.get_value("stats", key, default_value))


func set_stat(key: String, value: int) -> void:
	config.set_value("stats", key, value)
