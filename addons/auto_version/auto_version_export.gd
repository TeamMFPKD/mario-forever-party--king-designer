@tool
extends EditorExportPlugin

func _export_begin(features, is_debug, path, flags):
    var utc_plus_8 = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system() + 8 * 3600)
    var version_str = "v%04d%02d%02d_%02d%02d" % [utc_plus_8.year, utc_plus_8.month, utc_plus_8.day, utc_plus_8.hour, utc_plus_8.minute]
    ProjectSettings.set_setting("application/config/version", version_str)
    ProjectSettings.save()
    print("[AutoVersion] 导出前自动更新版本号：", version_str)