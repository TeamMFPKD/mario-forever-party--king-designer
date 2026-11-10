class_name AdventureStore
extends RefCounted

## user://adventure.ini 的读写。
##
## 这里只存单人/百人团数据、排除、设置和当前团进度。
## 联机的 pass_count/death_count 存在关卡文件 .lvl 里，不写这里。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const PATH: String = "user://adventure.ini"
const SCHEMA: int = 1

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
		Log.w("AdventureStore", ["adventure.ini schema 不匹配：", config.get_value("meta", "schema", 0)])


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


func record_skip(key: String) -> void:
	var section: String = level_section(key)
	config.set_value(section, "solo_skip", int(config.get_value(section, "solo_skip", 0)) + 1)
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


# ---------------------------------------------------------------------------
# 设置 / 当前团 / 累计统计
# ---------------------------------------------------------------------------

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return config.get_value("settings", key, default_value)


func set_setting(key: String, value: Variant) -> void:
	config.set_value("settings", key, value)
	save()


func get_run() -> Dictionary:
	var result: Dictionary = {}
	if not config.has_section("run"):
		return result
	for key: String in config.get_section_keys("run"):
		result[key] = config.get_value("run", key)
	return result


func set_run(run: Dictionary) -> void:
	for key: String in run.keys():
		config.set_value("run", key, run[key])
	save()


func clear_run() -> void:
	if config.has_section("run"):
		config.erase_section("run")
	config.set_value("run", "active", false)
	save()


func bump_stat(key: String, amount: int = 1) -> void:
	config.set_value("stats", key, int(config.get_value("stats", key, 0)) + amount)


func get_stat(key: String, default_value: int = 0) -> int:
	return int(config.get_value("stats", key, default_value))


func set_stat(key: String, value: int) -> void:
	config.set_value("stats", key, value)
