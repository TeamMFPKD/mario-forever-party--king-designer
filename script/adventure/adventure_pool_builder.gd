class_name AdventurePoolBuilder
extends RefCounted

## 扫描 user:// 根目录和 user://liked courses，构造百人团的关卡池。
## 单人数据来自 adventure.ini；联机 pass/death 来自 .lvl 本身。
##
## 线程安全约定：
## - build() 在主线程用，直接写回 store；
## - build_isolated() 在线程用，只读自己的 AdventureStore 副本，
##   把指纹/单人样本变更收集到 meta_updates，由主线程 apply_updates() 落盘。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const LIKED_DIR: String = "user://liked courses"


static func build(store: AdventureStore, source: String) -> Array[AdventureLevelStat]:
	var built: Dictionary = _build(store, source, false)
	apply_updates(store, built.get("meta_updates", []))
	return built.get("stats", [])


## 线程里调用：只读，不碰主线程共享的 AdventureStore。
static func build_isolated(source: String, ini_path: String) -> Dictionary:
	var store: AdventureStore = AdventureStore.new(ini_path)
	store.load()
	return _build(store, source, true)


static func apply_updates(store: AdventureStore, updates: Array) -> void:
	if updates.is_empty():
		return
	for value: Variant in updates:
		var update: Dictionary = value
		var key: String = str(update.get("key", ""))
		if key.is_empty():
			continue
		if bool(update.get("reset", false)):
			store.reset_solo(key)
		store.set_level_meta(
			key,
			key,
			str(update.get("fingerprint", "")),
			int(update.get("generation", 0))
		)
	store.save()


static func _build(store: AdventureStore, source: String, threaded: bool) -> Dictionary:
	var paths: Dictionary = {}
	if source == "liked":
		_collect_liked(paths)
	else:
		_scan_dir("user://", paths)
		_scan_dir(LIKED_DIR, paths)

	var result: Array[AdventureLevelStat] = []
	var keys: Array = paths.keys()
	keys.sort()
	var state: Dictionary = {
		"threaded": threaded,
		"meta_updates": [],
	}

	for key_value: Variant in keys:
		var key: String = str(key_value)
		var path: String = str(paths[key])
		var stat: AdventureLevelStat = _load_stat(store, key, path, state)
		if stat == null:
			continue
		if stat.fingerprint.is_empty():
			continue
		result.append(stat)

	return {
		"stats": result,
		"meta_updates": state["meta_updates"],
	}


## 收藏池以索引（user://liked courses/liked_courses.cfg）为准：新版收藏不再在
## 收藏目录里放 .lvl 副本，关卡正本统一留在 user:// 根目录。
## LikedCourses.get_files() / level_path() 都是纯文件读取，线程里可直接调用。
static func _collect_liked(paths: Dictionary) -> void:
	for file_name: String in LikedCourses.get_files():
		if paths.has(file_name):
			continue
		paths[file_name] = LikedCourses.level_path(file_name)
	# 兜底：索引损坏或旧版迁移失败时，收藏目录里的 .lvl 副本仍然可玩。
	_scan_dir(LIKED_DIR, paths)


static func _scan_dir(dir_path: String, paths: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			if not paths.has(file_name):
				var prefix: String = dir_path
				if not prefix.ends_with("/"):
					prefix += "/"
				paths[file_name] = prefix + file_name
		file_name = dir.get_next()
	dir.list_dir_end()


static func _load_stat(
	store: AdventureStore,
	key: String,
	path: String,
	state: Dictionary
) -> AdventureLevelStat:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		if not bool(state.get("threaded", false)):
			Log.w("AdventurePool", ["关卡 JSON 解析失败，已跳过：", path])
		return null
	var data: Variant = json.data
	if not data is Dictionary:
		if not bool(state.get("threaded", false)):
			Log.w("AdventurePool", ["关卡 JSON 不是字典，已跳过：", path])
		return null
	var level_data: Dictionary = data

	var stat: AdventureLevelStat = AdventureLevelStat.new()
	stat.key = key
	stat.path = path
	stat.file_exists = true
	stat.fingerprint = AdventureLevelIdentity.fingerprint_from_json_text(text)
	stat.online_pass = int(level_data.get("pass_count", 0))
	stat.online_death = int(level_data.get("death_count", 0))

	var saved: Dictionary = store.get_level_data(key)
	stat.excluded = bool(saved.get("excluded", false))
	stat.exclude_reason = str(saved.get("exclude_reason", ""))
	stat.solo_attempt = int(saved.get("solo_attempt", 0))
	stat.solo_pass = int(saved.get("solo_pass", 0))
	stat.solo_death = int(saved.get("solo_death", 0))
	stat.solo_skip = int(saved.get("solo_skip", 0))
	stat.solo_skip_soft = int(saved.get("solo_skip_soft", 0))
	stat.solo_last = int(saved.get("solo_last", 0))

	var saved_fingerprint: String = str(saved.get("fingerprint", ""))
	var generation: int = int(saved.get("generation", 0))
	if saved_fingerprint.is_empty():
		_append_update(state, key, stat.fingerprint, generation, false)
	elif saved_fingerprint != stat.fingerprint:
		if not bool(state.get("threaded", false)):
			Log.w("AdventurePool", ["关卡布局已变化，单人样本作废：", key])
		_append_update(state, key, stat.fingerprint, generation + 1, true)
		stat.solo_attempt = 0
		stat.solo_pass = 0
		stat.solo_death = 0
		stat.solo_skip = 0

	return stat


static func _append_update(
	state: Dictionary,
	key: String,
	fingerprint: String,
	generation: int,
	reset: bool
) -> void:
	var updates: Array = state.get("meta_updates", [])
	updates.append({
		"key": key,
		"fingerprint": fingerprint,
		"generation": generation,
		"reset": reset,
	})
	state["meta_updates"] = updates
