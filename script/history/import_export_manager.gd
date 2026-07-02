extends Node

signal import_finished
signal import_succeeded
signal import_failed
signal export_succeeded
signal export_failed

@export var is_liked_room: bool = false
@export var hint_lable: Label

const LIKED_COURSE_FOLDER_NAME = "liked courses"

var _dialog_result: String = ""
signal _dialog_completed


func _get_source_path() -> String:
	return "user://" + (LIKED_COURSE_FOLDER_NAME + "/" if is_liked_room else "")


func _get_device_id() -> String:
	var uid = OS.get_unique_id()
	if uid.is_empty():
		return "?????"
	return uid.replace("{", "").replace("}", "").replace("-", "").substr(0, 5).to_lower()


func _on_export_button_pressed():
	var msg = await export_levels()
	_update_export_ui(msg)


func _on_import_button_pressed():
	var msg = await import_levels()
	_update_import_ui(msg)


func _update_export_ui(msg: String):
	if msg.begins_with("导出成功"):
		hint_lable.text = tr("导出成功")
		emit_signal("export_succeeded")
	else:
		hint_lable.text = tr("导出失败") if not msg.begins_with("导出已取消") else tr("导出已取消")
		emit_signal("export_failed")


func _update_import_ui(msg: String):
	if msg.begins_with("导入成功"):
		hint_lable.text = tr("导入成功")
		emit_signal("import_succeeded")
	else:
		hint_lable.text = tr("导入失败") if not msg.begins_with("导入已取消") else tr("导入已取消")
		emit_signal("import_failed")


func export_levels() -> String:
	var source = _get_source_path()
	var dir = DirAccess.open(source)
	if not dir:
		return "导出失败：无法打开目录 %s" % source

	var lvl_files = []
	var png_files = []
	dir.list_dir_begin()
	var f = dir.get_next()
	while not f.is_empty():
		if not dir.current_is_dir():
			if f.ends_with(".lvl"):
				lvl_files.append(f)
			elif f.ends_with(".png"):
				png_files.append(f)
		f = dir.get_next()
	dir.list_dir_end()

	if lvl_files.is_empty():
		return "导出失败：目录中没有 .lvl 文件"

	var regex = RegEx.new()
	regex.compile("\\d{4}-\\d{2}-\\d{2}")
	var dates = []
	for lf in lvl_files:
		var res = regex.search(lf)
		if res:
			dates.append(res.get_string())

	if dates.is_empty():
		return "导出失败：无法从文件名中提取日期"

	dates.sort()
	var earliest = dates[0]
	var latest = dates[-1]

	var device_id = _get_device_id()
	var liked_part = "liked_" if is_liked_room else ""
	var zip_name = "%s_mfmp_history_%s(%s_to_%s).zip" % [device_id, liked_part, earliest, latest]

	var default_path = ProjectSettings.globalize_path("user://")
	var save_path = await _request_save_file(default_path, zip_name)
	if save_path.is_empty():
		return "导出已取消"

	var packer = ZIPPacker.new()
	var err = packer.open(save_path)
	if err != OK:
		return "导出失败：无法创建压缩包（%s）" % error_string(err)

	var all_files = lvl_files + png_files
	for file_name in all_files:
		var file = FileAccess.open(source + file_name, FileAccess.READ)
		if not file:
			continue
		var data = file.get_buffer(file.get_length())
		file.close()
		packer.start_file(file_name)
		packer.write_file(data)
		packer.close_file()

	packer.close()
	return "导出成功：%s" % save_path


func import_levels() -> String:
	var default_path = ProjectSettings.globalize_path("user://")
	var zip_path = await _request_open_file(default_path, "*.zip")
	if zip_path.is_empty():
		return "导入已取消"

	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		return "导入失败：无法打开压缩包（%s）" % error_string(err)

	var target = _get_source_path()
	if is_liked_room:
		var d = DirAccess.open("user://")
		if d and not d.dir_exists(LIKED_COURSE_FOLDER_NAME):
			d.make_dir(LIKED_COURSE_FOLDER_NAME)

	var file_list = reader.get_files()
	var count = 0
	for file_name in file_list:
		var data = reader.read_file(file_name)
		if data.is_empty():
			continue
		var out = FileAccess.open(target + file_name, FileAccess.WRITE)
		if not out:
			continue
		out.store_buffer(data)
		out.close()
		count += 1

	reader.close()
	emit_signal("import_finished")
	return "导入成功：%d 个文件已解压到 %s" % [count, target]


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


func _on_dialog_callback(status: bool, paths: PackedStringArray, _filter_idx: int):
	if status and paths.size() > 0:
		_dialog_result = paths[0]
	emit_signal("_dialog_completed")
