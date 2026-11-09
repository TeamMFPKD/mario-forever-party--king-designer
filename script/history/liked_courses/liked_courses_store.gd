extends Node

## 收藏关卡索引（autoload 名：LikedCourses）。
##
## 新版收藏不再复制 .lvl：关卡数据只保留在 user:// 根目录一份，
## liked courses/ 目录里只放封面 png 与索引 liked_courses.cfg。
##
## 索引格式（ConfigFile）：
##   [liked_courses]
##   version=2
##   files=PackedStringArray("mfmp_xxx.lvl", ...)
##
## 启动时 migrate_legacy() 把旧版收藏夹里的 .lvl 副本移回根目录并登记索引（幂等）。

const USER_ROOT: String = "user://"
const FOLDER_NAME: String = "liked courses"
const FOLDER_DIR: String = "user://liked courses"
const FOLDER_PATH: String = "user://liked courses/"
const CONFIG_PATH: String = "user://liked courses/liked_courses.cfg"
const SECTION: String = "liked_courses"
const KEY_VERSION: String = "version"
const KEY_FILES: String = "files"
const INDEX_VERSION: int = 2


func _ready() -> void:
	migrate_legacy()


## 确保收藏目录存在；失败返回 false 并记录日志。
func ensure_folder() -> bool:
	var dir: DirAccess = DirAccess.open(USER_ROOT)
	if dir == null:
		Log.e("LikedCourses", "无法打开 user:// 目录")
		return false
	if dir.dir_exists(FOLDER_NAME):
		return true
	var error: Error = dir.make_dir(FOLDER_NAME)
	if error != OK:
		Log.e("LikedCourses", "创建收藏目录失败：%s" % error_string(error))
		return false
	return true


## 关卡文件名必须是 user:// 根目录下的裸 .lvl 文件名，拒绝任何路径成分。
func is_valid_level_name(file_name: String) -> bool:
	if file_name.is_empty() or not file_name.ends_with(".lvl"):
		return false
	if file_name.contains("/") or file_name.contains("\\") or file_name.contains(":"):
		return false
	return not file_name.contains("..")


## 读取收藏索引（去重 + 合法性过滤）。纯文件读取，可在工作线程调用。
func get_files() -> Array[String]:
	var result: Array[String] = []
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return result
	var stored: Variant = config.get_value(SECTION, KEY_FILES, [])
	if not stored is Array:
		return result
	var stored_array: Array = stored
	for item: Variant in stored_array:
		var file_name: String = str(item)
		if not is_valid_level_name(file_name):
			continue
		if result.has(file_name):
			continue
		result.append(file_name)
	return result


func is_liked(file_name: String) -> bool:
	if not is_valid_level_name(file_name):
		return false
	return get_files().has(file_name)


func add(file_name: String) -> void:
	var names: Array[String] = [file_name]
	add_many(names)


## 批量登记收藏，返回本次真正新增的条数。
func add_many(names: Array[String]) -> int:
	var files: Array[String] = get_files()
	var added: int = 0
	for file_name: String in names:
		if not is_valid_level_name(file_name):
			continue
		if files.has(file_name):
			continue
		files.append(file_name)
		added += 1
	if added > 0:
		_save_files(files)
	return added


func remove(file_name: String) -> void:
	var files: Array[String] = get_files()
	if not files.has(file_name):
		return
	files.erase(file_name)
	_save_files(files)


## 收藏关卡的真实路径：根目录优先，回退旧收藏目录（迁移兜底）。
func level_path(file_name: String) -> String:
	var root_path: String = USER_ROOT + file_name
	if FileAccess.file_exists(root_path):
		return root_path
	var legacy_path: String = FOLDER_PATH + file_name
	if FileAccess.file_exists(legacy_path):
		return legacy_path
	return root_path


func photo_path(file_name: String) -> String:
	return FOLDER_PATH + file_name.get_basename() + ".png"


## 生成索引文本，供导出时直接写入 zip。
func build_index_text(files: Array[String]) -> String:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, KEY_VERSION, INDEX_VERSION)
	config.set_value(SECTION, KEY_FILES, files)
	return config.encode_to_text()


## 旧版迁移：收藏夹里的 .lvl 副本移回 user:// 根目录并登记索引；可重复执行。
func migrate_legacy() -> void:
	var dir: DirAccess = DirAccess.open(FOLDER_DIR)
	if dir == null:
		return

	var files: Array[String] = get_files()
	var changed: bool = false
	var migrated: int = 0

	for file_name: String in dir.get_files():
		if not is_valid_level_name(file_name):
			continue

		var legacy_path: String = FOLDER_PATH + file_name
		var root_path: String = USER_ROOT + file_name
		var moved: bool = false

		if FileAccess.file_exists(root_path):
			# 根目录已有正本：保留正本，丢弃旧副本，绝不反向覆盖。
			var remove_error: Error = dir.remove(file_name)
			if remove_error != OK:
				Log.w("LikedCourses", "删除旧收藏副本失败：%s" % file_name)
			else:
				moved = true
				Log.i("LikedCourses", "根目录已存在同名关卡，删除旧收藏副本：%s" % file_name)
		else:
			var rename_error: Error = dir.rename(file_name, root_path)
			if rename_error == OK:
				moved = true
				Log.i("LikedCourses", "收藏副本移回根目录：%s" % file_name)
			else:
				moved = _copy_then_remove(legacy_path, root_path, dir, file_name)
				if moved:
					Log.i("LikedCourses", "收藏副本复制回根目录：%s" % file_name)

		if not moved:
			continue

		migrated += 1
		if not files.has(file_name):
			files.append(file_name)
			changed = true

	if changed:
		_save_files(files)
	if migrated > 0:
		Log.i("LikedCourses", "旧版收藏迁移完成：%d 个关卡" % migrated)


func _save_files(files: Array[String]) -> void:
	if not ensure_folder():
		return

	var tmp_path: String = CONFIG_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		Log.e("LikedCourses", "写入收藏索引失败：%s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(build_index_text(files))
	file.close()

	var dir: DirAccess = DirAccess.open(USER_ROOT)
	if dir == null:
		Log.e("LikedCourses", "无法打开 user:// 目录")
		return
	if FileAccess.file_exists(CONFIG_PATH):
		dir.remove(CONFIG_PATH)
	var error: Error = dir.rename(tmp_path, CONFIG_PATH)
	if error != OK:
		Log.e("LikedCourses", "替换收藏索引失败：%s" % error_string(error))


func _copy_then_remove(source: String, target: String, dir: DirAccess, file_name: String) -> bool:
	var input: FileAccess = FileAccess.open(source, FileAccess.READ)
	if input == null:
		Log.e("LikedCourses", "读取旧收藏副本失败：%s" % source)
		return false
	var data: PackedByteArray = input.get_buffer(input.get_length())
	input.close()

	var output: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if output == null:
		Log.e("LikedCourses", "写入根目录失败：%s" % target)
		return false
	output.store_buffer(data)
	output.close()

	var remove_error: Error = dir.remove(file_name)
	if remove_error != OK:
		Log.w("LikedCourses", "已复制到根目录但删除旧副本失败：%s" % file_name)
	return true
