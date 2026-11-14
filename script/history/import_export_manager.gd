extends Node

signal import_finished
signal import_succeeded
signal import_failed
signal export_succeeded
signal export_failed

enum ExportMode {
	ALL_WITH_LIKED,          # 所有关卡 + 收藏索引 + 收藏封面
	LIKED_ONLY,              # 仅收藏关卡 + 索引 + 封面
	ALL_ONLY,                # 仅所有关卡，不含收藏索引/封面
	ALL_WITH_LIKED_RAID,     # 所有关卡 + 收藏 + 随心挑战排除名单 + 随心挑战存档
	ALL_WITH_LIKED_EXCLUDED, # 所有关卡 + 收藏 + 随心挑战排除名单（不含存档）
}

@export var is_liked_room: bool = false
@export var export_mode_dialog: Control

const USER_ROOT: String = "user://"
const LIKED_INDEX_NAME: String = "liked_courses.cfg"
const LIKED_ARCHIVE_PREFIX: String = "liked_courses/"
## 随心挑战数据以两个独立 cfg 平铺进 zip：分开才能只带排除名单、不带存档。
const RAID_EXCLUDED_NAME: String = "raid_excluded.cfg"
const RAID_SAVES_NAME: String = "raid_saves.cfg"
const RAID_META_SECTION: String = "raid"
const RAID_VERSION: int = 1
const RAID_KIND_EXCLUDED: String = "excluded"
const RAID_KIND_SAVES: String = "saves"
const RAID_LEVEL_PREFIX: String = "level."

var _dialog_result: String = ""
signal _dialog_completed


func _get_device_id() -> String:
	var uid: String = OS.get_unique_id()
	if uid.is_empty():
		return "?????"
	return uid.replace("{", "").replace("}", "").replace("-", "").substr(0, 5).to_lower()


func _on_export_button_pressed() -> void:
	if export_mode_dialog == null:
		_start_export(ExportMode.ALL_WITH_LIKED)
		return
	export_mode_dialog.visible = true


func hide_export_mode_dialog() -> void:
	if export_mode_dialog != null:
		export_mode_dialog.visible = false


func _on_export_mode_all_with_liked() -> void:
	_start_export(ExportMode.ALL_WITH_LIKED)


func _on_export_mode_liked_only() -> void:
	_start_export(ExportMode.LIKED_ONLY)


func _on_export_mode_all_only() -> void:
	_start_export(ExportMode.ALL_ONLY)


func _on_export_mode_all_with_liked_raid() -> void:
	_start_export(ExportMode.ALL_WITH_LIKED_RAID)


func _on_export_mode_all_with_liked_excluded() -> void:
	_start_export(ExportMode.ALL_WITH_LIKED_EXCLUDED)


func _start_export(mode: ExportMode) -> void:
	hide_export_mode_dialog()
	var msg: String = await export_levels(mode)
	_update_export_ui(msg)


func _on_import_button_pressed() -> void:
	var msg: String = await import_levels()
	_update_import_ui(msg)


## 结果提示统一走 autoload Notice（纯信息通知），不在场景里自建面板。
func _update_export_ui(msg: String) -> void:
	if msg.begins_with("导出成功"):
		Notice.show_notice("导出成功", "导出")
		emit_signal("export_succeeded")
	else:
		var text: String = "导出已取消" if msg.begins_with("导出已取消") else "导出失败"
		Notice.show_notice(text, "导出")
		emit_signal("export_failed")


func _update_import_ui(msg: String) -> void:
	if msg.begins_with("导入成功"):
		Notice.show_notice("导入成功", "导入")
		emit_signal("import_succeeded")
	else:
		var text: String = "导入已取消" if msg.begins_with("导入已取消") else "导入失败"
		Notice.show_notice(text, "导入")
		emit_signal("import_failed")


# ---------------------------------------------------------------------------
# 导出
# ---------------------------------------------------------------------------

func export_levels(mode: ExportMode) -> String:
	if mode == ExportMode.LIKED_ONLY:
		return await _export_liked_levels()
	if mode == ExportMode.ALL_WITH_LIKED_RAID:
		return await _export_all_levels(true, true, true)
	if mode == ExportMode.ALL_WITH_LIKED_EXCLUDED:
		return await _export_all_levels(true, true, false)
	if mode == ExportMode.ALL_WITH_LIKED:
		return await _export_all_levels(true)
	return await _export_all_levels(false)


func _export_all_levels(
	include_liked: bool, include_excluded: bool = false, include_raid_saves: bool = false
) -> String:
	var level_names: Array[String] = _list_root_levels()
	if level_names.is_empty():
		return "导出失败：目录中没有 .lvl 文件"

	var entries: Array[Dictionary] = []
	for file_name: String in level_names:
		entries.append({"archive": file_name, "source": USER_ROOT + file_name})

	if include_liked:
		_append_liked_entries(entries, level_names)
	if include_excluded:
		_append_raid_entries(entries, include_raid_saves)

	var tag: String = "all_liked" if include_liked else "history"
	if include_raid_saves:
		tag = "all_liked_raid"
	elif include_excluded:
		tag = "all_liked_excluded"
	return await _write_zip(entries, tag)


func _export_liked_levels() -> String:
	var liked_names: Array[String] = LikedCourses.get_files()
	var entries: Array[Dictionary] = []
	var included: Array[String] = []

	for file_name: String in liked_names:
		if not FileAccess.file_exists(USER_ROOT + file_name):
			continue
		included.append(file_name)
		entries.append({"archive": file_name, "source": USER_ROOT + file_name})

	if included.is_empty():
		return "导出失败：没有可导出的收藏关卡"

	_append_liked_index(entries, included)
	_append_liked_photos(entries, included)
	return await _write_zip(entries, "liked")


## 模式 1：把收藏索引与封面追加到「所有关卡」包里。
func _append_liked_entries(entries: Array[Dictionary], level_names: Array[String]) -> void:
	var liked_names: Array[String] = LikedCourses.get_files()
	var included: Array[String] = []
	for file_name: String in liked_names:
		if level_names.has(file_name):
			included.append(file_name)
	if included.is_empty():
		return
	_append_liked_index(entries, included)
	_append_liked_photos(entries, included)


func _append_liked_index(entries: Array[Dictionary], names: Array[String]) -> void:
	entries.append({"archive": LIKED_INDEX_NAME, "content": LikedCourses.build_index_text(names)})


func _append_liked_photos(entries: Array[Dictionary], names: Array[String]) -> void:
	for file_name: String in names:
		var photo_path: String = LikedCourses.photo_path(file_name)
		if not FileAccess.file_exists(photo_path):
			continue
		entries.append({
			"archive": LIKED_ARCHIVE_PREFIX + photo_path.get_file(),
			"source": photo_path,
		})


# ---------------------------------------------------------------------------
# 随心挑战数据（adventure.ini 子集）：排除名单 / 5 个存档位
# ---------------------------------------------------------------------------

## 模式 1 写两个 cfg，模式 2 只写排除名单的 cfg。
func _append_raid_entries(entries: Array[Dictionary], include_saves: bool) -> void:
	entries.append({"archive": RAID_EXCLUDED_NAME, "content": _build_raid_excluded_text()})
	if include_saves:
		entries.append({"archive": RAID_SAVES_NAME, "content": _build_raid_saves_text()})


func _raid_source() -> ConfigFile:
	if Adventure == null or Adventure.store == null:
		Log.w("ImportExport", "随心挑战存档未就绪，导出的数据为空")
		return null
	return Adventure.store.config


func _raid_header(out: ConfigFile, kind: String) -> void:
	out.set_value(RAID_META_SECTION, "version", RAID_VERSION)
	out.set_value(RAID_META_SECTION, "kind", kind)


## 只打包 [level.*] 里 excluded=true 的记录，不带单人样本统计。
func _build_raid_excluded_text() -> String:
	var out: ConfigFile = ConfigFile.new()
	_raid_header(out, RAID_KIND_EXCLUDED)
	var source: ConfigFile = _raid_source()
	if source != null:
		for section: String in source.get_sections():
			if not section.begins_with(RAID_LEVEL_PREFIX):
				continue
			if source.get_value(section, "excluded", false) != true:
				continue
			var key: String = section.trim_prefix(RAID_LEVEL_PREFIX)
			if not LikedCourses.is_valid_level_name(key):
				continue
			out.set_value(section, "file", source.get_value(section, "file", key))
			out.set_value(section, "excluded", true)
			out.set_value(section, "exclude_reason", source.get_value(section, "exclude_reason", ""))
			out.set_value(section, "excluded_at", source.get_value(section, "excluded_at", 0))
	return out.encode_to_text()


## 打包 [run.1]..[run.5] 的完整键，恢复时按槽位逐段写回。
func _build_raid_saves_text() -> String:
	var out: ConfigFile = ConfigFile.new()
	_raid_header(out, RAID_KIND_SAVES)
	var source: ConfigFile = _raid_source()
	if source != null:
		for slot: int in range(1, AdventureStore.MAX_RUN_SLOTS + 1):
			var section: String = "run.%d" % slot
			if not source.has_section(section):
				continue
			var keys: PackedStringArray = source.get_section_keys(section)
			if keys.is_empty():
				continue
			for key: String in keys:
				out.set_value(section, key, source.get_value(section, key))
	return out.encode_to_text()


func _list_root_levels() -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(USER_ROOT)
	if dir == null:
		return result
	for file_name: String in dir.get_files():
		if file_name.ends_with(".lvl"):
			result.append(file_name)
	return result


func _write_zip(entries: Array[Dictionary], tag: String) -> String:
	var dates: Array[String] = []
	for entry: Dictionary in entries:
		var archive_name: String = str(entry.get("archive", ""))
		if not archive_name.ends_with(".lvl"):
			continue
		var date_text: String = _extract_date(archive_name)
		if not date_text.is_empty():
			dates.append(date_text)

	var earliest: String = Time.get_date_string_from_system()
	var latest: String = earliest
	if not dates.is_empty():
		dates.sort()
		earliest = dates[0]
		latest = dates[dates.size() - 1]

	var device_id: String = _get_device_id()
	var zip_name: String = "%s_mfmp_%s_(%s_to_%s).zip" % [device_id, tag, earliest, latest]

	var default_path: String = ProjectSettings.globalize_path(USER_ROOT)
	var save_path: String = await _request_save_file(default_path, zip_name)
	if save_path.is_empty():
		return "导出已取消"

	var packer: ZIPPacker = ZIPPacker.new()
	var err: Error = packer.open(save_path)
	if err != OK:
		return "导出失败：无法创建压缩包（%s）" % error_string(err)

	var skipped: int = 0
	for entry: Dictionary in entries:
		var archive_name: String = str(entry.get("archive", ""))
		var data: PackedByteArray = PackedByteArray()

		if entry.has("content"):
			data = str(entry.get("content", "")).to_utf8_buffer()
		else:
			var source_path: String = str(entry.get("source", ""))
			var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
			if file == null:
				skipped += 1
				continue
			data = file.get_buffer(file.get_length())
			file.close()

		packer.start_file(archive_name)
		packer.write_file(data)
		packer.close_file()

	packer.close()

	if skipped > 0:
		return "导出成功：%s（已跳过 %d 个缺失文件）" % [save_path, skipped]
	return "导出成功：%s" % save_path


func _extract_date(file_name: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\d{4}-\\d{2}-\\d{2}")
	var result: RegExMatch = regex.search(file_name)
	if result == null:
		return ""
	return result.get_string()


# ---------------------------------------------------------------------------
# 导入：按条目类型分流，旧版平铺包自动转换
# ---------------------------------------------------------------------------

func import_levels() -> String:
	var default_path: String = ProjectSettings.globalize_path(USER_ROOT)
	var zip_path: String = await _request_open_file(default_path, "*.zip")
	if zip_path.is_empty():
		return "导入已取消"
	return _import_zip(zip_path)


## 从指定 zip 导入（与文件对话框解耦，便于无头验证）。
func _import_zip(zip_path: String) -> String:
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		return "导入失败：无法打开压缩包（%s）" % error_string(err)

	var file_list: PackedStringArray = reader.get_files()
	var has_index: bool = file_list.has(LIKED_INDEX_NAME)
	var index_names: Array[String] = []
	if has_index:
		index_names = _parse_index(reader.read_file(LIKED_INDEX_NAME))

	var raid_excluded: ConfigFile = _read_raid_config(reader, file_list, RAID_EXCLUDED_NAME, RAID_KIND_EXCLUDED)
	var raid_saves: ConfigFile = _read_raid_config(reader, file_list, RAID_SAVES_NAME, RAID_KIND_SAVES)

	var zip_levels: Array[String] = []
	var imported_count: int = 0
	var failed_count: int = 0
	if raid_excluded != null:
		imported_count += 1
	if raid_saves != null:
		imported_count += 1

	for entry_name: String in file_list:
		var entry_path: String = entry_name.replace("\\", "/")
		if entry_path.ends_with("/"):
			continue
		if entry_path == LIKED_INDEX_NAME:
			continue
		# 随心挑战数据已在上面解析，不走普通条目的落盘分支
		if entry_path == RAID_EXCLUDED_NAME or entry_path == RAID_SAVES_NAME:
			continue

		# 新版收藏封面：liked_courses/<base>.png
		if entry_path.begins_with(LIKED_ARCHIVE_PREFIX) and entry_path.ends_with(".png"):
			var png_name: String = entry_path.get_file()
			if not _is_valid_flat_file_name(png_name):
				failed_count += 1
				continue
			if not LikedCourses.ensure_folder():
				failed_count += 1
				continue
			if _write_archive_entry(reader, entry_name, LikedCourses.photo_path(png_name)):
				imported_count += 1
			else:
				failed_count += 1
			continue

		# 旧版平铺 png：收藏房间放收藏夹，历史房间放根目录
		if entry_path.ends_with(".png") and not entry_path.contains("/"):
			if not _is_valid_flat_file_name(entry_path):
				failed_count += 1
				continue
			var png_target: String = ""
			if is_liked_room:
				if not LikedCourses.ensure_folder():
					failed_count += 1
					continue
				png_target = LikedCourses.photo_path(entry_path)
			else:
				png_target = USER_ROOT + entry_path
			if _write_archive_entry(reader, entry_name, png_target):
				imported_count += 1
			else:
				failed_count += 1
			continue

		# 关卡：只接受 zip 根目录下的裸 .lvl
		if not entry_path.ends_with(".lvl") or entry_path.contains("/"):
			Log.w("ImportExport", "拒绝非法压缩包条目：%s" % entry_name)
			failed_count += 1
			continue
		if not LikedCourses.is_valid_level_name(entry_path):
			Log.w("ImportExport", "拒绝非法关卡文件名：%s" % entry_name)
			failed_count += 1
			continue

		zip_levels.append(entry_path)
		var level_target: String = USER_ROOT + entry_path
		if FileAccess.file_exists(level_target):
			# 同名关卡已存在：跳过不覆盖
			imported_count += 1
			continue
		if _write_archive_entry(reader, entry_name, level_target):
			imported_count += 1
		else:
			failed_count += 1

	reader.close()

	var restored_excluded: int = _restore_raid_excluded(raid_excluded)
	var restored_saves: int = _restore_raid_saves(raid_saves)
	var raid_note: String = ""
	if restored_excluded > 0 or restored_saves > 0:
		raid_note = "，恢复排除 %d / 存档 %d" % [restored_excluded, restored_saves]

	var favorites: Array[String] = []
	if has_index:
		# 以包内索引为准：模式 1 的包里包含全部关卡，不能把未收藏的也登记成收藏
		for file_name: String in index_names:
			if zip_levels.has(file_name) or FileAccess.file_exists(USER_ROOT + file_name):
				favorites.append(file_name)
	elif is_liked_room:
		# 旧版收藏包没有索引：包内全部关卡转为收藏
		for file_name: String in zip_levels:
			favorites.append(file_name)

	var added: int = 0
	if not favorites.is_empty():
		added = LikedCourses.add_many(favorites)

	if imported_count == 0:
		if failed_count > 0:
			return "导入失败：没有可导入的文件（跳过 %d）" % failed_count
		return "导入失败：压缩包中没有可用文件"

	emit_signal("import_finished")
	if failed_count > 0:
		return "导入成功：%d 个文件（新增收藏 %d，跳过 %d）%s" % [imported_count, added, failed_count, raid_note]
	return "导入成功：%d 个文件（新增收藏 %d）%s" % [imported_count, added, raid_note]


## 读取并校验包内随心挑战数据；不存在 / 损坏 / kind 不匹配都返回 null。
func _read_raid_config(
	reader: ZIPReader, file_list: PackedStringArray, entry_name: String, kind: String
) -> ConfigFile:
	if not file_list.has(entry_name):
		return null
	var data: PackedByteArray = reader.read_file(entry_name)
	if data.is_empty():
		Log.w("ImportExport", "压缩包内随心挑战数据为空：%s" % entry_name)
		return null
	var config: ConfigFile = ConfigFile.new()
	if config.parse(data.get_string_from_utf8()) != OK:
		Log.w("ImportExport", "随心挑战数据解析失败：%s" % entry_name)
		return null
	if config.get_value(RAID_META_SECTION, "kind", "") != kind:
		Log.w("ImportExport", "随心挑战数据类型不匹配：%s" % entry_name)
		return null
	return config


## 排除名单只增不减：本机已排除的关卡保留原有的 reason / 排除时间。
func _restore_raid_excluded(config: ConfigFile) -> int:
	if config == null or Adventure == null or Adventure.store == null:
		return 0
	var target: ConfigFile = Adventure.store.config
	var added: int = 0
	for section: String in config.get_sections():
		if not section.begins_with(RAID_LEVEL_PREFIX):
			continue
		var key: String = section.trim_prefix(RAID_LEVEL_PREFIX)
		if not LikedCourses.is_valid_level_name(key):
			continue
		if target.get_value(section, "excluded", false) == true:
			continue
		target.set_value(section, "file", config.get_value(section, "file", key))
		target.set_value(section, "excluded", true)
		target.set_value(section, "exclude_reason", config.get_value(section, "exclude_reason", ""))
		target.set_value(section, "excluded_at", config.get_value(section, "excluded_at", 0))
		added += 1
	if added > 0:
		Adventure.store.save()
		Log.i("ImportExport", ["已恢复随心挑战排除关卡：", added])
	return added


## 存档按槽位恢复；已有进行中团（active）的槽位跳过，避免覆盖本地进度。
func _restore_raid_saves(config: ConfigFile) -> int:
	if config == null or Adventure == null or Adventure.store == null:
		return 0
	var target: ConfigFile = Adventure.store.config
	var restored: int = 0
	for slot: int in range(1, AdventureStore.MAX_RUN_SLOTS + 1):
		var section: String = "run.%d" % slot
		if not config.has_section(section):
			continue
		if Adventure.store.is_run_occupied(slot):
			Log.w("ImportExport", ["存档位已有进行中的团，跳过恢复：", slot])
			continue
		if target.has_section(section):
			target.erase_section(section)
		for key: String in config.get_section_keys(section):
			target.set_value(section, key, config.get_value(section, key))
		restored += 1
	if restored > 0:
		Adventure.store.save()
		Log.i("ImportExport", ["已恢复随心挑战存档：", restored])
	return restored


func _parse_index(data: PackedByteArray) -> Array[String]:
	var result: Array[String] = []
	if data.is_empty():
		return result

	var config: ConfigFile = ConfigFile.new()
	if config.parse(data.get_string_from_utf8()) != OK:
		Log.w("ImportExport", "收藏索引解析失败，忽略包内索引")
		return result

	var stored: Variant = config.get_value("liked_courses", "files", [])
	if not stored is Array:
		return result
	var stored_array: Array = stored
	for item: Variant in stored_array:
		var file_name: String = str(item)
		if not LikedCourses.is_valid_level_name(file_name):
			continue
		if result.has(file_name):
			continue
		result.append(file_name)
	return result


func _is_valid_flat_file_name(file_name: String) -> bool:
	if file_name.is_empty():
		return false
	if file_name.contains("/") or file_name.contains("\\") or file_name.contains(":"):
		return false
	return not file_name.contains("..")


func _write_archive_entry(reader: ZIPReader, entry_name: String, target: String) -> bool:
	var data: PackedByteArray = reader.read_file(entry_name)
	if data.is_empty():
		Log.w("ImportExport", "压缩包条目为空或读取失败：%s" % entry_name)
		return false

	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		Log.e("ImportExport", "写入文件失败：%s（%s）" % [target, error_string(FileAccess.get_open_error())])
		return false
	file.store_buffer(data)
	file.close()
	return true


# ---------------------------------------------------------------------------
# 系统文件对话框
# ---------------------------------------------------------------------------

func _request_save_file(default_path: String, default_name: String) -> String:
	_dialog_result = ""
	DisplayServer.file_dialog_show(
		tr("导出"),
		default_path,
		default_name,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		["*.zip"],
		_on_dialog_callback
	)
	await _dialog_completed
	return _dialog_result


func _request_open_file(default_path: String, filter_str: String) -> String:
	_dialog_result = ""
	DisplayServer.file_dialog_show(
		tr("导入"),
		default_path,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		[filter_str],
		_on_dialog_callback
	)
	await _dialog_completed
	return _dialog_result


func _on_dialog_callback(status: bool, paths: PackedStringArray, _filter_idx: int) -> void:
	if status and paths.size() > 0:
		_dialog_result = paths[0]
	emit_signal("_dialog_completed")
